-- Align the accounting summary receivables with the customer aging report.
-- Opening-balance collections are deducted once; invoice collections and debt
-- returns are already reflected in sales_invoices.remaining_amount.
DO $migration$
DECLARE
  v_definition text;
  v_old text := $old$
  SELECT COALESCE(sum(remaining_amount),0) INTO v_ar
  FROM public.sales_invoices
  WHERE status IN ('POSTED','PARTIAL') AND remaining_amount>0.01;
$old$;
  v_new text := $new$
  SELECT
    COALESCE((
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
    ),0)
    + COALESCE((
        SELECT SUM(GREATEST(COALESCE(si.remaining_amount,0),0))
        FROM public.sales_invoices si
        JOIN public.customers c
          ON c.customer_id=si.customer_id
         AND c.is_active=true
        WHERE si.status IN ('POSTED','PAID','PARTIAL')
          AND COALESCE(si.remaining_amount,0)>0.01
      ),0)
  INTO v_ar;
$new$;
BEGIN
  v_definition := pg_get_functiondef('public.get_period_summary(date,date)'::regprocedure);

  IF strpos(v_definition,v_old)=0 THEN
    RAISE EXCEPTION 'get_period_summary receivables block did not match expected definition; migration stopped';
  END IF;

  v_definition := replace(v_definition,v_old,v_new);
  EXECUTE v_definition;
END
$migration$;

DO $verify$
DECLARE
  v_definition text;
BEGIN
  v_definition := pg_get_functiondef('public.get_period_summary(date,date)'::regprocedure);
  IF position('allocation_type=''OPENING_BALANCE''' in v_definition)=0
     OR position('si.remaining_amount' in v_definition)=0 THEN
    RAISE EXCEPTION 'get_period_summary receivables update verification failed';
  END IF;
END
$verify$;
