# Historical SQL Recovery Archive

تم استرداد 14 مصدر SQL تاريخيًا من الفرع `qa/full-cycle-v108` بتاريخ 2026-11-20.

المسار:
`supabase/migration_archive/recovered_2026-11-11/`

هذه الملفات مرجعية تاريخية فقط. لا توضع في `supabase/migrations` ولا يجوز تنفيذها تلقائيًا.

سبب الحفظ:
- استعادة المصادر التاريخية التي لم تكن موجودة في main الحالي.
- الحفاظ على محتوى الملفات كما ظهر في الفرع التاريخي.
- فصل المصادر التاريخية عن ملفات الترحيلات التنفيذية.

الملفات المستردة:
1. LOT_TRACEABILITY_SCHEMA_2026-11-11.sql
2. LOT_TRACEABILITY_FUNCTIONS_2026-11-11.sql
3. QA_CANCEL_SALES_INVOICE_EXACT_LOT_2026-11-11.sql
4. QA_CUSTOMER_INSERT_RLS_CONSOLIDATION_2026-11-11.sql
5. QA_DATABASE_FIXES_2026-11-10.sql
6. QA_FINANCIAL_SUMMARY_LEDGER_FIX_2026-11-11.sql
7. QA_INDEX_EXPENSES_CANCELLED_BY_2026-11-11.sql
8. QA_NOTIFICATION_ADMIN_ONLY_2026-11-11.sql
9. QA_PARTNER_CAPITAL_OUT_GUARD_2026-11-10.sql
10. QA_RESERVED_STOCK_GUARDS_2026-11-11.sql
11. QA_REVERSE_STOCK_TRANSFER_EXACT_LOTS_2026-11-11.sql
12. QA_STOCK_VALUATION_GUARD_2026-11-11.sql
13. QA_TREASURY_STATEMENT_RUNNING_BALANCE_2026-11-11.sql
14. QA_TRIP_SURPLUS_RETURN_LOT_SCOPE_2026-11-11.sql

لا يعني وجود هذه الملفات أن أرقام migrations الأصلية لها معروفة أو مثبتة في `schema_migrations`. مطابقة رقم التنفيذ تحتاج دليلًا من سجل Supabase أو تاريخ Git آخر.

الخطوة التالية هي مقارنة هذه المصادر مع سجل migrations الحالي ومع الملفات الموجودة في main، ثم تحديد ما يمكن ربطه برقم migration بثقة وما يبقى مصدرًا تاريخيًا غير قابل للربط.
