-- Allow the two required inspection roles to read return headers, lines and inspection records.
DROP POLICY IF EXISTS sales_returns_select_permission ON public.sales_returns;
CREATE POLICY sales_returns_select_permission ON public.sales_returns
FOR SELECT TO authenticated
USING (
 (public.has_permission('RETURNS_VIEW') OR public.has_permission('RETURNS_CREATE')
  OR public.has_permission('RETURNS_APPROVE') OR public.has_permission('RETURNS_MANAGE')
  OR public.has_permission('INVENTORY_ADJUST') OR public.has_permission('PRODUCTION_MANAGE'))
 AND (
  public.get_current_user_role()::text<>'SALES_REP'
  OR sales_rep_id=public.get_current_sales_rep_id()
 )
);

DROP POLICY IF EXISTS return_items_view ON public.sales_return_items;
CREATE POLICY return_items_view ON public.sales_return_items
FOR SELECT TO authenticated
USING (
 (public.has_permission('RETURNS_VIEW') OR public.has_permission('RETURNS_MANAGE')
  OR public.has_permission('RETURNS_APPROVE') OR public.has_permission('INVENTORY_ADJUST')
  OR public.has_permission('PRODUCTION_MANAGE'))
 AND (
  public.get_current_user_role()::text<>'SALES_REP'
  OR EXISTS (
   SELECT 1 FROM public.sales_returns sr
   WHERE sr.sales_return_id=sales_return_items.sales_return_id
     AND sr.sales_rep_id=public.get_current_sales_rep_id()
  )
 )
);

DROP POLICY IF EXISTS sales_return_item_inspections_read ON public.sales_return_item_inspections;
CREATE POLICY sales_return_item_inspections_read ON public.sales_return_item_inspections
FOR SELECT TO authenticated
USING (
 public.has_permission('RETURNS_VIEW') OR public.has_permission('RETURNS_MANAGE')
 OR public.has_permission('RETURNS_APPROVE') OR public.has_permission('INVENTORY_VIEW')
 OR public.has_permission('INVENTORY_ADJUST') OR public.has_permission('PRODUCTION_VIEW')
 OR public.has_permission('PRODUCTION_MANAGE')
);

ALTER TABLE public.production_rework_consumptions DROP CONSTRAINT IF EXISTS production_rework_consumptions_movement_id_return_item_id_key;
CREATE INDEX IF NOT EXISTS production_rework_consumptions_movement_item_idx ON public.production_rework_consumptions(movement_id,return_item_id);
DO $migration$
DECLARE d text; oldtxt text; newtxt text; anchor text; extra text;
BEGIN
 d:=pg_get_functiondef('public.track_return_rework_consumption()'::regprocedure);
 oldtxt:=$old$ON CONFLICT(movement_id,return_item_id) DO NOTHING;$old$;
 IF position(oldtxt in d)=0 THEN RAISE EXCEPTION 'track_return_rework_consumption conflict clause changed'; END IF;
 EXECUTE replace(d,oldtxt,';');
 d:=pg_get_functiondef('public.execute_production_order_v6_internal_return_rework(bigint,numeric,jsonb,jsonb,jsonb,jsonb,date)'::regprocedure);
 oldtxt:=$old$LEFT JOIN public.products p
      ON p.product_id=(x.value->>'product_id')::bigint
     AND p.is_active=true
     AND p.can_be_produced=true
     AND p.product_type IN ('RAW','SEMI_FINISHED','FINISHED')$old$;
 newtxt:=$new$LEFT JOIN public.products p
      ON p.product_id=(x.value->>'product_id')::bigint
     AND p.is_active=true
     AND (p.can_be_produced=true OR (p.category_id=16 AND p.product_name LIKE 'طبق%'))
     AND p.product_type IN ('RAW','SEMI_FINISHED','FINISHED')$new$;
 IF position(oldtxt in d)=0 THEN RAISE EXCEPTION 'recovered product validation source changed'; END IF;
 d:=replace(d,oldtxt,newtxt);
 oldtxt:=$old$WHERE (e->>'base_quantity')::numeric<=0 OR (e->>'allocated_cost')::numeric<=0$old$;
 newtxt:=$new$WHERE (e->>'base_quantity')::numeric<0
                OR ((e->>'base_quantity')::numeric=0 AND jsonb_array_length(
                     CASE WHEN jsonb_typeof(e->'packaging_items')='array' THEN e->'packaging_items' ELSE '[]'::jsonb END
                   )=0)
                OR (e->>'allocated_cost')::numeric<=0$new$;
 IF position(oldtxt in d)=0 THEN RAISE EXCEPTION 'abnormal/recovered waste validation source changed'; END IF;
 d:=replace(d,oldtxt,newtxt);
 anchor:=$anchor$  IF p_abnormal_waste IS NULL OR jsonb_typeof(p_abnormal_waste)<>'array' THEN
    RAISE EXCEPTION 'بيانات الهالك غير الطبيعي يجب أن تكون قائمة';
  END IF;$anchor$;
 extra:=$extra$  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_abnormal_waste) w
    WHERE w ? 'packaging_items'
      AND jsonb_typeof(w->'packaging_items') NOT IN ('array','null')
  ) THEN
    RAISE EXCEPTION 'مستلزمات التغليف التالفة يجب أن تكون قائمة';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_abnormal_waste) w
    CROSS JOIN LATERAL jsonb_array_elements(
      CASE WHEN jsonb_typeof(w->'packaging_items')='array' THEN w->'packaging_items' ELSE '[]'::jsonb END
    ) pi
    LEFT JOIN public.products p
      ON p.product_id=NULLIF(pi->>'product_id','')::bigint
     AND p.is_active=true AND p.product_type='RAW' AND p.category_id=16
    WHERE p.product_id IS NULL OR NULLIF(pi->>'quantity','') IS NULL
       OR (pi->>'quantity')::numeric<=0
       OR NULLIF(pi->>'unit_id','')::bigint IS DISTINCT FROM p.base_unit_id
  ) THEN
    RAISE EXCEPTION 'مستلزم التعبئة التالف غير نشط أو غير تابع لتصنيف التعبئة أو كميته ووحدته غير صحيحتين';
  END IF;$extra$;
 IF position(anchor in d)=0 THEN RAISE EXCEPTION 'abnormal waste array validation anchor changed'; END IF;
 d:=replace(d,anchor,anchor||chr(10)||extra);
 EXECUTE d;
 d:=pg_get_functiondef('public.record_sales_return_item_inspection(bigint,text,text,text)'::regprocedure);
 oldtxt:=$old$IF NOT FOUND OR v_item.status<>'POSTED' THEN$old$;
 newtxt:=$new$IF NOT FOUND OR v_item.status NOT IN ('POSTED','APPROVED') THEN$new$;
 IF position(oldtxt in d)=0 THEN RAISE EXCEPTION 'inspection status source changed'; END IF;
 EXECUTE replace(d,oldtxt,newtxt);
 d:=pg_get_functiondef('public.create_return_item_holds()'::regprocedure);
 oldtxt:=$old$IF v_status NOT IN('DRAFT','POSTED') THEN RETURN NEW; END IF;$old$;
 newtxt:=$new$IF v_status IS NULL OR v_status='CANCELLED' THEN RETURN NEW; END IF;$new$;
 IF position(oldtxt in d)=0 THEN RAISE EXCEPTION 'return hold status source changed'; END IF;
 EXECUTE replace(d,oldtxt,newtxt);
 d:=pg_get_functiondef('public.guard_sales_return_cancel_after_rework()'::regprocedure);
 oldtxt:=$old$OLD.status='POSTED'$old$;
 newtxt:=$new$OLD.status IN ('POSTED','APPROVED')$new$;
 IF position(oldtxt in d)=0 THEN RAISE EXCEPTION 'return cancel status source changed'; END IF;
 EXECUTE replace(d,oldtxt,newtxt);
END
$migration$;

-- Keep all security-definer entry points restricted to authenticated callers.
REVOKE ALL ON FUNCTION public.settle_trip(bigint,bigint) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.create_stock_transfer(bigint,bigint,date,jsonb,text,uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.execute_production_order_v6(bigint,numeric,jsonb,jsonb,jsonb,jsonb,date) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.cancel_sales_return(bigint,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.create_return_item_holds() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.cleanup_sales_return_holds_on_cancel() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.guard_sales_return_cancel_after_rework() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.track_return_rework_consumption() FROM PUBLIC,anon;
