DROP POLICY IF EXISTS fixed_assets_supplier_credit_select ON public.fixed_assets;
DROP POLICY IF EXISTS fixed_assets_select_permission ON public.fixed_assets;
CREATE POLICY fixed_assets_select_permission
ON public.fixed_assets
FOR SELECT
TO authenticated
USING (
  public.has_permission('ACCOUNTING_VIEW')
  OR public.has_permission('ACCOUNTING_MANAGE')
  OR (
    source_type='SUPPLIER_CREDIT'
    AND supplier_id IS NOT NULL
    AND (
      public.has_permission('SUPPLIERS_VIEW')
      OR public.has_permission('SUPPLIERS_MANAGE')
    )
  )
);