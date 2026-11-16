-- Use product-level selling prices and remove the required approved customer price list.
CREATE OR REPLACE FUNCTION public.set_sales_invoice_price_list()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_terms integer;
BEGIN
  SELECT c.payment_terms_days INTO v_terms
  FROM public.customers c
  WHERE c.customer_id=NEW.customer_id AND c.is_active=true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'العميل غير موجود أو غير نشط.';
  END IF;

  NEW.price_list_id := NULL;
  NEW.payment_terms_days := COALESCE(v_terms,0);
  NEW.due_date := NEW.invoice_date::date + COALESCE(v_terms,0);
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.validate_sales_invoice_header_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_item_count integer;
  v_terms integer;
BEGIN
  IF NEW.customer_id IS NOT DISTINCT FROM OLD.customer_id
     AND NEW.invoice_date IS NOT DISTINCT FROM OLD.invoice_date
     AND NEW.price_list_id IS NOT DISTINCT FROM OLD.price_list_id THEN
    RETURN NEW;
  END IF;

  SELECT count(*) INTO v_item_count
  FROM public.sales_invoice_items
  WHERE sales_invoice_id=NEW.sales_invoice_id;

  IF v_item_count>0 THEN
    RAISE EXCEPTION 'لا يمكن تغيير العميل أو تاريخ الفاتورة بعد إضافة بنود الفاتورة.';
  END IF;

  SELECT c.payment_terms_days INTO v_terms
  FROM public.customers c
  WHERE c.customer_id=NEW.customer_id AND c.is_active=true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'العميل غير موجود أو غير نشط.';
  END IF;

  NEW.price_list_id := NULL;
  NEW.payment_terms_days := COALESCE(v_terms,0);
  NEW.due_date := NEW.invoice_date::date + COALESCE(v_terms,0);
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.validate_sales_invoice_item_price()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_min numeric;
  v_target numeric;
  v_max numeric;
  v_invoice_discount numeric;
  v_invoice_subtotal numeric;
  v_effective_price numeric;
BEGIN
  SELECT p.min_selling_price,p.target_selling_price,p.max_selling_price
    INTO v_min,v_target,v_max
  FROM public.products p
  WHERE p.product_id=NEW.product_id
    AND p.is_active=true
    AND p.can_be_sold=true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الصنف غير موجود أو غير نشط أو غير مسموح ببيعه.';
  END IF;

  SELECT si.discount_amount,si.subtotal
    INTO v_invoice_discount,v_invoice_subtotal
  FROM public.sales_invoices si
  WHERE si.sales_invoice_id=NEW.sales_invoice_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'فاتورة البيع غير موجودة.';
  END IF;

  IF v_max IS NOT NULL AND NEW.unit_price > v_max THEN
    RAISE EXCEPTION 'سعر الصنف تجاوز الحد الأقصى المسجل في بيانات الصنف: %',v_max;
  END IF;

  v_effective_price := NEW.unit_price;
  IF COALESCE(v_invoice_subtotal,0)>0 AND COALESCE(v_invoice_discount,0)>0 THEN
    v_effective_price := NEW.unit_price *
      (1 - LEAST(v_invoice_discount/v_invoice_subtotal,1));
  END IF;

  IF v_min IS NOT NULL AND v_effective_price < v_min THEN
    RAISE EXCEPTION
      'السعر النهائي بعد خصم الفاتورة أقل من الحد الأدنى للصنف (%). خفّض الخصم أو ارفع سعر البيع.',
      v_min;
  END IF;

  RETURN NEW;
END;
$function$;