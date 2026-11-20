-- Applied to the MeatManagement Supabase project on 2026-11-11.
-- Reject any stock issue that would make inventory valuation negative.
-- The previous one-cent tolerance silently clamped small deficits to zero.

DO $migration$
DECLARE
  v_definition text;
BEGIN
  SELECT pg_get_functiondef('public.apply_stock_movement_cost()'::regprocedure)
    INTO v_definition;

  IF position('IF v_new_value < -0.01 THEN' IN v_definition) = 0
     OR position('v_new_value:=GREATEST(v_new_value,0);' IN v_definition) = 0 THEN
    RAISE EXCEPTION 'Unexpected apply_stock_movement_cost definition; refusing automatic patch';
  END IF;

  v_definition := replace(
    v_definition,
    'IF v_new_value < -0.01 THEN',
    'IF v_new_value < 0 THEN'
  );
  v_definition := replace(
    v_definition,
    '    v_new_value:=GREATEST(v_new_value,0);',
    '    -- Do not hide even a sub-cent inventory valuation deficit.'
  );

  EXECUTE v_definition;
END
$migration$;
