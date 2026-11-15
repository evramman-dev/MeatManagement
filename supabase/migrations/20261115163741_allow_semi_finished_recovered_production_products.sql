-- Allow semi-finished products to be returned to stock as recovered production output.
-- They can then be selected as ingredients in a later production recipe.
DO $migration$
DECLARE
  v_signature regprocedure := 'public.execute_production_order_v6(bigint,numeric,jsonb,jsonb,jsonb,jsonb,date)'::regprocedure;
  v_definition text;
  v_updated_definition text;
  v_old text := 'p.product_type IN (''RAW'',''FINISHED'')';
  v_new text := 'p.product_type IN (''RAW'',''SEMI_FINISHED'',''FINISHED'')';
BEGIN
  v_definition := pg_get_functiondef(v_signature);
  IF position(v_old in v_definition) = 0 THEN
    RAISE EXCEPTION 'Expected recovered-product type validation was not found; migration stopped';
  END IF;
  v_updated_definition := replace(v_definition, v_old, v_new);
  IF v_updated_definition = v_definition THEN
    RAISE EXCEPTION 'Production function definition was not changed';
  END IF;
  EXECUTE v_updated_definition;
END
$migration$;
