CREATE OR REPLACE FUNCTION public.cancel_sales_return_exchange_v1(p_sales_return_id bigint, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE r public.sales_returns%ROWTYPE; inv public.sales_invoices%ROWTYPE; m record; v_balance numeric; v_credit numeric; v_cash numeric; v_cash_account text; v_journal jsonb:='[]'::jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.has_permission('RETURNS_MANAGE') THEN RAISE EXCEPTION 'لا تملك صلاحية إلغاء الاستبدال'; END IF;
 IF COALESCE(trim(p_reason),'')='' THEN RAISE EXCEPTION 'اكتب سبب الإلغاء'; END IF;
 PERFORM pg_advisory_xact_lock(947351);
 SELECT * INTO r FROM public.sales_returns WHERE sales_return_id=p_sales_return_id FOR UPDATE;
 IF NOT FOUND OR r.return_type<>'EXCHANGE' THEN RAISE EXCEPTION 'الاستبدال غير موجود'; END IF;
 IF r.status='CANCELLED' THEN RAISE EXCEPTION 'الاستبدال ملغى بالفعل'; END IF;
 IF r.status NOT IN ('POSTED','APPROVED') THEN RAISE EXCEPTION 'لا يمكن إلغاء استبدال غير مرحل'; END IF;
 PERFORM public.assert_accounting_period_open(CURRENT_DATE);
 IF r.sales_invoice_id IS NOT NULL THEN SELECT * INTO inv FROM public.sales_invoices WHERE sales_invoice_id=r.sales_invoice_id FOR UPDATE; END IF;
 FOR m IN SELECT * FROM public.stock_movements WHERE sales_return_id=r.sales_return_id AND reversal_of_movement_id IS NULL ORDER BY movement_id DESC LOOP
   SELECT quantity INTO v_balance FROM public.stock_balances WHERE location_id=m.location_id AND product_id=m.product_id FOR UPDATE;
   IF m.quantity_change>0 THEN
     IF COALESCE(v_balance,0)<m.quantity_change THEN RAISE EXCEPTION 'رصيد المخزون لا يكفي لعكس حركة الاستبدال'; END IF;
     UPDATE public.stock_balances SET quantity=quantity-m.quantity_change,updated_at=now() WHERE location_id=m.location_id AND product_id=m.product_id;
   ELSE
     INSERT INTO public.stock_balances(location_id,product_id,quantity,updated_at) VALUES(m.location_id,m.product_id,0,now()) ON CONFLICT(location_id,product_id) DO NOTHING;
     UPDATE public.stock_balances SET quantity=quantity+ABS(m.quantity_change),updated_at=now() WHERE location_id=m.location_id AND product_id=m.product_id;
   END IF;
   INSERT INTO public.stock_movements(location_id,product_id,movement_type,quantity_change,quantity_after,notes,created_by,trip_id,reversal_of_movement_id,sales_return_id,unit_cost,total_cost)
   SELECT m.location_id,m.product_id,CASE WHEN m.quantity_change>0 THEN 'ISSUE' ELSE 'RETURN' END,-m.quantity_change,CASE WHEN m.quantity_change>0 THEN v_balance-m.quantity_change ELSE COALESCE(v_balance,0)+ABS(m.quantity_change) END,
          CASE WHEN m.quantity_change>0 THEN 'استبدال '||r.return_number||': '||trim(p_reason) ELSE 'عكس بضاعة الاستبدال للمرتجع '||r.return_number||': '||trim(p_reason) END,
          auth.uid(),m.trip_id,m.movement_id,r.sales_return_id,m.unit_cost,m.total_cost;
 END LOOP;
 IF r.cash_action='CUSTOMER_PAYS_CASH' THEN
   v_cash:=ABS(r.price_difference);UPDATE public.treasuries SET current_balance=current_balance-v_cash WHERE treasury_id=r.treasury_id AND current_balance>=v_cash AND is_active;
   IF NOT FOUND THEN RAISE EXCEPTION 'رصيد الخزنة لا يكفي لعكس تحصيل فرق الاستبدال'; END IF;
   INSERT INTO public.treasury_transactions(treasury_id,transaction_type,amount,reference_type,reference_id,notes,transaction_date,created_by) VALUES(r.treasury_id,'WITHDRAW',v_cash,'SALES_RETURN_CANCEL',r.sales_return_id,'عكس تحصيل فرق الاستبدال: '||trim(p_reason),CURRENT_DATE,auth.uid());
 ELSIF r.cash_action='CASH_BACK' THEN
   v_cash:=ABS(r.price_difference);UPDATE public.treasuries SET current_balance=current_balance+v_cash WHERE treasury_id=r.treasury_id AND is_active;
   IF NOT FOUND THEN RAISE EXCEPTION 'خزنة الاستبدال غير موجودة'; END IF;
   INSERT INTO public.treasury_transactions(treasury_id,transaction_type,amount,reference_type,reference_id,notes,transaction_date,created_by) VALUES(r.treasury_id,'DEPOSIT',v_cash,'SALES_RETURN_CANCEL',r.sales_return_id,'عكس رد فرق الاستبدال: '||trim(p_reason),CURRENT_DATE,auth.uid());
 ELSIF r.cash_action IN ('DEDUCT_DEBT','CUSTOMER_PAYS_CREDIT') AND inv.sales_invoice_id IS NOT NULL THEN
   UPDATE public.sales_invoices SET remaining_amount=GREATEST(remaining_amount-r.price_difference,0),status=CASE WHEN GREATEST(remaining_amount-r.price_difference,0)<=0.01 THEN 'PAID' WHEN COALESCE(paid_amount,0)>0 THEN 'PARTIAL' ELSE 'POSTED' END,updated_at=now() WHERE sales_invoice_id=inv.sales_invoice_id;
 ELSIF r.cash_action='CREDIT_BALANCE' THEN
   SELECT balance INTO v_credit FROM public.customer_credit_balances WHERE customer_id=r.customer_id FOR UPDATE;
   IF COALESCE(v_credit,0)<ABS(r.price_difference) THEN RAISE EXCEPTION 'الرصيد الدائن الحالي لا يكفي لعكس الاستبدال'; END IF;
   UPDATE public.customer_credit_balances SET balance=balance-ABS(r.price_difference),updated_at=now() WHERE customer_id=r.customer_id;
   INSERT INTO public.customer_credit_transactions(customer_id,sales_return_id,direction,amount,balance_after,notes,created_by) VALUES(r.customer_id,r.sales_return_id,'DEBIT',ABS(r.price_difference),(v_credit-ABS(r.price_difference)),'عكس رصيد دائن للاستبدال: '||trim(p_reason),auth.uid());
 END IF;
 v_journal:=jsonb_build_array(jsonb_build_object('account','1200','debit',r.total_returned_value,'credit',0),jsonb_build_object('account','4200','debit',0,'credit',r.total_returned_value),jsonb_build_object('account','4100','debit',r.total_exchange_value,'credit',0),jsonb_build_object('account','1200','debit',0,'credit',r.total_exchange_value));
 IF r.price_difference>0 AND r.cash_action='CUSTOMER_PAYS_CASH' THEN
   SELECT coa.account_code INTO v_cash_account FROM public.treasuries t JOIN public.chart_of_accounts coa ON coa.account_id=t.account_id WHERE t.treasury_id=r.treasury_id;
   v_journal:=v_journal||jsonb_build_array(jsonb_build_object('account','1200','debit',r.price_difference,'credit',0),jsonb_build_object('account',v_cash_account,'debit',0,'credit',r.price_difference));
 ELSIF r.price_difference<0 AND r.cash_action='CASH_BACK' THEN
   SELECT coa.account_code INTO v_cash_account FROM public.treasuries t JOIN public.chart_of_accounts coa ON coa.account_id=t.account_id WHERE t.treasury_id=r.treasury_id;
   v_journal:=v_journal||jsonb_build_array(jsonb_build_object('account',v_cash_account,'debit',ABS(r.price_difference),'credit',0),jsonb_build_object('account','1200','debit',0,'credit',ABS(r.price_difference)));
 ELSIF r.price_difference<0 AND r.cash_action='CREDIT_BALANCE' THEN
   v_journal:=v_journal||jsonb_build_array(jsonb_build_object('account','2200','debit',ABS(r.price_difference),'credit',0),jsonb_build_object('account','1200','debit',0,'credit',ABS(r.price_difference)));
 END IF;
 PERFORM public.post_journal_entry(CURRENT_DATE,'عكس استبدال بيع '||r.return_number,'SALES_RETURN_CANCEL',r.sales_return_id,v_journal);
 UPDATE public.sales_returns SET status='CANCELLED',cancellation_reason=trim(p_reason),cancelled_by=auth.uid(),cancelled_at=now() WHERE sales_return_id=r.sales_return_id;
END;
$function$
;