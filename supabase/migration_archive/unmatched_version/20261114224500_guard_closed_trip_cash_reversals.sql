-- Protect completed trip cash settlements from later cash reversals.
-- These operations share treasury 8, so they must serialize with settle_trip.
DO $migration$
DECLARE
  v_def text;
  v_old text;
  v_new text;
BEGIN
  v_def := pg_get_functiondef('public.cancel_collection_v2(bigint,text)'::regprocedure);
  v_old := '  v_treasury_balance numeric;' || chr(10);
  v_new := v_old || '  v_trip_status text;' || chr(10);
  IF strpos(v_def,v_old)=0 THEN RAISE EXCEPTION 'cancel_collection_v2 declaration anchor missing'; END IF;
  v_def := replace(v_def,v_old,v_new);

  v_old := $old$  IF v_collection.status IS DISTINCT FROM 'POSTED' THEN
    RAISE EXCEPTION 'لا يمكن إلغاء تحصيل غير مرحّل.';
  END IF;
$old$;
  v_new := v_old || $new$
  IF v_collection.trip_id IS NOT NULL
     AND UPPER(COALESCE(v_collection.payment_method,''))='CASH' THEN
    SELECT status INTO v_trip_status
    FROM public.trips
    WHERE trip_id=v_collection.trip_id
    FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'الجولة المرتبطة بالتحصيل غير موجودة.';
    END IF;
    IF v_trip_status='COMPLETED' THEN
      RAISE EXCEPTION 'لا يمكن إلغاء تحصيل نقدي مرتبط بجولة مكتملة حتى لا يتغير رصيد خزنة المناديب بعد التسوية.';
    END IF;
  END IF;
$new$;
  IF strpos(v_def,v_old)=0 THEN RAISE EXCEPTION 'cancel_collection_v2 status anchor missing'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.cancel_expense(bigint,text)'::regprocedure);
  v_old := '  v_expense public.expenses%ROWTYPE;' || chr(10);
  v_new := v_old || '  v_trip_status text;' || chr(10);
  IF strpos(v_def,v_old)=0 THEN RAISE EXCEPTION 'cancel_expense declaration anchor missing'; END IF;
  v_def := replace(v_def,v_old,v_new);

  v_old := '  PERFORM pg_advisory_xact_lock(947353);';
  v_new := '  PERFORM pg_advisory_xact_lock(947351);';
  IF strpos(v_def,v_old)=0 THEN RAISE EXCEPTION 'cancel_expense advisory lock anchor missing'; END IF;
  v_def := replace(v_def,v_old,v_new);

  v_old := $old$  IF v_expense.is_cancelled THEN
    RAISE EXCEPTION 'المصروف ملغى بالفعل';
  END IF;
$old$;
  v_new := v_old || $new$
  IF v_expense.trip_id IS NOT NULL THEN
    SELECT status INTO v_trip_status
    FROM public.trips
    WHERE trip_id=v_expense.trip_id
    FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'الجولة المرتبطة بالمصروف غير موجودة.';
    END IF;
    IF v_trip_status='COMPLETED' THEN
      RAISE EXCEPTION 'لا يمكن إلغاء مصروف جولة مكتملة حتى لا يتغير رصيد خزنة المناديب بعد التسوية.';
    END IF;
  END IF;
$new$;
  IF strpos(v_def,v_old)=0 THEN RAISE EXCEPTION 'cancel_expense status anchor missing'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.cancel_sales_return(bigint,text)'::regprocedure);
  v_old := $old$  IF v_return.status NOT IN ('POSTED','APPROVED') THEN
    RAISE EXCEPTION 'لا يمكن إلغاء مرتجع غير مرحل أو غير معتمد.';
  END IF;
$old$;
  v_new := v_old || $new$
  IF v_return.trip_id IS NOT NULL
     AND v_return.cash_action='CASH_BACK'
     AND v_return.treasury_id=8
     AND EXISTS (
       SELECT 1 FROM public.trips t
       WHERE t.trip_id=v_return.trip_id
         AND t.status='COMPLETED'
     ) THEN
    RAISE EXCEPTION 'لا يمكن عكس رد نقدية من خزنة المناديب بعد إغلاق الجولة.';
  END IF;
$new$;
  IF strpos(v_def,v_old)=0 THEN RAISE EXCEPTION 'cancel_sales_return status anchor missing'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;

  v_def := pg_get_functiondef('public.enforce_sales_return_cashback_treasury()'::regprocedure);
  v_old := '    ELSIF NEW.treasury_id IS NULL OR NOT EXISTS (';
  v_new := '    ELSIF NEW.treasury_id IS NULL OR NEW.treasury_id=8 OR NOT EXISTS (';
  IF strpos(v_def,v_old)=0 THEN RAISE EXCEPTION 'cashback treasury anchor missing'; END IF;
  v_def := replace(v_def,v_old,v_new);
  EXECUTE v_def;
END
$migration$;

DO $verify$
DECLARE
  v_collection text;
  v_expense text;
  v_return text;
  v_trigger text;
BEGIN
  v_collection:=pg_get_functiondef('public.cancel_collection_v2(bigint,text)'::regprocedure);
  v_expense:=pg_get_functiondef('public.cancel_expense(bigint,text)'::regprocedure);
  v_return:=pg_get_functiondef('public.cancel_sales_return(bigint,text)'::regprocedure);
  v_trigger:=pg_get_functiondef('public.enforce_sales_return_cashback_treasury()'::regprocedure);

  IF position('v_trip_status=''COMPLETED''' in v_collection)=0
     OR position('pg_advisory_xact_lock(947351)' in v_expense)=0
     OR position('v_trip_status=''COMPLETED''' in v_expense)=0
     OR position('v_return.treasury_id=8' in v_return)=0
     OR position('NEW.treasury_id=8' in v_trigger)=0 THEN
    RAISE EXCEPTION 'closed-trip cash protection verification failed';
  END IF;
END
$verify$;
