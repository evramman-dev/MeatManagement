-- MeatManagement QA database fixes
-- Applied to Supabase project mklbemoisdkoyrwcrmoj on 2026-11-10.
-- Scope: sales return stock/COGS posting, trip load actual quantities, expense journal duplication.
-- This file records the deployed SQL for review and reproducibility.
-- It is not an instruction to re-run the one-time stock-balance repair.

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
      quantity_after,notes,created_by,trip_id
    )
    VALUES(
      x.location_id,x.product_id,'RETURN',x.quantity,v_new_stock,
      'مرتجع عميل '||r.return_number,auth.uid(),r.trip_id
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
$function$;

CREATE OR REPLACE FUNCTION public.sync_trip_load_actual_quantities(p_trip_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
BEGIN
  IF p_trip_id IS NULL THEN RETURN; END IF;
  UPDATE public.trip_loads tl
  SET quantity_sold = COALESCE((
        SELECT SUM(sii.base_quantity)
        FROM public.sales_invoice_items sii
        JOIN public.sales_invoices si ON si.sales_invoice_id=sii.sales_invoice_id
        WHERE si.trip_id=p_trip_id
          AND si.status NOT IN ('DRAFT','CANCELLED')
          AND sii.product_id=tl.product_id
          AND sii.package_option_id IS NOT DISTINCT FROM tl.package_option_id
      ),0),
      quantity_returned = COALESCE((
        SELECT SUM(sri.base_quantity)
        FROM public.sales_return_items sri
        JOIN public.sales_returns sr ON sr.sales_return_id=sri.sales_return_id
        WHERE sr.trip_id=p_trip_id
          AND sr.status IN ('POSTED','APPROVED')
          AND sri.product_id=tl.product_id
          AND sri.package_option_id IS NOT DISTINCT FROM tl.package_option_id
      ),0)
  WHERE tl.trip_id=p_trip_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_sync_trip_load_actual_quantities()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_trip_id bigint;
BEGIN
  IF TG_TABLE_NAME='sales_invoice_items' THEN
    IF TG_OP<>'INSERT' THEN
      SELECT trip_id INTO v_trip_id FROM public.sales_invoices WHERE sales_invoice_id=OLD.sales_invoice_id;
      PERFORM public.sync_trip_load_actual_quantities(v_trip_id);
    END IF;
    IF TG_OP<>'DELETE' THEN
      SELECT trip_id INTO v_trip_id FROM public.sales_invoices WHERE sales_invoice_id=NEW.sales_invoice_id;
      PERFORM public.sync_trip_load_actual_quantities(v_trip_id);
    END IF;
  ELSIF TG_TABLE_NAME='sales_return_items' THEN
    IF TG_OP<>'INSERT' THEN
      SELECT trip_id INTO v_trip_id FROM public.sales_returns WHERE sales_return_id=OLD.sales_return_id;
      PERFORM public.sync_trip_load_actual_quantities(v_trip_id);
    END IF;
    IF TG_OP<>'DELETE' THEN
      SELECT trip_id INTO v_trip_id FROM public.sales_returns WHERE sales_return_id=NEW.sales_return_id;
      PERFORM public.sync_trip_load_actual_quantities(v_trip_id);
    END IF;
  ELSIF TG_TABLE_NAME IN ('sales_invoices','sales_returns') THEN
    IF TG_OP<>'INSERT' THEN PERFORM public.sync_trip_load_actual_quantities(OLD.trip_id); END IF;
    IF TG_OP<>'DELETE' THEN PERFORM public.sync_trip_load_actual_quantities(NEW.trip_id); END IF;
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_trip_load_from_invoice_items ON public.sales_invoice_items;
CREATE TRIGGER trg_sync_trip_load_from_invoice_items
AFTER INSERT OR UPDATE OR DELETE ON public.sales_invoice_items
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_trip_load_actual_quantities();

DROP TRIGGER IF EXISTS trg_sync_trip_load_from_return_items ON public.sales_return_items;
CREATE TRIGGER trg_sync_trip_load_from_return_items
AFTER INSERT OR UPDATE OR DELETE ON public.sales_return_items
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_trip_load_actual_quantities();

DROP TRIGGER IF EXISTS trg_sync_trip_load_from_invoices ON public.sales_invoices;
CREATE TRIGGER trg_sync_trip_load_from_invoices
AFTER INSERT OR DELETE OR UPDATE OF status,trip_id ON public.sales_invoices
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_trip_load_actual_quantities();

DROP TRIGGER IF EXISTS trg_sync_trip_load_from_returns ON public.sales_returns;
CREATE TRIGGER trg_sync_trip_load_from_returns
AFTER INSERT OR DELETE OR UPDATE OF status,trip_id ON public.sales_returns
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_trip_load_actual_quantities();

CREATE OR REPLACE FUNCTION public.create_expense_v2(
  p_expense_type text,
  p_expense_date date,
  p_treasury_id bigint,
  p_amount numeric,
  p_notes text,
  p_trip_id bigint,
  p_request_id uuid
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_expense_id bigint;
  v_existing public.expenses%ROWTYPE;
  v_effective_treasury_id bigint;
  v_amount numeric(14,2);
  v_date date;
BEGIN
  IF auth.uid() IS NULL OR NOT public.has_permission('EXPENSES_MANAGE') THEN
    RAISE EXCEPTION 'ليس لديك صلاحية تسجيل المصروفات';
  END IF;

  PERFORM pg_advisory_xact_lock(947351);

  IF p_request_id IS NULL THEN
    RAISE EXCEPTION 'رقم طلب المصروف مطلوب لمنع التكرار';
  END IF;

  v_date:=COALESCE(p_expense_date,CURRENT_DATE);
  v_amount:=ROUND(COALESCE(p_amount,0),2);
  v_effective_treasury_id:=CASE WHEN p_trip_id IS NOT NULL THEN 8 ELSE p_treasury_id END;

  IF NULLIF(BTRIM(COALESCE(p_expense_type,'')),'') IS NULL
     OR v_amount<=0 OR v_effective_treasury_id IS NULL THEN
    RAISE EXCEPTION 'نوع المصروف وقيمته والخزنة المطلوبة بيانات إلزامية';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));

  SELECT * INTO v_existing
  FROM public.expenses
  WHERE request_id=p_request_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.created_by IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'رقم الطلب مرتبط بمستخدم آخر';
    END IF;
    IF v_existing.expense_type IS DISTINCT FROM BTRIM(p_expense_type)
       OR v_existing.expense_date IS DISTINCT FROM v_date
       OR v_existing.treasury_id IS DISTINCT FROM v_effective_treasury_id
       OR v_existing.amount IS DISTINCT FROM v_amount
       OR v_existing.notes IS DISTINCT FROM p_notes
       OR v_existing.trip_id IS DISTINCT FROM p_trip_id THEN
      RAISE EXCEPTION 'رقم طلب المصروف مستخدم من قبل مع بيانات مختلفة';
    END IF;

    PERFORM 1 FROM public.journal_entries
    WHERE reference_type='EXPENSE'
      AND reference_id=v_existing.expense_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'يوجد مصروف سابق دون قيد محاسبي مرتبط؛ يلزم فحصه';
    END IF;

    RETURN v_existing.expense_id;
  END IF;

  PERFORM public.assert_accounting_period_open(v_date);

  -- The base function inserts the expense and updates treasury.
  -- The AFTER INSERT trigger creates the single journal entry.
  -- Do not insert a second journal entry here.
  v_expense_id:=public.create_expense(
    BTRIM(p_expense_type),
    v_date,
    p_treasury_id,
    v_amount,
    p_notes,
    p_trip_id
  );

  UPDATE public.expenses
  SET request_id=p_request_id
  WHERE expense_id=v_expense_id;

  RETURN v_expense_id;
END;
$function$;

-- One-time correction for the verified QA return movement 96 only.
-- Re-run is guarded: it updates only the exact expected old quantity and only
-- when no later movement exists for the same product/location balance.
UPDATE public.stock_balances sb
SET quantity=sm.quantity_after,
    average_unit_cost=CASE WHEN sm.quantity_after>0
      THEN ROUND(sb.inventory_value/sm.quantity_after,6) ELSE 0 END,
    updated_at=now()
FROM public.stock_movements sm
WHERE sm.movement_id=96
  AND sm.movement_type='RETURN'
  AND sm.notes='مرتجع عميل QA-SR-20261110-0001'
  AND sm.location_id=sb.location_id
  AND sm.product_id=sb.product_id
  AND sb.quantity=13.5
  AND sm.quantity_after=13.75
  AND NOT EXISTS (
    SELECT 1 FROM public.stock_movements later
    WHERE later.location_id=sm.location_id
      AND later.product_id=sm.product_id
      AND later.movement_id>sm.movement_id
  );

-- Keep helper functions SECURITY INVOKER. Trigger execution is performed in
-- the caller's transaction context and must not add SECURITY DEFINER access.
