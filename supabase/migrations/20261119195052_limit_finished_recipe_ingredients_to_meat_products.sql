UPDATE public.products
SET can_be_recipe_ingredient = (product_id IN (44,45,46,47,48,49,50,51,62,63,64)),
    updated_at = now()
WHERE category_id = 18
  AND product_type = 'FINISHED';
