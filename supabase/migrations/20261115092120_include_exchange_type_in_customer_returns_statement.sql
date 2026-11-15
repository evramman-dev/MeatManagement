-- Expose return type in customer statement data so exchange differences can be reported correctly
CREATE OR REPLACE FUNCTION public.get_customer_returns(p_customer_id bigint)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_result json;
  v_role text;
BEGIN
  IF NOT public.has_permission('CUSTOMERS_VIEW') THEN
    RAISE EXCEPTION 'لا تملك صلاحية عرض العملاء.';
  END IF;

  v_role:=public.get_current_user_role();

  SELECT COALESCE(
    json_agg(row_to_json(x) ORDER BY x.return_date,x.sales_return_id),
    '[]'::json
  )
  INTO v_result
  FROM (
    SELECT
      sales_return_id,
      return_number,
      return_type,
      return_date,
      total_returned_value,
      total_exchange_value,
      price_difference,
      cash_action
    FROM public.sales_returns
    WHERE customer_id=p_customer_id
      AND status='POSTED'
      AND (
        v_role<>'SALES_REP'
        OR sales_rep_id IS NOT DISTINCT FROM public.get_current_sales_rep_id()
      )
  ) x;

  RETURN v_result;
END;
$function$
