CREATE OR REPLACE FUNCTION public.guard_raw_meat_carton_sales()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_product_type text;
  v_category_id bigint;
BEGIN
  SELECT p.product_type, p.category_id
    INTO v_product_type, v_category_id
  FROM public.products p
  WHERE p.product_id = NEW.product_id;

  IF v_product_type = 'RAW' AND v_category_id = 19 THEN
    IF NEW.unit_id <> 6 THEN
      RAISE EXCEPTION 'البيع المباشر للحوم الخام يكون بالكرتونة فقط، وسعة الكرتونة 20 كجم';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM public.product_unit_conversions c
      WHERE c.product_id = NEW.product_id
        AND c.unit_id = 6
        AND c.is_active = true
        AND c.base_quantity_per_unit = 20
    ) THEN
      RAISE EXCEPTION 'تحويل الكرتونة لهذا الصنف غير مضبوط على 20 كجم';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_raw_meat_carton_sales ON public.sales_invoice_items;
CREATE TRIGGER trg_guard_raw_meat_carton_sales
BEFORE INSERT OR UPDATE OF product_id, unit_id
ON public.sales_invoice_items
FOR EACH ROW
EXECUTE FUNCTION public.guard_raw_meat_carton_sales();
