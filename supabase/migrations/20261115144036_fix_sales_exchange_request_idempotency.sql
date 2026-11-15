CREATE OR REPLACE FUNCTION public.create_sales_return_exchange_v1(
  p_return_number character varying,
  p_customer_id bigint,
  p_trip_id bigint,
  p_sales_rep_id bigint,
  p_sales_invoice_id bigint,
  p_return_date timestamp with time zone,
  p_reason text,
  p_notes text,
  p_created_by uuid,
  p_cash_action character varying,
  p_treasury_id bigint,
  p_request_id uuid,
  p_return_items jsonb,
  p_exchange_items jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_existing public.sales_returns%ROWTYPE;
  v_return_id bigint;
  v_trip public.trips%ROWTYPE;
  v_invoice public.sales_invoices%ROWTYPE;
  v_vehicle bigint;
  v_item jsonb;
  v_item_row record;
  v_qty numeric;
  v_price numeric;
  v_discount numeric;
  v_factor numeric;
  v_base numeric;
  v_line numeric;
  v_total_return numeric:=0;
  v_total_exchange numeric:=0;
  v_seq int:=0;
  v_ex_seq int:=0;
  v_request_count integer;
  v_distinct_request_count integer;
BEGIN
  IF auth.uid() IS NULL OR NOT (public.has_permission('RETURNS_CREATE') OR public.has_permission('RETURNS_MANAGE')) THEN
    RAISE EXCEPTION 'لا تملك صلاحية إنشاء الاستبدال';
  END IF;
  IF p_created_by IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'منشئ الاستبدال يجب أن يطابق المستخدم الحالي';
  END IF;
  IF p_request_id IS NULL THEN
    RAISE EXCEPTION 'رقم طلب الاستبدال مطلوب';
  END IF;
  IF COALESCE(BTRIM(p_return_number),'')='' THEN
    RAISE EXCEPTION 'رقم الاستبدال مطلوب';
  END IF;
  IF jsonb_typeof(p_return_items) IS DISTINCT FROM 'array'
     OR jsonb_typeof(p_exchange_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_return_items)=0
     OR jsonb_array_length(p_exchange_items)=0 THEN
    RAISE EXCEPTION 'الاستبدال يحتاج أصناف مرتجعة وأصناف بديلة';
  END IF;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_return_items) AS x(item)
    WHERE NULLIF(x.item->>'request_id','') IS NULL
  ) OR EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_exchange_items) AS x(item)
    WHERE NULLIF(x.item->>'request_id','') IS NULL
  ) THEN
    RAISE EXCEPTION 'معرف مستقل مطلوب لكل بند في الاستبدال';
  END IF;

  SELECT COUNT(*) INTO v_request_count
  FROM (
    SELECT (x.item->>'request_id')::uuid AS request_id
    FROM jsonb_array_elements(p_return_items) AS x(item)
    UNION ALL
    SELECT (x.item->>'request_id')::uuid AS request_id
    FROM jsonb_array_elements(p_exchange_items) AS x(item)
  ) q;

  SELECT COUNT(DISTINCT request_id) INTO v_distinct_request_count
  FROM (
    SELECT (x.item->>'request_id')::uuid AS request_id
    FROM jsonb_array_elements(p_return_items) AS x(item)
    UNION ALL
    SELECT (x.item->>'request_id')::uuid AS request_id
    FROM jsonb_array_elements(p_exchange_items) AS x(item)
  ) q;

  IF v_request_count<>v_distinct_request_count THEN
    RAISE EXCEPTION 'معرفات بنود الاستبدال يجب أن تكون مختلفة';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));

  SELECT * INTO v_existing
  FROM public.sales_returns
  WHERE request_id=p_request_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.return_number IS DISTINCT FROM p_return_number
       OR v_existing.customer_id IS DISTINCT FROM p_customer_id
       OR v_existing.trip_id IS DISTINCT FROM p_trip_id
       OR (p_sales_rep_id IS NOT NULL AND v_existing.sales_rep_id IS DISTINCT FROM p_sales_rep_id)
       OR v_existing.sales_invoice_id IS DISTINCT FROM p_sales_invoice_id
       OR v_existing.return_type IS DISTINCT FROM 'EXCHANGE'
       OR v_existing.return_date IS DISTINCT FROM COALESCE(p_return_date,now())::date
       OR v_existing.reason IS DISTINCT FROM p_reason
       OR v_existing.notes IS DISTINCT FROM p_notes
       OR v_existing.cash_action IS DISTINCT FROM p_cash_action
       OR v_existing.treasury_id IS DISTINCT FROM p_treasury_id
       OR v_existing.created_by IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'رقم طلب الاستبدال مستخدم من قبل مع بيانات مختلفة';
    END IF;

    IF (SELECT COUNT(*) FROM public.sales_return_items WHERE sales_return_id=v_existing.sales_return_id)<>jsonb_array_length(p_return_items)
       OR (SELECT COUNT(*) FROM public.sales_return_exchange_items WHERE sales_return_id=v_existing.sales_return_id)<>jsonb_array_length(p_exchange_items) THEN
      RAISE EXCEPTION 'رقم طلب الاستبدال مستخدم من قبل مع بيانات مختلفة';
    END IF;

    FOR v_item_row IN
      SELECT item,ordinality
      FROM jsonb_array_elements(p_return_items) WITH ORDINALITY AS x(item,ordinality)
    LOOP
      IF NOT EXISTS (
        SELECT 1 FROM public.sales_return_items sri
        WHERE sri.sales_return_id=v_existing.sales_return_id
          AND sri.sequence_no=v_item_row.ordinality
          AND sri.request_id=(v_item_row.item->>'request_id')::uuid
          AND sri.product_id=(v_item_row.item->>'product_id')::bigint
          AND sri.unit_id=(v_item_row.item->>'unit_id')::bigint
          AND sri.quantity=(v_item_row.item->>'quantity')::numeric
          AND sri.unit_price=COALESCE((v_item_row.item->>'unit_price')::numeric,0)
          AND sri.discount_amount=COALESCE((v_item_row.item->>'discount_amount')::numeric,0)
          AND sri.conversion_factor=(v_item_row.item->>'conversion_factor')::numeric
          AND sri.package_option_id IS NOT DISTINCT FROM NULLIF(NULLIF(v_item_row.item->>'package_option_id','')::bigint,0)
          AND sri.package_weight_kg IS NOT DISTINCT FROM NULLIF(NULLIF(v_item_row.item->>'package_weight_kg','')::numeric,0)
          AND sri.lot_id IS NOT DISTINCT FROM NULLIF(NULLIF(v_item_row.item->>'lot_id','')::bigint,0)
          AND sri.notes IS NOT DISTINCT FROM (v_item_row.item->>'notes')
      ) THEN
        RAISE EXCEPTION 'رقم طلب الاستبدال مستخدم من قبل مع بيانات مختلفة';
      END IF;
    END LOOP;

    FOR v_item_row IN
      SELECT item,ordinality
      FROM jsonb_array_elements(p_exchange_items) WITH ORDINALITY AS x(item,ordinality)
    LOOP
      IF NOT EXISTS (
        SELECT 1 FROM public.sales_return_exchange_items sri
        WHERE sri.sales_return_id=v_existing.sales_return_id
          AND sri.sequence_no=v_item_row.ordinality
          AND sri.request_id=(v_item_row.item->>'request_id')::uuid
          AND sri.product_id=(v_item_row.item->>'product_id')::bigint
          AND sri.unit_id=(v_item_row.item->>'unit_id')::bigint
          AND sri.quantity=(v_item_row.item->>'quantity')::numeric
          AND sri.unit_price=COALESCE((v_item_row.item->>'unit_price')::numeric,0)
          AND sri.conversion_factor=(v_item_row.item->>'conversion_factor')::numeric
          AND sri.package_option_id IS NOT DISTINCT FROM NULLIF(NULLIF(v_item_row.item->>'package_option_id','')::bigint,0)
          AND sri.package_weight_kg IS NOT DISTINCT FROM NULLIF(NULLIF(v_item_row.item->>'package_weight_kg','')::numeric,0)
          AND sri.lot_id IS NOT DISTINCT FROM NULLIF(NULLIF(v_item_row.item->>'lot_id','')::bigint,0)
      ) THEN
        RAISE EXCEPTION 'رقم طلب الاستبدال مستخدم من قبل مع بيانات مختلفة';
      END IF;
    END LOOP;

    RETURN v_existing.sales_return_id;
  END IF;

  SELECT * INTO v_invoice
  FROM public.sales_invoices
  WHERE sales_invoice_id=p_sales_invoice_id
  FOR UPDATE;

  IF NOT FOUND
     OR v_invoice.status NOT IN ('POSTED','PAID','PARTIAL')
     OR v_invoice.customer_id IS DISTINCT FROM p_customer_id
     OR v_invoice.trip_id IS DISTINCT FROM p_trip_id THEN
    RAISE EXCEPTION 'الفاتورة الأصلية غير صالحة للاستبدال';
  END IF;

  SELECT * INTO v_trip
  FROM public.trips
  WHERE trip_id=p_trip_id
  FOR UPDATE;

  IF NOT FOUND OR v_trip.status NOT IN ('DRAFT','ACTIVE') THEN
    RAISE EXCEPTION 'لا يمكن تنفيذ الاستبدال بعد إغلاق الجولة';
  END IF;

  v_vehicle:=v_trip.vehicle_location_id;
  IF v_vehicle IS NULL OR NOT EXISTS(
    SELECT 1 FROM public.locations
    WHERE location_id=v_vehicle AND is_active AND location_type='VEHICLE'
  ) THEN
    RAISE EXCEPTION 'الجولة لا تحتوي على مخزن سيارة نشط';
  END IF;

  INSERT INTO public.sales_returns(
    return_number,customer_id,sales_invoice_id,trip_id,return_type,return_date,
    total_returned_value,total_exchange_value,price_difference,cash_action,treasury_id,
    notes,status,created_by,sales_rep_id,subtotal,discount_amount,net_total,reason,request_id
  )
  VALUES(
    p_return_number,p_customer_id,p_sales_invoice_id,p_trip_id,'EXCHANGE',
    COALESCE(p_return_date,now())::date,0,0,0,p_cash_action,p_treasury_id,
    p_notes,'DRAFT',auth.uid(),p_sales_rep_id,0,0,0,p_reason,p_request_id
  )
  RETURNING sales_return_id INTO v_return_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_return_items) LOOP
    v_seq:=v_seq+1;
    v_qty:=NULLIF((v_item->>'quantity')::numeric,0);
    v_price:=COALESCE((v_item->>'unit_price')::numeric,0);
    v_discount:=COALESCE((v_item->>'discount_amount')::numeric,0);
    v_factor:=NULLIF((v_item->>'conversion_factor')::numeric,0);
    IF v_qty IS NULL OR v_qty<=0 OR v_price<0 OR v_discount<0
       OR v_discount>v_qty*v_price OR v_factor IS NULL OR v_factor<=0 THEN
      RAISE EXCEPTION 'بيانات صنف المرتجع غير صحيحة';
    END IF;
    v_base:=ROUND(v_qty*v_factor,6);
    v_line:=ROUND(v_qty*v_price-v_discount,3);
    INSERT INTO public.sales_return_items(
      sales_return_id,product_id,unit_id,quantity,unit_price,line_total,location_id,
      sequence_no,base_quantity,conversion_factor,package_option_id,package_weight_kg,
      lot_id,discount_amount,notes,request_id
    )
    VALUES(
      v_return_id,(v_item->>'product_id')::bigint,(v_item->>'unit_id')::bigint,
      v_qty,v_price,v_line,v_vehicle,v_seq,v_base,v_factor,
      NULLIF(NULLIF(v_item->>'package_option_id','')::bigint,0),
      NULLIF(NULLIF(v_item->>'package_weight_kg','')::numeric,0),
      NULLIF(NULLIF(v_item->>'lot_id','')::bigint,0),
      v_discount,v_item->>'notes',(v_item->>'request_id')::uuid
    );
    v_total_return:=v_total_return+v_line;
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_exchange_items) LOOP
    v_ex_seq:=v_ex_seq+1;
    v_qty:=NULLIF((v_item->>'quantity')::numeric,0);
    v_price:=COALESCE((v_item->>'unit_price')::numeric,0);
    v_factor:=NULLIF((v_item->>'conversion_factor')::numeric,0);
    IF v_qty IS NULL OR v_qty<=0 OR v_price<0 OR v_factor IS NULL OR v_factor<=0 THEN
      RAISE EXCEPTION 'بيانات الصنف البديل غير صحيحة';
    END IF;
    v_base:=ROUND(v_qty*v_factor,6);
    v_line:=ROUND(v_qty*v_price,3);
    INSERT INTO public.sales_return_exchange_items(
      sales_return_id,product_id,unit_id,quantity,unit_price,line_total,location_id,
      sequence_no,base_quantity,conversion_factor,package_option_id,package_weight_kg,
      lot_id,request_id
    )
    VALUES(
      v_return_id,(v_item->>'product_id')::bigint,(v_item->>'unit_id')::bigint,
      v_qty,v_price,v_line,v_vehicle,v_ex_seq,v_base,v_factor,
      NULLIF(NULLIF(v_item->>'package_option_id','')::bigint,0),
      NULLIF(NULLIF(v_item->>'package_weight_kg','')::numeric,0),
      NULLIF(NULLIF(v_item->>'lot_id','')::bigint,0),
      (v_item->>'request_id')::uuid
    );
    v_total_exchange:=v_total_exchange+v_line;
  END LOOP;

  UPDATE public.sales_returns
  SET total_returned_value=ROUND(v_total_return,2),
      total_exchange_value=ROUND(v_total_exchange,2),
      price_difference=ROUND(v_total_exchange-v_total_return,2),
      subtotal=ROUND(v_total_return,2),
      net_total=ROUND(v_total_return,2),
      discount_amount=0
  WHERE sales_return_id=v_return_id;

  RETURN v_return_id;
END;
$function$;