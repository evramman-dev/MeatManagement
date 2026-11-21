CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;
CREATE OR REPLACE FUNCTION private.current_partner_id()
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
REVOKE ALL ON FUNCTION private.current_partner_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.current_partner_id() TO authenticated;
DROP POLICY IF EXISTS partner_read_only_select ON public.partners;
CREATE POLICY partner_read_only_select ON public.partners FOR SELECT TO authenticated
USING (public.is_partner_user() AND partner_id = (SELECT private.current_partner_id()));
DROP POLICY IF EXISTS partner_read_only_select ON public.partner_transactions;
CREATE POLICY partner_read_only_select ON public.partner_transactions FOR SELECT TO authenticated
USING (public.is_partner_user() AND partner_id = (SELECT private.current_partner_id()));
DROP POLICY IF EXISTS partner_read_only_select ON public.partner_inventory_contributions;
CREATE POLICY partner_read_only_select ON public.partner_inventory_contributions FOR SELECT TO authenticated
USING (public.is_partner_user() AND partner_id = (SELECT private.current_partner_id()));
DROP POLICY IF EXISTS partner_read_only_select ON public.partner_profit_distribution_items;
CREATE POLICY partner_read_only_select ON public.partner_profit_distribution_items FOR SELECT TO authenticated
USING (public.is_partner_user() AND partner_id = (SELECT private.current_partner_id()));
DROP POLICY IF EXISTS partner_read_only_select ON public.partner_profit_distributions;
CREATE POLICY partner_read_only_select ON public.partner_profit_distributions FOR SELECT TO authenticated
USING (public.is_partner_user() AND EXISTS (
  SELECT 1 FROM public.partner_profit_distribution_items pdi
  WHERE pdi.distribution_id = partner_profit_distributions.distribution_id
    AND pdi.partner_id = (SELECT private.current_partner_id())
));
DROP POLICY IF EXISTS partner_read_only_select ON public.fixed_assets;
CREATE POLICY partner_read_only_select ON public.fixed_assets FOR SELECT TO authenticated
USING (public.is_partner_user() AND (partner_id IS NULL OR partner_id = (SELECT private.current_partner_id())));
REVOKE ALL ON FUNCTION public.current_partner_id() FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS public.current_partner_id();