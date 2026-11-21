-- Require a linked, active partner record before any PARTNER read policy grants access.
CREATE OR REPLACE FUNCTION public.is_partner_user()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.app_users au
    JOIN public.app_roles ar ON ar.role_id = au.role_id
    JOIN public.partners p ON p.partner_id = au.partner_id
    WHERE au.user_id = auth.uid()
      AND au.is_active = TRUE
      AND ar.is_active = TRUE
      AND ar.role_code = 'PARTNER'
      AND au.partner_id IS NOT NULL
      AND p.is_active = TRUE
  );
$function$;
