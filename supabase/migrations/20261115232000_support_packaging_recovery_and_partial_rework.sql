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
  OR sales_rep_id IS NOT DISTINCT FROM public.get_current_sales_rep_id()
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
     AND sr.sales_rep_id IS NOT DISTINCT FROM public.get_current_sales_rep_id()
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


-- Reverse any previously recorded scrap movement before the original return is cancelled.
DO $cancel_scrap$
DECLARE d text; anchor text; addition text;
BEGIN
 d:=pg_get_functiondef('public.cancel_sales_return_internal_return_hold(bigint,text)'::regprocedure);
 anchor:=$anchor$  -- Remove goods previously received as a return.$anchor$;
 addition:=$addition$  -- Restore scrapped returned stock first so the original return can be fully reversed.
  FOR v_qty IN
    SELECT sm.movement_id,sm.location_id,sm.product_id,sm.quantity_change,
           sm.unit_cost,sm.total_cost,sm.sales_return_item_id
    FROM public.stock_movements sm
    WHERE sm.sales_return_id=p_sales_return_id
      AND sm.movement_type='ISSUE'
      AND sm.notes LIKE 'هالك مرتجع %'
      AND sm.reversal_of_movement_id IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.stock_movements rev
        WHERE rev.reversal_of_movement_id=sm.movement_id
      )
    ORDER BY sm.movement_id
  LOOP
    INSERT INTO public.stock_balances(location_id,product_id,quantity,updated_at)
    VALUES(v_qty.location_id,v_qty.product_id,0,now())
    ON CONFLICT(location_id,product_id) DO NOTHING;

    UPDATE public.stock_balances
    SET quantity=quantity+ABS(v_qty.quantity_change),updated_at=now()
    WHERE location_id=v_qty.location_id AND product_id=v_qty.product_id
    RETURNING quantity INTO v_new_stock;

    INSERT INTO public.stock_movements(
      location_id,product_id,movement_type,quantity_change,quantity_after,
      notes,created_by,trip_id,sales_return_id,sales_return_item_id,
      unit_cost,total_cost,reversal_of_movement_id
    )
    VALUES(
      v_qty.location_id,v_qty.product_id,'RETURN',ABS(v_qty.quantity_change),v_new_stock,
      'عكس هالك مرتجع '||v_return.return_number,auth.uid(),v_return.trip_id,
      p_sales_return_id,v_qty.sales_return_item_id,v_qty.unit_cost,
      v_qty.total_cost,v_qty.movement_id
    );
  END LOOP;

$addition$;
 IF position(anchor in d)=0 THEN RAISE EXCEPTION 'cancel_sales_return scrap reversal anchor changed'; END IF;
 EXECUTE replace(d,anchor,addition||anchor);
END
$cancel_scrap$;


-- Cancel each returned line at its current held/inspected location, preserving item-level lot links.
DO $cancel_location$
DECLARE d text; oldtxt text; newtxt text; s integer; e integer;
BEGIN
 d:=pg_get_functiondef('public.cancel_sales_return_internal_return_hold(bigint,text)'::regprocedure);
 s:=strpos(d,'  -- Remove goods previously received as a return.');
 IF s=0 THEN RAISE EXCEPTION 'cancel return removal section changed'; END IF;
 s:=strpos(d,'  FOR v_qty IN',s);
 IF s=0 THEN RAISE EXCEPTION 'cancel return item loop changed'; END IF;
 e:=s+strpos(substr(d,s),'  END LOOP;')+length('  END LOOP;')-1;
 newtxt:=$new$  FOR v_qty IN
    SELECT sri.return_item_id,
           COALESCE(active_res.location_id,i.received_location_id,sri.location_id) AS location_id,
           sri.product_id,sri.base_quantity AS quantity
    FROM public.sales_return_items sri
    LEFT JOIN public.sales_return_item_inspections i ON i.return_item_id=sri.return_item_id
    LEFT JOIN LATERAL (
      SELECT rr.location_id
      FROM public.reservations rr
      WHERE rr.source_return_item_id=sri.return_item_id
        AND rr.status='ACTIVE'
        AND (rr.notes LIKE 'RETURN_PENDING:%' OR rr.notes LIKE 'RETURN_REWORK:%')
      ORDER BY rr.created_at DESC,rr.reservation_id DESC
      LIMIT 1
    ) active_res ON true
    WHERE sri.sales_return_id=p_sales_return_id
    ORDER BY location_id,sri.product_id,sri.return_item_id
    FOR UPDATE OF sri
  LOOP
    SELECT quantity INTO v_new_stock
    FROM public.stock_balances
    WHERE location_id=v_qty.location_id AND product_id=v_qty.product_id
    FOR UPDATE;

    IF NOT FOUND OR v_new_stock<v_qty.quantity THEN
      RAISE EXCEPTION 'رصيد المرتجع لا يكفي لعكس الصنف % في الموقع %.',
        v_qty.product_id,v_qty.location_id;
    END IF;

    PERFORM public.assert_stock_available(v_qty.location_id,v_qty.product_id,v_qty.quantity);
    v_new_stock:=v_new_stock-v_qty.quantity;

    UPDATE public.stock_balances
    SET quantity=v_new_stock,updated_at=now()
    WHERE location_id=v_qty.location_id AND product_id=v_qty.product_id;

    INSERT INTO public.stock_movements(
      location_id,product_id,movement_type,quantity_change,
      quantity_after,notes,created_by,trip_id,sales_return_id,sales_return_item_id
    )
    VALUES(
      v_qty.location_id,v_qty.product_id,'ISSUE',-v_qty.quantity,
      v_new_stock,'عكس استلام المرتجع '||v_return.return_number,
      auth.uid(),v_return.trip_id,p_sales_return_id,v_qty.return_item_id
    );
  END LOOP;$new$;
 d:=substr(d,1,s-1)||newtxt||substr(d,e+1);
 EXECUTE d;

 d:=pg_get_functiondef('public.sync_stock_movement_lots()'::regprocedure);
 oldtxt:=$old$WHERE source_movement.sales_return_id=NEW.sales_return_id
        AND source_movement.location_id=NEW.location_id
        AND source_movement.product_id=NEW.product_id
        AND (NEW.sales_return_item_id IS NULL OR source_movement.sales_return_item_id=NEW.sales_return_item_id)$old$;
 newtxt:=$new$WHERE source_movement.sales_return_id=NEW.sales_return_id
        AND source_movement.product_id=NEW.product_id
        AND (NEW.sales_return_item_id IS NULL OR source_movement.sales_return_item_id=NEW.sales_return_item_id)$new$;
 IF position(oldtxt in d)=0 THEN RAISE EXCEPTION 'sync return lot location filter changed'; END IF;
 EXECUTE replace(d,oldtxt,newtxt);
END
$cancel_location$;

-- Keep all security-definer entry points restricted to authenticated callers.
REVOKE ALL ON FUNCTION public.settle_trip(bigint,bigint) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.create_stock_transfer(bigint,bigint,date,jsonb,text,uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.execute_production_order_v6(bigint,numeric,jsonb,jsonb,jsonb,jsonb,date) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.cancel_sales_return(bigint,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.create_return_item_holds() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.cleanup_sales_return_holds_on_cancel() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.guard_sales_return_cancel_after_rework() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.track_return_rework_consumption() FROM PUBLIC,anon;
