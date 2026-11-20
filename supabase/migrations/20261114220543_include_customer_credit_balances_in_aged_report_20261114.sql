DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  v_def := pg_get_functiondef('public.get_aged_receivables_v2()'::regprocedure);

  v_old := $old$AND COALESCE(si.remaining_amount,0)>0$old$;
  v_new := $new$AND COALESCE(si.remaining_amount,0)>0.01$new$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'Expected invoice balance threshold was not found in get_aged_receivables_v2';
  END IF;
  v_def := replace(v_def,v_old,v_new);

  v_old := $old$WHERE (ct.opening_balance+ct.b0_30+ct.b31_60+ct.b61_90+ct.bover90)>0$old$;
  v_new := $new$WHERE ABS(ct.opening_balance+ct.b0_30+ct.b31_60+ct.b61_90+ct.bover90)>0.01$new$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'Expected net receivable filter was not found in get_aged_receivables_v2';
  END IF;
  v_def := replace(v_def,v_old,v_new);

  EXECUTE v_def;
END;
$migration$;