-- Add indexes for the two uncovered foreign keys on accounting period closures.
-- These indexes support joins and referenced-row maintenance as the table grows.

CREATE INDEX IF NOT EXISTS idx_accounting_period_closures_closing_entry_id
ON public.accounting_period_closures (closing_entry_id);

CREATE INDEX IF NOT EXISTS idx_accounting_period_closures_created_by
ON public.accounting_period_closures (created_by);
