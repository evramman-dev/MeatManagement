-- A canceled sales return must reverse every unit originally received.
-- Sellable units have no active reservation after inspection, while rework
-- units may have a reservation smaller than the original return after use.
-- Release all holds linked to the item before reducing stock, because the
-- stock-balance guard must not see reservations for a return being canceled.
-- The rework-consumption guard separately requires production reversal first.

DO $migration$
DECLARE
  v_definition text;
  v_old text := 'COALESCE(active_res.quantity,sri.base_quantity) AS quantity';
  v_new text := 'sri.base_quantity AS quantity';
  v_occurrences integer;
BEGIN
  v_definition := pg_get_functiondef(
    'public.cancel_sales_return_internal_return_hold(bigint,text)'::regprocedure
  );

  v_occurrences :=
    (length(v_definition) - length(replace(v_definition, v_old, '')))
    / length(v_old);

  IF v_occurrences <> 1 THEN
    RAISE EXCEPTION
      'Expected exactly one return-quantity expression in cancellation function, found %',
      v_occurrences;
  END IF;

  EXECUTE replace(v_definition, v_old, v_new);
END
$migration$;

DO $migration$
DECLARE
  v_definition text;
  v_old text := '    SELECT quantity INTO v_new_stock' || E'\n' ||
                '    FROM public.stock_balances' || E'\n' ||
                '    WHERE location_id=v_qty.location_id AND product_id=v_qty.product_id' || E'\n' ||
                '    FOR UPDATE;';
  v_new text := '    -- Release this return item''s holds before reducing stock, because' || E'\n' ||
                '    -- stock-balance guards correctly reject quantities below active reservations.' || E'\n' ||
                '    UPDATE public.reservations' || E'\n' ||
                '    SET status=''CANCELLED''' || E'\n' ||
                '    WHERE source_return_item_id=v_qty.return_item_id' || E'\n' ||
                '      AND status=''ACTIVE'';' || E'\n' || E'\n' ||
                '    SELECT quantity INTO v_new_stock' || E'\n' ||
                '    FROM public.stock_balances' || E'\n' ||
                '    WHERE location_id=v_qty.location_id AND product_id=v_qty.product_id' || E'\n' ||
                '    FOR UPDATE;';
  v_occurrences integer;
BEGIN
  v_definition := pg_get_functiondef(
    'public.cancel_sales_return_internal_return_hold(bigint,text)'::regprocedure
  );

  v_occurrences :=
    (length(v_definition) - length(replace(v_definition, v_old, '')))
    / length(v_old);

  IF v_occurrences <> 1 THEN
    RAISE EXCEPTION
      'Expected exactly one stock-lock block in cancellation function, found %',
      v_occurrences;
  END IF;

  EXECUTE replace(v_definition, v_old, v_new);
END
$migration$;

COMMENT ON FUNCTION public.cancel_sales_return_internal_return_hold(bigint,text)
IS 'Cancels a sales return by reversing the full received base quantity per item after scrap restoration, releasing linked reservations before stock reduction; production rework consumption must be fully reversed first.';
