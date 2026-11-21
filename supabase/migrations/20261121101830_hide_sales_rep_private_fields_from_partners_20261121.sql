DROP POLICY IF EXISTS partner_read_only_select ON public.sales_reps;
DROP POLICY IF EXISTS sales_reps_select_access ON public.sales_reps;

CREATE POLICY sales_reps_select_access
ON public.sales_reps
FOR SELECT TO authenticated
USING (
  (SELECT public.get_current_user_role()) <> 'PARTNER'
  AND (
    public.has_permission('SALES_REPS_VIEW')
    OR public.has_permission('SALES_REPS_MANAGE')
  )
);
