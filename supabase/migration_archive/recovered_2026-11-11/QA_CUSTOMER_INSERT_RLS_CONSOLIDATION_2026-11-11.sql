-- Applied to the MeatManagement QA Supabase project on 2026-11-11.
-- Consolidates the two customers INSERT policies without changing their combined authorization logic.

DROP POLICY IF EXISTS customers_insert_manage ON public.customers;
DROP POLICY IF EXISTS customers_insert_sales_rep_assigned_area ON public.customers;

CREATE POLICY customers_insert_authorized
ON public.customers
FOR INSERT
TO authenticated
WITH CHECK (
  (SELECT public.has_permission('CUSTOMERS_MANAGE'))
  OR (
    (SELECT public.get_current_user_role())='SALES_REP'
    AND (SELECT public.has_permission('CUSTOMERS_VIEW'))
    AND area_id IS NOT NULL
    AND credit_limit=0
    AND opening_balance=0
    AND payment_terms_days=0
    AND is_active=true
    AND EXISTS (
      SELECT 1
      FROM public.sales_rep_areas sra
      WHERE sra.area_id=customers.area_id
        AND sra.sales_rep_id=(SELECT public.get_current_sales_rep_id())
        AND sra.is_active=true
    )
  )
);
