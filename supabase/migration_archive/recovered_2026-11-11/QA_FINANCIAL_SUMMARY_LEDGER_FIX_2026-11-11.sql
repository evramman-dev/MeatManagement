-- Applied to the MeatManagement QA Supabase project on 2026-11-11.
-- Keeps accounting period revenue consistent with the posted-ledger P&L.
-- Also includes cost of goods sold in the all-time financial summary profit.

CREATE OR REPLACE FUNCTION public.get_period_summary(p_from date,p_to date)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
DECLARE
  v_rev numeric;
  v_purch numeric;
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

  SELECT COALESCE(sum(amount),0) INTO v_exp
  FROM public.expenses WHERE expense_date BETWEEN p_from AND p_to;

  SELECT COALESCE(sum(amount),0) INTO v_coll
  FROM public.customer_collections
  WHERE collection_date BETWEEN p_from AND p_to AND status='POSTED';

  SELECT COALESCE(sum(current_balance),0) INTO v_cash
  FROM public.treasuries WHERE is_active=true;

  SELECT COALESCE(sum(remaining_amount),0) INTO v_ar
  FROM public.sales_invoices WHERE status='POSTED' AND remaining_amount>0.01;

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
    'rev',v_rev,'purch',v_purch,'exp',v_exp,'coll',v_coll,
    'profit',COALESCE(v_profit,0),'cash',v_cash,'ar',v_ar,'ap',v_ap
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_financial_summary()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','pg_temp'
AS $function$
DECLARE
  v_revenue numeric;
  v_cogs numeric;
  v_expenses numeric;
  v_cash numeric;
  v_ar numeric;
  v_ap numeric;
  v_net_profit numeric;
BEGIN
  IF NOT public.has_permission('ACCOUNTING_VIEW') THEN
    RAISE EXCEPTION 'ليس لديك صلاحية عرض الملخص المالي';
  END IF;

  SELECT
    COALESCE(sum(CASE WHEN coa.account_type='REVENUE' THEN jel.credit-jel.debit ELSE 0 END),0),
    COALESCE(sum(CASE WHEN coa.account_code='5100' THEN jel.debit-jel.credit ELSE 0 END),0),
    COALESCE(sum(CASE WHEN coa.account_type='EXPENSE' AND coa.account_code<>'5100' THEN jel.debit-jel.credit ELSE 0 END),0)
  INTO v_revenue,v_cogs,v_expenses
  FROM public.journal_entries je
  JOIN public.journal_entry_lines jel ON jel.entry_id=je.entry_id
  JOIN public.chart_of_accounts coa ON coa.account_id=jel.account_id
  WHERE je.status='POSTED';

  SELECT COALESCE(sum(current_balance),0) INTO v_cash
  FROM public.treasuries WHERE is_active=true;

  SELECT COALESCE(sum(remaining_amount),0) INTO v_ar
  FROM public.sales_invoices WHERE status<>'CANCELLED';

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

  v_net_profit:=v_revenue-v_cogs-v_expenses;
  RETURN json_build_object(
    'revenue',v_revenue,'cogs',v_cogs,'expenses',v_expenses,
    'cash',v_cash,'ar',v_ar,'ap',v_ap,'net_profit',v_net_profit
  );
END;
$function$;
