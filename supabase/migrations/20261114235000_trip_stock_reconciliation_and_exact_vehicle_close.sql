DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  v_def := pg_get_functiondef('public.settle_trip(bigint,bigint)'::regprocedure);

  v_old := $old$    v_sub_balance numeric;$old$;
  v_new := $new$    v_sub_balance numeric;
    v_unsettled_product_id bigint;
    v_unsettled_quantity numeric;$new$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'settle_trip declaration anchor not found';
  END IF;
  v_def := replace(v_def,v_old,v_new);

  v_def := replace(v_def,'بالكيلوجرام','بوحدة الأساس');
  v_def := replace(v_def,'كجم','بوحدة الأساس');

  v_old := $old$    END LOOP;

    IF v_cash_due > 0 THEN$old$;
  v_new := $new$    END LOOP;

    SELECT sb.product_id, sb.quantity
    INTO v_unsettled_product_id, v_unsettled_quantity
    FROM public.stock_balances sb
    WHERE sb.location_id = v_trip.vehicle_location_id
      AND ABS(COALESCE(sb.quantity,0)) > 0.000001
    ORDER BY sb.product_id
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        RAISE EXCEPTION 'لا يمكن إغلاق الجولة: ما زال يوجد رصيد غير محسوب في السيارة للصنف رقم %، الكمية % بوحدة الأساس',
            v_unsettled_product_id, v_unsettled_quantity;
    END IF;

    IF v_cash_due > 0 THEN$new$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'settle_trip final vehicle balance guard anchor not found';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.get_trip_returns(bigint)'::regprocedure);
  v_old := $old$AND sr.status = 'POSTED'$old$;
  v_new := $new$AND sr.status IN ('POSTED', 'APPROVED')$new$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'get_trip_returns status filter not found';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END;
$migration$;

CREATE OR REPLACE FUNCTION public.get_trip_stock_reconciliation(p_trip_id bigint)
RETURNS TABLE(
  product_id bigint,
  product_code character varying,
  product_name character varying,
  base_unit_name character varying,
  loaded_quantity numeric,
  sold_quantity numeric,
  returned_quantity numeric,
  exchanged_quantity numeric,
  previously_received_quantity numeric,
  calculated_remaining numeric,
  vehicle_quantity numeric,
  quantity_difference numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_trip public.trips%ROWTYPE;
  v_role text;
  v_sales_rep_id bigint;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;
  IF NOT public.has_permission('TRIPS_VIEW') THEN
    RAISE EXCEPTION 'لا تملك صلاحية عرض حركة الجولات';
  END IF;
  IF p_trip_id IS NULL THEN
    RAISE EXCEPTION 'يجب تحديد الجولة';
  END IF;

  SELECT * INTO v_trip
  FROM public.trips
  WHERE trip_id=p_trip_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الجولة غير موجودة';
  END IF;

  v_role := public.get_current_user_role();
  v_sales_rep_id := public.get_current_sales_rep_id();

  IF v_role='SALES_REP'
     AND (v_sales_rep_id IS NULL OR v_sales_rep_id IS DISTINCT FROM v_trip.sales_rep_id) THEN
    RAISE EXCEPTION 'لا يمكنك عرض مطابقة مخزون جولة مندوب آخر';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.sales_invoice_items sii
    JOIN public.sales_invoices si ON si.sales_invoice_id=sii.sales_invoice_id
    WHERE si.trip_id=p_trip_id
      AND si.status NOT IN ('DRAFT','CANCELLED')
      AND sii.base_quantity IS NULL
  ) THEN
    RAISE EXCEPTION 'توجد بنود بيع دون كمية محفوظة بوحدة الأساس';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.sales_return_items sri
    JOIN public.sales_returns sr ON sr.sales_return_id=sri.sales_return_id
    WHERE sr.trip_id=p_trip_id
      AND sr.status IN ('POSTED','APPROVED')
      AND sri.base_quantity IS NULL
  ) THEN
    RAISE EXCEPTION 'توجد بنود مرتجعات دون كمية محفوظة بوحدة الأساس';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.sales_return_exchange_items sei
    JOIN public.sales_returns sr ON sr.sales_return_id=sei.sales_return_id
    WHERE sr.trip_id=p_trip_id
      AND sr.status IN ('POSTED','APPROVED')
      AND sei.base_quantity IS NULL
  ) THEN
    RAISE EXCEPTION 'توجد بنود استبدال دون كمية محفوظة بوحدة الأساس';
  END IF;

  RETURN QUERY
  WITH product_ids AS (
    SELECT tl.product_id
    FROM public.trip_loads tl
    WHERE tl.trip_id=p_trip_id
      AND tl.load_status='LOADED'
    UNION
    SELECT sii.product_id
    FROM public.sales_invoice_items sii
    JOIN public.sales_invoices si ON si.sales_invoice_id=sii.sales_invoice_id
    WHERE si.trip_id=p_trip_id
      AND si.status NOT IN ('DRAFT','CANCELLED')
    UNION
    SELECT sri.product_id
    FROM public.sales_return_items sri
    JOIN public.sales_returns sr ON sr.sales_return_id=sri.sales_return_id
    WHERE sr.trip_id=p_trip_id
      AND sr.status IN ('POSTED','APPROVED')
    UNION
    SELECT sei.product_id
    FROM public.sales_return_exchange_items sei
    JOIN public.sales_returns sr ON sr.sales_return_id=sei.sales_return_id
    WHERE sr.trip_id=p_trip_id
      AND sr.status IN ('POSTED','APPROVED')
    UNION
    SELECT sb.product_id
    FROM public.stock_balances sb
    WHERE sb.location_id=v_trip.vehicle_location_id
      AND ABS(COALESCE(sb.quantity,0))>0.000001
  ),
  loaded AS (
    SELECT tl.product_id,SUM(tl.quantity_loaded) AS qty
    FROM public.trip_loads tl
    WHERE tl.trip_id=p_trip_id
      AND tl.load_status='LOADED'
    GROUP BY tl.product_id
  ),
  sold AS (
    SELECT sii.product_id,SUM(sii.base_quantity) AS qty
    FROM public.sales_invoice_items sii
    JOIN public.sales_invoices si ON si.sales_invoice_id=sii.sales_invoice_id
    WHERE si.trip_id=p_trip_id
      AND si.status NOT IN ('DRAFT','CANCELLED')
    GROUP BY sii.product_id
  ),
  returned AS (
    SELECT sri.product_id,SUM(sri.base_quantity) AS qty
    FROM public.sales_return_items sri
    JOIN public.sales_returns sr ON sr.sales_return_id=sri.sales_return_id
    WHERE sr.trip_id=p_trip_id
      AND sr.status IN ('POSTED','APPROVED')
      AND sri.location_id=v_trip.vehicle_location_id
    GROUP BY sri.product_id
  ),
  exchanged AS (
    SELECT sei.product_id,SUM(sei.base_quantity) AS qty
    FROM public.sales_return_exchange_items sei
    JOIN public.sales_returns sr ON sr.sales_return_id=sei.sales_return_id
    WHERE sr.trip_id=p_trip_id
      AND sr.status IN ('POSTED','APPROVED')
    GROUP BY sei.product_id
  ),
  previously_received AS (
    SELECT sm.product_id,SUM(sm.quantity_change) AS qty
    FROM public.stock_movements sm
    WHERE sm.trip_id=p_trip_id
      AND sm.location_id=v_trip.source_location_id
      AND sm.movement_type='RECEIVE'
      AND sm.notes LIKE 'استلام فائض جولة %'
    GROUP BY sm.product_id
  ),
  vehicle AS (
    SELECT sb.product_id,SUM(sb.quantity) AS qty
    FROM public.stock_balances sb
    WHERE sb.location_id=v_trip.vehicle_location_id
    GROUP BY sb.product_id
  ),
  calculated AS (
    SELECT
      ids.product_id,
      COALESCE(l.qty,0) AS loaded_qty,
      COALESCE(s.qty,0) AS sold_qty,
      COALESCE(r.qty,0) AS returned_qty,
      COALESCE(e.qty,0) AS exchanged_qty,
      COALESCE(pr.qty,0) AS received_qty,
      COALESCE(l.qty,0)-COALESCE(s.qty,0)+COALESCE(r.qty,0)
        -COALESCE(e.qty,0)-COALESCE(pr.qty,0) AS remaining_qty,
      COALESCE(v.qty,0) AS vehicle_qty
    FROM product_ids ids
    LEFT JOIN loaded l ON l.product_id=ids.product_id
    LEFT JOIN sold s ON s.product_id=ids.product_id
    LEFT JOIN returned r ON r.product_id=ids.product_id
    LEFT JOIN exchanged e ON e.product_id=ids.product_id
    LEFT JOIN previously_received pr ON pr.product_id=ids.product_id
    LEFT JOIN vehicle v ON v.product_id=ids.product_id
  )
  SELECT
    c.product_id,
    p.product_code,
    p.product_name,
    COALESCE(u.unit_name,'غير محدد')::character varying,
    c.loaded_qty::numeric,
    c.sold_qty::numeric,
    c.returned_qty::numeric,
    c.exchanged_qty::numeric,
    c.received_qty::numeric,
    c.remaining_qty::numeric,
    c.vehicle_qty::numeric,
    (c.vehicle_qty-c.remaining_qty)::numeric
  FROM calculated c
  JOIN public.products p ON p.product_id=c.product_id
  LEFT JOIN public.units u ON u.unit_id=p.base_unit_id
  ORDER BY p.product_name,p.product_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_trip_stock_reconciliation(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_trip_stock_reconciliation(bigint) TO authenticated;