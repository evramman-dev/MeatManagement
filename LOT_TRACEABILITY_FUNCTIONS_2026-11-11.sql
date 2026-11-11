-- MeatManagement Lot Traceability - applied function snapshot
-- Date: 2026-11-11
-- Release candidate: v70 / Service Worker meat-v103
-- Audit snapshot of final definitions after the applied migrations.
-- Not a standalone reset script. Apply through reviewed Supabase migrations only.

-- Applied migrations:
-- create_lot_traceability_foundation_20261111
-- backfill_legacy_opening_lot_balances_20261111
-- link_lot_traceability_to_purchase_sales_and_returns_20261111
-- link_single_lot_sales_invoice_items_20261111
-- complete_purchase_lot_idempotency_and_production_expiry_20261111
-- enable_sales_return_lot_selection_and_validation_20261111
-- reverse_customer_return_lots_exactly_on_cancel_20261111
-- allow_legacy_purchase_return_without_historical_lot_20261111
-- preserve_legacy_stock_reversals_without_lot_history_20261111
-- validate_purchase_lot_dates_and_classify_trip_returns_20261111


-- Function snapshot: add_sales_return_item
CREATE OR REPLACE FUNCTION public.add_sales_return_item(p_sales_return_id bigint, p_product_id bigint, p_unit_id bigint, p_quantity numeric, p_unit_price numeric, p_discount_amount numeric, p_lot_id bigint, p_notes text, p_package_option_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_return record;
  v_location_id bigint;
  v_trip record;
  v_factor numeric;
  v_package_weight numeric;
  v_base_quantity numeric;
  v_line_total numeric(18,3);
  v_seq integer;
  v_item_id bigint;
  v_subtotal numeric(18,3);
  v_discount numeric(18,3);
  v_invoice_status character varying;
  v_invoice_base_qty numeric(18,6);
  v_returned_base_qty numeric(18,6);
  v_max_price_per_base numeric;
  v_allowed_price numeric;
  v_invoice_ratio numeric:=1;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;
  IF NOT (public.has_permission('RETURNS_CREATE') OR public.has_permission('RETURNS_MANAGE')) THEN
    RAISE EXCEPTION 'لا تملك صلاحية إضافة أصناف للمرتجع';
  END IF;

  SELECT status,trip_id,sales_invoice_id
    INTO v_return
  FROM public.sales_returns
  WHERE sales_return_id=p_sales_return_id
  FOR UPDATE;

  IF NOT FOUND OR v_return.status<>'DRAFT' THEN
    RAISE EXCEPTION 'لا يمكن تعديل إلا مرتجع في حالة مسودة';
  END IF;

  IF p_quantity IS NULL OR p_quantity<=0 OR p_unit_price IS NULL OR p_unit_price<0
     OR COALESCE(p_discount_amount,0)<0
     OR COALESCE(p_discount_amount,0)>p_quantity*p_unit_price THEN
    RAISE EXCEPTION 'الكمية أو السعر أو الخصم غير صحيح';
  END IF;

  IF NOT EXISTS(SELECT 1 FROM public.products WHERE product_id=p_product_id)
     OR NOT EXISTS(SELECT 1 FROM public.units WHERE unit_id=p_unit_id) THEN
    RAISE EXCEPTION 'المنتج أو الوحدة غير موجودين';
  END IF;

  IF v_return.sales_invoice_id IS NULL THEN
    RAISE EXCEPTION 'المرتجع غير مرتبط بفاتورة أصلية';
  END IF;

  IF v_return.trip_id IS NOT NULL THEN
    SELECT trip_id,status,vehicle_location_id,source_location_id
      INTO v_trip
    FROM public.trips
    WHERE trip_id=v_return.trip_id
      AND status IN ('DRAFT','ACTIVE','COMPLETED')
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'جولة المرتجع غير موجودة أو حالتها غير مقبولة';
    END IF;

    IF v_trip.status IN ('DRAFT','ACTIVE') THEN
      v_location_id:=v_trip.vehicle_location_id;
      IF v_location_id IS NULL OR NOT EXISTS(
        SELECT 1 FROM public.locations
        WHERE location_id=v_location_id
          AND is_active
          AND location_type='VEHICLE'
      ) THEN
        RAISE EXCEPTION 'الجولة النشطة غير مرتبطة بموقع سيارة نشط';
      END IF;
    ELSE
      v_location_id:=v_trip.source_location_id;
      IF v_location_id IS NULL OR NOT EXISTS(
        SELECT 1 FROM public.locations
        WHERE location_id=v_location_id
          AND is_active
          AND location_type<>'VEHICLE'
      ) THEN
        RAISE EXCEPTION 'موقع استلام المرتجع للجولة المكتملة غير صالح أو من نوع سيارة';
      END IF;
    END IF;
  ELSE
    SELECT location_id INTO v_location_id
    FROM public.sales_invoices
    WHERE sales_invoice_id=v_return.sales_invoice_id;
  END IF;

  IF v_location_id IS NULL OR NOT EXISTS(
    SELECT 1 FROM public.locations WHERE location_id=v_location_id AND is_active
  ) THEN
    RAISE EXCEPTION 'موقع استلام المرتجع غير موجود أو غير نشط';
  END IF;

  SELECT status,subtotal,net_total
    INTO v_invoice_status,v_invoice_base_qty,v_returned_base_qty
  FROM public.sales_invoices
  WHERE sales_invoice_id=v_return.sales_invoice_id
  FOR UPDATE;

  IF NOT FOUND OR v_invoice_status NOT IN ('POSTED','PAID','PARTIAL') THEN
    RAISE EXCEPTION 'الفاتورة الأصلية غير مرحّلة أو ملغاة';
  END IF;

  IF p_lot_id IS NULL AND EXISTS (
    SELECT 1
    FROM public.sales_invoice_items sii
    JOIN public.stock_movements sm
      ON sm.sales_invoice_item_id=sii.sales_invoice_item_id
     AND sm.sales_invoice_id=v_return.sales_invoice_id
    JOIN public.stock_movement_lot_allocations mla
      ON mla.movement_id=sm.movement_id
     AND mla.allocation_direction='OUT'
    WHERE sii.product_id=p_product_id
      AND sii.unit_id=p_unit_id
      AND sii.package_option_id IS NOT DISTINCT FROM p_package_option_id
  ) THEN
    RAISE EXCEPTION 'اختر تشغيلة الصنف المرتجع من الفاتورة الأصلية';
  END IF;

  IF p_package_option_id IS NOT NULL THEN
    IF EXISTS(
      SELECT 1 FROM public.sales_invoice_items sii
      WHERE sii.sales_invoice_id=v_return.sales_invoice_id
        AND sii.product_id=p_product_id
        AND (
      sii.lot_id IS NOT DISTINCT FROM p_lot_id
      OR (
        p_lot_id IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public.stock_movements sm
          JOIN public.stock_movement_lot_allocations mla
            ON mla.movement_id=sm.movement_id
           AND mla.allocation_direction='OUT'
          WHERE sm.sales_invoice_id=v_return.sales_invoice_id
            AND sm.sales_invoice_item_id=sii.sales_invoice_item_id
            AND mla.lot_id=p_lot_id
        )
      )
    )
        AND sii.package_option_id=p_package_option_id
        AND sii.base_quantity IS NULL
    ) THEN
      RAISE EXCEPTION 'الفاتورة الأصلية تحتوي على كمية أساسية غير محفوظة';
    END IF;

    SELECT
      SUM(sii.base_quantity)/NULLIF(SUM(sii.quantity),0),
      MAX(sii.package_weight_kg),
      SUM(sii.base_quantity)
    INTO v_factor,v_package_weight,v_invoice_base_qty
    FROM public.sales_invoice_items sii
    WHERE sii.sales_invoice_id=v_return.sales_invoice_id
      AND sii.product_id=p_product_id
      AND sii.unit_id=p_unit_id
      AND (
      sii.lot_id IS NOT DISTINCT FROM p_lot_id
      OR (
        p_lot_id IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public.stock_movements sm
          JOIN public.stock_movement_lot_allocations mla
            ON mla.movement_id=sm.movement_id
           AND mla.allocation_direction='OUT'
          WHERE sm.sales_invoice_id=v_return.sales_invoice_id
            AND sm.sales_invoice_item_id=sii.sales_invoice_item_id
            AND mla.lot_id=p_lot_id
        )
      )
    )
      AND sii.package_option_id=p_package_option_id;
  ELSE
    IF EXISTS(
      SELECT 1 FROM public.sales_invoice_items sii
      WHERE sii.sales_invoice_id=v_return.sales_invoice_id
        AND sii.product_id=p_product_id
        AND (
      sii.lot_id IS NOT DISTINCT FROM p_lot_id
      OR (
        p_lot_id IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public.stock_movements sm
          JOIN public.stock_movement_lot_allocations mla
            ON mla.movement_id=sm.movement_id
           AND mla.allocation_direction='OUT'
          WHERE sm.sales_invoice_id=v_return.sales_invoice_id
            AND sm.sales_invoice_item_id=sii.sales_invoice_item_id
            AND mla.lot_id=p_lot_id
        )
      )
    )
        AND sii.package_option_id IS NULL
        AND sii.base_quantity IS NULL
    ) THEN
      RAISE EXCEPTION 'الفاتورة الأصلية تحتوي على كمية أساسية غير محفوظة';
    END IF;

    SELECT
      SUM(sii.base_quantity)/NULLIF(SUM(sii.quantity),0),
      SUM(sii.base_quantity)
    INTO v_factor,v_invoice_base_qty
    FROM public.sales_invoice_items sii
    WHERE sii.sales_invoice_id=v_return.sales_invoice_id
      AND sii.product_id=p_product_id
      AND sii.unit_id=p_unit_id
      AND (
      sii.lot_id IS NOT DISTINCT FROM p_lot_id
      OR (
        p_lot_id IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public.stock_movements sm
          JOIN public.stock_movement_lot_allocations mla
            ON mla.movement_id=sm.movement_id
           AND mla.allocation_direction='OUT'
          WHERE sm.sales_invoice_id=v_return.sales_invoice_id
            AND sm.sales_invoice_item_id=sii.sales_invoice_item_id
            AND mla.lot_id=p_lot_id
        )
      )
    )
      AND sii.package_option_id IS NULL;
    v_package_weight:=NULL;
  END IF;

  IF v_factor IS NULL OR v_factor<=0 OR COALESCE(v_invoice_base_qty,0)<=0 THEN
    RAISE EXCEPTION 'الصنف أو الوحدة أو التشغيلة أو خيار التعبئة غير موجود في الفاتورة الأصلية';
  END IF;

  IF p_package_option_id IS NOT NULL AND (v_package_weight IS NULL OR v_package_weight<=0 OR v_factor<>v_package_weight) THEN
    RAISE EXCEPTION 'وزن العبوة أو معامل التحويل لا يطابق الفاتورة الأصلية';
  END IF;

  SELECT CASE
    WHEN p_lot_id IS NOT NULL THEN COALESCE((
      SELECT SUM(mla.quantity)
      FROM public.stock_movements sm
      JOIN public.stock_movement_lot_allocations mla
        ON mla.movement_id=sm.movement_id
       AND mla.allocation_direction='OUT'
      JOIN public.sales_invoice_items source_item
        ON source_item.sales_invoice_item_id=sm.sales_invoice_item_id
      WHERE sm.sales_invoice_id=v_return.sales_invoice_id
        AND source_item.product_id=p_product_id
        AND source_item.unit_id=p_unit_id
        AND source_item.package_option_id IS NOT DISTINCT FROM p_package_option_id
        AND mla.lot_id=p_lot_id
    ),COALESCE(SUM(sii.base_quantity),0))
    ELSE COALESCE(SUM(sii.base_quantity),0)
  END
    INTO v_invoice_base_qty
  FROM public.sales_invoice_items sii
  WHERE sii.sales_invoice_id=v_return.sales_invoice_id
    AND sii.product_id=p_product_id
    AND (
      sii.lot_id IS NOT DISTINCT FROM p_lot_id
      OR (
        p_lot_id IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public.stock_movements sm
          JOIN public.stock_movement_lot_allocations mla
            ON mla.movement_id=sm.movement_id
           AND mla.allocation_direction='OUT'
          WHERE sm.sales_invoice_id=v_return.sales_invoice_id
            AND sm.sales_invoice_item_id=sii.sales_invoice_item_id
            AND mla.lot_id=p_lot_id
        )
      )
    )
    AND sii.package_option_id IS NOT DISTINCT FROM p_package_option_id;

  v_base_quantity:=p_quantity*v_factor;
  v_line_total:=ROUND(p_quantity*p_unit_price-COALESCE(p_discount_amount,0),3);

  SELECT COALESCE(SUM(sri.base_quantity),0)
    INTO v_returned_base_qty
  FROM public.sales_return_items sri
  JOIN public.sales_returns sr ON sr.sales_return_id=sri.sales_return_id
  WHERE sr.sales_invoice_id=v_return.sales_invoice_id
    AND (sr.status IN ('POSTED','APPROVED') OR sr.sales_return_id=p_sales_return_id)
    AND sri.product_id=p_product_id
    AND sri.lot_id IS NOT DISTINCT FROM p_lot_id
    AND sri.package_option_id IS NOT DISTINCT FROM p_package_option_id;

  IF v_returned_base_qty+v_base_quantity>v_invoice_base_qty+0.000001 THEN
    RAISE EXCEPTION 'كمية المرتجع تتجاوز الكمية المباعة والمتبقية لنفس التشغيلة وخيار التعبئة';
  END IF;

  SELECT MAX(sii.line_total/NULLIF(sii.base_quantity,0))
    INTO v_max_price_per_base
  FROM public.sales_invoice_items sii
  WHERE sii.sales_invoice_id=v_return.sales_invoice_id
    AND sii.product_id=p_product_id
    AND (
      sii.lot_id IS NOT DISTINCT FROM p_lot_id
      OR (
        p_lot_id IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public.stock_movements sm
          JOIN public.stock_movement_lot_allocations mla
            ON mla.movement_id=sm.movement_id
           AND mla.allocation_direction='OUT'
          WHERE sm.sales_invoice_id=v_return.sales_invoice_id
            AND sm.sales_invoice_item_id=sii.sales_invoice_item_id
            AND mla.lot_id=p_lot_id
        )
      )
    )
    AND sii.package_option_id IS NOT DISTINCT FROM p_package_option_id;

  IF v_max_price_per_base IS NULL THEN
    RAISE EXCEPTION 'الصنف غير موجود في الفاتورة الأصلية';
  END IF;

  SELECT CASE WHEN COALESCE(subtotal,0)>0
              THEN LEAST(COALESCE(net_total,subtotal)/subtotal,1)
              ELSE 1 END
    INTO v_invoice_ratio
  FROM public.sales_invoices
  WHERE sales_invoice_id=v_return.sales_invoice_id;

  v_allowed_price:=ROUND(v_max_price_per_base*v_invoice_ratio*v_factor,2);
  IF p_unit_price>v_allowed_price+0.01 THEN
    RAISE EXCEPTION 'سعر المرتجع أعلى من سعر الصنف في الفاتورة الأصلية بعد الخصم';
  END IF;

  SELECT COALESCE(MAX(sequence_no),0)+1 INTO v_seq
  FROM public.sales_return_items WHERE sales_return_id=p_sales_return_id;

  INSERT INTO public.sales_return_items(
    sales_return_id,product_id,unit_id,lot_id,quantity,unit_price,
    discount_amount,line_total,location_id,sequence_no,base_quantity,
    conversion_factor,package_option_id,package_weight_kg,notes
  )
  VALUES(
    p_sales_return_id,p_product_id,p_unit_id,p_lot_id,p_quantity,p_unit_price,
    COALESCE(p_discount_amount,0),v_line_total,v_location_id,v_seq,
    v_base_quantity,v_factor,p_package_option_id,v_package_weight,p_notes
  )
  RETURNING return_item_id INTO v_item_id;

  SELECT COALESCE(SUM(quantity*unit_price),0),COALESCE(SUM(discount_amount),0)
    INTO v_subtotal,v_discount
  FROM public.sales_return_items
  WHERE sales_return_id=p_sales_return_id;

  UPDATE public.sales_returns
  SET subtotal=v_subtotal,
      discount_amount=v_discount,
      net_total=v_subtotal-v_discount,
      total_returned_value=v_subtotal-v_discount,
      price_difference=-(v_subtotal-v_discount)
  WHERE sales_return_id=p_sales_return_id;

  RETURN v_item_id;
END;
$function$
;


-- Function snapshot: cancel_sales_return
CREATE OR REPLACE FUNCTION public.cancel_sales_return(p_sales_return_id bigint, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_return record;
  v_invoice record;
  v_collection record;
  v_treasury_balance numeric;
  v_original_tx_count integer;
  v_qty record;
  v_new_stock numeric;
  v_new_remaining numeric;
BEGIN
  IF auth.uid() IS NULL OR NOT public.has_permission('RETURNS_MANAGE') THEN
    RAISE EXCEPTION 'لا تملك صلاحية إلغاء المرتجعات.';
  END IF;

  PERFORM pg_advisory_xact_lock(947351);

  -- Reversal journal entries and treasury transactions are dated today.
  -- Check the accounting period before locking the return, invoice, stock, or treasury.
  PERFORM public.assert_accounting_period_open(CURRENT_DATE);

  IF p_reason IS NULL OR length(trim(p_reason))=0 THEN
    RAISE EXCEPTION 'اكتب سبب إلغاء المرتجع.';
  END IF;

  SELECT *
  INTO v_return
  FROM public.sales_returns
  WHERE sales_return_id=p_sales_return_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'المرتجع غير موجود.';
  END IF;

  IF v_return.status='CANCELLED' THEN
    RAISE EXCEPTION 'المرتجع ملغى بالفعل.';
  END IF;

  IF v_return.status NOT IN ('POSTED','APPROVED') THEN
    RAISE EXCEPTION 'لا يمكن إلغاء مرتجع غير مرحل أو غير معتمد.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.sales_return_items
    WHERE sales_return_id=p_sales_return_id
      AND (base_quantity IS NULL OR base_quantity<=0 OR location_id IS NULL)
  ) OR EXISTS (
    SELECT 1 FROM public.sales_return_exchange_items
    WHERE sales_return_id=p_sales_return_id
      AND (base_quantity IS NULL OR base_quantity<=0 OR location_id IS NULL)
  ) THEN
    RAISE EXCEPTION 'يوجد بند مرتجع أو استبدال دون كمية أساسية أو موقع صالح.';
  END IF;

  IF v_return.sales_invoice_id IS NOT NULL THEN
    SELECT *
    INTO v_invoice
    FROM public.sales_invoices
    WHERE sales_invoice_id=v_return.sales_invoice_id
    FOR UPDATE;

    IF NOT FOUND OR v_invoice.status='CANCELLED' THEN
      RAISE EXCEPTION 'الفاتورة الأصلية غير موجودة أو ملغاة.';
    END IF;
  END IF;

  -- Reverse goods delivered to the customer in an exchange first.
  FOR v_qty IN
    SELECT location_id,product_id,SUM(base_quantity) AS quantity
    FROM public.sales_return_exchange_items
    WHERE sales_return_id=p_sales_return_id
    GROUP BY location_id,product_id
    ORDER BY location_id,product_id
  LOOP
    INSERT INTO public.stock_balances(location_id,product_id,quantity,updated_at)
    VALUES(v_qty.location_id,v_qty.product_id,0,now())
    ON CONFLICT(location_id,product_id) DO NOTHING;

    UPDATE public.stock_balances
    SET quantity=quantity+v_qty.quantity,updated_at=now()
    WHERE location_id=v_qty.location_id AND product_id=v_qty.product_id
    RETURNING quantity INTO v_new_stock;

    INSERT INTO public.stock_movements(
      location_id,product_id,movement_type,quantity_change,
      quantity_after,notes,created_by,trip_id
    )
    VALUES(
      v_qty.location_id,v_qty.product_id,'RETURN',v_qty.quantity,
      v_new_stock,'عكس بضاعة الاستبدال للمرتجع '||v_return.return_number,
      auth.uid(),v_return.trip_id
    );
  END LOOP;

  -- Remove goods previously received as a return.
  FOR v_qty IN
    SELECT location_id,product_id,SUM(base_quantity) AS quantity
    FROM public.sales_return_items
    WHERE sales_return_id=p_sales_return_id
    GROUP BY location_id,product_id
    ORDER BY location_id,product_id
  LOOP
    SELECT quantity INTO v_new_stock
    FROM public.stock_balances
    WHERE location_id=v_qty.location_id AND product_id=v_qty.product_id
    FOR UPDATE;

    IF NOT FOUND OR v_new_stock<v_qty.quantity THEN
      RAISE EXCEPTION 'رصيد السيارة لا يكفي لعكس المرتجع للمنتج % في الموقع %.',
        v_qty.product_id,v_qty.location_id;
    END IF;

    PERFORM public.assert_stock_available(v_qty.location_id,v_qty.product_id,v_qty.quantity);
    v_new_stock:=v_new_stock-v_qty.quantity;

    UPDATE public.stock_balances
    SET quantity=v_new_stock,updated_at=now()
    WHERE location_id=v_qty.location_id AND product_id=v_qty.product_id;

    INSERT INTO public.stock_movements(
      location_id,product_id,movement_type,quantity_change,
      quantity_after,notes,created_by,trip_id,sales_return_id
    )
    VALUES(
      v_qty.location_id,v_qty.product_id,'ISSUE',-v_qty.quantity,
      v_new_stock,'عكس استلام المرتجع '||v_return.return_number,
      auth.uid(),v_return.trip_id,p_sales_return_id
    );
  END LOOP;

  -- Reverse the cash movement and link it to the return.
  IF v_return.cash_action='CUSTOMER_PAYS_CASH' THEN
    SELECT COUNT(*) INTO v_original_tx_count
    FROM public.treasury_transactions
    WHERE reference_type='SALES_RETURN'
      AND reference_id=p_sales_return_id
      AND transaction_type='DEPOSIT'
      AND treasury_id=v_return.treasury_id
      AND amount=ABS(v_return.price_difference);

    IF v_original_tx_count<>1 THEN
      RAISE EXCEPTION 'تعذر تحديد حركة التحصيل الأصلية للمرتجع بشكل فريد.';
    END IF;

    SELECT * INTO v_collection
    FROM public.customer_collections
    WHERE reference_number=v_return.return_number
    FOR UPDATE;

    IF NOT FOUND OR v_collection.status<>'POSTED'
       OR v_collection.amount<>ABS(v_return.price_difference)
       OR v_collection.treasury_id<>v_return.treasury_id THEN
      RAISE EXCEPTION 'سجل تحصيل فرق الاستبدال غير موجود أو لا يطابق المرتجع.';
    END IF;

    SELECT current_balance INTO v_treasury_balance
    FROM public.treasuries
    WHERE treasury_id=v_return.treasury_id
    FOR UPDATE;

    IF NOT FOUND OR COALESCE(v_treasury_balance,0)<v_collection.amount THEN
      RAISE EXCEPTION 'رصيد الخزنة لا يكفي لعكس تحصيل فرق الاستبدال.';
    END IF;

    UPDATE public.treasuries
    SET current_balance=current_balance-v_collection.amount
    WHERE treasury_id=v_return.treasury_id;

    INSERT INTO public.treasury_transactions(
      treasury_id,transaction_type,amount,reference_type,reference_id,
      notes,transaction_date,created_by
    )
    VALUES(
      v_return.treasury_id,'WITHDRAW',v_collection.amount,
      'SALES_RETURN_CANCEL',p_sales_return_id,
      'عكس تحصيل المرتجع '||v_return.return_number||': '||trim(p_reason),
      CURRENT_DATE,auth.uid()
    );

    UPDATE public.customer_collections
    SET status='CANCELLED',
        cancellation_reason=trim(p_reason),
        cancelled_by=auth.uid(),
        cancelled_at=now(),
        updated_at=now()
    WHERE collection_id=v_collection.collection_id;

  ELSIF v_return.cash_action='CASH_BACK' THEN
    SELECT COUNT(*) INTO v_original_tx_count
    FROM public.treasury_transactions
    WHERE reference_type='SALES_RETURN'
      AND reference_id=p_sales_return_id
      AND transaction_type='WITHDRAW'
      AND treasury_id=v_return.treasury_id
      AND amount=ABS(v_return.price_difference);

    IF v_original_tx_count<>1 THEN
      RAISE EXCEPTION 'تعذر تحديد حركة رد النقدية الأصلية للمرتجع بشكل فريد.';
    END IF;

    UPDATE public.treasuries
    SET current_balance=current_balance+ABS(v_return.price_difference)
    WHERE treasury_id=v_return.treasury_id
      AND is_active=TRUE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'خزنة المرتجع غير موجودة أو غير نشطة.';
    END IF;

    INSERT INTO public.treasury_transactions(
      treasury_id,transaction_type,amount,reference_type,reference_id,
      notes,transaction_date,created_by
    )
    VALUES(
      v_return.treasury_id,'DEPOSIT',ABS(v_return.price_difference),
      'SALES_RETURN_CANCEL',p_sales_return_id,
      'عكس رد النقدية للمرتجع '||v_return.return_number||': '||trim(p_reason),
      CURRENT_DATE,auth.uid()
    );
  END IF;

  -- Reverse the return impact on the invoice balance.
  IF v_return.sales_invoice_id IS NOT NULL
     AND v_return.cash_action IN ('NONE','DEDUCT_DEBT','CUSTOMER_PAYS_CREDIT') THEN
    v_new_remaining:=COALESCE(v_invoice.remaining_amount,0)-COALESCE(v_return.price_difference,0);

    IF v_new_remaining<0 THEN
      RAISE EXCEPTION 'لا يمكن إلغاء المرتجع لأن العميل سدد جزءًا من فرق الاستبدال، وسيؤدي العكس إلى رصيد دائن غير مدعوم.';
    END IF;

    UPDATE public.sales_invoices
    SET remaining_amount=v_new_remaining,
        status=CASE
          WHEN v_new_remaining=0 THEN 'PAID'
          WHEN COALESCE(v_invoice.paid_amount,0)>0 THEN 'PARTIAL'
          ELSE 'POSTED'
        END,
        updated_at=now()
    WHERE sales_invoice_id=v_return.sales_invoice_id;
  END IF;

  UPDATE public.sales_returns
  SET status='CANCELLED',
      cancellation_reason=trim(p_reason),
      cancelled_by=auth.uid(),
      cancelled_at=now()
  WHERE sales_return_id=p_sales_return_id;
END;
$function$
;


-- Function snapshot: create_purchase_invoice
CREATE OR REPLACE FUNCTION public.create_purchase_invoice(p_supplier_id bigint, p_location_id bigint, p_invoice_date date, p_discount numeric, p_notes text, p_items jsonb, p_treasury_id bigint, p_request_id uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
    v_invoice_id BIGINT;
    v_invoice_number TEXT;
    v_item JSONB;
    v_product_id BIGINT;
    v_unit_id BIGINT;
    v_qty NUMERIC;
    v_price NUMERIC;
    v_line NUMERIC;
    v_base_qty NUMERIC;
    v_conversion_factor NUMERIC;
    v_subtotal NUMERIC := 0;
    v_total NUMERIC := 0;
    v_discount NUMERIC := COALESCE(p_discount, 0);
    v_new_stock NUMERIC;
    v_treasury_balance NUMERIC;
    v_account_id BIGINT;
    v_account_code TEXT;
    v_date DATE := COALESCE(p_invoice_date, CURRENT_DATE);

    v_existing_supplier_id BIGINT;
    v_existing_location_id BIGINT;
    v_existing_date DATE;
    v_existing_discount NUMERIC;
    v_existing_notes TEXT;
    v_existing_treasury_id BIGINT;
    v_existing_items JSONB;
    v_requested_items JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
    END IF;

    IF NOT public.has_permission('PURCHASES_MANAGE') THEN
        RAISE EXCEPTION 'صلاحية غير كافية';
    END IF;

    PERFORM pg_advisory_xact_lock(947351);

    PERFORM public.assert_accounting_period_open(v_date);

    IF p_request_id IS NULL THEN
        RAISE EXCEPTION 'رقم طلب الفاتورة مطلوب';
    END IF;

    IF p_items IS NULL
       OR jsonb_typeof(p_items) <> 'array'
       OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'يجب إضافة صنف واحد على الأقل';
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'product_id', (value->>'product_id')::BIGINT,
            'unit_id', (value->>'unit_id')::BIGINT,
            'quantity', (value->>'quantity')::NUMERIC,
            'unit_price', (value->>'unit_price')::NUMERIC,
            'supplier_lot_code', NULLIF(BTRIM(value->>'supplier_lot_code'), ''),
            'manufactured_on', NULLIF(value->>'manufactured_on', ''),
            'expires_on', NULLIF(value->>'expires_on', '')
        )
        ORDER BY
            (value->>'product_id')::BIGINT,
            (value->>'unit_id')::BIGINT,
            (value->>'quantity')::NUMERIC,
            (value->>'unit_price')::NUMERIC,
            COALESCE(value->>'supplier_lot_code',''),
            COALESCE(value->>'manufactured_on',''),
            COALESCE(value->>'expires_on','')
    )
    INTO v_requested_items
    FROM jsonb_array_elements(p_items);

    PERFORM pg_advisory_xact_lock(
        hashtextextended(p_request_id::TEXT, 0)
    );

    SELECT
        purchase_invoice_id,
        supplier_id,
        location_id,
        invoice_date,
        discount,
        notes,
        treasury_id
    INTO
        v_invoice_id,
        v_existing_supplier_id,
        v_existing_location_id,
        v_existing_date,
        v_existing_discount,
        v_existing_notes,
        v_existing_treasury_id
    FROM public.purchase_invoices
    WHERE request_id = p_request_id;

    IF FOUND THEN
        SELECT jsonb_agg(
            jsonb_build_object(
                'product_id', product_id,
                'unit_id', unit_id,
                'quantity', quantity,
                'unit_price', unit_price,
                'supplier_lot_code', supplier_lot_code,
                'manufactured_on', manufactured_on,
                'expires_on', expires_on
            )
            ORDER BY
                product_id,
                unit_id,
                quantity,
                unit_price,
                COALESCE(supplier_lot_code,''),
                COALESCE(manufactured_on::text,''),
                COALESCE(expires_on::text,'')
        )
        INTO v_existing_items
        FROM public.purchase_invoice_items
        WHERE purchase_invoice_id = v_invoice_id;

        IF v_existing_supplier_id IS DISTINCT FROM p_supplier_id
           OR v_existing_location_id IS DISTINCT FROM p_location_id
           OR v_existing_date IS DISTINCT FROM v_date
           OR v_existing_discount IS DISTINCT FROM v_discount
           OR v_existing_notes IS DISTINCT FROM p_notes
           OR v_existing_treasury_id IS DISTINCT FROM p_treasury_id
           OR v_existing_items IS DISTINCT FROM v_requested_items
        THEN
            RAISE EXCEPTION
                'رقم طلب الفاتورة مستخدم بالفعل مع بيانات مختلفة';
        END IF;

        RETURN v_invoice_id;
    END IF;

    IF p_supplier_id IS NULL THEN
        RAISE EXCEPTION 'يجب اختيار المورد';
    END IF;

    PERFORM 1
    FROM public.suppliers
    WHERE supplier_id = p_supplier_id
      AND is_active = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'المورد غير موجود أو غير نشط';
    END IF;

    IF p_location_id IS NULL THEN
        RAISE EXCEPTION 'يجب اختيار الموقع';
    END IF;

    PERFORM 1
    FROM public.locations
    WHERE location_id = p_location_id
      AND is_active = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'الموقع غير موجود أو غير نشط';
    END IF;

    IF v_discount < 0 THEN
        RAISE EXCEPTION 'الخصم لا يمكن أن يكون سالبًا';
    END IF;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::BIGINT;
        v_unit_id := (v_item->>'unit_id')::BIGINT;
        v_qty := (v_item->>'quantity')::NUMERIC;
        v_price := (v_item->>'unit_price')::NUMERIC;

        IF v_qty IS NULL
           OR v_qty <= 0
           OR v_price IS NULL
           OR v_price < 0 THEN
            RAISE EXCEPTION 'كمية أو سعر غير صحيح';
        END IF;

        PERFORM public.fn_base_factor(
            v_product_id,
            v_unit_id
        );

        v_subtotal :=
            v_subtotal + ROUND(v_qty * v_price, 2);
    END LOOP;

    IF v_discount >= v_subtotal THEN
        RAISE EXCEPTION
            'قيمة الخصم يجب أن تكون أقل من إجمالي الفاتورة';
    END IF;

    v_total := v_subtotal - v_discount;

    IF p_treasury_id IS NOT NULL THEN
        SELECT
            t.current_balance,
            t.account_id,
            c.account_code
        INTO
            v_treasury_balance,
            v_account_id,
            v_account_code
        FROM public.treasuries t
        LEFT JOIN public.chart_of_accounts c
            ON c.account_id = t.account_id
           AND c.is_active = TRUE
        WHERE t.treasury_id = p_treasury_id
          AND t.is_active = TRUE
        FOR UPDATE OF t;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'الخزنة غير موجودة أو غير نشطة';
        END IF;

        IF v_account_id IS NULL OR v_account_code IS NULL THEN
            RAISE EXCEPTION
                'الخزنة غير مرتبطة بحساب محاسبي نشط';
        END IF;

        IF COALESCE(v_treasury_balance, 0) < v_total THEN
            RAISE EXCEPTION
                'رصيد الخزنة غير كافٍ. المتاح: %',
                COALESCE(v_treasury_balance, 0);
        END IF;
    ELSE
        v_account_code := '2100';
    END IF;

    v_invoice_number :=
        'PUR-' ||
        lpad(
            nextval('public.purchase_invoice_seq')::TEXT,
            6,
            '0'
        );

    INSERT INTO public.purchase_invoices (
        invoice_number,
        supplier_id,
        location_id,
        invoice_date,
        subtotal,
        discount,
        net_total,
        notes,
        status,
        created_by,
        treasury_id,
        request_id
    )
    VALUES (
        v_invoice_number,
        p_supplier_id,
        p_location_id,
        v_date,
        v_subtotal,
        v_discount,
        v_total,
        p_notes,
        'POSTED',
        auth.uid(),
        p_treasury_id,
        p_request_id
    )
    RETURNING purchase_invoice_id
    INTO v_invoice_id;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::BIGINT;
        v_unit_id := (v_item->>'unit_id')::BIGINT;
        v_qty := (v_item->>'quantity')::NUMERIC;
        v_price := (v_item->>'unit_price')::NUMERIC;

        IF NULLIF(v_item->>'manufactured_on','') IS NOT NULL
           AND NULLIF(v_item->>'expires_on','') IS NOT NULL
           AND (v_item->>'expires_on')::date < (v_item->>'manufactured_on')::date THEN
            RAISE EXCEPTION 'تاريخ الصلاحية لا يمكن أن يسبق تاريخ الإنتاج للصنف رقم %',v_product_id;
        END IF;

        v_line := ROUND(v_qty * v_price, 2);

        v_conversion_factor :=
            public.fn_base_factor(
                v_product_id,
                v_unit_id
            );

        v_base_qty :=
            v_qty * v_conversion_factor;

        INSERT INTO public.purchase_invoice_items (
            purchase_invoice_id,
            product_id,
            unit_id,
            quantity,
            base_quantity,
            conversion_factor,
            unit_price,
            line_total,
            supplier_lot_code,
            manufactured_on,
            expires_on
        )
        VALUES (
            v_invoice_id,
            v_product_id,
            v_unit_id,
            v_qty,
            v_base_qty,
            v_conversion_factor,
            v_price,
            v_line,
            NULLIF(BTRIM(v_item->>'supplier_lot_code'), ''),
            NULLIF(v_item->>'manufactured_on','')::date,
            NULLIF(v_item->>'expires_on','')::date
        );

        INSERT INTO public.stock_balances (
            location_id,
            product_id,
            quantity,
            updated_at
        )
        VALUES (
            p_location_id,
            v_product_id,
            v_base_qty,
            NOW()
        )
        ON CONFLICT (location_id, product_id)
        DO UPDATE SET
            quantity =
                public.stock_balances.quantity + v_base_qty,
            updated_at = NOW()
        RETURNING quantity
        INTO v_new_stock;

        INSERT INTO public.stock_movements (
            location_id,
            product_id,
            movement_type,
            quantity_change,
            quantity_after,
            notes,
            created_by,
            purchase_invoice_id
        )
        VALUES (
            p_location_id,
            v_product_id,
            'RECEIVE',
            v_base_qty,
            v_new_stock,
            'فاتورة مشتريات ' || v_invoice_number,
            auth.uid(),
            v_invoice_id
        );
    END LOOP;

    IF p_treasury_id IS NOT NULL AND v_total > 0 THEN
        PERFORM public.adjust_treasury_balance(
            p_treasury_id,
            -v_total,
            'فاتورة مشتريات ' || v_invoice_number
        );
    END IF;

    PERFORM public.post_journal_entry(
        v_date::TIMESTAMP AT TIME ZONE 'Africa/Cairo',
        'فاتورة مشتريات ' || v_invoice_number,
        'PURCHASE',
        v_invoice_id,
        jsonb_build_array(
            jsonb_build_object(
                'account', '1300',
                'debit', v_total,
                'credit', 0
            ),
            jsonb_build_object(
                'account', v_account_code,
                'debit', 0,
                'credit', v_total
            )
        )
    );

    RETURN v_invoice_id;
END;
$function$
;


-- Function snapshot: create_sales_invoice_v2
CREATE OR REPLACE FUNCTION public.create_sales_invoice_v2(p_customer_id bigint, p_location_id bigint, p_invoice_date date, p_discount numeric, p_notes text, p_items jsonb, p_trip_id bigint, p_payments jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
    v_invoice_id bigint;
    v_sales_invoice_item_id bigint;
    v_invoice_number text;
    v_collection_id bigint;
    v_collection_number text;

    v_subtotal numeric := 0;
    v_total numeric := 0;
    v_paid numeric := 0;
    v_remaining numeric := 0;

    v_invoice_method text := 'CREDIT';
    v_first_method text;
    v_first_treasury bigint;
    v_method text;
    v_treasury_id bigint;
    v_expected_treasury bigint;
    v_expected_type text;

    v_item jsonb;
    v_payment jsonb;

    v_product_id bigint;
    v_sale_unit_id bigint;
    v_package_option_id bigint;
    v_package_weight numeric;
    v_base_unit_id bigint;
    v_units_per_carton numeric;
    v_is_package boolean;

    v_qty numeric;
    v_price numeric;
    v_line numeric;
    v_base_qty numeric;
    v_current_stock numeric;
    v_new_stock numeric;

    v_seq int := 0;
    v_user_role_id bigint;
    v_sales_rep_id bigint;
    v_trip_sales_rep_id bigint;
    v_status text;
    v_account_id bigint;

BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'يجب تسجيل الدخول.';
    END IF;

    IF NOT (
        public.has_permission('INVOICES_CREATE')
        OR public.has_permission('SALES_MANAGE')
    ) THEN
        RAISE EXCEPTION 'لا توجد صلاحية لإنشاء الفاتورة.';
    END IF;
    PERFORM pg_advisory_xact_lock(947351);

    IF p_customer_id IS NULL OR p_location_id IS NULL THEN
        RAISE EXCEPTION 'يجب اختيار العميل والموقع.';
    END IF;

    IF p_items IS NULL
       OR jsonb_typeof(p_items) <> 'array'
       OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'يجب إضافة صنف واحد على الأقل.';
    END IF;

    IF p_payments IS NULL THEN
        p_payments := '[]'::jsonb;
    END IF;

    IF jsonb_typeof(p_payments) <> 'array' THEN
        RAISE EXCEPTION 'بيانات الدفعات يجب أن تكون قائمة.';
    END IF;

    SELECT role_id, sales_rep_id
    INTO v_user_role_id, v_sales_rep_id
    FROM public.app_users
    WHERE user_id = auth.uid()
      AND is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'المستخدم غير نشط أو غير مسجل.';
    END IF;

    IF v_user_role_id = 3 AND v_sales_rep_id IS NULL THEN
        SELECT sales_rep_id
        INTO v_sales_rep_id
        FROM public.sales_reps
        WHERE auth_user_id = auth.uid()
        LIMIT 1;
    END IF;

    IF p_trip_id IS NOT NULL THEN
        SELECT vehicle_location_id,sales_rep_id
        INTO p_location_id,v_trip_sales_rep_id
        FROM public.trips
        WHERE trip_id = p_trip_id
          AND status IN ('DRAFT', 'ACTIVE')
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'الجولة غير موجودة أو لا تقبل الفواتير.';
        END IF;
        IF v_sales_rep_id IS NULL THEN
            v_sales_rep_id:=v_trip_sales_rep_id;
        ELSIF v_sales_rep_id IS DISTINCT FROM v_trip_sales_rep_id THEN
            RAISE EXCEPTION 'مندوب المستخدم لا يطابق مندوب الجولة.';
        END IF;

        IF p_location_id IS NULL THEN
            RAISE EXCEPTION 'الجولة غير مرتبطة بمخزن سيارة.';
        END IF;

        IF v_user_role_id = 3 THEN
            IF v_sales_rep_id IS NULL THEN
                RAISE EXCEPTION 'لم يتم ربط المستخدم بمندوب مبيعات.';
            END IF;

            PERFORM 1
            FROM public.trips
            WHERE trip_id = p_trip_id
              AND sales_rep_id = v_sales_rep_id
              AND status = 'ACTIVE';

            IF NOT FOUND THEN
                RAISE EXCEPTION 'الجولة لا تخص المندوب أو ليست نشطة.';
            END IF;
        END IF;

    ELSIF v_user_role_id = 3 THEN
        RAISE EXCEPTION 'يجب اختيار جولة المندوب قبل إصدار الفاتورة.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.customers
        WHERE customer_id = p_customer_id
          AND is_active = true
    ) THEN
        RAISE EXCEPTION 'العميل غير موجود أو غير نشط.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.locations
        WHERE location_id = p_location_id
          AND is_active = true
    ) THEN
        RAISE EXCEPTION 'موقع المخزون غير موجود أو غير نشط.';
    END IF;

    IF COALESCE(p_discount, 0) < 0 THEN
        RAISE EXCEPTION 'الخصم لا يمكن أن يكون سالبًا.';
    END IF;

    -- حساب إجمالي الفاتورة

    FOR v_item IN
        SELECT value FROM jsonb_array_elements(p_items)
    LOOP
        v_qty := (v_item->>'quantity')::numeric;
        v_price := (v_item->>'unit_price')::numeric;

        IF v_qty IS NULL OR v_qty <= 0
           OR v_price IS NULL OR v_price < 0 THEN
            RAISE EXCEPTION 'كمية أو سعر الصنف غير صحيح.';
        END IF;

        v_line := round(v_qty * v_price, 2);
        v_subtotal := v_subtotal + v_line;
    END LOOP;

    IF v_user_role_id = 3
       AND COALESCE(p_discount, 0) > (v_subtotal * 0.03) THEN
        RAISE EXCEPTION
            'خصم المندوب يتجاوز الحد المسموح وهو 3%% من إجمالي الأصناف.';
    END IF;

    v_total := v_subtotal - COALESCE(p_discount, 0);

    IF v_total <= 0 THEN
        RAISE EXCEPTION 'صافي الفاتورة يجب أن يكون أكبر من صفر؛ راجع الأسعار والخصم.';
    END IF;

    IF v_total < 0 THEN
        RAISE EXCEPTION 'الخصم أكبر من إجمالي الفاتورة.';
    END IF;

    -- التحقق من الدفعات والخزن

    FOR v_payment IN
        SELECT value FROM jsonb_array_elements(p_payments)
    LOOP
        v_method := upper(trim(v_payment->>'payment_method'));
        v_qty := (v_payment->>'amount')::numeric;

        IF v_method NOT IN (
            'CASH',
            'BANK_TRANSFER',
            'INSTAPAY',
            'CHEQUE'
        ) THEN
            RAISE EXCEPTION 'وسيلة الدفع غير مدعومة: %', v_method;
        END IF;

        IF v_qty IS NULL OR v_qty <= 0 THEN
            RAISE EXCEPTION 'قيمة كل دفعة يجب أن تكون أكبر من صفر.';
        END IF;

        v_paid := v_paid + v_qty;

        IF v_method = 'CASH' THEN
            IF p_trip_id IS NOT NULL THEN
                v_expected_treasury := 8;
            ELSE
                v_expected_treasury :=
                    (v_payment->>'treasury_id')::bigint;

                IF v_expected_treasury NOT BETWEEN 1 AND 5 THEN
                    RAISE EXCEPTION
                        'النقدية خارج الجولة يجب أن تذهب إلى خزنة من 1 إلى 5.';
                END IF;
            END IF;

            v_expected_type := 'CASH';

        ELSIF v_method = 'BANK_TRANSFER' THEN
            v_expected_treasury := 7;
            v_expected_type := 'BANK';

        ELSIF v_method = 'INSTAPAY' THEN
            v_expected_treasury := 6;
            v_expected_type := 'INSTAPAY';

        ELSIF v_method = 'CHEQUE' THEN
            v_expected_treasury := 10;
            v_expected_type := 'CHEQUE';
        END IF;

        IF v_payment ? 'treasury_id'
           AND NULLIF(v_payment->>'treasury_id', '') IS NOT NULL
           AND (v_payment->>'treasury_id')::bigint
               <> v_expected_treasury THEN
            RAISE EXCEPTION
                'الخزنة المحددة لا تطابق وسيلة الدفع %.',
                v_method;
        END IF;

        SELECT treasury_id
        INTO v_treasury_id
        FROM public.treasuries
        WHERE treasury_id = v_expected_treasury
          AND is_active = true
          AND treasury_type = v_expected_type
          AND account_id IS NOT NULL;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'الخزنة المطلوبة غير نشطة أو غير مرتبطة بحساب محاسبي. رقم الخزنة: %',
                v_expected_treasury;
        END IF;

        IF v_first_method IS NULL THEN
            v_first_method := v_method;
            v_first_treasury := v_expected_treasury;
        ELSIF v_first_method <> v_method THEN
            v_invoice_method := 'MIXED';
        END IF;
    END LOOP;

    IF v_paid > v_total THEN
        RAISE EXCEPTION 'إجمالي الدفعات أكبر من صافي الفاتورة.';
    END IF;

    IF v_invoice_method <> 'MIXED' THEN
        IF v_first_method IS NOT NULL THEN
            v_invoice_method := v_first_method;
        ELSE
            v_invoice_method := 'CREDIT';
        END IF;
    END IF;

    IF v_paid = v_total AND v_total > 0 THEN
        v_status := 'PAID';
    ELSIF v_paid > 0 THEN
        v_status := 'PARTIAL';
    ELSE
        v_status := 'POSTED';
    END IF;

    v_remaining := v_total - v_paid;

    IF v_paid > 0
       AND NOT public.has_permission('COLLECTIONS_POST') THEN
        RAISE EXCEPTION 'لا توجد صلاحية لترحيل التحصيلات.';
    END IF;

    -- التحقق من المخزون والوحدات

    FOR v_item IN
        SELECT value FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::bigint;
        v_sale_unit_id := (v_item->>'sale_unit_id')::bigint;
        v_package_option_id := NULLIF(v_item->>'package_option_id','')::bigint;
        v_package_weight := NULL;
        v_qty := (v_item->>'quantity')::numeric;
        v_price := (v_item->>'unit_price')::numeric;

        SELECT base_unit_id, COALESCE(units_per_carton, 1)
        INTO v_base_unit_id, v_units_per_carton
        FROM public.products
        WHERE product_id = v_product_id
          AND is_active = true
          AND can_be_sold = true
          AND (v_sale_unit_id = base_unit_id
               OR v_sale_unit_id = sales_unit_id
               OR EXISTS (
                 SELECT 1 FROM public.product_unit_conversions puc
                 WHERE puc.product_id=products.product_id
                   AND puc.unit_id=v_sale_unit_id
                   AND puc.is_active=true
               )
               OR EXISTS (
                 SELECT 1 FROM public.units u
                 WHERE u.unit_id=v_sale_unit_id
                   AND u.is_active=true
                   AND u.is_package_unit=true
                   AND COALESCE(products.units_per_carton,0)>0
               ));

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'المنتج رقم % غير نشط أو غير مسموح ببيعه أو وحدة البيع لا تطابق الوحدة المسجلة.',
                v_product_id;
        END IF;

        IF v_user_role_id NOT IN (1, 2)
           AND EXISTS (
               SELECT 1
               FROM public.products p
               WHERE p.product_id = v_product_id
                 AND (
                     (p.min_selling_price IS NOT NULL
                      AND v_price < p.min_selling_price)
                     OR
                     (p.max_selling_price IS NOT NULL
                      AND v_price > p.max_selling_price)
                 )
           )
        THEN
            RAISE EXCEPTION
                'سعر بيع المنتج رقم % خارج حدود السعر المسموح بها. الحد الأدنى أو الأقصى لا يسمح بهذا السعر.',
                v_product_id;
        END IF;

        SELECT is_package_unit
        INTO v_is_package
        FROM public.units
        WHERE unit_id = v_sale_unit_id
          AND is_active = true;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'وحدة البيع غير موجودة أو غير نشطة.';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM public.units
            WHERE unit_id = v_sale_unit_id
              AND (
                  (
                      COALESCE(allows_decimal, false) = false
                      AND v_qty <> trunc(v_qty)
                  )
                  OR
                  (
                      COALESCE(allows_decimal, false) = true
                      AND v_qty <> round(
                          v_qty,
                          GREATEST(COALESCE(decimal_places, 0), 0)
                      )
                  )
              )
        ) THEN
            RAISE EXCEPTION
                'الكمية لا تتوافق مع إعدادات الكسور العشرية لوحدة البيع.';
        END IF;

        IF v_package_option_id IS NOT NULL THEN
            SELECT weight_kg INTO v_package_weight
            FROM public.product_packaging_options
            WHERE package_option_id = v_package_option_id
              AND product_id = v_product_id
              AND unit_id = v_sale_unit_id
              AND is_active = true;
            IF NOT FOUND OR v_package_weight IS NULL OR v_package_weight <= 0 THEN
                RAISE EXCEPTION 'خيار التعبئة غير موجود أو غير نشط لهذا المنتج.';
            END IF;
            IF v_base_unit_id <> 1 THEN
                RAISE EXCEPTION 'يجب أن تكون وحدة المخزون الأساسية كيلوجرام لاستخدام وزن العبوة.';
            END IF;
            v_base_qty := v_qty * v_package_weight;
        ELSIF v_sale_unit_id = 5 AND v_base_unit_id = 1 THEN
            RAISE EXCEPTION 'يجب اختيار حجم الطبق قبل البيع.';
        ELSIF v_sale_unit_id = v_base_unit_id THEN
            v_base_qty := v_qty;
        ELSIF COALESCE(v_is_package, false)
              AND NOT EXISTS (
                SELECT 1 FROM public.product_unit_conversions puc
                WHERE puc.product_id=v_product_id
                  AND puc.unit_id=v_sale_unit_id
                  AND puc.is_active=true
              ) THEN
            v_base_qty := v_qty * v_units_per_carton;
        ELSE
            v_base_qty := v_qty * public.fn_base_factor(v_product_id,v_sale_unit_id);
        END IF;

        SELECT quantity
        INTO v_current_stock
        FROM public.stock_balances
        WHERE location_id = p_location_id
          AND product_id = v_product_id;

        IF NOT FOUND THEN
            v_current_stock := 0;
        END IF;

        IF v_current_stock < v_base_qty THEN
            RAISE EXCEPTION
                'الرصيد غير كافٍ للمنتج رقم %.',
                v_product_id;
        END IF;
    END LOOP;

    -- إنشاء الفاتورة

    v_invoice_number :=
        'INV-' ||
        lpad(nextval('public.sales_invoice_seq')::text, 6, '0');

    INSERT INTO public.sales_invoices (
        invoice_number,
        customer_id,
        location_id,
        invoice_date,
        payment_method,
        subtotal,
        discount_amount,
        net_total,
        paid_amount,
        remaining_amount,
        notes,
        status,
        created_by,
        trip_id
    )
    VALUES (
        v_invoice_number,
        p_customer_id,
        p_location_id,
        COALESCE(p_invoice_date, CURRENT_DATE),
        v_invoice_method,
        v_subtotal,
        COALESCE(p_discount, 0),
        v_total,
        v_paid,
        v_remaining,
        p_notes,
        v_status,
        auth.uid(),
        p_trip_id
    )
    RETURNING sales_invoice_id INTO v_invoice_id;

    -- تسجيل البنود وخصم المخزون

    FOR v_item IN
        SELECT value FROM jsonb_array_elements(p_items)
    LOOP
        v_seq := v_seq + 1;

        v_product_id := (v_item->>'product_id')::bigint;
        v_sale_unit_id := (v_item->>'sale_unit_id')::bigint;
        v_package_option_id := NULLIF(v_item->>'package_option_id','')::bigint;
        v_package_weight := NULL;
        v_qty := (v_item->>'quantity')::numeric;
        v_price := (v_item->>'unit_price')::numeric;

        SELECT base_unit_id, COALESCE(units_per_carton, 1)
        INTO v_base_unit_id, v_units_per_carton
        FROM public.products
        WHERE product_id = v_product_id;

        SELECT is_package_unit
        INTO v_is_package
        FROM public.units
        WHERE unit_id = v_sale_unit_id;

        IF v_package_option_id IS NOT NULL THEN
            SELECT weight_kg INTO v_package_weight
            FROM public.product_packaging_options
            WHERE package_option_id = v_package_option_id
              AND product_id = v_product_id
              AND unit_id = v_sale_unit_id
              AND is_active = true;
            IF NOT FOUND OR v_package_weight IS NULL OR v_package_weight <= 0 THEN
                RAISE EXCEPTION 'خيار التعبئة غير موجود أو غير نشط لهذا المنتج.';
            END IF;
            IF v_base_unit_id <> 1 THEN
                RAISE EXCEPTION 'يجب أن تكون وحدة المخزون الأساسية كيلوجرام لاستخدام وزن العبوة.';
            END IF;
            v_base_qty := v_qty * v_package_weight;
        ELSIF v_sale_unit_id = 5 AND v_base_unit_id = 1 THEN
            RAISE EXCEPTION 'يجب اختيار حجم الطبق قبل البيع.';
        ELSIF v_sale_unit_id = v_base_unit_id THEN
            v_base_qty := v_qty;
        ELSIF COALESCE(v_is_package, false)
              AND NOT EXISTS (
                SELECT 1 FROM public.product_unit_conversions puc
                WHERE puc.product_id=v_product_id
                  AND puc.unit_id=v_sale_unit_id
                  AND puc.is_active=true
              ) THEN
            v_base_qty := v_qty * v_units_per_carton;
        ELSE
            v_base_qty := v_qty * public.fn_base_factor(v_product_id,v_sale_unit_id);
        END IF;

        v_line := round(v_qty * v_price, 2);

        INSERT INTO public.sales_invoice_items (
            sales_invoice_id,
            product_id,
            unit_id,
            quantity,
            base_quantity,
            unit_price,
            line_total,
            sequence_no,
            package_option_id,
            package_weight_kg
        )
        VALUES (
            v_invoice_id,
            v_product_id,
            v_sale_unit_id,
            v_qty,
            v_base_qty,
            v_price,
            v_line,
            v_seq,
            v_package_option_id,
            v_package_weight
        )
        RETURNING sales_invoice_item_id INTO v_sales_invoice_item_id;

        INSERT INTO public.stock_balances (
            location_id,
            product_id,
            quantity,
            updated_at
        )
        VALUES (
            p_location_id,
            v_product_id,
            0,
            NOW()
        )
        ON CONFLICT (location_id, product_id)
        DO NOTHING;

        SELECT quantity
        INTO v_current_stock
        FROM public.stock_balances
        WHERE location_id = p_location_id
          AND product_id = v_product_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'تعذر قفل رصيد المخزون.';
        END IF;

        PERFORM public.assert_stock_available(p_location_id,v_product_id,v_base_qty);
        IF v_current_stock < v_base_qty THEN
            RAISE EXCEPTION
                'الرصيد غير كافٍ للمنتج رقم %. المتاح: %، المطلوب: %.',
                v_product_id,
                v_current_stock,
                v_base_qty;
        END IF;

        v_new_stock := v_current_stock - v_base_qty;

        UPDATE public.stock_balances
        SET quantity = v_new_stock,
            updated_at = NOW()
        WHERE location_id = p_location_id
          AND product_id = v_product_id;

        INSERT INTO public.stock_movements (
            location_id,
            product_id,
            movement_type,
            quantity_change,
            quantity_after,
            notes,
            created_by,
            trip_id,
            sales_invoice_id,
            sales_invoice_item_id
        )
        VALUES (
            p_location_id,
            v_product_id,
            'ISSUE',
            -v_base_qty,
            v_new_stock,
            'فاتورة بيع ' || v_invoice_number,
            auth.uid(),
            p_trip_id,
            v_invoice_id,
            v_sales_invoice_item_id
        );
    END LOOP;

    -- تسجيل كل دفعة في خزنتها

    FOR v_payment IN
        SELECT value FROM jsonb_array_elements(p_payments)
    LOOP
        v_method := upper(trim(v_payment->>'payment_method'));
        v_qty := (v_payment->>'amount')::numeric;

        IF v_method = 'CASH' THEN
            IF p_trip_id IS NOT NULL THEN
                v_treasury_id := 8;
            ELSE
                v_treasury_id :=
                    (v_payment->>'treasury_id')::bigint;
            END IF;
        ELSIF v_method = 'BANK_TRANSFER' THEN
            v_treasury_id := 7;
        ELSIF v_method = 'INSTAPAY' THEN
            v_treasury_id := 6;
        ELSE
            v_treasury_id := 10;
        END IF;

        v_collection_number :=
            'COL-' ||
            lpad(
                nextval('public.customer_collection_seq')::text,
                6,
                '0'
            );

        INSERT INTO public.customer_collections (
            collection_number,
            customer_id,
            sales_invoice_id,
            amount,
            payment_method,
            collection_date,
            reference_number,
            notes,
            created_by,
            trip_id,
            status,
            treasury_id
        )
        VALUES (
            v_collection_number,
            p_customer_id,
            v_invoice_id,
            v_qty,
            v_method,
            COALESCE(p_invoice_date, CURRENT_DATE),
            v_payment->>'reference_number',
            COALESCE(
                v_payment->>'notes',
                'دفعة مع فاتورة ' || v_invoice_number
            ),
            auth.uid(),
            p_trip_id,
            'POSTED',
            v_treasury_id
        )
        RETURNING collection_id INTO v_collection_id;

        IF v_method = 'CHEQUE' THEN
            IF NULLIF(BTRIM(v_payment->>'reference_number'), '') IS NULL THEN
                RAISE EXCEPTION 'يجب إدخال رقم الشيك قبل تسجيل التحصيل.';
            END IF;

            INSERT INTO public.customer_cheques (
                collection_id,
                cheque_number,
                bank_name,
                due_date,
                amount,
                notes,
                created_by
            )
            VALUES (
                v_collection_id,
                BTRIM(v_payment->>'reference_number'),
                NULLIF(BTRIM(v_payment->>'bank_name'), ''),
                NULLIF(BTRIM(v_payment->>'due_date'), '')::date,
                v_qty,
                COALESCE(v_payment->>'notes', 'شيك مع فاتورة ' || v_invoice_number),
                auth.uid()
            );
        END IF;

        UPDATE public.treasuries
        SET current_balance = current_balance + v_qty
        WHERE treasury_id = v_treasury_id
          AND is_active = true
        RETURNING account_id INTO v_account_id;

        IF NOT FOUND OR v_account_id IS NULL THEN
            RAISE EXCEPTION 'تعذر تحديث رصيد الخزنة رقم %.', v_treasury_id;
        END IF;

        INSERT INTO public.treasury_transactions (
            treasury_id,
            transaction_type,
            amount,
            reference_type,
            reference_id,
            notes,
            transaction_date,
            created_by
        )
        VALUES (
            v_treasury_id,
            'DEPOSIT',
            v_qty,
            'COLLECTION',
            v_collection_id,
            'تحصيل فاتورة ' || v_invoice_number,
            COALESCE(p_invoice_date, CURRENT_DATE),
            auth.uid()
        );
    END LOOP;

    RETURN v_invoice_id;
END;
$function$
;


-- Function snapshot: get_sales_invoice_lot_allocations
CREATE OR REPLACE FUNCTION public.get_sales_invoice_lot_allocations(p_sales_invoice_id bigint)
 RETURNS TABLE(sales_invoice_item_id bigint, product_id bigint, lot_id bigint, lot_code text, allocated_quantity numeric, unit_id bigint, package_option_id bigint, expires_on date)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL
     OR NOT (public.has_permission('RETURNS_CREATE') OR public.has_permission('RETURNS_MANAGE')) THEN
    RAISE EXCEPTION 'لا تملك صلاحية عرض تشغيلات الفاتورة للمرتجع';
  END IF;
  IF NOT (
    public.has_permission('INVOICES_VIEW')
    OR public.has_permission('SALES_MANAGE')
    OR public.has_permission('RETURNS_MANAGE')
  ) THEN
    RAISE EXCEPTION 'لا تملك صلاحية عرض الفاتورة الأصلية';
  END IF;
  IF p_sales_invoice_id IS NULL THEN
    RAISE EXCEPTION 'الفاتورة الأصلية مطلوبة';
  END IF;

  RETURN QUERY
  SELECT sm.sales_invoice_item_id,
         sm.product_id,
         a.lot_id,
         l.lot_code,
         SUM(a.quantity)::numeric,
         sii.unit_id,
         sii.package_option_id,
         l.expires_on
  FROM public.stock_movements sm
  JOIN public.stock_movement_lot_allocations a
    ON a.movement_id=sm.movement_id
   AND a.allocation_direction='OUT'
  JOIN public.stock_lots l ON l.lot_id=a.lot_id
  JOIN public.sales_invoice_items sii
    ON sii.sales_invoice_item_id=sm.sales_invoice_item_id
  WHERE sm.sales_invoice_id=p_sales_invoice_id
    AND sm.sales_invoice_item_id IS NOT NULL
    AND sm.movement_type='ISSUE'
  GROUP BY sm.sales_invoice_item_id,sm.product_id,a.lot_id,l.lot_code,
           sii.unit_id,sii.package_option_id,l.expires_on
  ORDER BY sm.sales_invoice_item_id,l.expires_on ASC NULLS LAST,l.lot_code;
END;
$function$
;


-- Function snapshot: post_sales_return
CREATE OR REPLACE FUNCTION public.post_sales_return(p_sales_return_id bigint, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  r public.sales_returns%ROWTYPE;
  x record;
  v_new_stock numeric;
  v_new_remaining numeric;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;
  IF NOT (public.has_permission('RETURNS_APPROVE') OR public.has_permission('RETURNS_MANAGE')) THEN
    RAISE EXCEPTION 'لا تملك صلاحية ترحيل المرتجعات';
  END IF;
  IF p_created_by IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'منفذ الترحيل يجب أن يطابق المستخدم الحالي';
  END IF;
  PERFORM pg_advisory_xact_lock(947351);

  SELECT * INTO r FROM public.sales_returns
  WHERE sales_return_id=p_sales_return_id FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'المرتجع غير موجود'; END IF;
  IF r.status='POSTED' THEN RETURN; END IF;
  IF r.status<>'DRAFT' THEN RAISE EXCEPTION 'المرتجع ليس في حالة مسودة'; END IF;

  PERFORM public.validate_sales_return(p_sales_return_id);
  PERFORM public.assert_accounting_period_open(r.return_date);

  FOR x IN
    SELECT location_id,product_id,SUM(base_quantity) AS quantity
    FROM public.sales_return_items
    WHERE sales_return_id=p_sales_return_id
    GROUP BY location_id,product_id
    ORDER BY location_id,product_id
  LOOP
    INSERT INTO public.stock_balances(location_id,product_id,quantity,updated_at)
    VALUES(x.location_id,x.product_id,0,now())
    ON CONFLICT(location_id,product_id) DO NOTHING;

    UPDATE public.stock_balances
    SET quantity=quantity+x.quantity,updated_at=now()
    WHERE location_id=x.location_id AND product_id=x.product_id
    RETURNING quantity INTO v_new_stock;

    INSERT INTO public.stock_movements(
      location_id,product_id,movement_type,quantity_change,
      quantity_after,notes,created_by,trip_id,sales_return_id
    )
    VALUES(
      x.location_id,x.product_id,'RETURN',x.quantity,v_new_stock,
      'مرتجع عميل '||r.return_number,auth.uid(),r.trip_id,p_sales_return_id
    );
  END LOOP;

  IF r.cash_action='CASH_BACK' AND EXISTS (
    SELECT 1 FROM public.sales_invoices si
    WHERE si.sales_invoice_id=r.sales_invoice_id
      AND si.remaining_amount>0.01
  ) THEN
    RAISE EXCEPTION 'لا يمكن رد النقدية مع وجود مديونية على الفاتورة.';
  END IF;

  IF r.cash_action='DEDUCT_DEBT' THEN
    UPDATE public.sales_invoices
    SET remaining_amount=remaining_amount-r.total_returned_value,
        status=CASE
          WHEN remaining_amount-r.total_returned_value<=0.01 THEN 'PAID'
          WHEN COALESCE(paid_amount,0)>0 THEN 'PARTIAL'
          ELSE 'POSTED'
        END,
        updated_at=now()
    WHERE sales_invoice_id=r.sales_invoice_id
      AND remaining_amount>=r.total_returned_value
    RETURNING remaining_amount INTO v_new_remaining;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'تعذر خصم قيمة المرتجع من مديونية الفاتورة';
    END IF;

  ELSIF r.cash_action='CASH_BACK' THEN
    UPDATE public.treasuries
    SET current_balance=current_balance-r.total_returned_value
    WHERE treasury_id=r.treasury_id
      AND is_active
      AND current_balance>=r.total_returned_value;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'رصيد الخزنة المحددة لا يكفي لرد المبلغ';
    END IF;

    INSERT INTO public.treasury_transactions(
      treasury_id,transaction_type,amount,reference_type,reference_id,
      notes,transaction_date,created_by
    )
    VALUES(
      r.treasury_id,'WITHDRAW',r.total_returned_value,'SALES_RETURN',r.sales_return_id,
      'رد نقدية مرتجع '||r.return_number,r.return_date,auth.uid()
    );
  END IF;

  UPDATE public.sales_returns
  SET status='POSTED',
      price_difference=-total_returned_value,
      approved_at=now(),
      approved_by=auth.uid()
  WHERE sales_return_id=p_sales_return_id;
END;
$function$
;


-- Function snapshot: sync_stock_movement_lots
CREATE OR REPLACE FUNCTION public.sync_stock_movement_lots()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_lot_id bigint;
  v_source_movement_id bigint;
  v_remaining numeric;
  v_take numeric;
  v_alloc record;
  v_balance record;
  v_item record;
  v_source_total numeric;
  v_source_type text;
  v_supplier_id bigint;
BEGIN
  IF NEW.quantity_change=0 THEN RETURN NEW; END IF;

  IF NEW.quantity_change < 0 THEN
    v_remaining := abs(NEW.quantity_change);

    -- Exact source lot for supplier returns.
    IF NEW.purchase_return_id IS NOT NULL THEN
      SELECT COUNT(*) INTO v_source_total
      FROM public.purchase_return_items pri
      JOIN public.stock_lots l
        ON l.source_purchase_invoice_item_id=pri.purchase_invoice_item_id
      WHERE pri.return_id=NEW.purchase_return_id
        AND pri.product_id=NEW.product_id;
      FOR v_item IN
        SELECT pri.product_id,pri.base_quantity,pri.purchase_invoice_item_id,
               l.lot_id,lb.quantity AS available_quantity
        FROM public.purchase_return_items pri
        JOIN public.stock_lots l
          ON l.source_purchase_invoice_item_id=pri.purchase_invoice_item_id
        JOIN public.stock_lot_balances lb
          ON lb.lot_id=l.lot_id AND lb.location_id=NEW.location_id
        WHERE pri.return_id=NEW.purchase_return_id
          AND pri.product_id=NEW.product_id
        ORDER BY l.lot_id
        FOR UPDATE OF lb
      LOOP
        v_take := LEAST(v_remaining,v_item.base_quantity,v_item.available_quantity);
        IF v_take>0 THEN
          UPDATE public.stock_lot_balances
          SET quantity=quantity-v_take,updated_at=now()
          WHERE lot_id=v_item.lot_id AND location_id=NEW.location_id
            AND quantity>=v_take;
          IF NOT FOUND THEN RAISE EXCEPTION 'تعذر خصم كمية التشغيلة من رصيد الموقع'; END IF;
          INSERT INTO public.stock_movement_lot_allocations(movement_id,lot_id,allocation_direction,quantity)
          VALUES(NEW.movement_id,v_item.lot_id,'OUT',v_take);
          v_remaining:=v_remaining-v_take;
        END IF;
        EXIT WHEN v_remaining<=0;
      END LOOP;
    END IF;

    -- Reverse an earlier movement using its exact lot allocations.
    IF v_remaining>0 AND NEW.reversal_of_movement_id IS NOT NULL THEN
      SELECT COUNT(*) INTO v_source_total
      FROM public.stock_movement_lot_allocations
      WHERE movement_id=NEW.reversal_of_movement_id;
      FOR v_alloc IN
        SELECT a.lot_id,a.allocation_direction,a.quantity
        FROM public.stock_movement_lot_allocations a
        WHERE a.movement_id=NEW.reversal_of_movement_id
        ORDER BY a.allocation_id
      LOOP
        v_take:=LEAST(v_remaining,v_alloc.quantity);
        IF v_take>0 THEN
          IF v_alloc.allocation_direction='IN' THEN
            UPDATE public.stock_lot_balances
            SET quantity=quantity-v_take,updated_at=now()
            WHERE lot_id=v_alloc.lot_id AND location_id=NEW.location_id
              AND quantity>=v_take;
            IF NOT FOUND THEN RAISE EXCEPTION 'لا يمكن عكس التشغيلة لأن كميتها لم تعد متاحة'; END IF;
            INSERT INTO public.stock_movement_lot_allocations(movement_id,lot_id,allocation_direction,quantity)
            VALUES(NEW.movement_id,v_alloc.lot_id,'OUT',v_take);
          ELSE
            INSERT INTO public.stock_lot_balances(lot_id,location_id,quantity)
            VALUES(v_alloc.lot_id,NEW.location_id,v_take)
            ON CONFLICT(lot_id,location_id)
            DO UPDATE SET quantity=public.stock_lot_balances.quantity+EXCLUDED.quantity,updated_at=now();
            INSERT INTO public.stock_movement_lot_allocations(movement_id,lot_id,allocation_direction,quantity)
            VALUES(NEW.movement_id,v_alloc.lot_id,'IN',v_take);
          END IF;
          v_remaining:=v_remaining-v_take;
        END IF;
        EXIT WHEN v_remaining<=0;
      END LOOP;
    END IF;

    -- Cancelling a customer return removes the exact lots previously received by that return.
    IF v_remaining>0 AND NEW.sales_return_id IS NOT NULL THEN
      SELECT COALESCE(SUM(a.quantity),0) INTO v_source_total
      FROM public.stock_movements source_movement
      JOIN public.stock_movement_lot_allocations a
        ON a.movement_id=source_movement.movement_id
       AND a.allocation_direction='IN'
      WHERE source_movement.sales_return_id=NEW.sales_return_id
        AND source_movement.location_id=NEW.location_id
        AND source_movement.product_id=NEW.product_id
        AND source_movement.quantity_change>0;
      IF v_source_total>0 THEN
        FOR v_alloc IN
          SELECT a.lot_id,SUM(a.quantity) AS quantity
          FROM public.stock_movements source_movement
          JOIN public.stock_movement_lot_allocations a
            ON a.movement_id=source_movement.movement_id
           AND a.allocation_direction='IN'
          WHERE source_movement.sales_return_id=NEW.sales_return_id
            AND source_movement.location_id=NEW.location_id
            AND source_movement.product_id=NEW.product_id
            AND source_movement.quantity_change>0
          GROUP BY a.lot_id
          ORDER BY a.lot_id
        LOOP
          v_take:=LEAST(v_remaining,v_alloc.quantity);
          IF v_take>0 THEN
            UPDATE public.stock_lot_balances
            SET quantity=quantity-v_take,updated_at=now()
            WHERE lot_id=v_alloc.lot_id AND location_id=NEW.location_id
              AND quantity>=v_take;
            IF NOT FOUND THEN
              RAISE EXCEPTION 'لا يمكن إلغاء المرتجع لأن كمية التشغيلة الأصلية لم تعد متاحة';
            END IF;
            INSERT INTO public.stock_movement_lot_allocations(movement_id,lot_id,allocation_direction,quantity)
            VALUES(NEW.movement_id,v_alloc.lot_id,'OUT',v_take);
            v_remaining:=v_remaining-v_take;
          END IF;
          EXIT WHEN v_remaining<=0;
        END LOOP;
        IF v_remaining>0 THEN
          RAISE EXCEPTION 'كمية التشغيلة الأصلية لا تكفي لعكس المرتجع';
        END IF;
      END IF;
    END IF;

    -- Otherwise consume eligible lots by FEFO (expiry first, then receipt date).
    IF v_remaining>0 AND (NEW.purchase_return_id IS NULL OR v_source_total=0)
       AND (NEW.reversal_of_movement_id IS NULL OR v_source_total=0)
       AND (NEW.sales_return_id IS NULL OR v_source_total=0) THEN
      FOR v_balance IN
        SELECT lb.lot_id,lb.quantity
        FROM public.stock_lot_balances lb
        JOIN public.stock_lots l ON l.lot_id=lb.lot_id
        WHERE lb.location_id=NEW.location_id
          AND l.product_id=NEW.product_id
          AND lb.quantity>0
          AND l.status='ACTIVE'
          AND (l.expires_on IS NULL OR l.expires_on>=CURRENT_DATE)
        ORDER BY l.expires_on ASC NULLS LAST,l.received_at ASC,l.lot_id ASC
        FOR UPDATE OF lb
      LOOP
        v_take:=LEAST(v_remaining,v_balance.quantity);
        UPDATE public.stock_lot_balances
        SET quantity=quantity-v_take,updated_at=now()
        WHERE lot_id=v_balance.lot_id AND location_id=NEW.location_id
          AND quantity>=v_take;
        IF NOT FOUND THEN RAISE EXCEPTION 'تغير رصيد التشغيلة أثناء الصرف، أعد المحاولة'; END IF;
        INSERT INTO public.stock_movement_lot_allocations(movement_id,lot_id,allocation_direction,quantity)
        VALUES(NEW.movement_id,v_balance.lot_id,'OUT',v_take);
        v_remaining:=v_remaining-v_take;
        EXIT WHEN v_remaining<=0;
      END LOOP;
    END IF;

    IF v_remaining>0 THEN
      RAISE EXCEPTION 'كمية التشغيلات المتاحة لا تكفي للحركة رقم %، العجز %',NEW.movement_id,v_remaining;
    END IF;
    IF NEW.sales_invoice_item_id IS NOT NULL THEN
      UPDATE public.sales_invoice_items sii
      SET lot_id=(
        SELECT MIN(a.lot_id)
        FROM public.stock_movement_lot_allocations a
        WHERE a.movement_id=NEW.movement_id
          AND a.allocation_direction='OUT'
        HAVING COUNT(*)=1
      )
      WHERE sii.sales_invoice_item_id=NEW.sales_invoice_item_id;
    END IF;
    RETURN NEW;
  END IF;

  -- Incoming reversal restores exact original lots when the original movement was tracked.
  IF NEW.reversal_of_movement_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_source_total
    FROM public.stock_movement_lot_allocations
    WHERE movement_id=NEW.reversal_of_movement_id;
    IF v_source_total>0 THEN
      FOR v_alloc IN
        SELECT a.lot_id,a.allocation_direction,a.quantity
        FROM public.stock_movement_lot_allocations a
        WHERE a.movement_id=NEW.reversal_of_movement_id
        ORDER BY a.allocation_id
      LOOP
        IF v_alloc.allocation_direction='OUT' THEN
          INSERT INTO public.stock_lot_balances(lot_id,location_id,quantity)
          VALUES(v_alloc.lot_id,NEW.location_id,v_alloc.quantity)
          ON CONFLICT(lot_id,location_id)
          DO UPDATE SET quantity=public.stock_lot_balances.quantity+EXCLUDED.quantity,updated_at=now();
          INSERT INTO public.stock_movement_lot_allocations(movement_id,lot_id,allocation_direction,quantity)
          VALUES(NEW.movement_id,v_alloc.lot_id,'IN',v_alloc.quantity);
        ELSE
          UPDATE public.stock_lot_balances
          SET quantity=quantity-v_alloc.quantity,updated_at=now()
          WHERE lot_id=v_alloc.lot_id AND location_id=NEW.location_id
            AND quantity>=v_alloc.quantity;
          IF NOT FOUND THEN RAISE EXCEPTION 'لا يمكن عكس حركة الاستلام لأن كمية التشغيلة غير متاحة'; END IF;
          INSERT INTO public.stock_movement_lot_allocations(movement_id,lot_id,allocation_direction,quantity)
          VALUES(NEW.movement_id,v_alloc.lot_id,'OUT',v_alloc.quantity);
        END IF;
      END LOOP;
      RETURN NEW;
    END IF;
  END IF;

  -- Transfer-in movements inherit exact lots when the source movement is tracked.
  IF NEW.movement_type='TRANSFER_IN' THEN
    SELECT m.movement_id INTO v_source_movement_id
    FROM public.stock_movements m
    WHERE m.movement_type='TRANSFER_OUT'
      AND m.product_id=NEW.product_id
      AND (
        (NEW.stock_transfer_id IS NOT NULL AND m.stock_transfer_id=NEW.stock_transfer_id)
        OR (NEW.trip_load_id IS NOT NULL AND m.trip_load_id=NEW.trip_load_id)
      )
    ORDER BY m.movement_id DESC LIMIT 1;
    IF v_source_movement_id IS NULL THEN
      RAISE EXCEPTION 'حركة التحويل الوارد لا ترتبط بحركة صرف صادرة';
    END IF;
    SELECT COALESCE(SUM(quantity),0) INTO v_source_total
    FROM public.stock_movement_lot_allocations
    WHERE movement_id=v_source_movement_id AND allocation_direction='OUT';
    IF v_source_total>0 THEN
      IF abs(v_source_total-NEW.quantity_change)>0.0001 THEN
        RAISE EXCEPTION 'توزيع التشغيلات في حركة التحويل لا يطابق الكمية المحولة';
      END IF;
      FOR v_alloc IN
        SELECT lot_id,quantity FROM public.stock_movement_lot_allocations
        WHERE movement_id=v_source_movement_id AND allocation_direction='OUT'
      LOOP
        INSERT INTO public.stock_lot_balances(lot_id,location_id,quantity)
        VALUES(v_alloc.lot_id,NEW.location_id,v_alloc.quantity)
        ON CONFLICT(lot_id,location_id)
        DO UPDATE SET quantity=public.stock_lot_balances.quantity+EXCLUDED.quantity,updated_at=now();
        INSERT INTO public.stock_movement_lot_allocations(movement_id,lot_id,allocation_direction,quantity)
        VALUES(NEW.movement_id,v_alloc.lot_id,'IN',v_alloc.quantity);
      END LOOP;
      RETURN NEW;
    END IF;
    -- Historical source movement without allocations: destination lot will be untraced.
  END IF;

  -- Trip surplus return preserves known lots; legacy trips receive an untraced return lot.
  IF NEW.trip_id IS NOT NULL AND NEW.movement_type IN ('RECEIVE','RETURN') THEN
    SELECT m.movement_id INTO v_source_movement_id
    FROM public.stock_movements m
    WHERE m.trip_id=NEW.trip_id AND m.product_id=NEW.product_id
      AND m.quantity_change<0 AND m.notes ILIKE '%إرجاع فائض جولة%'
    ORDER BY m.movement_id DESC LIMIT 1;
    IF v_source_movement_id IS NOT NULL THEN
      SELECT COALESCE(SUM(quantity),0) INTO v_source_total
      FROM public.stock_movement_lot_allocations
      WHERE movement_id=v_source_movement_id AND allocation_direction='OUT';
      IF v_source_total>0 THEN
        IF abs(v_source_total-NEW.quantity_change)>0.0001 THEN
          RAISE EXCEPTION 'كمية التشغيلات المرتجعة من السيارة لا تطابق الكمية المستلمة';
        END IF;
        FOR v_alloc IN
          SELECT lot_id,quantity FROM public.stock_movement_lot_allocations
          WHERE movement_id=v_source_movement_id AND allocation_direction='OUT'
        LOOP
          INSERT INTO public.stock_lot_balances(lot_id,location_id,quantity)
          VALUES(v_alloc.lot_id,NEW.location_id,v_alloc.quantity)
          ON CONFLICT(lot_id,location_id)
          DO UPDATE SET quantity=public.stock_lot_balances.quantity+EXCLUDED.quantity,updated_at=now();
          INSERT INTO public.stock_movement_lot_allocations(movement_id,lot_id,allocation_direction,quantity)
          VALUES(NEW.movement_id,v_alloc.lot_id,'IN',v_alloc.quantity);
        END LOOP;
        RETURN NEW;
      END IF;
    END IF;
  END IF;

  -- Customer returns restore a selected source lot when one was recorded.
  IF NEW.sales_return_id IS NOT NULL AND NEW.movement_type IN ('RETURN','RECEIVE') THEN
    v_source_total:=0;
    FOR v_item IN
      SELECT sri.lot_id,SUM(sri.base_quantity) AS quantity
      FROM public.sales_return_items sri
      WHERE sri.sales_return_id=NEW.sales_return_id
        AND sri.product_id=NEW.product_id
        AND sri.location_id=NEW.location_id
        AND sri.lot_id IS NOT NULL
      GROUP BY sri.lot_id
      ORDER BY sri.lot_id
    LOOP
      INSERT INTO public.stock_lot_balances(lot_id,location_id,quantity)
      VALUES(v_item.lot_id,NEW.location_id,v_item.quantity)
      ON CONFLICT(lot_id,location_id)
      DO UPDATE SET quantity=public.stock_lot_balances.quantity+EXCLUDED.quantity,updated_at=now();
      INSERT INTO public.stock_movement_lot_allocations(movement_id,lot_id,allocation_direction,quantity)
      VALUES(NEW.movement_id,v_item.lot_id,'IN',v_item.quantity);
      v_source_total:=v_source_total+v_item.quantity;
    END LOOP;
    v_remaining:=NEW.quantity_change-v_source_total;
    IF v_remaining<0 THEN RAISE EXCEPTION 'كمية التشغيلات المرتجعة أكبر من كمية بند المرتجع'; END IF;
    IF v_remaining=0 THEN RETURN NEW; END IF;
    INSERT INTO public.stock_lots(product_id,source_type,received_at,created_by,notes)
    VALUES(NEW.product_id,'RETURN',NEW.created_at,NEW.created_by,
      'مرتجع عميل دون تحديد تشغيلة المصدر')
    RETURNING lot_id INTO v_lot_id;
    INSERT INTO public.stock_lot_balances(lot_id,location_id,quantity)
    VALUES(v_lot_id,NEW.location_id,v_remaining);
    INSERT INTO public.stock_movement_lot_allocations(movement_id,lot_id,allocation_direction,quantity)
    VALUES(NEW.movement_id,v_lot_id,'IN',v_remaining);
    RETURN NEW;
  END IF;

  -- Purchase receipts create one lot per invoice line.
  IF NEW.purchase_invoice_id IS NOT NULL AND NEW.movement_type='RECEIVE' THEN
    SELECT pi.supplier_id INTO v_supplier_id
    FROM public.purchase_invoices pi
    WHERE pi.purchase_invoice_id=NEW.purchase_invoice_id;
    SELECT pii.item_id,pii.supplier_lot_code,pii.manufactured_on,pii.expires_on
      INTO v_item
    FROM public.purchase_invoice_items pii
    WHERE pii.purchase_invoice_id=NEW.purchase_invoice_id
      AND pii.product_id=NEW.product_id
      AND NOT EXISTS (
        SELECT 1 FROM public.stock_lots l
        WHERE l.source_purchase_invoice_item_id=pii.item_id
      )
    ORDER BY pii.item_id LIMIT 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'تعذر تحديد بند فاتورة الشراء لإنشاء التشغيلة'; END IF;
    INSERT INTO public.stock_lots(product_id,source_type,source_purchase_invoice_item_id,
      supplier_id,supplier_lot_code,manufactured_on,expires_on,received_at,created_by,notes)
    VALUES(NEW.product_id,'PURCHASE',v_item.item_id,v_supplier_id,v_item.supplier_lot_code,
      v_item.manufactured_on,v_item.expires_on,NEW.created_at,NEW.created_by,
      'تشغيلة ناتجة عن فاتورة مشتريات')
    RETURNING lot_id INTO v_lot_id;
  ELSIF NEW.production_order_id IS NOT NULL AND NEW.movement_type='RECEIVE' THEN
    INSERT INTO public.stock_lots(product_id,source_type,source_production_order_id,
      manufactured_on,expires_on,received_at,created_by,notes)
    SELECT NEW.product_id,'PRODUCTION',NEW.production_order_id,NEW.created_at::date,
      CASE WHEN p.shelf_life_days IS NOT NULL THEN NEW.created_at::date+p.shelf_life_days ELSE NULL END,
      NEW.created_at,NEW.created_by,'تشغيلة ناتجة عن أمر إنتاج'
    FROM public.products p WHERE p.product_id=NEW.product_id
    RETURNING lot_id INTO v_lot_id;
    UPDATE public.production_orders SET output_lot_id=v_lot_id
    WHERE order_id=NEW.production_order_id AND output_lot_id IS NULL;
  ELSE
    INSERT INTO public.stock_lots(product_id,source_type,received_at,created_by,notes)
    VALUES(NEW.product_id,
      CASE WHEN NEW.movement_type='RETURN' OR NEW.trip_id IS NOT NULL THEN 'RETURN' ELSE 'OTHER' END,
      NEW.created_at,NEW.created_by,
      COALESCE(NEW.notes,'حركة استلام دون مصدر تشغيلة مباشر'))
    RETURNING lot_id INTO v_lot_id;
  END IF;

  INSERT INTO public.stock_lot_balances(lot_id,location_id,quantity)
  VALUES(v_lot_id,NEW.location_id,NEW.quantity_change)
  ON CONFLICT(lot_id,location_id)
  DO UPDATE SET quantity=public.stock_lot_balances.quantity+EXCLUDED.quantity,updated_at=now();

  INSERT INTO public.stock_movement_lot_allocations(movement_id,lot_id,allocation_direction,quantity)
  VALUES(NEW.movement_id,v_lot_id,'IN',NEW.quantity_change);

  RETURN NEW;
END;
$function$
;
