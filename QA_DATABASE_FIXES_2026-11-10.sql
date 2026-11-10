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


-- Applied 2026-11-10: correct vehicle stock reconciliation during trip settlement.
-- Customer returns count as vehicle stock only when their return location is the vehicle.
-- Surplus already received by the trip source warehouse is deducted to prevent a second return.
CREATE OR REPLACE FUNCTION public.settle_trip(p_trip_id bigint, p_target_location_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
    v_trip public.trips%ROWTYPE;
    v_stock record;
    v_vehicle_balance numeric;
    v_vehicle_after numeric;
    v_target_balance numeric;
    v_vehicle_unit_cost numeric;
    v_transfer_cost numeric;
    v_cash_collections numeric := 0;
    v_trip_expenses numeric := 0;
    v_cash_back numeric := 0;
    v_cash_due numeric := 0;
    v_sub_balance numeric;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
    END IF;

    IF NOT (public.has_permission('TRIPS_SETTLE') OR public.has_permission('TRIPS_MANAGE')) THEN
        RAISE EXCEPTION 'ليس لديك صلاحية تسوية الجولات';
    END IF;

    PERFORM pg_advisory_xact_lock(947351);
    PERFORM public.assert_accounting_period_open(CURRENT_DATE);

    SELECT * INTO v_trip
    FROM public.trips
    WHERE trip_id = p_trip_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'الجولة غير موجودة';
    END IF;

    IF v_trip.status NOT IN ('DRAFT', 'ACTIVE') THEN
        RAISE EXCEPTION 'لا يمكن تسوية جولة مكتملة أو ملغاة';
    END IF;

    IF v_trip.source_location_id IS NULL
       OR p_target_location_id <> v_trip.source_location_id THEN
        RAISE EXCEPTION 'مخزن الإرجاع يجب أن يطابق مخزن المصدر المسجل في الجولة';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.locations
        WHERE location_id = p_target_location_id
          AND is_active = true
          AND location_type IN ('MAIN_WAREHOUSE', 'FRIDGE')
    ) THEN
        RAISE EXCEPTION 'مخزن الإرجاع غير نشط أو ليس مخزنًا صالحًا';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.trip_loads
        WHERE trip_id = p_trip_id
          AND load_status IN ('REQUESTED', 'APPROVED')
    ) THEN
        RAISE EXCEPTION 'لا يمكن تسوية الجولة قبل إنهاء طلبات التحميل المعلقة';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.sales_invoice_items sii
        JOIN public.sales_invoices si ON si.sales_invoice_id = sii.sales_invoice_id
        WHERE si.trip_id = p_trip_id
          AND si.status NOT IN ('DRAFT', 'CANCELLED')
          AND sii.base_quantity IS NULL
    ) THEN
        RAISE EXCEPTION 'توجد بنود فواتير لهذه الجولة دون كمية أساسية محفوظة بالكيلوجرام. لا يمكن التسوية قبل تصحيحها.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.sales_return_items sri
        JOIN public.sales_returns sr ON sr.sales_return_id = sri.sales_return_id
        WHERE sr.trip_id = p_trip_id
          AND sr.status IN ('POSTED', 'APPROVED')
          AND sri.base_quantity IS NULL
    ) THEN
        RAISE EXCEPTION 'توجد بنود مرتجعات لهذه الجولة دون كمية أساسية محفوظة بالكيلوجرام. لا يمكن التسوية قبل تصحيحها.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.sales_return_exchange_items sei
        JOIN public.sales_returns sr ON sr.sales_return_id = sei.sales_return_id
        WHERE sr.trip_id = p_trip_id
          AND sr.status IN ('POSTED', 'APPROVED')
          AND sei.base_quantity IS NULL
    ) THEN
        RAISE EXCEPTION 'توجد بنود استبدال لهذه الجولة دون كمية أساسية محفوظة بالكيلوجرام. لا يمكن التسوية قبل تصحيحها.';
    END IF;

    PERFORM 1 FROM public.treasuries
    WHERE treasury_id = 5 AND is_active = true
      AND treasury_type = 'CASH' AND account_id = 3
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'الخزنة الرئيسية رقم 5 غير موجودة أو غير صالحة';
    END IF;

    PERFORM 1 FROM public.treasuries
    WHERE treasury_id = 8 AND is_active = true
      AND treasury_type = 'CASH' AND account_id = 3
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'خزنة المناديب رقم 8 غير موجودة أو غير صالحة';
    END IF;

    SELECT COALESCE(SUM(amount), 0)
    INTO v_cash_collections
    FROM public.customer_collections
    WHERE trip_id = p_trip_id
      AND status = 'POSTED'
      AND payment_method = 'CASH'
      AND treasury_id = 8;

    SELECT COALESCE(SUM(amount), 0)
    INTO v_trip_expenses
    FROM public.expenses
    WHERE trip_id = p_trip_id
      AND treasury_id = 8;

    SELECT COALESCE(SUM(-price_difference), 0)
    INTO v_cash_back
    FROM public.sales_returns
    WHERE trip_id = p_trip_id
      AND status IN ('POSTED', 'APPROVED')
      AND cash_action = 'CASH_BACK'
      AND treasury_id = 8;

    v_cash_due := COALESCE(v_trip.initial_cash, 0)
                  + v_cash_collections
                  - v_trip_expenses
                  - v_cash_back;

    IF v_cash_due < 0 THEN
        RAISE EXCEPTION 'حساب الجولة يظهر عجزًا نقديًا قدره % ولا يمكن إتمام التسوية', ABS(v_cash_due);
    END IF;

    SELECT current_balance INTO v_sub_balance
    FROM public.treasuries
    WHERE treasury_id = 8;

    IF v_sub_balance < v_cash_due THEN
        RAISE EXCEPTION 'رصيد خزنة المناديب لا يكفي لتسوية هذه الجولة. رصيد الخزنة: %، مستحق الجولة: %',
            v_sub_balance, v_cash_due;
    END IF;

    FOR v_stock IN
        WITH product_ids AS (
            SELECT product_id
            FROM public.trip_loads
            WHERE trip_id = p_trip_id
              AND load_status = 'LOADED'
            UNION
            SELECT sii.product_id
            FROM public.sales_invoice_items sii
            JOIN public.sales_invoices si ON si.sales_invoice_id = sii.sales_invoice_id
            WHERE si.trip_id = p_trip_id
              AND si.status NOT IN ('DRAFT', 'CANCELLED')
            UNION
            SELECT sri.product_id
            FROM public.sales_return_items sri
            JOIN public.sales_returns sr ON sr.sales_return_id = sri.sales_return_id
            WHERE sr.trip_id = p_trip_id
              AND sr.status IN ('POSTED', 'APPROVED')
            UNION
            SELECT sei.product_id
            FROM public.sales_return_exchange_items sei
            JOIN public.sales_returns sr ON sr.sales_return_id = sei.sales_return_id
            WHERE sr.trip_id = p_trip_id
              AND sr.status IN ('POSTED', 'APPROVED')
        ),
        loaded AS (
            SELECT product_id, SUM(quantity_loaded) AS qty
            FROM public.trip_loads
            WHERE trip_id = p_trip_id
              AND load_status = 'LOADED'
            GROUP BY product_id
        ),
        sold AS (
            SELECT sii.product_id, SUM(sii.base_quantity) AS qty
            FROM public.sales_invoice_items sii
            JOIN public.sales_invoices si ON si.sales_invoice_id = sii.sales_invoice_id
            WHERE si.trip_id = p_trip_id
              AND si.status NOT IN ('DRAFT', 'CANCELLED')
            GROUP BY sii.product_id
        ),
        returned AS (
            SELECT sri.product_id, SUM(sri.base_quantity) AS qty
            FROM public.sales_return_items sri
            JOIN public.sales_returns sr ON sr.sales_return_id = sri.sales_return_id
            WHERE sr.trip_id = p_trip_id
              AND sr.status IN ('POSTED', 'APPROVED')
              AND sri.location_id = v_trip.vehicle_location_id
            GROUP BY sri.product_id
        ),
        exchanged AS (
            SELECT sei.product_id, SUM(sei.base_quantity) AS qty
            FROM public.sales_return_exchange_items sei
            JOIN public.sales_returns sr ON sr.sales_return_id = sei.sales_return_id
            WHERE sr.trip_id = p_trip_id
              AND sr.status IN ('POSTED', 'APPROVED')
            GROUP BY sei.product_id
        )
        SELECT
            ids.product_id,
            COALESCE(l.qty, 0)
              - COALESCE(s.qty, 0)
              + COALESCE(r.qty, 0)
              - COALESCE(e.qty, 0)
              - COALESCE((
                  SELECT SUM(sm.quantity_change)
                  FROM public.stock_movements sm
                  WHERE sm.trip_id = p_trip_id
                    AND sm.product_id = ids.product_id
                    AND sm.location_id = p_target_location_id
                    AND sm.movement_type = 'RECEIVE'
                    AND sm.notes LIKE 'استلام فائض جولة %'
                ), 0) AS remaining_quantity
        FROM product_ids ids
        LEFT JOIN loaded l ON l.product_id = ids.product_id
        LEFT JOIN sold s ON s.product_id = ids.product_id
        LEFT JOIN returned r ON r.product_id = ids.product_id
        LEFT JOIN exchanged e ON e.product_id = ids.product_id
        ORDER BY ids.product_id
    LOOP
        IF v_stock.remaining_quantity < -0.000001 THEN
            RAISE EXCEPTION 'كميات الجولة للصنف رقم % غير متوازنة. الرصيد المحسوب بالسالب: % كجم',
                v_stock.product_id, v_stock.remaining_quantity;
        END IF;

        IF v_stock.remaining_quantity > 0.000001 THEN
            SELECT quantity,COALESCE(average_unit_cost,0)
              INTO v_vehicle_balance,v_vehicle_unit_cost
            FROM public.stock_balances
            WHERE location_id = v_trip.vehicle_location_id
              AND product_id = v_stock.product_id
            FOR UPDATE;

            IF NOT FOUND OR v_vehicle_balance < v_stock.remaining_quantity THEN
                RAISE EXCEPTION 'رصيد السيارة للصنف رقم % أقل من الكمية المتبقية المحسوبة للجولة. المتبقي: % كجم، رصيد السيارة: %',
                    v_stock.product_id, v_stock.remaining_quantity, COALESCE(v_vehicle_balance, 0);
            END IF;
            IF v_vehicle_unit_cost<0 THEN
                RAISE EXCEPTION 'تكلفة مخزون السيارة للصنف رقم % غير صحيحة',v_stock.product_id;
            END IF;
            v_transfer_cost:=ROUND(v_stock.remaining_quantity*v_vehicle_unit_cost,4);

            v_vehicle_after := v_vehicle_balance - v_stock.remaining_quantity;

            UPDATE public.stock_balances
            SET quantity = v_vehicle_after, updated_at = now()
            WHERE location_id = v_trip.vehicle_location_id
              AND product_id = v_stock.product_id;

            SELECT quantity INTO v_target_balance
            FROM public.stock_balances
            WHERE location_id = p_target_location_id
              AND product_id = v_stock.product_id
            FOR UPDATE;

            IF NOT FOUND THEN
                v_target_balance := 0;
                INSERT INTO public.stock_balances (
                    location_id, product_id, quantity, updated_at
                )
                VALUES (
                    p_target_location_id, v_stock.product_id,
                    v_stock.remaining_quantity, now()
                );
            ELSE
                UPDATE public.stock_balances
                SET quantity = quantity + v_stock.remaining_quantity,
                    updated_at = now()
                WHERE location_id = p_target_location_id
                  AND product_id = v_stock.product_id;
            END IF;

            INSERT INTO public.stock_movements (
                location_id, product_id, movement_type,
                quantity_change, quantity_after, notes, created_by, trip_id, unit_cost, total_cost
            )
            VALUES (
                v_trip.vehicle_location_id, v_stock.product_id, 'ISSUE',
                -v_stock.remaining_quantity, v_vehicle_after,
                'إرجاع فائض جولة ' || v_trip.trip_number, auth.uid(), p_trip_id,
                v_vehicle_unit_cost, v_transfer_cost
            );

            INSERT INTO public.stock_movements (
                location_id, product_id, movement_type,
                quantity_change, quantity_after, notes, created_by, trip_id, unit_cost, total_cost
            )
            VALUES (
                p_target_location_id, v_stock.product_id, 'RECEIVE',
                v_stock.remaining_quantity,
                v_target_balance + v_stock.remaining_quantity,
                'استلام فائض جولة ' || v_trip.trip_number, auth.uid(), p_trip_id,
                v_vehicle_unit_cost, v_transfer_cost
            );
        END IF;
    END LOOP;

    IF v_cash_due > 0 THEN
        UPDATE public.treasuries
        SET current_balance = current_balance - v_cash_due
        WHERE treasury_id = 8;

        UPDATE public.treasuries
        SET current_balance = current_balance + v_cash_due
        WHERE treasury_id = 5;

        INSERT INTO public.treasury_transactions (
            treasury_id, transaction_type, amount, reference_type,
            reference_id, notes, transaction_date, created_by
        )
        VALUES
        (8, 'WITHDRAW', v_cash_due, 'TRIP_SETTLEMENT', p_trip_id,
         'تسوية نقدية للجولة ' || v_trip.trip_number, CURRENT_DATE, auth.uid()),
        (5, 'DEPOSIT', v_cash_due, 'TRIP_SETTLEMENT', p_trip_id,
         'استلام تسوية الجولة ' || v_trip.trip_number, CURRENT_DATE, auth.uid());
    END IF;

    UPDATE public.trips
    SET status = 'COMPLETED',
        end_date = CURRENT_DATE,
        updated_at = now()
    WHERE trip_id = p_trip_id;
END;
$function$



-- Applied 2026-11-10: cover all nine foreign keys reported by the database performance advisor.
CREATE INDEX IF NOT EXISTS idx_expense_types_account_id
  ON public.expense_types (account_id);
CREATE INDEX IF NOT EXISTS idx_fixed_assets_account_id
  ON public.fixed_assets (account_id);
CREATE INDEX IF NOT EXISTS idx_fixed_assets_cancelled_by
  ON public.fixed_assets (cancelled_by);
CREATE INDEX IF NOT EXISTS idx_fixed_assets_created_by
  ON public.fixed_assets (created_by);
CREATE INDEX IF NOT EXISTS idx_fixed_assets_treasury_id
  ON public.fixed_assets (treasury_id);
CREATE INDEX IF NOT EXISTS idx_purchase_landed_costs_cancelled_by
  ON public.purchase_landed_costs (cancelled_by);
CREATE INDEX IF NOT EXISTS idx_purchase_landed_costs_created_by
  ON public.purchase_landed_costs (created_by);
CREATE INDEX IF NOT EXISTS idx_purchase_landed_costs_expense_id
  ON public.purchase_landed_costs (expense_id);
CREATE INDEX IF NOT EXISTS idx_purchase_landed_costs_treasury_id
  ON public.purchase_landed_costs (treasury_id);

-- Applied 2026-11-10: block direct purchase invoices into vehicle locations.
-- Vehicle inventory must enter through the approved trip-load workflow.
CREATE OR REPLACE FUNCTION public.prevent_vehicle_purchase_invoice()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_location_type text;
BEGIN
  SELECT location_type
  INTO v_location_type
  FROM public.locations
  WHERE location_id = NEW.location_id
    AND is_active = true;

  IF v_location_type = 'VEHICLE' THEN
    RAISE EXCEPTION 'لا يمكن تسجيل فاتورة مشتريات مباشرة على موقع سيارة. استخدم مسار تحميل السيارة المعتمد.';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_block_vehicle_purchase_invoice
ON public.purchase_invoices;

CREATE TRIGGER trg_block_vehicle_purchase_invoice
BEFORE INSERT OR UPDATE OF location_id
ON public.purchase_invoices
FOR EACH ROW
EXECUTE FUNCTION public.prevent_vehicle_purchase_invoice();


-- Applied 2026-11-10: prevent untracked stock movements on vehicle locations.
-- Vehicle stock may only move through a trip-linked workflow.
CREATE OR REPLACE FUNCTION public.prevent_untracked_vehicle_stock_movement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_location_type text;
  v_vehicle_location_id bigint;
BEGIN
  SELECT l.location_type
  INTO v_location_type
  FROM public.locations l
  WHERE l.location_id = NEW.location_id;

  IF v_location_type = 'VEHICLE' THEN
    IF NEW.trip_id IS NULL THEN
      RAISE EXCEPTION 'لا يمكن تسجيل حركة مخزون مباشرة على موقع سيارة بدون ربطها بجولة.';
    END IF;

    SELECT t.vehicle_location_id
    INTO v_vehicle_location_id
    FROM public.trips t
    WHERE t.trip_id = NEW.trip_id;

    IF v_vehicle_location_id IS NULL THEN
      RAISE EXCEPTION 'الجولة المرتبطة بحركة مخزون السيارة غير موجودة أو لا تحتوي على موقع سيارة.';
    END IF;

    IF v_vehicle_location_id IS DISTINCT FROM NEW.location_id THEN
      RAISE EXCEPTION 'موقع السيارة في حركة المخزون لا يطابق موقع السيارة المسجل في الجولة.';
    END IF;

    IF NEW.movement_type NOT IN ('ISSUE','TRANSFER_IN','RETURN') THEN
      RAISE EXCEPTION 'نوع حركة المخزون غير مسموح به على موقع سيارة.';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_block_untracked_vehicle_stock_movements
ON public.stock_movements;

CREATE TRIGGER trg_block_untracked_vehicle_stock_movements
BEFORE INSERT OR UPDATE OF location_id, movement_type, trip_id
ON public.stock_movements
FOR EACH ROW
EXECUTE FUNCTION public.prevent_untracked_vehicle_stock_movement();


-- Applied 2026-11-10: reconcile the derived sold/returned quantities for completed QA trip 16.
-- The completed trip had one posted invoice line (1 kg) but its trip_loads summary
-- still showed quantity_sold=0. Re-running the idempotent sync function corrected it to 1 kg.
-- This does not create stock movements, treasury transactions, or journal entries.
SELECT public.sync_trip_load_actual_quantities(16);


-- Applied 2026-11-10: keep trip_loads sold/returned summaries synchronized
-- when a load row is first inserted or its trip/product/package key changes.
-- This covers a load row created after an invoice already exists.
CREATE OR REPLACE FUNCTION public.trg_sync_trip_load_after_load_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP <> 'INSERT' AND OLD.trip_id IS DISTINCT FROM NEW.trip_id THEN
    PERFORM public.sync_trip_load_actual_quantities(OLD.trip_id);
  END IF;

  PERFORM public.sync_trip_load_actual_quantities(NEW.trip_id);
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_trip_load_after_load_change
ON public.trip_loads;

CREATE TRIGGER trg_sync_trip_load_after_load_change
AFTER INSERT OR UPDATE OF trip_id, product_id, package_option_id
ON public.trip_loads
FOR EACH ROW
EXECUTE FUNCTION public.trg_sync_trip_load_after_load_change();

-- One-time reconciliation of completed QA trip 16, already applied.
-- The function recalculates only derived trip_loads quantities; it creates
-- no stock movement, treasury transaction, or journal entry.
SELECT public.sync_trip_load_actual_quantities(16);


-- Applied 2026-11-10: prevent approval of price lists containing
-- unsellable/inactive products, inactive or incompatible units, or prices
-- outside the combined product and price-list min/max limits.
-- Validation follows the same product/unit/price rules used by invoice creation.
CREATE OR REPLACE FUNCTION public.approve_price_list(p_price_list_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_list public.price_lists%ROWTYPE;
  v_invalid_product_id bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT public.has_permission('PRICES_MANAGE') THEN
    RAISE EXCEPTION 'لا توجد صلاحية لاعتماد قائمة الأسعار.';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('meatmanagement_default_price_list_approval',0));

  SELECT * INTO v_list
  FROM public.price_lists
  WHERE price_list_id=p_price_list_id
    AND approval_status='DRAFT'
    AND is_active=true
    AND (valid_to IS NULL OR valid_to >= CURRENT_DATE)
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'قائمة الأسعار غير موجودة أو ليست مسودة أو انتهت صلاحيتها.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.price_list_items
    WHERE price_list_id=p_price_list_id AND is_active=true
  ) THEN
    RAISE EXCEPTION 'لا يمكن اعتماد قائمة أسعار دون أصناف فعالة.';
  END IF;

  SELECT p.product_id
  INTO v_invalid_product_id
  FROM public.price_list_items pli
  JOIN public.products p ON p.product_id=pli.product_id
  LEFT JOIN public.units u ON u.unit_id=pli.unit_id
  WHERE pli.price_list_id=p_price_list_id
    AND pli.is_active=true
    AND (
      NOT COALESCE(p.is_active,false)
      OR NOT COALESCE(p.can_be_sold,false)
      OR NOT COALESCE(u.is_active,false)
      OR NOT (
        pli.unit_id=p.base_unit_id
        OR pli.unit_id=p.sales_unit_id
        OR EXISTS (
          SELECT 1 FROM public.product_unit_conversions puc
          WHERE puc.product_id=p.product_id
            AND puc.unit_id=pli.unit_id
            AND puc.is_active=true
        )
        OR (COALESCE(u.is_package_unit,false)=true AND COALESCE(p.units_per_carton,0)>0)
      )
      OR GREATEST(COALESCE(pli.minimum_price,0),COALESCE(p.min_selling_price,0))
        > CASE
            WHEN pli.maximum_price IS NOT NULL AND p.max_selling_price IS NOT NULL
              THEN LEAST(pli.maximum_price,p.max_selling_price)
            ELSE COALESCE(pli.maximum_price,p.max_selling_price)
          END
      OR pli.selling_price < GREATEST(COALESCE(pli.minimum_price,0),COALESCE(p.min_selling_price,0))
      OR (
        CASE
          WHEN pli.maximum_price IS NOT NULL AND p.max_selling_price IS NOT NULL
            THEN LEAST(pli.maximum_price,p.max_selling_price)
          ELSE COALESCE(pli.maximum_price,p.max_selling_price)
        END IS NOT NULL
        AND pli.selling_price >
          CASE
            WHEN pli.maximum_price IS NOT NULL AND p.max_selling_price IS NOT NULL
              THEN LEAST(pli.maximum_price,p.max_selling_price)
            ELSE COALESCE(pli.maximum_price,p.max_selling_price)
          END
      )
    )
  ORDER BY p.product_id
  LIMIT 1;

  IF v_invalid_product_id IS NOT NULL THEN
    RAISE EXCEPTION
      'لا يمكن اعتماد القائمة: المنتج رقم % غير قابل للبيع أو وحدته غير صالحة أو سعره خارج الحدود. راجع إعدادات المنتج وسعر القائمة.',
      v_invalid_product_id;
  END IF;

  IF v_list.is_default AND EXISTS (
    SELECT 1
    FROM public.price_lists other_list
    WHERE other_list.price_list_id<>p_price_list_id
      AND other_list.is_default=true
      AND other_list.is_active=true
      AND other_list.approval_status='APPROVED'
      AND other_list.valid_from<=COALESCE(v_list.valid_to,'infinity'::date)
      AND COALESCE(other_list.valid_to,'infinity'::date)>=v_list.valid_from
  ) THEN
    RAISE EXCEPTION 'توجد قائمة افتراضية معتمدة تتداخل صلاحيتها مع هذه القائمة.';
  END IF;

  UPDATE public.price_lists
  SET approval_status='APPROVED',
      approved_by=auth.uid(),
      approved_at=now()
  WHERE price_list_id=p_price_list_id;
END;
$function$;

-- QA finding resolved 2026-11-10: TEST-20261110 is a synthetic test price list.
-- Product 2 (لحمة مفرومة) is intended to be sold at 250 EGP/kg in this fixture.
-- The product was enabled for sale and vehicle loading; the 3% discount floor
-- is 242.50 EGP/kg. Production remains disabled until an active recipe exists.
-- No stock was fabricated; invoice tests must use available inventory or a
-- legitimate purchase/production flow.


-- Applied 2026-11-10: harden sales invoice cancellation.
-- Cancellation now requires the original ISSUE movements to match invoice
-- lines exactly, rejects any later stock movement for the same product/site,
-- blocks invoices linked to completed/cancelled trips, and blocks every
-- non-cancelled return (including drafts). This prevents inventory from being
-- restored into a balance that has already changed after the sale.
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
  v_actual_issue_count integer;
  v_actual_issue_qty numeric(18,6);
  v_last_issue_id bigint;
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
    SELECT product_id,base_quantity
    FROM public.sales_invoice_items
    WHERE sales_invoice_id=p_invoice_id
    ORDER BY product_id
  LOOP
    v_qty:=v_item.base_quantity;

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
      quantity_after,notes,created_by,trip_id
    )
    VALUES(
      v_invoice.location_id,v_item.product_id,'RETURN',
      v_qty,v_new_stock,'إلغاء فاتورة '||v_invoice.invoice_number,
      auth.uid(),v_invoice.trip_id
    );
  END LOOP;

  UPDATE public.sales_invoices
  SET status='CANCELLED',updated_at=now()
  WHERE sales_invoice_id=p_invoice_id;
END;
$function$;


-- Applied 2026-11-10: align the synthetic minced-meat QA product with its
-- approved test price list. Safe to re-run; targets only the exact QA product.
UPDATE public.products
SET can_be_sold = true,
    can_be_loaded = true,
    min_selling_price = 242.50,
    target_selling_price = 250.00,
    max_selling_price = 250.00,
    can_be_produced = CASE
      WHEN EXISTS (
        SELECT 1 FROM public.recipes r
        WHERE r.product_id = public.products.product_id
          AND r.is_active = true
      ) THEN can_be_produced
      ELSE false
    END,
    updated_at = now()
WHERE product_id = 2
  AND product_code = 'Row-002'
  AND product_name = 'لحمة مفرومة'
  AND is_active = true
  AND (
    can_be_sold IS DISTINCT FROM true
    OR can_be_loaded IS DISTINCT FROM true
    OR min_selling_price IS DISTINCT FROM 242.50
    OR target_selling_price IS DISTINCT FROM 250.00
    OR max_selling_price IS DISTINCT FROM 250.00
    OR (
      can_be_produced = true
      AND NOT EXISTS (
        SELECT 1 FROM public.recipes r
        WHERE r.product_id = public.products.product_id
          AND r.is_active = true
      )
    )
  );


-- QA fixture applied 2026-11-10: minced-meat production recipe.
-- This fixture is intentionally explicit: 1.000 kg of product 1 (لحمة كولاطة)
-- yields 1.000 kg of product 2 (لحمة مفرومة), with zero assumed waste.
-- It exists only to exercise production costing and the downstream sales flow.
DO $qa$
DECLARE
  v_recipe_id bigint;
BEGIN
  SELECT recipe_id INTO v_recipe_id
  FROM public.recipes
  WHERE recipe_code='QA-MINCED-1KG-20261110';

  IF v_recipe_id IS NULL THEN
    INSERT INTO public.recipes(
      product_id,recipe_code,recipe_name,version_number,yield_quantity,
      yield_unit_id,preparation_notes,is_active,output_quantity,unit_id,
      notes,created_by
    )
    VALUES(
      2,'QA-MINCED-1KG-20261110','وصفة اختبار اللحمة المفرومة 1 كجم',
      1,1,1,
      'وصفة اختبار QA: 1 كجم خام لحمة كولاطة ينتج 1 كجم لحمة مفرومة، دون افتراض فاقد.',
      true,1,1,'بيانات تجريبية لاختبار دورة الإنتاج',
      '759df318-8315-44b6-832d-c51d3926bdb9'::uuid
    )
    RETURNING recipe_id INTO v_recipe_id;
  END IF;

  IF NOT EXISTS(
    SELECT 1 FROM public.recipe_items
    WHERE recipe_id=v_recipe_id
      AND ingredient_product_id=1
      AND raw_product_id=1
      AND unit_id=1
  ) THEN
    INSERT INTO public.recipe_items(
      recipe_id,ingredient_product_id,raw_product_id,unit_id,
      quantity,waste_percentage,sequence_no,notes
    )
    VALUES(
      v_recipe_id,1,1,1,1,0,1,
      'اختبار تحويل 1 كجم خام إلى 1 كجم منتج مفروم دون فاقد مفترض'
    );
  END IF;

  UPDATE public.products
  SET can_be_produced=true,has_recipe=true,updated_at=now()
  WHERE product_id=2
    AND product_code='Row-002'
    AND product_name='لحمة مفرومة'
    AND is_active=true;
END
$qa$;

-- QA full-cycle records created and verified on 2026-11-10:
-- Production order PRD-20261110-000005: 5 kg minced meat; material cost EGP 242.3077.
-- Sales invoice INV-000021: EGP 250, collected EGP 100 + EGP 150, fully paid.
-- Vehicle trip TRIP-20261110-000019: 2 kg loaded, 1 kg sold, 0.5 kg customer return,
-- and 1.5 kg returned from the vehicle during successful settlement.
-- Sales return QA-TRIP-RETURN-20261110: EGP 125 cash refund from mandoub treasury 8.
-- Purchase invoice PUR-000010: EGP 50 credit purchase of 1 kg raw material.
-- Purchase return: 0.25 kg / EGP 12.50 credited to the supplier.
-- Supplier payment: EGP 20.00 from treasury 5.
-- Expense: EGP 10.00 (مواد النظافة), with exactly one linked journal entry.
-- These records are intentionally retained as QA fixtures; do not delete them during testing.


-- QA fixture applied 2026-11-10: assign the approved test price list to all
-- synthetic customers. Customers 3 (اميجوس) and 4 (الراعي الصالح) previously
-- had no active list, which blocked invoice creation before any stock check.
-- The approved TEST-20261110 list contains three active, validated products.
INSERT INTO public.customer_price_lists(
  price_list_id,customer_id,customer_group_id,priority,
  valid_from,valid_to,is_active,created_by
)
SELECT 3,c.customer_id,NULL,1,CURRENT_DATE,NULL,true,
       '759df318-8315-44b6-832d-c51d3926bdb9'::uuid
FROM public.customers c
WHERE c.customer_id IN (3,4)
  AND c.is_active=true
  AND NOT EXISTS(
    SELECT 1 FROM public.customer_price_lists cpl
    WHERE cpl.customer_id=c.customer_id
      AND cpl.is_active=true
      AND cpl.valid_from<=CURRENT_DATE
      AND (cpl.valid_to IS NULL OR cpl.valid_to>=CURRENT_DATE)
  );

-- QA verification on 2026-11-10: customers 1-4 all resolve to approved
-- TEST-20261110 with three active items each.


-- Additional QA verification on 2026-11-10:
-- Customer 3 (اميجوس): invoice INV-000024, EGP 62.50, fully paid.
-- Customer 4 (الراعي الصالح): invoice INV-000025, EGP 62.50, fully paid.
-- Both invoices resolved to approved TEST-20261110 without bypassing price validation.
-- Role-separation test: WAREHOUSE_KEEPER was rejected by approve_trip_load_v2
-- with the expected permission error, while TRIP_LOAD_DISPATCH remained granted.
-- The negative permission test used a transaction rolled back after verification.
