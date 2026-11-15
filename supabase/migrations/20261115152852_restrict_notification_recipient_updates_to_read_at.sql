REVOKE UPDATE ON TABLE public.notification_recipients FROM authenticated;
GRANT UPDATE (read_at) ON TABLE public.notification_recipients TO authenticated;
