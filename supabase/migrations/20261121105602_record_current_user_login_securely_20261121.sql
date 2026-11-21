CREATE OR REPLACE FUNCTION private.record_current_user_login()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication is required'
      USING ERRCODE = '28000';
  END IF;

  UPDATE public.app_users
  SET last_login = statement_timestamp()
  WHERE user_id = v_user_id
    AND is_active IS TRUE;

  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION private.record_current_user_login() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.record_current_user_login() TO authenticated;

CREATE OR REPLACE FUNCTION public.record_current_user_login()
RETURNS boolean
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT private.record_current_user_login();
$$;

REVOKE ALL ON FUNCTION public.record_current_user_login() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_current_user_login() TO authenticated;
