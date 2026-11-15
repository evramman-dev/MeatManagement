CREATE OR REPLACE FUNCTION public.set_stock_opening_balance(p_location_id bigint, p_product_id bigint, p_base_quantity numeric, p_unit_cost numeric)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_balance record;
  v_movement_id bigint;
  v_total_cost numeric(18,4);
  v_entry_id bigint;
  v_product_name text;
  v_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;

  SELECT r.role_code
    INTO v_role
  FROM public.app_users u
  JOIN public.app_roles r ON r.role_id = u.role_id
  WHERE u.user_id = auth.uid()
    AND u.is_active = true
    AND r.is_active = true;

  IF v_role IS DISTINCT FROM 'SYSTEM_ADMIN' THEN
    RAISE EXCEPTION 'تسجيل الرصيد الافتتاحي للمخزون متاح لمدير النظام فقط';
  END IF;
  PERFORM pg_advisory_xact_lock(947351);
  PERFORM public.assert_accounting_period_open(CURRENT_DATE);

  IF p_location_id IS NULL OR p_product_id IS NULL
     OR p_base_quantity IS NULL OR p_base_quantity <= 0
     OR p_unit_cost IS NULL OR p_unit_cost <= 0 THEN
    RAISE EXCEPTION 'بيانات كمية أو تكلفة الرصيد الافتتاحي غير صحيحة';
  END IF;

  PERFORM 1 FROM public.locations
  WHERE location_id = p_location_id AND is_active = true
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'الموقع غير موجود أو غير نشط';
  END IF;

  SELECT product_name INTO v_product_name
  FROM public.products
  WHERE product_id = p_product_id AND is_active = true
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'المنتج غير موجود أو غير نشط';
  END IF;

  INSERT INTO public.stock_balances(location_id, product_id, quantity, average_unit_cost, inventory_value)
  VALUES (p_location_id, p_product_id, 0, 0, 0)
  ON CONFLICT (location_id, product_id) DO NOTHING;

  SELECT balance_id, quantity, inventory_value
    INTO v_balance
  FROM public.stock_balances
  WHERE location_id = p_location_id AND product_id = p_product_id
  FOR UPDATE;

  IF COALESCE(v_balance.quantity, 0) <> 0
     OR COALESCE(v_balance.inventory_value, 0) <> 0 THEN
    RAISE EXCEPTION 'يوجد رصيد فعلي لهذا المنتج والموقع. استخدم تسوية المخزون العادية بدل الرصيد الافتتاحي';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.stock_movements
    WHERE location_id = p_location_id AND product_id = p_product_id
  ) THEN
    RAISE EXCEPTION 'توجد حركة مخزون سابقة لهذا المنتج والموقع. لا يمكن تسجيل رصيد افتتاحي جديد';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.reservations
    WHERE location_id = p_location_id AND product_id = p_product_id
      AND status = 'ACTIVE'
      AND (reserved_until IS NULL OR reserved_until >= CURRENT_DATE)
  ) THEN
    RAISE EXCEPTION 'يوجد حجز نشط لهذا المنتج والموقع. ألغِ الحجز قبل تسجيل الرصيد الافتتاحي';
  END IF;

  v_total_cost := ROUND(p_base_quantity * p_unit_cost, 4);
  IF v_total_cost <= 0 THEN
    RAISE EXCEPTION 'إجمالي قيمة الرصيد الافتتاحي يجب أن يكون أكبر من صفر';
  END IF;

  -- The RECEIVE movement and its AFTER trigger are the sole path that updates stock quantity and valuation.
  -- Keep the locked balance at zero here to prevent applying the opening quantity twice.
  INSERT INTO public.stock_movements(
    location_id, product_id, movement_type, quantity_change, quantity_after,
    notes, created_by, unit_cost, total_cost
  )
  VALUES (
    p_location_id, p_product_id, 'RECEIVE', p_base_quantity, p_base_quantity,
    'رصيد افتتاحي للمخزون - ' || v_product_name, auth.uid(),
    ROUND(p_unit_cost, 6), v_total_cost
  )
  RETURNING movement_id INTO v_movement_id;

  IF v_total_cost > 0 THEN
    v_entry_id := public.post_journal_entry(
      now(),
      'رصيد افتتاحي مخزون - ' || v_product_name,
      'STOCK_OPENING_BALANCE',
      v_movement_id,
      jsonb_build_array(
        jsonb_build_object('account', '1300', 'debit', v_total_cost, 'credit', 0),
        jsonb_build_object('account', '3400', 'debit', 0, 'credit', v_total_cost)
      )
    );
    IF v_entry_id IS NULL THEN
      RAISE EXCEPTION 'تعذر إنشاء القيد المحاسبي للرصيد الافتتاحي للمخزون';
    END IF;
  END IF;

  RETURN v_movement_id;
END;
$function$;
