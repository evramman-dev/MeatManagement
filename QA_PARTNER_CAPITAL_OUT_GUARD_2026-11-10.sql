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


-- Additional QA verification performed on 2026-11-10, all inside BEGIN/ROLLBACK:
-- 1. CAPITAL_IN, WITHDRAWAL, and PROFIT each created one balanced PARTNER_MOVE journal.
-- 2. Repeating CAPITAL_IN with the same request_id returned the same transaction_id.
-- 3. Reusing that request_id with a different amount was rejected.
-- 4. WAREHOUSE_KEEPER and unauthenticated attempts were rejected by the permission check.
-- 5. A withdrawal larger than the treasury balance was rejected.
-- 6. The in-kind CAPITAL_OUT attempt was rejected with the expected Arabic message.
-- 7. After rollback: partner_transactions=0, CAPITAL_OUT=0, no QA partner row,
--    no QA partner journal, and treasury_id=5 remained at 1065.000.
-- 8. No existing partner, treasury, or journal data was changed by these tests.

-- Important accounting design note:
-- Do not enable CAPITAL_OUT until the UI requires a specific active ASSET account,
-- the database stores the selected account on the transaction, and the RPC creates
-- a balanced debit-to-asset / credit-to-partner-capital journal.
-- The cancellation/reversal path must reverse that exact journal and transaction.
-- Do not assume every in-kind contribution is a fixed asset; it may be inventory,
-- equipment, a vehicle, or another asset category.
