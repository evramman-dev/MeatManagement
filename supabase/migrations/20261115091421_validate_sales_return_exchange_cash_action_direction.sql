-- Enforce exchange price-difference direction for every settlement action
CREATE OR REPLACE FUNCTION public.validate_sales_return_exchange_v1(p_sales_return_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  r public.sales_returns%ROWTYPE;
  inv public.sales_invoices%ROWTYPE;
  tr public.trips%ROWTYPE;
  x record;
  sold numeric;
  returned numeric;
  v_return numeric;
  v_exchange numeric;
BEGIN
  IF auth.uid() IS NULL OR NOT (public.has_permission('RETURNS_APPROVE') OR public.has_permission('RETURNS_MANAGE')) THEN
    RAISE EXCEPTION 'لا تملك صلاحية اعتماد الاستبدال';
  END IF;

  SELECT * INTO r FROM public.sales_returns WHERE sales_return_id=p_sales_return_id FOR UPDATE;
  IF NOT FOUND OR r.status<>'DRAFT' OR r.return_type<>'EXCHANGE' THEN
    RAISE EXCEPTION 'الاستبدال غير موجود أو ليس مسودة';
  END IF;

  SELECT * INTO inv FROM public.sales_invoices WHERE sales_invoice_id=r.sales_invoice_id FOR UPDATE;
  IF NOT FOUND OR inv.status NOT IN ('POSTED','PAID','PARTIAL') OR inv.customer_id<>r.customer_id OR inv.trip_id<>r.trip_id THEN
    RAISE EXCEPTION 'الفاتورة الأصلية غير صالحة للاستبدال';
  END IF;

  SELECT * INTO tr FROM public.trips WHERE trip_id=r.trip_id FOR UPDATE;
  IF NOT FOUND OR tr.status NOT IN ('DRAFT','ACTIVE') THEN
    RAISE EXCEPTION 'لا يمكن اعتماد استبدال لجولة مغلقة';
  END IF;
  IF tr.vehicle_location_id IS NULL THEN
    RAISE EXCEPTION 'الجولة لا تحتوي على موقع سيارة';
  END IF;

  SELECT COALESCE(SUM(line_total),0) INTO v_return
  FROM public.sales_return_items WHERE sales_return_id=r.sales_return_id;
  SELECT COALESCE(SUM(line_total),0) INTO v_exchange
  FROM public.sales_return_exchange_items WHERE sales_return_id=r.sales_return_id;

  IF ABS(v_return-r.total_returned_value)>0.01 OR ABS(v_exchange-r.total_exchange_value)>0.01 THEN
    RAISE EXCEPTION 'إجماليات الاستبدال لا تطابق الأصناف';
  END IF;
  IF ABS((v_exchange-v_return)-r.price_difference)>0.01 THEN
    RAISE EXCEPTION 'فرق سعر الاستبدال غير صحيح';
  END IF;

  IF EXISTS(
    SELECT 1 FROM public.sales_return_items
    WHERE sales_return_id=r.sales_return_id
      AND (quantity<=0 OR base_quantity IS NULL OR base_quantity<=0
        OR conversion_factor IS NULL OR conversion_factor<=0
        OR location_id<>tr.vehicle_location_id)
  ) OR EXISTS(
    SELECT 1 FROM public.sales_return_exchange_items
    WHERE sales_return_id=r.sales_return_id
      AND (quantity<=0 OR base_quantity IS NULL OR base_quantity<=0
        OR conversion_factor IS NULL OR conversion_factor<=0
        OR location_id<>tr.vehicle_location_id)
  ) THEN
    RAISE EXCEPTION 'يوجد بند استبدال بكمية أو تحويل أو موقع غير صحيح';
  END IF;

  FOR x IN
    SELECT product_id,lot_id,package_option_id,SUM(base_quantity) qty
    FROM public.sales_return_items
    WHERE sales_return_id=r.sales_return_id
    GROUP BY product_id,lot_id,package_option_id
  LOOP
    SELECT COALESCE(SUM(sii.base_quantity),0) INTO sold
    FROM public.sales_invoice_items sii
    WHERE sii.sales_invoice_id=r.sales_invoice_id
      AND sii.product_id=x.product_id
      AND sii.lot_id IS NOT DISTINCT FROM x.lot_id
      AND sii.package_option_id IS NOT DISTINCT FROM x.package_option_id;

    SELECT COALESCE(SUM(sri.base_quantity),0) INTO returned
    FROM public.sales_return_items sri
    JOIN public.sales_returns sr ON sr.sales_return_id=sri.sales_return_id
    WHERE sr.sales_invoice_id=r.sales_invoice_id
      AND sr.status IN ('POSTED','APPROVED')
      AND sr.sales_return_id<>r.sales_return_id
      AND sri.product_id=x.product_id
      AND sri.lot_id IS NOT DISTINCT FROM x.lot_id
      AND sri.package_option_id IS NOT DISTINCT FROM x.package_option_id;

    IF x.qty+returned>sold THEN
      RAISE EXCEPTION 'الكمية المرتجعة تتجاوز المباعة للصنف %',x.product_id;
    END IF;
  END LOOP;

  IF r.cash_action='CASH_BACK' AND COALESCE(inv.remaining_amount,0)>0.01 THEN
    RAISE EXCEPTION 'لا يمكن رد النقدية مع وجود مديونية على الفاتورة';
  END IF;
  IF r.cash_action='DEDUCT_DEBT' AND COALESCE(inv.remaining_amount,0)+r.price_difference< -0.01 THEN
    RAISE EXCEPTION 'فرق الاستبدال أكبر من المديونية المتاحة';
  END IF;
  IF r.cash_action IN ('CASH_BACK','CUSTOMER_PAYS_CASH')
     AND (r.treasury_id IS NULL OR NOT EXISTS(
       SELECT 1 FROM public.treasuries
       WHERE treasury_id=r.treasury_id AND is_active
         AND treasury_type IN ('CASH','BANK','INSTAPAY')
     )) THEN
    RAISE EXCEPTION 'خزنة التسوية غير صالحة';
  END IF;
  IF r.cash_action='CUSTOMER_PAYS_CASH' AND r.price_difference<=0 THEN
    RAISE EXCEPTION 'التحصيل النقدي يتطلب فرق سعر موجبًا';
  END IF;
  IF r.cash_action='CUSTOMER_PAYS_CREDIT' AND r.price_difference<=0 THEN
    RAISE EXCEPTION 'إضافة الفرق للمديونية تتطلب فرق سعر موجبًا';
  END IF;
  IF r.cash_action='CASH_BACK' AND r.price_difference>=0 THEN
    RAISE EXCEPTION 'رد النقدية يتطلب فرق سعر سالبًا';
  END IF;
  IF r.cash_action='CREDIT_BALANCE' AND r.price_difference>=0 THEN
    RAISE EXCEPTION 'الرصيد الدائن يتطلب فرق سعر سالبًا';
  END IF;
  IF r.cash_action NOT IN ('DEDUCT_DEBT','CUSTOMER_PAYS_CASH','CUSTOMER_PAYS_CREDIT','CASH_BACK','CREDIT_BALANCE') THEN
    RAISE EXCEPTION 'طريقة تسوية فرق الاستبدال غير صالحة';
  END IF;

  RETURN TRUE;
END;
$function$;
