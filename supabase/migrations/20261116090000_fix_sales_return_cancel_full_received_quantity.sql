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

  IF v_occurrences = 1 THEN
    EXECUTE replace(v_definition, v_old, v_new);
  ELSIF position(v_new IN v_definition) = 0 THEN
    RAISE EXCEPTION
      'Expected the old or already-fixed return-quantity expression in cancellation function; found % old matches',
      v_occurrences;
  END IF;
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

  IF v_occurrences = 1 THEN
    EXECUTE replace(v_definition, v_old, v_new);
  ELSIF position('UPDATE public.reservations' IN v_definition) = 0 THEN
    RAISE EXCEPTION
      'Expected the old or already-fixed reservation-release block in cancellation function; found % old matches',
      v_occurrences;
  END IF;
END
$migration$;

COMMENT ON FUNCTION public.cancel_sales_return_internal_return_hold(bigint,text)
IS 'Cancels a sales return by reversing the full received base quantity per item after scrap restoration, releasing linked reservations before stock reduction; production rework consumption must be fully reversed first.';

-- Full American journal: every posted voucher line, with voucher totals.
CREATE OR REPLACE FUNCTION public.get_journal_entries_full(p_from date,p_to date)
RETURNS TABLE(
  entry_id bigint,
  entry_number text,
  entry_date date,
  description text,
  reference_type text,
  reference_id bigint,
  line_id bigint,
  account_code text,
  account_name text,
  line_description text,
  debit numeric,
  credit numeric,
  entry_debit numeric,
  entry_credit numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
BEGIN
  IF NOT public.has_permission('ACCOUNTING_VIEW') THEN
    RAISE EXCEPTION 'ليس لديك صلاحية عرض اليومية الأمريكية';
  END IF;
  IF p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN
    RAISE EXCEPTION 'فترة التقرير غير صحيحة';
  END IF;

  RETURN QUERY
  SELECT
    je.entry_id,
    COALESCE(je.entry_number,'')::text,
    je.entry_date,
    COALESCE(je.description,''),
    COALESCE(je.reference_type,'')::text,
    je.reference_id,
    jel.line_id,
    coa.account_code,
    coa.account_name,
    COALESCE(jel.description,''),
    jel.debit,
    jel.credit,
    SUM(jel.debit) OVER(PARTITION BY je.entry_id)::numeric,
    SUM(jel.credit) OVER(PARTITION BY je.entry_id)::numeric
  FROM public.journal_entries je
  JOIN public.journal_entry_lines jel ON jel.entry_id=je.entry_id
  JOIN public.chart_of_accounts coa ON coa.account_id=jel.account_id
  WHERE je.status='POSTED'
    AND je.entry_date BETWEEN p_from AND p_to
  ORDER BY je.entry_date,je.entry_id,jel.line_id;
END;
$function$;

-- Account ledger with opening balance carried forward before the selected date.
CREATE OR REPLACE FUNCTION public.get_account_ledger(
  p_account_id bigint,p_from date,p_to date
)
RETURNS TABLE(
  entry_id bigint,
  entry_number text,
  entry_date date,
  description text,
  line_description text,
  debit numeric,
  credit numeric,
  running_balance numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
BEGIN
  IF NOT public.has_permission('ACCOUNTING_VIEW') THEN
    RAISE EXCEPTION 'ليس لديك صلاحية عرض دفتر الأستاذ';
  END IF;
  IF p_account_id IS NULL OR p_account_id<=0
     OR p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN
    RAISE EXCEPTION 'بيانات تقرير دفتر الأستاذ غير صحيحة';
  END IF;
  IF NOT EXISTS(
    SELECT 1 FROM public.chart_of_accounts coa WHERE coa.account_id=p_account_id
  ) THEN
    RAISE EXCEPTION 'الحساب المحدد غير موجود';
  END IF;

  RETURN QUERY
  WITH opening AS (
    SELECT COALESCE(SUM(jel.debit-jel.credit),0)::numeric AS opening_balance
    FROM public.journal_entries je
    JOIN public.journal_entry_lines jel ON jel.entry_id=je.entry_id
    WHERE je.status='POSTED'
      AND je.entry_date<p_from
      AND jel.account_id=p_account_id
  ),
  lines AS (
    SELECT
      je.entry_id,
      COALESCE(je.entry_number,'')::text AS entry_number,
      je.entry_date,
      COALESCE(je.description,'') AS description,
      COALESCE(jel.description,'') AS line_description,
      jel.debit,
      jel.credit,
      (SELECT opening_balance FROM opening)
        + SUM(jel.debit-jel.credit) OVER(
            ORDER BY je.entry_date,je.entry_id,jel.line_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
          ) AS running_balance
    FROM public.journal_entries je
    JOIN public.journal_entry_lines jel ON jel.entry_id=je.entry_id
    WHERE je.status='POSTED'
      AND je.entry_date BETWEEN p_from AND p_to
      AND jel.account_id=p_account_id
  )
  SELECT lines.entry_id,lines.entry_number,lines.entry_date,
         lines.description,lines.line_description,
         lines.debit,lines.credit,lines.running_balance
  FROM lines
  ORDER BY lines.entry_date,lines.entry_id;
END;
$function$;

COMMENT ON FUNCTION public.get_journal_entries_full(date,date)
IS 'Returns every posted journal entry line with voucher number, account details and per-entry totals for the American journal screen.';

COMMENT ON FUNCTION public.get_account_ledger(bigint,date,date)
IS 'Returns account ledger lines for the selected period with opening balance carried forward from all earlier posted journal lines.';


-- Include an explicit opening-balance row even when the selected period has no movement.
CREATE OR REPLACE FUNCTION public.get_account_ledger(
  p_account_id bigint,p_from date,p_to date
)
RETURNS TABLE(
  entry_id bigint,
  entry_number text,
  entry_date date,
  description text,
  line_description text,
  debit numeric,
  credit numeric,
  running_balance numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
BEGIN
  IF NOT public.has_permission('ACCOUNTING_VIEW') THEN
    RAISE EXCEPTION 'ليس لديك صلاحية عرض دفتر الأستاذ';
  END IF;
  IF p_account_id IS NULL OR p_account_id<=0
     OR p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN
    RAISE EXCEPTION 'بيانات تقرير دفتر الأستاذ غير صحيحة';
  END IF;
  IF NOT EXISTS(
    SELECT 1 FROM public.chart_of_accounts coa WHERE coa.account_id=p_account_id
  ) THEN
    RAISE EXCEPTION 'الحساب المحدد غير موجود';
  END IF;

  RETURN QUERY
  WITH opening AS (
    SELECT COALESCE(SUM(jel.debit-jel.credit),0)::numeric AS opening_balance
    FROM public.journal_entries je
    JOIN public.journal_entry_lines jel ON jel.entry_id=je.entry_id
    WHERE je.status='POSTED'
      AND je.entry_date<p_from
      AND jel.account_id=p_account_id
  ),
  lines AS (
    SELECT
      je.entry_id,
      COALESCE(je.entry_number,'')::text AS entry_number,
      je.entry_date,
      COALESCE(je.description,'') AS description,
      COALESCE(jel.description,'') AS line_description,
      jel.debit,
      jel.credit,
      (SELECT opening_balance FROM opening)
        + SUM(jel.debit-jel.credit) OVER(
            ORDER BY je.entry_date,je.entry_id,jel.line_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
          ) AS running_balance
    FROM public.journal_entries je
    JOIN public.journal_entry_lines jel ON jel.entry_id=je.entry_id
    WHERE je.status='POSTED'
      AND je.entry_date BETWEEN p_from AND p_to
      AND jel.account_id=p_account_id
  ),
  combined AS (
    SELECT
      NULL::bigint AS entry_id,
      '—'::text AS entry_number,
      p_from AS entry_date,
      'رصيد أول المدة'::text AS description,
      'رصيد أول المدة'::text AS line_description,
      GREATEST(o.opening_balance,0)::numeric AS debit,
      GREATEST(-o.opening_balance,0)::numeric AS credit,
      o.opening_balance AS running_balance,
      0 AS sort_order
    FROM opening o
    UNION ALL
    SELECT l.entry_id,l.entry_number,l.entry_date,l.description,l.line_description,
           l.debit,l.credit,l.running_balance,1 AS sort_order
    FROM lines l
  )
  SELECT c.entry_id,c.entry_number,c.entry_date,c.description,c.line_description,
         c.debit,c.credit,c.running_balance
  FROM combined c
  ORDER BY c.sort_order,c.entry_date,c.entry_id;
END;
$function$;


-- Expose gross purchases, purchase returns and net purchases separately.
CREATE OR REPLACE FUNCTION public.get_period_summary(p_from date, p_to date)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
DECLARE
  v_rev numeric;
  v_purch numeric;
  v_purch_returns numeric;
  v_net_purch numeric;
  v_exp numeric;
  v_coll numeric;
  v_cash numeric;
  v_ar numeric;
  v_ap numeric;
  v_profit numeric;
BEGIN
  IF NOT public.has_permission('ACCOUNTING_VIEW') THEN
    RAISE EXCEPTION 'ليس لديك صلاحية عرض ملخص المحاسبة';
  END IF;
  IF p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN
    RAISE EXCEPTION 'فترة التقرير غير صحيحة';
  END IF;

  SELECT COALESCE(sum(CASE WHEN coa.account_type='REVENUE'
    THEN jel.credit-jel.debit ELSE 0 END),0)
  INTO v_rev
  FROM public.journal_entries je
  JOIN public.journal_entry_lines jel ON jel.entry_id=je.entry_id
  JOIN public.chart_of_accounts coa ON coa.account_id=jel.account_id
  WHERE je.status='POSTED' AND je.entry_date BETWEEN p_from AND p_to;

  SELECT COALESCE(sum(net_total),0) INTO v_purch
  FROM public.purchase_invoices
  WHERE invoice_date BETWEEN p_from AND p_to AND status<>'CANCELLED';

  SELECT COALESCE(sum(total_return_amount),0) INTO v_purch_returns
  FROM public.purchase_returns
  WHERE return_date BETWEEN p_from AND p_to AND is_cancelled=false;

  v_net_purch := v_purch-v_purch_returns;

  SELECT COALESCE(sum(amount),0) INTO v_exp
  FROM public.expenses
  WHERE expense_date BETWEEN p_from AND p_to AND is_cancelled=false;

  SELECT COALESCE(sum(amount),0) INTO v_coll
  FROM public.customer_collections
  WHERE collection_date BETWEEN p_from AND p_to AND status='POSTED';

  SELECT COALESCE(sum(current_balance),0) INTO v_cash
  FROM public.treasuries WHERE is_active=true;

  SELECT
    COALESCE((
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
    ),0)
    + COALESCE((
        SELECT SUM(GREATEST(COALESCE(si.remaining_amount,0),0))
        FROM public.sales_invoices si
        JOIN public.customers c ON c.customer_id=si.customer_id
        WHERE si.status IN ('POSTED','PAID','PARTIAL')
          AND COALESCE(si.remaining_amount,0)>0.01
      ),0)
  INTO v_ar;

  SELECT
    COALESCE((SELECT sum(s.opening_balance) FROM public.suppliers s),0)
    + COALESCE((SELECT sum(pi.net_total) FROM public.purchase_invoices pi
        WHERE pi.status='POSTED' AND pi.treasury_id IS NULL),0)
    + COALESCE((SELECT sum(plc.amount) FROM public.purchase_landed_costs plc
        WHERE plc.source_type='EXTERNAL_SUPPLIER' AND plc.status='ACTIVE'),0)
    + COALESCE((SELECT sum(fa.acquisition_cost) FROM public.fixed_assets fa
        WHERE fa.source_type='SUPPLIER_CREDIT' AND fa.status='ACTIVE'),0)
    - COALESCE((SELECT sum(pr.total_return_amount) FROM public.purchase_returns pr
        WHERE pr.settlement_method='SUPPLIER_CREDIT' AND pr.is_cancelled=false),0)
    - COALESCE((SELECT sum(sp.amount) FROM public.supplier_payments sp
        WHERE sp.is_cancelled=false),0)
  INTO v_ap;

  SELECT
    COALESCE(sum(CASE WHEN coa.account_type='REVENUE' THEN jel.credit-jel.debit ELSE 0 END),0)
    - COALESCE(sum(CASE WHEN coa.account_code='5100' THEN jel.debit-jel.credit ELSE 0 END),0)
    - COALESCE(sum(CASE WHEN coa.account_type='EXPENSE' AND coa.account_code<>'5100' THEN jel.debit-jel.credit ELSE 0 END),0)
  INTO v_profit
  FROM public.journal_entries je
  JOIN public.journal_entry_lines jel ON jel.entry_id=je.entry_id
  JOIN public.chart_of_accounts coa ON coa.account_id=jel.account_id
  WHERE je.status='POSTED' AND je.entry_date BETWEEN p_from AND p_to;

  RETURN json_build_object(
    'rev',v_rev,'purch',v_purch,'purch_returns',v_purch_returns,
    'net_purch',v_net_purch,'exp',v_exp,'coll',v_coll,
    'profit',COALESCE(v_profit,0),'cash',v_cash,'ar',v_ar,'ap',v_ap
  );
END;
$function$;
