-- MeatManagement QA hotfix
-- Applied Supabase migration: scope_trip_surplus_lot_restore_to_surplus_receipt
-- Date: 2026-11-11
-- Purpose: isolate completed-trip customer returns from trip-surplus lot restoration.
-- This is the exact deployed function definition after the hotfix.

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
  IF NEW.trip_id IS NOT NULL AND NEW.sales_return_id IS NULL AND NEW.movement_type IN ('RECEIVE','RETURN') AND COALESCE(NEW.notes,'') LIKE 'استلام فائض جولة %' THEN
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
$function$;
