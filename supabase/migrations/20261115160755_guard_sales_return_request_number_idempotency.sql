CREATE OR REPLACE FUNCTION public.create_sales_return_v2(p_return_number character varying, p_customer_id bigint, p_trip_id bigint, p_sales_rep_id bigint, p_sales_invoice_id bigint, p_return_type character varying, p_return_date timestamp with time zone, p_reason text, p_notes text, p_created_by uuid, p_cash_action character varying, p_treasury_id bigint, p_request_id uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_existing public.sales_returns%ROWTYPE;
  v_return_id bigint;
  v_date date:=COALESCE(p_return_date,now())::date;
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_permission('RETURNS_CREATE')
    OR public.has_permission('RETURNS_MANAGE')
  ) THEN
    RAISE EXCEPTION 'لا تملك صلاحية إنشاء طلب مرتجع';
  END IF;

  IF p_request_id IS NULL THEN
    RAISE EXCEPTION 'رقم طلب المرتجع مطلوب لمنع التكرار';
  END IF;

  IF p_created_by IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'منشئ المرتجع يجب أن يطابق المستخدم الحالي';
  END IF;

  IF UPPER(BTRIM(COALESCE(p_return_type,'')))<>'RETURN' THEN
    RAISE EXCEPTION 'مسار المرتجعات الحالي يدعم المرتجع فقط؛ الاستبدال غير متاح عبر هذا المسار';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));

  SELECT * INTO v_existing
  FROM public.sales_returns
  WHERE request_id=p_request_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.return_number IS DISTINCT FROM p_return_number
       OR v_existing.customer_id IS DISTINCT FROM p_customer_id
       OR v_existing.sales_invoice_id IS DISTINCT FROM p_sales_invoice_id
       OR v_existing.return_type IS DISTINCT FROM 'RETURN'
       OR v_existing.return_date IS DISTINCT FROM v_date
       OR v_existing.reason IS DISTINCT FROM p_reason
       OR v_existing.notes IS DISTINCT FROM p_notes
       OR v_existing.cash_action IS DISTINCT FROM p_cash_action
       OR v_existing.created_by IS DISTINCT FROM auth.uid()
       OR (p_trip_id IS NOT NULL AND v_existing.trip_id IS DISTINCT FROM p_trip_id)
       OR (p_sales_rep_id IS NOT NULL AND v_existing.sales_rep_id IS DISTINCT FROM p_sales_rep_id)
       OR (p_cash_action='CASH_BACK' AND p_treasury_id IS NOT NULL
           AND v_existing.treasury_id IS DISTINCT FROM p_treasury_id) THEN
      RAISE EXCEPTION 'رقم طلب المرتجع مستخدم من قبل مع بيانات مختلفة';
    END IF;

    RETURN v_existing.sales_return_id;
  END IF;

  v_return_id:=public.create_sales_return(
    p_return_number,p_customer_id,p_trip_id,p_sales_rep_id,
    p_sales_invoice_id,p_return_type,p_return_date,p_reason,
    p_notes,p_created_by,p_cash_action,p_treasury_id
  );

  UPDATE public.sales_returns
  SET request_id=p_request_id
  WHERE sales_return_id=v_return_id;

  RETURN v_return_id;
END;
$function$;
