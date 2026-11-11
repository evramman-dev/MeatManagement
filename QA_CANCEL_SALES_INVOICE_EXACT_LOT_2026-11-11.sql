-- MeatManagement QA hotfix
-- Applied Supabase migration: restore_exact_sales_invoice_lots_and_cost_on_cancel_20261111
-- Date: 2026-11-11
-- Purpose: link each sales invoice cancellation to its exact original issue movement and cost.
-- This is the exact deployed function definition after the hotfix.

CREATE OR REPLACE FUNCTION public.cancel_sales_invoice(p_invoice_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_invoice record;
  v_item record;
  v_current_stock numeric;
  v_new_stock numeric;
  v_qty numeric;
  v_invoice_date date;
  v_expected_issue_count integer;
  v_actual_issue_count integer;
  v_expected_issue_qty numeric(18,6);
  v_actual_issue_qty numeric(18,6);
  v_last_issue_id bigint;
  v_original_issue_movement_id bigint;
  v_original_issue_unit_cost numeric(18,6);
  v_original_issue_total_cost numeric(18,4);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;

  IF NOT public.has_permission('SALES_MANAGE') THEN
    RAISE EXCEPTION 'صلاحية غير كافية لإلغاء الفاتورة';
  END IF;

  PERFORM pg_advisory_xact_lock(947351);

  SELECT (si.invoice_date AT TIME ZONE 'Africa/Cairo')::date
  INTO v_invoice_date
  FROM public.sales_invoices si
  WHERE si.sales_invoice_id = p_invoice_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الفاتورة غير موجودة';
  END IF;

  PERFORM public.assert_accounting_period_open(COALESCE(v_invoice_date, CURRENT_DATE));
  PERFORM public.assert_accounting_period_open(CURRENT_DATE);

  SELECT * INTO v_invoice
  FROM public.sales_invoices
  WHERE sales_invoice_id=p_invoice_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'الفاتورة غير موجودة'; END IF;
  IF v_invoice.status='CANCELLED' THEN RAISE EXCEPTION 'الفاتورة ملغاة بالفعل'; END IF;
  IF v_invoice.status='DRAFT' THEN
    RAISE EXCEPTION 'لا يمكن إلغاء فاتورة مسودة من مسار الإلغاء. احذف المسودة أو اتركها دون ترحيل';
  END IF;

  IF COALESCE(v_invoice.paid_amount,0)>0
     OR EXISTS (
       SELECT 1 FROM public.customer_collections
       WHERE sales_invoice_id=p_invoice_id
         AND status IS DISTINCT FROM 'CANCELLED'
     ) THEN
    RAISE EXCEPTION 'لا يمكن إلغاء فاتورة عليها تحصيلات. ألغِ التحصيلات أولاً.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.sales_returns
    WHERE sales_invoice_id=p_invoice_id
      AND status IS DISTINCT FROM 'CANCELLED'
  ) THEN
    RAISE EXCEPTION 'لا يمكن إلغاء فاتورة مرتبطة بمرتجع نشط. عالج أو ألغِ المرتجع أولاً.';
  END IF;

  IF v_invoice.trip_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.trips
       WHERE trip_id=v_invoice.trip_id
         AND status IN ('DRAFT','ACTIVE')
     ) THEN
    RAISE EXCEPTION 'لا يمكن إلغاء فاتورة مرتبطة بجولة منتهية أو ملغاة. عالج تسوية الجولة أولاً.';
  END IF;

  IF v_invoice.location_id IS NULL THEN
    RAISE EXCEPTION 'الفاتورة بدون موقع، لا يمكن إرجاع الرصيد';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.sales_invoice_items
    WHERE sales_invoice_id=p_invoice_id
  ) THEN
    RAISE EXCEPTION 'لا يمكن إلغاء فاتورة بدون بنود.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.sales_invoice_items
    WHERE sales_invoice_id=p_invoice_id
      AND (base_quantity IS NULL OR base_quantity<=0)
  ) THEN
    RAISE EXCEPTION 'يوجد بند في الفاتورة دون كمية أساسية صحيحة. لا يمكن إرجاع المخزون بأمان.';
  END IF;

  -- Preflight every product in a stable order. The original ISSUE rows must
  -- match the invoice lines exactly, and no later stock movement may exist.
  FOR v_item IN
    SELECT product_id,
           count(*)::integer AS expected_count,
           sum(base_quantity)::numeric(18,6) AS expected_qty
    FROM public.sales_invoice_items
    WHERE sales_invoice_id=p_invoice_id
    GROUP BY product_id
    ORDER BY product_id
  LOOP
    INSERT INTO public.stock_balances(location_id,product_id,quantity,updated_at)
    VALUES(v_invoice.location_id,v_item.product_id,0,now())
    ON CONFLICT(location_id,product_id) DO NOTHING;

    SELECT quantity INTO v_current_stock
    FROM public.stock_balances
    WHERE location_id=v_invoice.location_id
      AND product_id=v_item.product_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'تعذر قفل رصيد المخزون للمنتج %.',v_item.product_id;
    END IF;

    SELECT count(*)::integer,
           COALESCE(sum(-sm.quantity_change),0)::numeric(18,6),
           max(sm.movement_id)
    INTO v_actual_issue_count,v_actual_issue_qty,v_last_issue_id
    FROM public.stock_movements sm
    WHERE sm.location_id=v_invoice.location_id
      AND sm.product_id=v_item.product_id
      AND sm.movement_type='ISSUE'
      AND sm.quantity_change<0
      AND sm.notes='فاتورة بيع '||v_invoice.invoice_number;

    IF v_actual_issue_count<>v_item.expected_count
       OR v_actual_issue_qty IS DISTINCT FROM v_item.expected_qty
       OR v_last_issue_id IS NULL THEN
      RAISE EXCEPTION
        'حركات صرف الفاتورة لا تطابق بنودها للصنف رقم %. راجع المخزون قبل الإلغاء.',
        v_item.product_id;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.stock_movements later
      WHERE later.location_id=v_invoice.location_id
        AND later.product_id=v_item.product_id
        AND later.movement_id>v_last_issue_id
    ) THEN
      RAISE EXCEPTION
        'لا يمكن إلغاء الفاتورة: توجد حركة مخزون لاحقة للصنف رقم % في نفس الموقع. عالج الحركة اللاحقة أولاً.',
        v_item.product_id;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.stock_movements reversal
      WHERE reversal.location_id=v_invoice.location_id
        AND reversal.product_id=v_item.product_id
        AND reversal.movement_type='RETURN'
        AND reversal.notes='إلغاء فاتورة '||v_invoice.invoice_number
    ) THEN
      RAISE EXCEPTION
        'توجد حركة إرجاع سابقة لهذه الفاتورة للصنف رقم %. راجع السجلات قبل الإلغاء.',
        v_item.product_id;
    END IF;
  END LOOP;

  FOR v_item IN
    SELECT sales_invoice_item_id,product_id,base_quantity
    FROM public.sales_invoice_items
    WHERE sales_invoice_id=p_invoice_id
    ORDER BY product_id,sales_invoice_item_id
  LOOP
    v_qty:=v_item.base_quantity;

    SELECT sm.movement_id,sm.unit_cost,sm.total_cost
    INTO v_original_issue_movement_id,v_original_issue_unit_cost,v_original_issue_total_cost
    FROM public.stock_movements sm
    WHERE sm.sales_invoice_id=p_invoice_id
      AND sm.sales_invoice_item_id=v_item.sales_invoice_item_id
      AND sm.location_id=v_invoice.location_id
      AND sm.product_id=v_item.product_id
      AND sm.movement_type='ISSUE'
      AND sm.quantity_change<0
    ORDER BY sm.movement_id DESC
    LIMIT 1;
    IF v_original_issue_movement_id IS NULL THEN
      RAISE EXCEPTION 'تعذر تحديد حركة الصرف الأصلية لبند الفاتورة %',v_item.sales_invoice_item_id;
    END IF;

    SELECT quantity INTO v_current_stock
    FROM public.stock_balances
    WHERE location_id=v_invoice.location_id
      AND product_id=v_item.product_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'تعذر قفل رصيد المخزون للمنتج %.',v_item.product_id;
    END IF;

    v_new_stock:=v_current_stock+v_qty;

    UPDATE public.stock_balances
    SET quantity=v_new_stock,updated_at=now()
    WHERE location_id=v_invoice.location_id
      AND product_id=v_item.product_id;

    INSERT INTO public.stock_movements(
      location_id,product_id,movement_type,quantity_change,
      quantity_after,notes,created_by,trip_id,
      unit_cost,total_cost,reversal_of_movement_id
    )
    VALUES(
      v_invoice.location_id,v_item.product_id,'RETURN',
      v_qty,v_new_stock,'إلغاء فاتورة '||v_invoice.invoice_number,
      auth.uid(),v_invoice.trip_id,
      v_original_issue_unit_cost,v_original_issue_total_cost,v_original_issue_movement_id
    );
  END LOOP;

  UPDATE public.sales_invoices
  SET status='CANCELLED',updated_at=now()
  WHERE sales_invoice_id=p_invoice_id;
END;
$function$
;
