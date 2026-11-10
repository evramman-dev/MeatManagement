-- MeatManagement QA
-- Date: 2026-11-10
-- Migration: block_unaccounted_partner_in_kind_contribution_20261110
-- Purpose:
-- Prevent recording CAPITAL_OUT partner transactions until the UI captures
-- the asset account and the database posts the matching debit/credit journal.
-- Pre-change QA state: partner_transactions=0, CAPITAL_OUT=0, PARTNER_MOVE journals=0.
-- No existing partner transactions or balances were modified.

CREATE OR REPLACE FUNCTION public.block_unaccounted_partner_in_kind_contribution()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.transaction_type = 'CAPITAL_OUT' THEN
    RAISE EXCEPTION
      'تسجيل المساهمة العينية موقوف حاليًا. يجب تحديد حساب الأصل وإنشاء القيد المحاسبي قبل إتاحة هذا النوع.';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_block_unaccounted_partner_in_kind_contribution
ON public.partner_transactions;

CREATE TRIGGER trg_block_unaccounted_partner_in_kind_contribution
BEFORE INSERT OR UPDATE OF transaction_type
ON public.partner_transactions
FOR EACH ROW
EXECUTE FUNCTION public.block_unaccounted_partner_in_kind_contribution();

-- Verification performed:
-- An INSERT attempt for CAPITAL_OUT was rejected by the trigger with the
-- expected Arabic error. No row was created. partner_transactions remains empty.
