DROP TRIGGER IF EXISTS trg_sales_invoice_item_price ON public.sales_invoice_items;
CREATE TRIGGER trg_sales_invoice_item_price
BEFORE INSERT OR UPDATE OF
  product_id,
  unit_id,
  unit_price,
  sales_invoice_id,
  conversion_factor,
  package_option_id,
  package_weight_kg
ON public.sales_invoice_items
FOR EACH ROW
EXECUTE FUNCTION public.validate_sales_invoice_item_price();
