-- Applied Supabase migration: fix_treasury_statement_running_balance_order_20261111
-- Date: 2026-11-11
-- Ensures deterministic row-by-row running balances when multiple treasury movements share a timestamp.

CREATE OR REPLACE FUNCTION public.get_treasury_statement(p_treasury_id bigint)
 RETURNS TABLE(transaction_date timestamp with time zone, description text, deposit numeric, withdraw numeric, running_balance numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_opening_balance numeric;
BEGIN
  IF NOT (
    public.has_permission('TREASURIES_VIEW')
    OR public.has_permission('ACCOUNTING_VIEW')
  ) THEN
    RAISE EXCEPTION 'ليس لديك صلاحية عرض كشف الخزنة';
  END IF;

  SELECT opening_balance
  INTO v_opening_balance
  FROM public.treasuries
  WHERE treasury_id=p_treasury_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الخزنة غير موجودة';
  END IF;

  RETURN QUERY
  WITH tx AS (
    SELECT
      transaction_id,
      created_at,
      notes AS description,
      CASE
        WHEN transaction_type IN ('DEPOSIT','TRANSFER_IN') THEN amount
        ELSE 0
      END AS deposit,
      CASE
        WHEN transaction_type IN ('WITHDRAW','TRANSFER_OUT') THEN amount
        ELSE 0
      END AS withdraw
    FROM public.treasury_transactions
    WHERE treasury_id=p_treasury_id
  )
  SELECT
    tx.created_at,
    tx.description,
    tx.deposit,
    tx.withdraw,
    v_opening_balance
      + SUM(tx.deposit-tx.withdraw) OVER (
          ORDER BY tx.created_at,tx.transaction_id
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_balance
  FROM tx
  ORDER BY tx.created_at,tx.transaction_id;
END;
$function$
;
