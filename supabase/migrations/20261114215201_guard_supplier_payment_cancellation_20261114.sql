CREATE OR REPLACE FUNCTION public.cancel_supplier_payment(
  p_payment_id bigint,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_supplier_id bigint;
  v_amount numeric(14,2);
  v_payment_date date;
  v_treasury_id bigint;
  v_cancelled boolean;
  v_original_entry_id bigint;
  v_original_entry_count integer;
  v_reversal_count integer;
  v_treasury_txn_count integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;

  IF NOT public.has_permission('PURCHASES_MANAGE') THEN
    RAISE EXCEPTION 'لا تملك صلاحية إلغاء سداد الموردين';
  END IF;

  IF NULLIF(btrim(p_reason), '') IS NULL THEN
    RAISE EXCEPTION 'سبب الإلغاء مطلوب';
  END IF;

  IF char_length(btrim(p_reason)) > 1000 THEN
    RAISE EXCEPTION 'سبب الإلغاء لا يمكن أن يزيد عن 1000 حرف';
  END IF;

  PERFORM pg_advisory_xact_lock(947351);

  SELECT supplier_id, amount, payment_date, treasury_id, is_cancelled
  INTO v_supplier_id, v_amount, v_payment_date, v_treasury_id, v_cancelled
  FROM public.supplier_payments
  WHERE payment_id = p_payment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'سداد المورد غير موجود';
  END IF;

  IF v_cancelled THEN
    RAISE EXCEPTION 'سداد المورد ملغى بالفعل';
  END IF;

  PERFORM public.assert_accounting_period_open(v_payment_date);

  PERFORM 1
  FROM public.suppliers
  WHERE supplier_id = v_supplier_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'المورد المرتبط بالسداد غير موجود';
  END IF;

  PERFORM 1
  FROM public.treasuries
  WHERE treasury_id = v_treasury_id
    AND is_active = true
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الخزنة المرتبطة بالسداد غير موجودة أو غير نشطة';
  END IF;

  SELECT count(*)::integer, min(entry_id)
  INTO v_original_entry_count, v_original_entry_id
  FROM public.journal_entries
  WHERE reference_type = 'SUPPLIER_PAYMENT'
    AND reference_id = p_payment_id
    AND status = 'POSTED'
    AND reversal_of_entry_id IS NULL;

  IF v_original_entry_count <> 1 THEN
    RAISE EXCEPTION 'لا يمكن الإلغاء: لم يتم العثور على قيد سداد أصلي مرحّل واحد';
  END IF;

  SELECT count(*)::integer
  INTO v_reversal_count
  FROM public.journal_entries
  WHERE reversal_of_entry_id = v_original_entry_id;

  IF v_reversal_count <> 0 THEN
    RAISE EXCEPTION 'يوجد قيد عكسي سابق لسداد المورد قبل تسجيل الإلغاء';
  END IF;

  SELECT count(*)::integer
  INTO v_treasury_txn_count
  FROM public.treasury_transactions
  WHERE treasury_id = v_treasury_id
    AND transaction_type = 'WITHDRAW'
    AND amount = v_amount
    AND reference_type = 'SUPPLIER_PAYMENT'
    AND reference_id = p_payment_id;

  IF v_treasury_txn_count <> 1 THEN
    RAISE EXCEPTION 'لا يمكن الإلغاء: لم يتم العثور على حركة صرف خزنة أصلية واحدة مطابقة للسداد';
  END IF;

  UPDATE public.treasuries
  SET current_balance = current_balance + v_amount
  WHERE treasury_id = v_treasury_id;

  INSERT INTO public.treasury_transactions(
    treasury_id, transaction_type, amount, reference_type, reference_id,
    notes, transaction_date, created_by
  )
  VALUES(
    v_treasury_id, 'DEPOSIT', v_amount, 'SUPPLIER_PAYMENT_CANCEL', p_payment_id,
    'إلغاء سداد المورد: ' || btrim(p_reason), CURRENT_DATE, v_user_id
  );

  PERFORM public.reverse_journal_entries(
    'SUPPLIER_PAYMENT',
    p_payment_id,
    'إلغاء سداد المورد: ' || btrim(p_reason)
  );

  SELECT count(*)::integer
  INTO v_reversal_count
  FROM public.journal_entries
  WHERE reversal_of_entry_id = v_original_entry_id
    AND status = 'POSTED';

  IF v_reversal_count <> 1 THEN
    RAISE EXCEPTION 'لم يتم إنشاء القيد المحاسبي العكسي لسداد المورد';
  END IF;

  UPDATE public.supplier_payments
  SET is_cancelled = true,
      cancelled_at = now(),
      cancelled_by = v_user_id,
      notes = coalesce(notes, '') ||
        CASE WHEN coalesce(notes, '') = '' THEN '' ELSE ' | ' END ||
        'إلغاء: ' || btrim(p_reason)
  WHERE payment_id = p_payment_id
    AND is_cancelled = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'تعذر تحديث حالة سداد المورد إلى ملغى';
  END IF;
END;
$function$;