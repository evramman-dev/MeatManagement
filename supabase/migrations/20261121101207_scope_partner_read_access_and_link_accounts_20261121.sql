ALTER TABLE public.app_users
  ADD COLUMN IF NOT EXISTS partner_id bigint;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.app_users'::regclass
      AND conname = 'app_users_partner_id_fkey'
  ) THEN
    ALTER TABLE public.app_users
      ADD CONSTRAINT app_users_partner_id_fkey
      FOREIGN KEY (partner_id)
      REFERENCES public.partners(partner_id)
      ON DELETE RESTRICT;
  END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS app_users_partner_id_unique
  ON public.app_users(partner_id)
  WHERE partner_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.current_partner_id()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
  SELECT au.partner_id
  FROM public.app_users au
  JOIN public.app_roles ar ON ar.role_id = au.role_id
  WHERE au.user_id = auth.uid()
    AND au.is_active = TRUE
    AND ar.is_active = TRUE
    AND ar.role_code = 'PARTNER'
  LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION public.current_partner_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_partner_id() TO authenticated;

DROP POLICY IF EXISTS partner_read_only_select ON public.app_users;
DROP POLICY IF EXISTS partner_read_only_select ON public.notifications;
DROP POLICY IF EXISTS partner_read_only_select ON public.notification_recipients;
DROP POLICY IF EXISTS partner_read_only_select ON public.user_logs;

DROP POLICY IF EXISTS partner_read_only_select ON public.partners;
DROP POLICY IF EXISTS partners_select_permission ON public.partners;
CREATE POLICY partners_select_permission
ON public.partners FOR SELECT TO authenticated
USING (
  (SELECT public.get_current_user_role()) <> 'PARTNER'
  AND (public.has_permission('PARTNERS_VIEW') OR public.has_permission('PARTNERS_MANAGE'))
);
CREATE POLICY partner_read_only_select
ON public.partners FOR SELECT TO authenticated
USING (public.is_partner_user() AND partner_id = (SELECT public.current_partner_id()));

DROP POLICY IF EXISTS partner_read_only_select ON public.partner_transactions;
DROP POLICY IF EXISTS partner_transactions_select_permission ON public.partner_transactions;
CREATE POLICY partner_transactions_select_permission
ON public.partner_transactions FOR SELECT TO authenticated
USING (
  (SELECT public.get_current_user_role()) <> 'PARTNER'
  AND (
    public.has_permission('PARTNERS_TRANSACTIONS_VIEW')
    OR public.has_permission('PARTNERS_TRANSACTIONS_MANAGE')
    OR public.has_permission('PARTNERS_VIEW')
    OR public.has_permission('PARTNERS_MANAGE')
  )
);
CREATE POLICY partner_read_only_select
ON public.partner_transactions FOR SELECT TO authenticated
USING (public.is_partner_user() AND partner_id = (SELECT public.current_partner_id()));

DROP POLICY IF EXISTS partner_read_only_select ON public.partner_inventory_contributions;
DROP POLICY IF EXISTS partner_inventory_contributions_view ON public.partner_inventory_contributions;
CREATE POLICY partner_inventory_contributions_view
ON public.partner_inventory_contributions FOR SELECT TO authenticated
USING (
  (SELECT public.get_current_user_role()) <> 'PARTNER'
  AND (
    public.has_permission('ACCOUNTING_VIEW')
    OR public.has_permission('ACCOUNTING_MANAGE')
    OR public.has_permission('PARTNERS_TRANSACTIONS_VIEW')
    OR public.has_permission('PARTNERS_TRANSACTIONS_MANAGE')
  )
);
CREATE POLICY partner_read_only_select
ON public.partner_inventory_contributions FOR SELECT TO authenticated
USING (public.is_partner_user() AND partner_id = (SELECT public.current_partner_id()));

DROP POLICY IF EXISTS partner_read_only_select ON public.partner_profit_distribution_items;
DROP POLICY IF EXISTS partner_profit_distribution_items_authenticated_select ON public.partner_profit_distribution_items;
CREATE POLICY partner_profit_distribution_items_authenticated_select
ON public.partner_profit_distribution_items FOR SELECT TO authenticated
USING (
  (SELECT public.get_current_user_role()) <> 'PARTNER'
  AND public.has_permission('ACCOUNTING_VIEW')
);
CREATE POLICY partner_read_only_select
ON public.partner_profit_distribution_items FOR SELECT TO authenticated
USING (public.is_partner_user() AND partner_id = (SELECT public.current_partner_id()));

DROP POLICY IF EXISTS partner_read_only_select ON public.partner_profit_distributions;
DROP POLICY IF EXISTS partner_profit_distribution_authenticated_select ON public.partner_profit_distribution_authenticated_select;
CREATE POLICY partner_profit_distribution_authenticated_select
ON public.partner_profit_distributions FOR SELECT TO authenticated
USING (
  (SELECT public.get_current_user_role()) <> 'PARTNER'
  AND public.has_permission('ACCOUNTING_VIEW')
);
CREATE POLICY partner_read_only_select
ON public.partner_profit_distributions FOR SELECT TO authenticated
USING (
  public.is_partner_user()
  AND EXISTS (
    SELECT 1
    FROM public.partner_profit_distribution_items pdi
    WHERE pdi.distribution_id = partner_profit_distributions.distribution_id
      AND pdi.partner_id = (SELECT public.current_partner_id())
  )
);

DROP POLICY IF EXISTS partner_read_only_select ON public.fixed_assets;
DROP POLICY IF EXISTS fixed_assets_select_permission ON public.fixed_assets;
CREATE POLICY fixed_assets_select_permission
ON public.fixed_assets FOR SELECT TO authenticated
USING (
  (SELECT public.get_current_user_role()) <> 'PARTNER'
  AND (
    public.has_permission('ACCOUNTING_VIEW')
    OR public.has_permission('ACCOUNTING_MANAGE')
    OR (
      source_type = 'SUPPLIER_CREDIT'
      AND supplier_id IS NOT NULL
      AND (public.has_permission('SUPPLIERS_VIEW') OR public.has_permission('SUPPLIERS_MANAGE'))
    )
  )
);
CREATE POLICY partner_read_only_select
ON public.fixed_assets FOR SELECT TO authenticated
USING (
  public.is_partner_user()
  AND (partner_id IS NULL OR partner_id = (SELECT public.current_partner_id()))
);
