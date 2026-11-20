DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  v_def := pg_get_functiondef('public.get_period_summary(date,date)'::regprocedure);

  v_old := $old$    COALESCE((
      SELECT SUM(GREATEST(
        COALESCE(c.opening_balance,0)
        - COALESCE((
            SELECT SUM(cc.amount)
            FROM public.customer_collections cc
            WHERE cc.customer_id=c.customer_id
              AND cc.sales_invoice_id IS NULL
              AND cc.allocation_type='OPENING_BALANCE'
              AND cc.status='POSTED'
          ),0),
        0
      ))
      FROM public.customers c
      WHERE c.is_active=true
    ),0)$old$;
  v_new := $new$    COALESCE((
      SELECT SUM(
        COALESCE(c.opening_balance,0)
        - COALESCE((
            SELECT SUM(cc.amount)
            FROM public.customer_collections cc
            WHERE cc.customer_id=c.customer_id
              AND cc.sales_invoice_id IS NULL
              AND cc.allocation_type='OPENING_BALANCE'
              AND cc.status='POSTED'
          ),0)
      )
      FROM public.customers c
    ),0)$new$;

  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'Expected customer opening-balance block was not found in get_period_summary';
  END IF;
  v_def := replace(v_def,v_old,v_new);

  v_old := $old$JOIN public.customers c
          ON c.customer_id=si.customer_id
         AND c.is_active=true$old$;
  v_new := $new$JOIN public.customers c
          ON c.customer_id=si.customer_id$new$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'Expected active-customer invoice join was not found in get_period_summary';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.get_aged_receivables()'::regprocedure);
  v_old := $old$where c.is_active=true and (v_role<>'SALES_REP' or ia.customer_id is not null)$old$;
  v_new := $new$where (v_role<>'SALES_REP' or ia.customer_id is not null)$new$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'Expected active-customer filter was not found in get_aged_receivables';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.get_aged_receivables_v2()'::regprocedure);
  v_old := $old$CASE WHEN v_role='SALES_REP' THEN 0
           ELSE GREATEST(
             COALESCE(c.opening_balance,0)
             - COALESCE((
                 SELECT SUM(cc.amount)
                 FROM public.customer_collections cc
                 WHERE cc.customer_id=c.customer_id
                   AND cc.sales_invoice_id IS NULL
                   AND cc.allocation_type='OPENING_BALANCE'
                   AND cc.status='POSTED'
               ),0),
             0
           ) END AS opening_balance,$old$;
  v_new := $new$CASE WHEN v_role='SALES_REP' THEN 0
           ELSE COALESCE(c.opening_balance,0)
             - COALESCE((
                 SELECT SUM(cc.amount)
                 FROM public.customer_collections cc
                 WHERE cc.customer_id=c.customer_id
                   AND cc.sales_invoice_id IS NULL
                   AND cc.allocation_type='OPENING_BALANCE'
                   AND cc.status='POSTED'
               ),0)
           END AS opening_balance,$new$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'Expected opening-balance expression was not found in get_aged_receivables_v2';
  END IF;
  v_def := replace(v_def,v_old,v_new);

  v_old := $old$WHERE c.is_active=true
      AND (v_role<>'SALES_REP' OR ia.customer_id IS NOT NULL)$old$;
  v_new := $new$WHERE (v_role<>'SALES_REP' OR ia.customer_id IS NOT NULL)$new$;
  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'Expected active-customer filter was not found in get_aged_receivables_v2';
  END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END;
$migration$;