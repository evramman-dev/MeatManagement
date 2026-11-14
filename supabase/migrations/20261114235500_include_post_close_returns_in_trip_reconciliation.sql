DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  v_def := pg_get_functiondef('public.get_trip_stock_reconciliation(bigint)'::regprocedure);

  v_old := $old$  previously_received AS (
    SELECT sm.product_id,SUM(sm.quantity_change) AS qty
    FROM public.stock_movements sm
    WHERE sm.trip_id=p_trip_id
      AND sm.location_id=v_trip.source_location_id
      AND sm.movement_type='RECEIVE'
      AND sm.notes LIKE 'استلام فائض جولة %'
    GROUP BY sm.product_id
  ),$old$;

  v_new := $new$  previously_received AS (
    SELECT source_returns.product_id,SUM(source_returns.qty) AS qty
    FROM (
      SELECT sm.product_id,sm.quantity_change AS qty
      FROM public.stock_movements sm
      WHERE sm.trip_id=p_trip_id
        AND sm.location_id=v_trip.source_location_id
        AND sm.movement_type='RECEIVE'
        AND sm.notes LIKE 'استلام فائض جولة %'
      UNION ALL
      SELECT sri.product_id,sri.base_quantity AS qty
      FROM public.sales_return_items sri
      JOIN public.sales_returns sr ON sr.sales_return_id=sri.sales_return_id
      WHERE sr.trip_id=p_trip_id
        AND sr.status IN ('POSTED','APPROVED')
        AND sri.location_id=v_trip.source_location_id
    ) source_returns
    GROUP BY source_returns.product_id
  ),$new$;

  IF position(v_old IN v_def)=0 THEN
    RAISE EXCEPTION 'Previously received stock CTE was not found in get_trip_stock_reconciliation';
  END IF;

  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END;
$migration$;