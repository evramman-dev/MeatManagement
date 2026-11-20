CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;

  IF public.get_current_user_role() = 'PARTNER' THEN
    RAISE EXCEPTION 'حساب الشريك للعرض فقط ولا يمكنه تعديل حالة التنبيهات';
  END IF;

  UPDATE public.notification_recipients
  SET read_at = COALESCE(read_at, now())
  WHERE notification_id = p_notification_id
    AND user_id = auth.uid();
END;
$function$;
