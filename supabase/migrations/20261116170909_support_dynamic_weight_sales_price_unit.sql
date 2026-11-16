-- Convert product selling price limits from the product sales unit to each invoice line unit.
CREATE OR REPLACE FUNCTION public.validate_sales_invoice_item_price()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_min numeric;
  v_target numeric;
  v_max numeric;
  v_sales_unit_id bigint;
  v_base_unit_id bigint;
  v_units_per_carton numeric;
  v_reference_factor numeric;
  v_price_factor numeric;
  v_option_count integer;
  v_option_factor numeric;
  v_is_package boolean;
  v_invoice_discount numeric;
  v_invoice_subtotal numeric;
  v_effective_price numeric;
  v_converted_min numeric;
  v_converted_max numeric;
BEGIN
  SELECT p.min_selling_price,p.target_selling_price,p.max_selling_price,
         p.sales_unit_id,p.base_unit_id,COALESCE(p.units_per_carton,0)
    INTO v_min,v_target,v_max,v_sales_unit_id,v_base_unit_id,v_units_per_carton
  FROM public.products p
  WHERE p.product_id=NEW.product_id AND p.is_active=true AND p.can_be_sold=true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الصنف غير موجود أو غير نشط أو غير مسموح ببيعه.';
  END IF;

  SELECT si.discount_amount,si.subtotal
    INTO v_invoice_discount,v_invoice_subtotal
  FROM public.sales_invoices si
  WHERE si.sales_invoice_id=NEW.sales_invoice_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'فاتورة البيع غير موجودة.'; END IF;
  IF v_min IS NULL AND v_target IS NULL AND v_max IS NULL THEN RETURN NEW; END IF;
  IF v_sales_unit_id IS NULL THEN
    RAISE EXCEPTION 'لا يمكن تطبيق حدود السعر: لم يتم تحديد وحدة البيع الأساسية للصنف.';
  END IF;

  IF v_sales_unit_id=v_base_unit_id THEN
    v_reference_factor:=1;
  ELSE
    SELECT puc.base_quantity_per_unit INTO v_reference_factor
    FROM public.product_unit_conversions puc
    WHERE puc.product_id=NEW.product_id AND puc.unit_id=v_sales_unit_id AND puc.is_active=true
    LIMIT 1;

    IF COALESCE(v_reference_factor,0)<=0 THEN
      SELECT count(*),min(po.weight_kg) INTO v_option_count,v_option_factor
      FROM public.product_packaging_options po
      WHERE po.product_id=NEW.product_id AND po.unit_id=v_sales_unit_id AND po.is_active=true;
      IF v_option_count=1 THEN
        v_reference_factor:=v_option_factor;
      ELSE
        SELECT u.is_package_unit INTO v_is_package
        FROM public.units u WHERE u.unit_id=v_sales_unit_id AND u.is_active=true;
        IF COALESCE(v_is_package,false) AND v_units_per_carton>0 THEN
          v_reference_factor:=v_units_per_carton;
        END IF;
      END IF;
    END IF;
  END IF;

  IF COALESCE(v_reference_factor,0)>0 AND COALESCE(NEW.conversion_factor,0)>0 THEN
    v_price_factor:=NEW.conversion_factor/v_reference_factor;
  ELSIF NEW.unit_id=v_sales_unit_id AND NEW.package_option_id IS NULL THEN
    v_price_factor:=1;
  ELSE
    RAISE EXCEPTION 'لا يمكن تحويل حدود السعر من وحدة البيع المسجلة إلى وحدة الفاتورة. راجع تحويلات وحدات الصنف وخيارات التعبئة.';
  END IF;

  IF v_price_factor<=0 THEN RAISE EXCEPTION 'معامل تحويل سعر الصنف غير صحيح.'; END IF;
  v_converted_min:=CASE WHEN v_min IS NULL THEN NULL ELSE v_min*v_price_factor END;
  v_converted_max:=CASE WHEN v_max IS NULL THEN NULL ELSE v_max*v_price_factor END;

  IF v_converted_min IS NOT NULL AND v_converted_max IS NOT NULL AND v_converted_min>v_converted_max THEN
    RAISE EXCEPTION 'حدود السعر بعد تحويل الوحدة غير صحيحة. راجع بيانات الصنف.';
  END IF;
  IF v_converted_max IS NOT NULL AND NEW.unit_price>v_converted_max THEN
    RAISE EXCEPTION 'سعر الصنف تجاوز الحد الأقصى بعد تحويل وحدة البيع (%).',round(v_converted_max,2);
  END IF;

  v_effective_price:=NEW.unit_price;
  IF COALESCE(v_invoice_subtotal,0)>0 AND COALESCE(v_invoice_discount,0)>0 THEN
    v_effective_price:=NEW.unit_price*(1-LEAST(v_invoice_discount/v_invoice_subtotal,1));
  END IF;
  IF v_converted_min IS NOT NULL AND v_effective_price<v_converted_min THEN
    RAISE EXCEPTION 'السعر النهائي بعد خصم الفاتورة أقل من الحد الأدنى بعد تحويل وحدة البيع (%).',round(v_converted_min,2);
  END IF;
  RETURN NEW;
END;
$function$;