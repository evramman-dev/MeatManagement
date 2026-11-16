-- A canceled sales return must reverse every unit originally received.
-- Sellable units have no active reservation after inspection, while rework
-- units may have a reservation smaller than the original return after use.
-- The cancellation flow restores scrap movements first, then removes the
-- full received base quantity. The rework-consumption guard separately
-- requires production reversal before cancellation.

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

COMMENT ON FUNCTION public.cancel_sales_return_internal_return_hold(bigint,text)
IS 'Cancels a sales return by reversing the full received base quantity per item after scrap restoration; production rework consumption must be fully reversed first.';
