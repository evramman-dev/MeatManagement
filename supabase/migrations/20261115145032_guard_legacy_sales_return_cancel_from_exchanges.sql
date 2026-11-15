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

  IF v_return.return_type='EXCHANGE' THEN
    RAISE EXCEPTION 'استخدم دالة إلغاء الاستبدال المخصصة.';
  END IF;

  IF v_return.status='CANCELLED' THEN
    RAISE EXCEPTION 'المرتجع ملغى بالفعل.';
  END IF;

  IF v_return.status NOT IN ('POSTED','APPROVED') THEN
    RAISE EXCEPTION 'لا يمكن إلغاء مرتجع غير مرحل أو غير معتمد.';
  END IF;

  IF v_return.trip_id IS NOT NULL
     AND v_return.cash_action='CASH_BACK'
     AND v_return.treasury_id=8
     AND EXISTS (
       SELECT 1 FROM public.trips t
       WHERE t.trip_id=v_return.trip_id
         AND t.status='COMPLETED'
     ) THEN
    RAISE EXCEPTION 'لا يمكن عكس رد نقدية من خزنة المناديب بعد إغلاق الجولة.';
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