ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS can_be_recipe_ingredient boolean NOT NULL DEFAULT false;

UPDATE public.products
SET can_be_recipe_ingredient = true,
    updated_at = now()
WHERE category_id = 18
  AND product_type = 'FINISHED'
  AND can_be_recipe_ingredient IS DISTINCT FROM true;

CREATE OR REPLACE FUNCTION public.guard_recipe_item_product_type()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_product_id bigint;
  v_product_type text;
  v_active boolean;
  v_allowed_as_ingredient boolean;
  v_output_product_id bigint;
  v_cycle_found boolean;
BEGIN
  IF NEW.raw_product_id IS NOT NULL
     AND NEW.ingredient_product_id IS NOT NULL
     AND NEW.raw_product_id <> NEW.ingredient_product_id THEN
    RAISE EXCEPTION 'يجب أن يتطابق الصنف في حقلي مكوّن الوصفة';
  END IF;

  v_product_id := COALESCE(NEW.raw_product_id, NEW.ingredient_product_id);

  SELECT p.product_type, p.is_active, p.can_be_recipe_ingredient
    INTO v_product_type, v_active, v_allowed_as_ingredient
  FROM public.products p
  WHERE p.product_id = v_product_id;

  IF NOT FOUND OR NOT COALESCE(v_active, false) THEN
    RAISE EXCEPTION 'مكوّن الوصفة غير موجود أو غير نشط';
  END IF;

  IF v_product_type NOT IN ('RAW', 'SEMI_FINISHED')
     AND NOT COALESCE(v_allowed_as_ingredient, false) THEN
    RAISE EXCEPTION 'هذا المنتج غير مسموح باستخدامه كمكوّن في التصنيع';
  END IF;

  SELECT r.product_id
    INTO v_output_product_id
  FROM public.recipes r
  WHERE r.recipe_id = NEW.recipe_id;

  IF v_output_product_id IS NULL THEN
    RAISE EXCEPTION 'المنتج الناتج للوصفة غير محدد';
  END IF;

  IF v_output_product_id = v_product_id THEN
    RAISE EXCEPTION 'لا يمكن استخدام المنتج الناتج كمكوّن في وصفته نفسها';
  END IF;

  WITH RECURSIVE ingredient_path(product_id, path, cycle_found) AS (
    SELECT v_product_id, ARRAY[v_product_id]::bigint[], false
    UNION ALL
    SELECT ri.ingredient_product_id,
           ip.path || ri.ingredient_product_id,
           ri.ingredient_product_id = v_output_product_id
    FROM ingredient_path ip
    JOIN public.recipes r ON r.product_id = ip.product_id AND r.is_active = true
    JOIN public.recipe_items ri ON ri.recipe_id = r.recipe_id
    WHERE NOT ip.cycle_found
      AND NOT ri.ingredient_product_id = ANY(ip.path)
  )
  SELECT COALESCE(bool_or(cycle_found OR product_id = v_output_product_id), false)
    INTO v_cycle_found
  FROM ingredient_path;

  IF v_cycle_found THEN
    RAISE EXCEPTION 'إضافة هذا المكوّن ستنشئ دورة تصنيع غير مسموح بها';
  END IF;

  RETURN NEW;
END;
$function$;

INSERT INTO public.product_unit_conversions
  (product_id, unit_id, base_quantity_per_unit, is_active)
SELECT p.product_id, 6, 20, true
FROM public.products p
WHERE p.category_id = 19
  AND p.product_type = 'RAW'
ON CONFLICT (product_id, unit_id)
DO UPDATE SET base_quantity_per_unit = EXCLUDED.base_quantity_per_unit,
              is_active = true,
              updated_at = now();

UPDATE public.products
SET purchase_unit_id = 6,
    sales_unit_id = 6,
    can_be_sold = true,
    updated_at = now()
WHERE category_id = 19
  AND product_type = 'RAW';

UPDATE public.product_unit_conversions
SET base_quantity_per_unit = 0.45,
    is_active = true,
    updated_at = now()
WHERE product_id = 44
  AND unit_id = 12;

UPDATE public.products
SET sales_unit_id = 12,
    can_be_sold = true,
    can_be_recipe_ingredient = true,
    updated_at = now()
WHERE product_id = 44;
