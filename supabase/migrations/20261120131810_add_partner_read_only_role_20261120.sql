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
    WHERE au.user_id = auth.uid()
      AND au.is_active = TRUE
      AND ar.is_active = TRUE
      AND ar.role_code = 'PARTNER'
  );
$function$;

REVOKE ALL ON FUNCTION public.is_partner_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_partner_user() TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.app_roles WHERE role_code = 'PARTNER'
  ) THEN
    INSERT INTO public.app_roles (role_code, role_name, is_active)
    VALUES ('PARTNER', 'شريك - مشاهدة فقط', TRUE);
  ELSE
    UPDATE public.app_roles
    SET role_name = 'شريك - مشاهدة فقط', is_active = TRUE
    WHERE role_code = 'PARTNER';
  END IF;
END
$$;

INSERT INTO public.app_role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM public.app_roles r
CROSS JOIN public.app_permissions p
WHERE r.role_code = 'PARTNER'
  AND r.is_active = TRUE
  AND p.is_active = TRUE
  AND p.permission_code LIKE '%\_VIEW' ESCAPE '\'
  AND NOT EXISTS (
    SELECT 1
    FROM public.app_role_permissions arp
    WHERE arp.role_id = r.role_id
      AND arp.permission_id = p.permission_id
  );

DO $$
DECLARE
  t record;
BEGIN
  FOR t IN
    SELECT n.nspname AS schema_name, c.relname AS table_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relrowsecurity = TRUE
      AND EXISTS (
        SELECT 1
        FROM pg_policies p
        WHERE p.schemaname = n.nspname
          AND p.tablename = c.relname
          AND p.cmd = 'SELECT'
      )
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies p
      WHERE p.schemaname = t.schema_name
        AND p.tablename = t.table_name
        AND p.policyname = 'partner_read_only_select'
    ) THEN
      EXECUTE format(
        'CREATE POLICY partner_read_only_select ON %I.%I FOR SELECT TO authenticated USING (public.is_partner_user())',
        t.schema_name, t.table_name
      );
    END IF;
  END LOOP;
END
$$;

DROP POLICY IF EXISTS user_logs_insert_own ON public.user_logs;
CREATE POLICY user_logs_insert_own
ON public.user_logs
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = (SELECT auth.uid())
  AND (
    (SELECT public.get_current_user_role()) <> 'PARTNER'
    OR action_type = 'LOGIN'
  )
);

DROP POLICY IF EXISTS notification_recipients_update ON public.notification_recipients;
CREATE POLICY notification_recipients_update
ON public.notification_recipients
FOR UPDATE
TO authenticated
USING (
  (SELECT public.get_current_user_role()) = 'SYSTEM_ADMIN'
  OR (
    (SELECT public.get_current_user_role()) <> 'PARTNER'
    AND user_id = (SELECT auth.uid())
  )
)
WITH CHECK (
  (SELECT public.get_current_user_role()) = 'SYSTEM_ADMIN'
  OR (
    (SELECT public.get_current_user_role()) <> 'PARTNER'
    AND user_id = (SELECT auth.uid())
  )
);
