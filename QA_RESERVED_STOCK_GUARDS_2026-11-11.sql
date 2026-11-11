-- Applied to the MeatManagement Supabase project on 2026-11-11.
-- Protect active stock reservations from every authenticated stock-out path.
-- The helper is internal and is not executable through the public API.

CREATE OR REPLACE FUNCTION public.assert_stock_available(
  p_location_id bigint,
  p_product_id bigint,
  p_quantity numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
DECLARE
  v_on_hand numeric;
  v_reserved numeric;
BEGIN
  IF p_location_id IS NULL OR p_product_id IS NULL
     OR p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'بيانات فحص الكمية المتاحة غير صحيحة';
  END IF;

  SELECT sb.quantity INTO v_on_hand
  FROM public.stock_balances sb
  WHERE sb.location_id=p_location_id AND sb.product_id=p_product_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'لا يوجد رصيد مخزون للصنف رقم % في الموقع المحدد',p_product_id;
  END IF;

  SELECT COALESCE(SUM(r.quantity),0) INTO v_reserved
  FROM public.reservations r
  WHERE r.location_id=p_location_id
    AND r.product_id=p_product_id
    AND r.status='ACTIVE'
    AND (r.reserved_until IS NULL OR r.reserved_until>=CURRENT_DATE);

  IF v_on_hand-v_reserved < p_quantity THEN
    RAISE EXCEPTION
      'الكمية المتاحة غير المحجوزة للصنف رقم % هي %، والمطلوب %',
      p_product_id,GREATEST(v_on_hand-v_reserved,0),p_quantity;
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.assert_stock_available(bigint,bigint,numeric)
FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE
  v_definition text;
BEGIN
  SELECT pg_get_functiondef('public.create_sales_invoice_v2(bigint,bigint,date,numeric,text,jsonb,bigint,jsonb)'::regprocedure) INTO v_definition;
  IF strpos(v_definition,'IF v_current_stock < v_base_qty THEN
            RAISE EXCEPTION
                ''الرصيد غير كافٍ للمنتج رقم %. المتاح: %، المطلوب: %.'',
                v_product_id,
                v_current_stock,
                v_base_qty;')=0 THEN
    RAISE EXCEPTION 'Unexpected create_sales_invoice_v2 stock check';
  END IF;
  v_definition:=replace(v_definition,
    'IF v_current_stock < v_base_qty THEN
            RAISE EXCEPTION
                ''الرصيد غير كافٍ للمنتج رقم %. المتاح: %، المطلوب: %.'',
                v_product_id,
                v_current_stock,
                v_base_qty;',
    'PERFORM public.assert_stock_available(p_location_id,v_product_id,v_base_qty);
        IF v_current_stock < v_base_qty THEN
            RAISE EXCEPTION
                ''الرصيد غير كافٍ للمنتج رقم %. المتاح: %، المطلوب: %.'',
                v_product_id,
                v_current_stock,
                v_base_qty;');
  EXECUTE v_definition;

  SELECT pg_get_functiondef('public.create_stock_transfer(bigint,bigint,date,jsonb,text,uuid)'::regprocedure) INTO v_definition;
  IF strpos(v_definition,'if not found or v_source_quantity<v_quantity then raise exception ''الرصيد غير كافٍ للصنف رقم %'',v_product_id; end if;')=0 THEN
    RAISE EXCEPTION 'Unexpected create_stock_transfer stock check';
  END IF;
  v_definition:=replace(v_definition,
    'if not found or v_source_quantity<v_quantity then raise exception ''الرصيد غير كافٍ للصنف رقم %'',v_product_id; end if;',
    'PERFORM public.assert_stock_available(p_source_location_id,v_product_id,v_quantity);
        if not found or v_source_quantity<v_quantity then raise exception ''الرصيد غير كافٍ للصنف رقم %'',v_product_id; end if;');
  EXECUTE v_definition;

  SELECT pg_get_functiondef('public.confirm_trip_load_dispatch(bigint,numeric,uuid)'::regprocedure) INTO v_definition;
  IF strpos(v_definition,'if not found or v_source_balance<v_actual_weight then')=0 THEN
    RAISE EXCEPTION 'Unexpected confirm_trip_load_dispatch stock check';
  END IF;
  v_definition:=replace(v_definition,
    'if not found or v_source_balance<v_actual_weight then',
    'PERFORM public.assert_stock_available(v_trip.source_location_id,v_load.product_id,v_actual_weight);
  if not found or v_source_balance<v_actual_weight then');
  EXECUTE v_definition;

  SELECT pg_get_functiondef('public.execute_production_order_v5(bigint,numeric,jsonb,jsonb,jsonb,date)'::regprocedure) INTO v_definition;
  IF strpos(v_definition,'AND product_id=v_material.raw_product_id;

      IF COALESCE(v_current,0)<v_base THEN')=0 THEN
    RAISE EXCEPTION 'Unexpected execute_production_order_v5 stock check';
  END IF;
  v_definition:=replace(v_definition,
    'AND product_id=v_material.raw_product_id;

      IF COALESCE(v_current,0)<v_base THEN',
    'AND product_id=v_material.raw_product_id
      FOR UPDATE;

      PERFORM public.assert_stock_available(v_order.factory_location_id,v_material.raw_product_id,v_base);
      IF COALESCE(v_current,0)<v_base THEN');
  EXECUTE v_definition;

  SELECT pg_get_functiondef('public.create_purchase_return(bigint,bigint,date,jsonb,text,text,bigint,uuid)'::regprocedure) INTO v_definition;
  IF strpos(v_definition,'IF v_stock_quantity < v_stock.required_quantity THEN')=0 THEN
    RAISE EXCEPTION 'Unexpected create_purchase_return stock check';
  END IF;
  v_definition:=replace(v_definition,
    'IF v_stock_quantity < v_stock.required_quantity THEN',
    'PERFORM public.assert_stock_available(v_location_id,v_stock.product_id,v_stock.required_quantity);
        IF v_stock_quantity < v_stock.required_quantity THEN');
  EXECUTE v_definition;

  SELECT pg_get_functiondef('public.settle_trip(bigint,bigint)'::regprocedure) INTO v_definition;
  IF strpos(v_definition,'            IF v_vehicle_unit_cost<0 THEN')=0 THEN
    RAISE EXCEPTION 'Unexpected settle_trip stock logic';
  END IF;
  v_definition:=replace(v_definition,
    '            IF v_vehicle_unit_cost<0 THEN',
    '            PERFORM public.assert_stock_available(v_trip.vehicle_location_id,v_stock.product_id,v_stock.remaining_quantity);
            IF v_vehicle_unit_cost<0 THEN');
  EXECUTE v_definition;

  SELECT pg_get_functiondef('public.set_stock_balance(bigint,bigint,numeric,text)'::regprocedure) INTO v_definition;
  IF strpos(v_definition,'  IF v_diff = 0 THEN
    RETURN;
  END IF;')=0 THEN
    RAISE EXCEPTION 'Unexpected set_stock_balance difference check';
  END IF;
  v_definition:=replace(v_definition,
    '  IF v_diff = 0 THEN
    RETURN;
  END IF;',
    '  IF v_diff = 0 THEN
    RETURN;
  END IF;

  IF v_diff < 0 THEN
    PERFORM public.assert_stock_available(p_location_id,p_product_id,ABS(v_diff));
  END IF;');
  EXECUTE v_definition;
END
$migration$;

-- Close additional stock-out and reversal paths.
DO $migration$
DECLARE
  v_definition text;
BEGIN
  SELECT pg_get_functiondef('public.reverse_production_order(bigint,text)'::regprocedure)
    INTO v_definition;
  IF strpos(v_definition,'COALESCE(sb.quantity, 0) - COALESCE(sb.reserved_quantity, 0)')=0
     OR strpos(v_definition,'  LOOP
    UPDATE public.stock_balances
    SET quantity = quantity - v_original.quantity_change,')=0 THEN
    RAISE EXCEPTION 'Unexpected reverse_production_order stock logic';
  END IF;
  v_definition:=replace(
    v_definition,
    'COALESCE(sb.quantity, 0) - COALESCE(sb.reserved_quantity, 0)',
    'COALESCE(sb.quantity, 0)'
  );
  v_definition:=replace(
    v_definition,
    '  LOOP
    UPDATE public.stock_balances
    SET quantity = quantity - v_original.quantity_change,',
    '  LOOP
    IF v_original.quantity_change > 0 THEN
      PERFORM public.assert_stock_available(
        v_original.location_id,
        v_original.product_id,
        v_original.quantity_change
      );
    END IF;

    UPDATE public.stock_balances
    SET quantity = quantity - v_original.quantity_change,'
  );
  EXECUTE v_definition;

  SELECT pg_get_functiondef('public.cancel_sales_return(bigint,text)'::regprocedure)
    INTO v_definition;
  IF strpos(v_definition,'    v_new_stock:=v_new_stock-v_qty.quantity;')=0 THEN
    RAISE EXCEPTION 'Unexpected cancel_sales_return stock logic';
  END IF;
  v_definition:=replace(
    v_definition,
    '    v_new_stock:=v_new_stock-v_qty.quantity;',
    '    PERFORM public.assert_stock_available(v_qty.location_id,v_qty.product_id,v_qty.quantity);
    v_new_stock:=v_new_stock-v_qty.quantity;'
  );
  EXECUTE v_definition;

  SELECT pg_get_functiondef('public.cancel_partner_inventory_contribution(bigint,text,boolean,uuid)'::regprocedure)
    INTO v_definition;
  IF strpos(v_definition,'  IF NOT FOUND OR v_balance.quantity+0.000001<v_row.base_quantity THEN')=0 THEN
    RAISE EXCEPTION 'Unexpected cancel_partner_inventory_contribution stock logic';
  END IF;
  v_definition:=replace(
    v_definition,
    '  IF NOT FOUND OR v_balance.quantity+0.000001<v_row.base_quantity THEN',
    '  PERFORM public.assert_stock_available(v_row.location_id,v_row.product_id,v_row.base_quantity);
  IF NOT FOUND OR v_balance.quantity+0.000001<v_row.base_quantity THEN'
  );
  EXECUTE v_definition;
END
$migration$;
