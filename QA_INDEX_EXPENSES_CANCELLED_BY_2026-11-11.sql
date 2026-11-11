-- Applied Supabase migration: index_expenses_cancelled_by_20261111
-- Date: 2026-11-11
-- Supports the foreign key from expenses.cancelled_by to auth.users(id).
CREATE INDEX IF NOT EXISTS idx_expenses_cancelled_by
ON public.expenses (cancelled_by);
