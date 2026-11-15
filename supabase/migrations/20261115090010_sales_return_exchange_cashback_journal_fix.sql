-- Fix exchange cash-back accounting and validation
-- The production definitions are replaced here to keep cash-back journal entries balanced.
CREATE OR REPLACE FUNCTION public.validate_sales_return_exchange_v1(p_sales_return_id bigint)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog','public','pg_temp' AS $$
DECLARE r public.sales_returns%ROWTYPE; inv public.sales_invoices%ROWTYPE; tr public.trips%ROWTYPE; x record; sold numeric; returned numeric; v_return numeric; v_exchange numeric;
BEGIN
 IF auth.uid() IS NULL OR NOT (public.has_permission('RETURNS_APPROVE') OR public.has_permission('RETURNS_MANAGE')) THEN RAISE EXCEPTION 'لا تملك صلاحية اعتماد الاستبدال'; END IF;
 SELECT * INTO r FROM public.sales_returns WHERE sales_return_id=p_sales_return_id FOR UPDATE;
 IF NOT FOUND OR r.status<>'DRAFT' OR r.return_type<>'EXCHANGE' THEN RAISE EXCEPTION 'الاستبدال غير موجود أو ليس مسودة'; END IF;
 SELECT * INTO inv FROM public.sales_invoices WHERE sales_invoice_id=r.sales_invoice_id FOR UPDATE;
 IF NOT FOUND OR inv.status NOT IN ('POSTED','PAID','PARTIAL') OR inv.customer_id<>r.customer_id OR inv.trip_id<>r.trip_id THEN RAISE EXCEPTION 'الفاتورة الأصلية غير صالحة للاستبدال'; END IF;
 SELECT * INTO tr FROM public.trips WHERE trip_id=r.trip_id FOR UPDATE;
 IF NOT FOUND OR tr.status NOT IN ('DRAFT','ACTIVE') THEN RAISE EXCEPTION 'لا يمكن اعتماد استبدال لجولة مغلقة'; END IF;
 IF tr.vehicle_location_id IS NULL THEN RAISE EXCEPTION 'الجولة لا تحتوي على موقع سيارة'; END IF;
 SELECT COALESCE(SUM(line_total),0) INTO v_return FROM public.sales_return_items WHERE sales_return_id=r.sales_return_id;
 SELECT COALESCE(SUM(line_total),0) INTO v_exchange FROM public.sales_return_exchange_items WHERE sales_return_id=r.sales_return_id;
 IF ABS(v_return-r.total_returned_value)>0.01 OR ABS(v_exchange-r.total_exchange_value)>0.01 THEN RAISE EXCEPTION 'إجماليات الاستبدال لا تطابق الأصناف'; END IF;
 IF ABS((v_exchange-v_return)-r.price_difference)>0.01 THEN RAISE EXCEPTION 'فرق سعر الاستبدال غير صحيح'; END IF;
 IF EXISTS(SELECT 1 FROM public.sales_return_items WHERE sales_return_id=r.sales_return_id AND (quantity<=0 OR base_quantity IS NULL OR base_quantity<=0 OR conversion_factor IS NULL OR conversion_factor<=0 OR location_id<>tr.vehicle_location_id))
 OR EXISTS(SELECT 1 FROM public.sales_return_exchange_items WHERE sales_return_id=r.sales_return_id AND (quantity<=0 OR base_quantity IS NULL OR base_quantity<=0 OR conversion_factor IS NULL OR conversion_factor<=0 OR location_id<>tr.vehicle_location_id)) THEN RAISE EXCEPTION 'يوجد بند استبدال بكمية أو تحويل أو موقع غير صحيح'; END IF;
 FOR x IN SELECT product_id,lot_id,package_option_id,SUM(base_quantity) qty FROM public.sales_return_items WHERE sales_return_id=r.sales_return_id GROUP BY product_id,lot_id,package_option_id LOOP
   SELECT COALESCE(SUM(sii.base_quantity),0) INTO sold FROM public.sales_invoice_items sii WHERE sii.sales_invoice_id=r.sales_invoice_id AND sii.product_id=x.product_id AND sii.lot_id IS NOT DISTINCT FROM x.lot_id AND sii.package_option_id IS NOT DISTINCT FROM x.package_option_id;
   SELECT COALESCE(SUM(sri.base_quantity),0) INTO returned FROM public.sales_return_items sri JOIN public.sales_returns sr ON sr.sales_return_id=sri.sales_return_id WHERE sr.sales_invoice_id=r.sales_invoice_id AND sr.status IN ('POSTED','APPROVED') AND sr.sales_return_id<>r.sales_return_id AND sri.product_id=x.product_id AND sri.lot_id IS NOT DISTINCT FROM x.lot_id AND sri.package_option_id IS NOT DISTINCT FROM x.package_option_id;
   IF x.qty+returned>sold THEN RAISE EXCEPTION 'الكمية المرتجعة تتجاوز المباعة للصنف %',x.product_id; END IF;
 END LOOP;
 IF r.cash_action='CASH_BACK' AND COALESCE(inv.remaining_amount,0)>0.01 THEN RAISE EXCEPTION 'لا يمكن رد النقدية مع وجود مديونية على الفاتورة'; END IF;
 IF r.cash_action='DEDUCT_DEBT' AND COALESCE(inv.remaining_amount,0)+r.price_difference< -0.01 THEN RAISE EXCEPTION 'فرق الاستبدال أكبر من المديونية المتاحة'; END IF;
 IF r.cash_action IN ('CASH_BACK','CUSTOMER_PAYS_CASH') AND (r.treasury_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.treasuries WHERE treasury_id=r.treasury_id AND is_active AND treasury_type IN ('CASH','BANK','INSTAPAY'))) THEN RAISE EXCEPTION 'خزنة التسوية غير صالحة'; END IF;
 IF r.cash_action='CUSTOMER_PAYS_CASH' AND r.price_difference<=0 THEN RAISE EXCEPTION 'التحصيل النقدي يتطلب فرق سعر موجبًا'; END IF;
 IF r.cash_action='CASH_BACK' AND r.price_difference>=0 THEN RAISE EXCEPTION 'رد النقدية يتطلب فرق سعر سالبًا'; END IF;
 RETURN TRUE;
END;
$$;
CREATE OR REPLACE FUNCTION public.post_sales_return_exchange_v1(p_sales_return_id bigint,p_created_by uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog','public','pg_temp' AS $$
DECLARE r public.sales_returns%ROWTYPE; x record; v_new_stock numeric; v_remaining numeric; v_cash_account text; v_credit_after numeric; v_journal jsonb:='[]'::jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT (public.has_permission('RETURNS_APPROVE') OR public.has_permission('RETURNS_MANAGE')) THEN RAISE EXCEPTION 'لا تملك صلاحية ترحيل الاستبدال'; END IF;
 IF p_created_by IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'منفذ الترحيل يجب أن يطابق المستخدم الحالي'; END IF;
 PERFORM pg_advisory_xact_lock(947351);
 SELECT * INTO r FROM public.sales_returns WHERE sales_return_id=p_sales_return_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'الاستبدال غير موجود'; END IF;
 IF r.status='POSTED' THEN RETURN; END IF;
 PERFORM public.validate_sales_return_exchange_v1(p_sales_return_id);
 FOR x IN SELECT location_id,product_id,SUM(base_quantity) qty FROM public.sales_return_items WHERE sales_return_id=r.sales_return_id GROUP BY location_id,product_id ORDER BY location_id,product_id LOOP
   INSERT INTO public.stock_balances(location_id,product_id,quantity,updated_at) VALUES(x.location_id,x.product_id,0,now()) ON CONFLICT(location_id,product_id) DO NOTHING;
   UPDATE public.stock_balances SET quantity=quantity+x.qty,updated_at=now() WHERE location_id=x.location_id AND product_id=x.product_id RETURNING quantity INTO v_new_stock;
   INSERT INTO public.stock_movements(location_id,product_id,movement_type,quantity_change,quantity_after,notes,created_by,trip_id,sales_return_id) VALUES(x.location_id,x.product_id,'RETURN',x.qty,v_new_stock,'استلام مرتجع ضمن استبدال '||r.return_number,auth.uid(),r.trip_id,r.sales_return_id);
 END LOOP;
 FOR x IN SELECT location_id,product_id,SUM(base_quantity) qty FROM public.sales_return_exchange_items WHERE sales_return_id=r.sales_return_id GROUP BY location_id,product_id ORDER BY location_id,product_id LOOP
   SELECT quantity INTO v_remaining FROM public.stock_balances WHERE location_id=x.location_id AND product_id=x.product_id FOR UPDATE;
   IF NOT FOUND OR v_remaining<x.qty THEN RAISE EXCEPTION 'رصيد السيارة لا يكفي للصنف البديل %',x.product_id; END IF;
   UPDATE public.stock_balances SET quantity=quantity-x.qty,updated_at=now() WHERE location_id=x.location_id AND product_id=x.product_id;
   INSERT INTO public.stock_movements(location_id,product_id,movement_type,quantity_change,quantity_after,notes,created_by,trip_id,sales_return_id) VALUES(x.location_id,x.product_id,'ISSUE',-x.qty,v_remaining-x.qty,'صرف صنف بديل ضمن استبدال '||r.return_number,auth.uid(),r.trip_id,r.sales_return_id);
 END LOOP;
 IF r.cash_action IN ('DEDUCT_DEBT','CUSTOMER_PAYS_CREDIT') THEN
   UPDATE public.sales_invoices SET remaining_amount=GREATEST(remaining_amount+r.price_difference,0),status=CASE WHEN GREATEST(remaining_amount+r.price_difference,0)<=0.01 THEN 'PAID' WHEN COALESCE(paid_amount,0)>0 THEN 'PARTIAL' ELSE 'POSTED' END,updated_at=now() WHERE sales_invoice_id=r.sales_invoice_id;
 ELSIF r.cash_action='CUSTOMER_PAYS_CASH' THEN
   IF r.price_difference<=0 OR r.treasury_id IS NULL THEN RAISE EXCEPTION 'خزنة التحصيل أو فرق السعر غير صالح'; END IF;
   UPDATE public.treasuries SET current_balance=current_balance+r.price_difference WHERE treasury_id=r.treasury_id AND is_active AND treasury_type IN ('CASH','BANK','INSTAPAY');
   IF NOT FOUND THEN RAISE EXCEPTION 'خزنة التحصيل غير صالحة'; END IF;
   INSERT INTO public.treasury_transactions(treasury_id,transaction_type,amount,reference_type,reference_id,notes,transaction_date,created_by) VALUES(r.treasury_id,'DEPOSIT',r.price_difference,'SALES_RETURN',r.sales_return_id,'تحصيل فرق استبدال '||r.return_number,r.return_date,auth.uid());
 ELSIF r.cash_action='CASH_BACK' THEN
   IF r.price_difference>=0 OR r.treasury_id IS NULL THEN RAISE EXCEPTION 'خزنة رد النقدية أو فرق السعر غير صالح'; END IF;
   UPDATE public.treasuries SET current_balance=current_balance-ABS(r.price_difference) WHERE treasury_id=r.treasury_id AND is_active AND current_balance>=ABS(r.price_difference);
   IF NOT FOUND THEN RAISE EXCEPTION 'رصيد الخزنة لا يكفي لرد فرق الاستبدال'; END IF;
   INSERT INTO public.treasury_transactions(treasury_id,transaction_type,amount,reference_type,reference_id,notes,transaction_date,created_by) VALUES(r.treasury_id,'WITHDRAW',ABS(r.price_difference),'SALES_RETURN',r.sales_return_id,'رد فرق استبدال '||r.return_number,r.return_date,auth.uid());
 ELSIF r.cash_action='CREDIT_BALANCE' THEN
   IF r.price_difference>=0 THEN RAISE EXCEPTION 'الرصيد الدائن يستخدم فقط عندما يكون فرق السعر سالبًا'; END IF;
   INSERT INTO public.customer_credit_balances(customer_id,balance,updated_at) VALUES(r.customer_id,ABS(r.price_difference),now()) ON CONFLICT(customer_id) DO UPDATE SET balance=public.customer_credit_balances.balance+EXCLUDED.balance,updated_at=now() RETURNING balance INTO v_credit_after;
   INSERT INTO public.customer_credit_transactions(customer_id,sales_return_id,direction,amount,balance_after,notes,created_by) VALUES(r.customer_id,r.sales_return_id,'CREDIT',ABS(r.price_difference),v_credit_after,'رصيد دائن من استبدال '||r.return_number,auth.uid());
 END IF;
 v_journal:=jsonb_build_array(jsonb_build_object('account','4200','debit',r.total_returned_value,'credit',0),jsonb_build_object('account','1200','debit',0,'credit',r.total_returned_value),jsonb_build_object('account','1200','debit',r.total_exchange_value,'credit',0),jsonb_build_object('account','4100','debit',0,'credit',r.total_exchange_value));
 IF r.price_difference>0 AND r.cash_action='CUSTOMER_PAYS_CASH' THEN
   SELECT coa.account_code INTO v_cash_account FROM public.treasuries t JOIN public.chart_of_accounts coa ON coa.account_id=t.account_id WHERE t.treasury_id=r.treasury_id;
   IF v_cash_account IS NULL THEN RAISE EXCEPTION 'حساب الخزنة غير موجود'; END IF;
   v_journal:=v_journal||jsonb_build_array(jsonb_build_object('account',v_cash_account,'debit',r.price_difference,'credit',0),jsonb_build_object('account','1200','debit',0,'credit',r.price_difference));
 ELSIF r.price_difference<0 AND r.cash_action='CASH_BACK' THEN
   SELECT coa.account_code INTO v_cash_account FROM public.treasuries t JOIN public.chart_of_accounts coa ON coa.account_id=t.account_id WHERE t.treasury_id=r.treasury_id;
   IF v_cash_account IS NULL THEN RAISE EXCEPTION 'حساب خزنة رد النقدية غير موجود'; END IF;
   v_journal:=v_journal||jsonb_build_array(jsonb_build_object('account','1200','debit',ABS(r.price_difference),'credit',0),jsonb_build_object('account',v_cash_account,'debit',0,'credit',ABS(r.price_difference)));
 END IF;
 PERFORM public.post_journal_entry(r.return_date,'استبدال بيع '||r.return_number,'SALES_RETURN',r.sales_return_id,v_journal);
 UPDATE public.sales_returns SET status='POSTED',approved_at=now(),approved_by=auth.uid() WHERE sales_return_id=r.sales_return_id;
END;
$$;
CREATE OR REPLACE FUNCTION public.cancel_sales_return_exchange_v1(p_sales_return_id bigint,p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog','public','pg_temp' AS $$
DECLARE r public.sales_returns%ROWTYPE; inv public.sales_invoices%ROWTYPE; m record; v_balance numeric; v_credit numeric; v_cash numeric; v_cash_account text; v_journal jsonb:='[]'::jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.has_permission('RETURNS_MANAGE') THEN RAISE EXCEPTION 'لا تملك صلاحية إلغاء الاستبدال'; END IF;
 IF COALESCE(trim(p_reason),'')='' THEN RAISE EXCEPTION 'اكتب سبب الإلغاء'; END IF;
 SELECT * INTO r FROM public.sales_returns WHERE sales_return_id=p_sales_return_id FOR UPDATE;
 IF NOT FOUND OR r.return_type<>'EXCHANGE' THEN RAISE EXCEPTION 'الاستبدال غير موجود'; END IF;
 IF r.status='CANCELLED' THEN RAISE EXCEPTION 'الاستبدال ملغى بالفعل'; END IF;
 IF r.status NOT IN ('POSTED','APPROVED') THEN RAISE EXCEPTION 'لا يمكن إلغاء استبدال غير مرحل'; END IF;
 PERFORM public.assert_accounting_period_open(CURRENT_DATE);
 IF r.sales_invoice_id IS NOT NULL THEN SELECT * INTO inv FROM public.sales_invoices WHERE sales_invoice_id=r.sales_invoice_id FOR UPDATE; END IF;
 FOR m IN SELECT * FROM public.stock_movements WHERE sales_return_id=r.sales_return_id AND reversal_of_movement_id IS NULL ORDER BY movement_id LOOP
   SELECT quantity INTO v_balance FROM public.stock_balances WHERE location_id=m.location_id AND product_id=m.product_id FOR UPDATE;
   IF m.quantity_change>0 THEN
     IF COALESCE(v_balance,0)<m.quantity_change THEN RAISE EXCEPTION 'رصيد المخزون لا يكفي لعكس حركة الاستبدال'; END IF;
     UPDATE public.stock_balances SET quantity=quantity-m.quantity_change,updated_at=now() WHERE location_id=m.location_id AND product_id=m.product_id;
   ELSE
     INSERT INTO public.stock_balances(location_id,product_id,quantity,updated_at) VALUES(m.location_id,m.product_id,0,now()) ON CONFLICT(location_id,product_id) DO NOTHING;
     UPDATE public.stock_balances SET quantity=quantity+ABS(m.quantity_change),updated_at=now() WHERE location_id=m.location_id AND product_id=m.product_id;
   END IF;
   INSERT INTO public.stock_movements(location_id,product_id,movement_type,quantity_change,quantity_after,notes,created_by,trip_id,reversal_of_movement_id,sales_return_id)
   SELECT m.location_id,m.product_id,CASE WHEN m.quantity_change>0 THEN 'ISSUE' ELSE 'RETURN' END,-m.quantity_change,CASE WHEN m.quantity_change>0 THEN v_balance-m.quantity_change ELSE COALESCE(v_balance,0)+ABS(m.quantity_change) END,'عكس حركة استبدال '||r.return_number||': '||trim(p_reason),auth.uid(),m.trip_id,m.movement_id,r.sales_return_id;
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
 v_journal:=jsonb_build_array(jsonb_build_object('account','1200','debit',r.total_returned_value,'credit',0),jsonb_build_object('account','4200','debit',0,'credit',r.total_returned_value),jsonb_build_object('account','4100','debit',0,'credit',r.total_exchange_value),jsonb_build_object('account','1200','debit',r.total_exchange_value,'credit',0));
 IF r.price_difference>0 AND r.cash_action='CUSTOMER_PAYS_CASH' THEN
   SELECT coa.account_code INTO v_cash_account FROM public.treasuries t JOIN public.chart_of_accounts coa ON coa.account_id=t.account_id WHERE t.treasury_id=r.treasury_id;
   v_journal:=v_journal||jsonb_build_array(jsonb_build_object('account','1200','debit',r.price_difference,'credit',0),jsonb_build_object('account',v_cash_account,'debit',0,'credit',r.price_difference));
 ELSIF r.price_difference<0 AND r.cash_action='CASH_BACK' THEN
   SELECT coa.account_code INTO v_cash_account FROM public.treasuries t JOIN public.chart_of_accounts coa ON coa.account_id=t.account_id WHERE t.treasury_id=r.treasury_id;
   v_journal:=v_journal||jsonb_build_array(jsonb_build_object('account',v_cash_account,'debit',ABS(r.price_difference),'credit',0),jsonb_build_object('account','1200','debit',0,'credit',ABS(r.price_difference)));
 END IF;
 PERFORM public.post_journal_entry(CURRENT_DATE,'عكس استبدال بيع '||r.return_number,'SALES_RETURN_CANCEL',r.sales_return_id,v_journal);
 UPDATE public.sales_returns SET status='CANCELLED',cancellation_reason=trim(p_reason),cancelled_by=auth.uid(),cancelled_at=now() WHERE sales_return_id=r.sales_return_id;
END;
$$;