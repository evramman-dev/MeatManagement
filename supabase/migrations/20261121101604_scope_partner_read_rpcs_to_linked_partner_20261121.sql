CREATE OR REPLACE FUNCTION public.get_partner_ledger(p_partner_id bigint)
RETURNS TABLE(
  transaction_id bigint,
  transaction_date date,
  transaction_type text,
  description text,
  amount numeric,
  signed_amount numeric,
  running_balance numeric,
  treasury_id bigint,
  reference_type text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $function$
SELECT
  pt.transaction_id,pt.transaction_date,pt.transaction_type,
  COALESCE(pt.notes,pt.transaction_type),pt.amount,
  CASE
    WHEN pt.transaction_type IN ('CAPITAL_IN','CAPITAL_OUT','PROFIT_ALLOCATION','PROFIT_PAYOUT_REVERSAL')
      THEN pt.amount ELSE -pt.amount END,
  COALESCE(p.opening_balance,0)+SUM(
    CASE
      WHEN pt.transaction_type IN ('CAPITAL_IN','CAPITAL_OUT','PROFIT_ALLOCATION','PROFIT_PAYOUT_REVERSAL')
        THEN pt.amount ELSE -pt.amount END
  ) OVER(ORDER BY pt.transaction_date,pt.transaction_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
  pt.treasury_id,
  CASE
    WHEN pt.transaction_type LIKE 'PROFIT_ALLOCATION%' THEN 'PARTNER_PROFIT_DISTRIBUTION'
    WHEN pt.transaction_type IN ('PROFIT_PAYOUT','PROFIT_PAYOUT_REVERSAL') THEN 'PARTNER_PROFIT_PAYOUT'
    ELSE 'PARTNER_MOVE'
  END
FROM public.partner_transactions pt
JOIN public.partners p ON p.partner_id=pt.partner_id
WHERE pt.partner_id=p_partner_id
  AND (
    (public.get_current_user_role()='PARTNER' AND p_partner_id=(SELECT private.current_partner_id()))
    OR (public.get_current_user_role()<>'PARTNER' AND public.has_permission('ACCOUNTING_VIEW'))
  )
ORDER BY pt.transaction_date,pt.transaction_id
$function$;

CREATE OR REPLACE FUNCTION public.get_partner_profit_distribution_items(p_distribution_id bigint)
RETURNS TABLE(
  distribution_item_id bigint,
  partner_id bigint,
  partner_name text,
  share_percentage numeric,
  allocated_amount numeric,
  paid_amount numeric,
  remaining_amount numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
  SELECT
    i.distribution_item_id,
    i.partner_id,
    p.partner_name,
    i.share_percentage,
    i.amount,
    COALESCE(SUM(CASE
      WHEN pt.transaction_type='PROFIT_PAYOUT' THEN pt.amount
      WHEN pt.transaction_type='PROFIT_PAYOUT_REVERSAL' THEN -pt.amount
      ELSE 0 END),0)::numeric,
    GREATEST(i.amount-COALESCE(SUM(CASE
      WHEN pt.transaction_type='PROFIT_PAYOUT' THEN pt.amount
      WHEN pt.transaction_type='PROFIT_PAYOUT_REVERSAL' THEN -pt.amount
      ELSE 0 END),0),0)::numeric
  FROM public.partner_profit_distribution_items i
  JOIN public.partners p ON p.partner_id=i.partner_id
  LEFT JOIN public.partner_transactions pt
    ON pt.profit_distribution_item_id=i.distribution_item_id
   AND pt.transaction_type IN ('PROFIT_PAYOUT','PROFIT_PAYOUT_REVERSAL')
  WHERE i.distribution_id=p_distribution_id
    AND (
      (public.get_current_user_role()='PARTNER' AND i.partner_id=(SELECT private.current_partner_id()))
      OR (
        public.get_current_user_role()<>'PARTNER'
        AND (
          public.has_permission('ACCOUNTING_VIEW')
          OR public.has_permission('ACCOUNTING_MANAGE')
          OR public.has_permission('PARTNERS_TRANSACTIONS_VIEW')
        )
      )
    )
  GROUP BY i.distribution_item_id,i.partner_id,p.partner_name,i.share_percentage,i.amount
  ORDER BY p.partner_name
$function$;
