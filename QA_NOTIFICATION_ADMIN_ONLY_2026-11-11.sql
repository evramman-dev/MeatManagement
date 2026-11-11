-- Applied to the MeatManagement QA Supabase project on 2026-11-11.
-- Purpose: restrict notification management to SYSTEM_ADMIN at the RPC and RLS layers.
-- The SYSTEM_TESTER role no longer carries NOTIFICATIONS_MANAGE.
-- The frontend broadcast mode sends an explicit list of all active app_users,
-- so no database schema change is required for GENERAL notification type.

CREATE OR REPLACE FUNCTION public.create_notification(
  p_notification_type text,
  p_title text,
  p_body text,
  p_event_key text,
  p_user_ids uuid[],
  p_entity_type text DEFAULT NULL,
  p_entity_id text DEFAULT NULL,
  p_due_at timestamptz DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_id uuid;
  v_user_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;
  IF public.get_current_user_role() IS DISTINCT FROM 'SYSTEM_ADMIN'
     OR NOT public.has_permission('NOTIFICATIONS_MANAGE') THEN
    RAISE EXCEPTION 'إرسال التنبيهات متاح لمدير النظام فقط';
  END IF;
  IF nullif(trim(coalesce(p_title,'')),'') IS NULL
     OR nullif(trim(coalesce(p_body,'')),'') IS NULL THEN
    RAISE EXCEPTION 'عنوان ونص الإشعار مطلوبان';
  END IF;
  IF p_user_ids IS NULL OR coalesce(array_length(p_user_ids,1),0)=0 THEN
    RAISE EXCEPTION 'يجب اختيار مستلم واحد على الأقل';
  END IF;

  INSERT INTO public.notifications(
    notification_type,title,body,event_key,entity_type,entity_id,created_by,due_at,metadata
  )
  VALUES(
    p_notification_type,p_title,p_body,p_event_key,p_entity_type,p_entity_id,
    auth.uid(),p_due_at,coalesce(p_metadata,'{}'::jsonb)
  )
  ON CONFLICT(event_key) DO UPDATE
    SET title=excluded.title,body=excluded.body,metadata=excluded.metadata
  RETURNING notification_id INTO v_id;

  FOREACH v_user_id IN ARRAY p_user_ids LOOP
    INSERT INTO public.notification_recipients(notification_id,user_id)
    SELECT v_id,v_user_id
    WHERE EXISTS(
      SELECT 1 FROM public.app_users au
      WHERE au.user_id=v_user_id AND au.is_active=true
    )
    ON CONFLICT(notification_id,user_id) DO NOTHING;
  END LOOP;
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_due_invoice_notifications()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_count integer := 0;
  r record;
  v_event_key text;
  v_notification_id uuid;
  v_users uuid[];
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;
  IF public.get_current_user_role() IS DISTINCT FROM 'SYSTEM_ADMIN'
     OR NOT public.has_permission('NOTIFICATIONS_MANAGE') THEN
    RAISE EXCEPTION 'إدارة التنبيهات متاحة لمدير النظام فقط';
  END IF;

  SELECT coalesce(array_agg(au.user_id),array[]::uuid[]) INTO v_users
  FROM public.app_users au
  JOIN public.app_roles ar ON ar.role_id=au.role_id
  WHERE au.is_active=true AND ar.is_active=true
    AND ar.role_code IN ('ACCOUNTANT','GENERAL_MANAGER');

  IF coalesce(array_length(v_users,1),0)=0 THEN RETURN 0; END IF;

  FOR r IN
    SELECT si.sales_invoice_id,si.invoice_number,si.due_date,si.remaining_amount,c.customer_name
    FROM public.sales_invoices si
    JOIN public.customers c ON c.customer_id=si.customer_id
    WHERE si.status<>'CANCELLED'
      AND coalesce(si.remaining_amount,0)>0
      AND si.due_date IS NOT NULL
      AND si.due_date<=current_date+2
      AND si.due_date>=current_date-30
  LOOP
    v_event_key:='SALES_INVOICE_DUE:'||r.sales_invoice_id||':'||r.due_date::text;
    INSERT INTO public.notifications(
      notification_type,title,body,event_key,entity_type,entity_id,due_at,metadata
    )
    VALUES(
      'SALES_INVOICE_DUE',
      CASE WHEN r.due_date<current_date THEN 'فاتورة بيع متأخرة' ELSE 'اقتراب استحقاق فاتورة بيع' END,
      'الفاتورة '||r.invoice_number||' للعميل '||coalesce(r.customer_name,'-')||
      ' متبقي منها '||to_char(r.remaining_amount,'FM999999990D00')||
      ' وتاريخ الاستحقاق '||to_char(r.due_date,'YYYY-MM-DD'),
      v_event_key,'sales_invoice',r.sales_invoice_id::text,r.due_date::timestamptz,
      jsonb_build_object('sales_invoice_id',r.sales_invoice_id,'invoice_number',r.invoice_number,
                         'due_date',r.due_date,'remaining_amount',r.remaining_amount)
    )
    ON CONFLICT(event_key) DO NOTHING
    RETURNING notification_id INTO v_notification_id;

    IF v_notification_id IS NOT NULL THEN
      INSERT INTO public.notification_recipients(notification_id,user_id)
      SELECT v_notification_id,u FROM unnest(v_users) u
      ON CONFLICT(notification_id,user_id) DO NOTHING;
      v_count:=v_count+1;
    END IF;
  END LOOP;
  RETURN v_count;
END;
$function$;

DROP POLICY IF EXISTS notifications_select ON public.notifications;
CREATE POLICY notifications_select ON public.notifications
FOR SELECT TO authenticated
USING (
  EXISTS(
    SELECT 1 FROM public.notification_recipients nr
    WHERE nr.notification_id=notifications.notification_id
      AND nr.user_id=(SELECT auth.uid())
  )
  OR (SELECT public.get_current_user_role())='SYSTEM_ADMIN'
);

DROP POLICY IF EXISTS notification_recipients_select ON public.notification_recipients;
CREATE POLICY notification_recipients_select ON public.notification_recipients
FOR SELECT TO authenticated
USING (
  user_id=(SELECT auth.uid())
  OR (SELECT public.get_current_user_role())='SYSTEM_ADMIN'
);

DROP POLICY IF EXISTS notification_recipients_update ON public.notification_recipients;
CREATE POLICY notification_recipients_update ON public.notification_recipients
FOR UPDATE TO authenticated
USING (
  user_id=(SELECT auth.uid())
  OR (SELECT public.get_current_user_role())='SYSTEM_ADMIN'
)
WITH CHECK (
  user_id=(SELECT auth.uid())
  OR (SELECT public.get_current_user_role())='SYSTEM_ADMIN'
);

DELETE FROM public.app_role_permissions arp
USING public.app_roles ar, public.app_permissions ap
WHERE arp.role_id=ar.role_id
  AND arp.permission_id=ap.permission_id
  AND ar.role_code='SYSTEM_TESTER'
  AND ap.permission_code='NOTIFICATIONS_MANAGE';
