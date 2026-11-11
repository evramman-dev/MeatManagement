-- MeatManagement QA hotfix
-- Applied Supabase migration: preserve_exact_lots_when_reversing_stock_transfers_20261111
-- Date: 2026-11-11
-- Purpose: reverse stock transfers using the exact original lot allocations.
-- This is the exact deployed function definition after the hotfix.

CREATE OR REPLACE FUNCTION public.reverse_stock_transfer(p_original_transfer_id bigint, p_reason text, p_request_id uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_original public.stock_transfers%ROWTYPE;
    v_existing public.stock_transfer_reversals%ROWTYPE;
    v_item record;
    v_out record;
    v_in record;
    v_reversal_id bigint;
    v_reversal_number text;
    v_transfer_timestamp timestamptz := now();
    v_destination_quantity numeric;
    v_destination_value numeric;
    v_source_quantity_after numeric;
    v_destination_quantity_after numeric;
    v_reserved numeric;
    v_out_count integer;
    v_in_count integer;
    v_item_count integer := 0;
    v_reason text := NULLIF(btrim(p_reason), '');
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'يجب تسجيل الدخول';
    END IF;

    IF NOT public.has_permission('INVENTORY_TRANSFER') THEN
        RAISE EXCEPTION 'ليس لديك صلاحية عكس التحويلات المخزنية';
    END IF;

    PERFORM pg_advisory_xact_lock(947351);

    IF p_original_transfer_id IS NULL OR p_original_transfer_id <= 0 THEN
        RAISE EXCEPTION 'رقم التحويل الأصلي غير صحيح';
    END IF;

    IF v_reason IS NULL THEN
        RAISE EXCEPTION 'يجب كتابة سبب عكس التحويل';
    END IF;

    IF p_request_id IS NULL THEN
        RAISE EXCEPTION 'رقم طلب العكس مطلوب لمنع التكرار';
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtextextended('stock-transfer-reversal:' || p_request_id::text, 0)
    );

    SELECT *
      INTO v_existing
      FROM public.stock_transfer_reversals
     WHERE request_id = p_request_id
     FOR UPDATE;

    IF FOUND THEN
        IF v_existing.original_transfer_id IS DISTINCT FROM p_original_transfer_id
           OR v_existing.reason IS DISTINCT FROM v_reason THEN
            RAISE EXCEPTION 'رقم طلب العكس مستخدم من قبل ببيانات مختلفة';
        END IF;
        RETURN v_existing.reversal_transfer_id;
    END IF;

    SELECT *
      INTO v_original
      FROM public.stock_transfers
     WHERE transfer_id = p_original_transfer_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'التحويل الأصلي غير موجود';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM public.stock_transfer_reversals r
         WHERE r.original_transfer_id = p_original_transfer_id
            OR r.reversal_transfer_id = p_original_transfer_id
    ) THEN
        RAISE EXCEPTION 'لا يمكن عكس هذا التحويل لأنه عُكس من قبل أو أنه تحويل عكسي';
    END IF;

    IF v_original.source_location_id IS NULL
       OR v_original.destination_location_id IS NULL
       OR v_original.source_location_id = v_original.destination_location_id THEN
        RAISE EXCEPTION 'بيانات مخازن التحويل الأصلي غير صالحة';
    END IF;

    PERFORM public.assert_accounting_period_open(CURRENT_DATE);

    IF NOT EXISTS (
        SELECT 1
          FROM public.stock_transfer_items i
         WHERE i.transfer_id = p_original_transfer_id
    ) THEN
        RAISE EXCEPTION 'التحويل الأصلي لا يحتوي على أصناف';
    END IF;

    v_reversal_id := nextval('public.stock_transfers_transfer_id_seq');
    v_reversal_number := 'TRF-' || lpad(v_reversal_id::text, 6, '0');

    INSERT INTO public.stock_transfers (
        transfer_id, transfer_number, source_location_id,
        destination_location_id, transfer_date, notes,
        created_by, created_at, request_id
    )
    VALUES (
        v_reversal_id, v_reversal_number,
        v_original.destination_location_id,
        v_original.source_location_id,
        CURRENT_DATE,
        'عكس التحويل ' || v_original.transfer_number || ' - ' || v_reason,
        v_uid, v_transfer_timestamp, p_request_id
    );

    FOR v_item IN
        SELECT i.product_id, i.quantity
          FROM public.stock_transfer_items i
         WHERE i.transfer_id = p_original_transfer_id
         ORDER BY i.product_id
    LOOP
        v_item_count := v_item_count + 1;

        SELECT count(*) INTO v_out_count
          FROM public.stock_movements sm
         WHERE sm.stock_transfer_id = p_original_transfer_id
           AND sm.product_id = v_item.product_id
           AND sm.location_id = v_original.source_location_id
           AND sm.movement_type = 'TRANSFER_OUT';

        SELECT count(*) INTO v_in_count
          FROM public.stock_movements sm
         WHERE sm.stock_transfer_id = p_original_transfer_id
           AND sm.product_id = v_item.product_id
           AND sm.location_id = v_original.destination_location_id
           AND sm.movement_type = 'TRANSFER_IN';

        IF v_out_count <> 1 OR v_in_count <> 1 THEN
            RAISE EXCEPTION 'حركات التحويل الأصلي للصنف رقم % غير مكتملة أو مكررة', v_item.product_id;
        END IF;

        SELECT sm.movement_id, sm.quantity_change, sm.unit_cost, sm.total_cost
          INTO v_out
          FROM public.stock_movements sm
         WHERE sm.stock_transfer_id = p_original_transfer_id
           AND sm.product_id = v_item.product_id
           AND sm.location_id = v_original.source_location_id
           AND sm.movement_type = 'TRANSFER_OUT';

        SELECT sm.movement_id, sm.quantity_change, sm.unit_cost, sm.total_cost
          INTO v_in
          FROM public.stock_movements sm
         WHERE sm.stock_transfer_id = p_original_transfer_id
           AND sm.product_id = v_item.product_id
           AND sm.location_id = v_original.destination_location_id
           AND sm.movement_type = 'TRANSFER_IN';

        IF v_out.quantity_change IS DISTINCT FROM -v_item.quantity
           OR v_in.quantity_change IS DISTINCT FROM v_item.quantity
           OR v_out.unit_cost IS NULL
           OR v_out.total_cost IS NULL
           OR v_out.unit_cost < 0
           OR v_out.total_cost < 0
           OR v_out.unit_cost IS DISTINCT FROM v_in.unit_cost
           OR v_out.total_cost IS DISTINCT FROM v_in.total_cost THEN
            RAISE EXCEPTION 'كمية أو تكلفة حركات التحويل الأصلي للصنف رقم % غير متطابقة', v_item.product_id;
        END IF;

        -- Lock both location balances in a stable order.
        PERFORM sb.balance_id
          FROM public.stock_balances sb
         WHERE sb.product_id = v_item.product_id
           AND sb.location_id IN (
               v_original.source_location_id,
               v_original.destination_location_id
           )
         ORDER BY sb.location_id
         FOR UPDATE;

        SELECT sb.quantity, sb.inventory_value
          INTO v_destination_quantity, v_destination_value
          FROM public.stock_balances sb
         WHERE sb.location_id = v_original.destination_location_id
           AND sb.product_id = v_item.product_id
         FOR UPDATE;

        IF NOT FOUND OR v_destination_quantity < v_item.quantity THEN
            RAISE EXCEPTION 'لا يمكن عكس التحويل للصنف رقم % لأن رصيد مخزن الوجهة غير كافٍ', v_item.product_id;
        END IF;

        SELECT COALESCE(SUM(r.quantity), 0)
          INTO v_reserved
          FROM public.reservations r
         WHERE r.location_id = v_original.destination_location_id
           AND r.product_id = v_item.product_id
           AND r.status = 'ACTIVE'
           AND (r.reserved_until IS NULL OR r.reserved_until >= CURRENT_DATE);

        IF v_destination_quantity - v_item.quantity < v_reserved THEN
            RAISE EXCEPTION 'لا يمكن عكس الصنف رقم % لأن الكمية المطلوبة مرتبطة بحجوزات نشطة', v_item.product_id;
        END IF;

        IF COALESCE(v_destination_value, 0) + 0.01 < v_out.total_cost THEN
            RAISE EXCEPTION 'قيمة المخزون المتاحة في الوجهة لا تكفي لعكس تكلفة الصنف رقم %', v_item.product_id;
        END IF;

        UPDATE public.stock_balances
           SET quantity = quantity - v_item.quantity,
               updated_at = v_transfer_timestamp
         WHERE location_id = v_original.destination_location_id
           AND product_id = v_item.product_id
         RETURNING quantity INTO v_destination_quantity_after;

        INSERT INTO public.stock_balances (
            location_id, product_id, quantity, updated_at
        )
        VALUES (
            v_original.source_location_id, v_item.product_id,
            v_item.quantity, v_transfer_timestamp
        )
        ON CONFLICT (location_id, product_id)
        DO UPDATE SET
            quantity = public.stock_balances.quantity + EXCLUDED.quantity,
            updated_at = EXCLUDED.updated_at
        RETURNING quantity INTO v_source_quantity_after;

        INSERT INTO public.stock_transfer_items (transfer_id, product_id, quantity)
        VALUES (v_reversal_id, v_item.product_id, v_item.quantity);

        INSERT INTO public.stock_movements (
            location_id, product_id, movement_type, quantity_change,
            quantity_after, notes, created_by, created_at,
            unit_cost, total_cost, stock_transfer_id,
            reversal_of_movement_id
        )
        VALUES (
            v_original.destination_location_id, v_item.product_id,
            'TRANSFER_OUT', -v_item.quantity,
            v_destination_quantity_after,
            'عكس تحويل صادر ' || v_reversal_number || ' للأصل ' || v_original.transfer_number,
            v_uid, v_transfer_timestamp,
            v_out.unit_cost, v_out.total_cost, v_reversal_id,
            v_in.movement_id
        );

        INSERT INTO public.stock_movements (
            location_id, product_id, movement_type, quantity_change,
            quantity_after, notes, created_by, created_at,
            unit_cost, total_cost, stock_transfer_id,
            reversal_of_movement_id
        )
        VALUES (
            v_original.source_location_id, v_item.product_id,
            'TRANSFER_IN', v_item.quantity,
            v_source_quantity_after,
            'عكس تحويل وارد ' || v_reversal_number || ' للأصل ' || v_original.transfer_number,
            v_uid, v_transfer_timestamp,
            v_out.unit_cost, v_out.total_cost, v_reversal_id,
            v_out.movement_id
        );
    END LOOP;

    INSERT INTO public.stock_transfer_reversals (
        original_transfer_id, reversal_transfer_id,
        request_id, reason, reversed_by, reversed_at
    )
    VALUES (
        p_original_transfer_id, v_reversal_id,
        p_request_id, v_reason, v_uid, v_transfer_timestamp
    );

    RETURN v_reversal_id;
END;
$function$
;
