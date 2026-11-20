# Recovered SQL Migration Mapping

تاريخ الفحص: 2026-11-20

هذا الملف يوثق مقارنة مصادر SQL التاريخية المستردة في `recovered_2026-11-11` مع سجل `supabase_migrations.schema_migrations`.

لا يحتوي هذا الملف على SQL تنفيذي. لا يجوز استخدامه كبديل عن ملفات `supabase/migrations`.

## النتائج

| الملف | النتيجة |
|---|---|
| LOT_TRACEABILITY_SCHEMA_2026-11-11.sql | مصدر تأسيس/مخطط لتتبع التشغيلات. يرتبط بسلسلة ترحيلات تتبع التشغيلات بتاريخ 2026-11-11. |
| LOT_TRACEABILITY_FUNCTIONS_2026-11-11.sql | لقطة وظائف نهائية بعد عدة ترحيلات. ليست migration واحدة. |
| QA_CANCEL_SALES_INVOICE_EXACT_LOT_2026-11-11.sql | 20261111151926 restore_exact_sales_invoice_lots_and_cost_on_cancel_20261111 |
| QA_CUSTOMER_INSERT_RLS_CONSOLIDATION_2026-11-11.sql | 20261111084901 consolidate_customer_insert_rls_policy_20261111 |
| QA_DATABASE_FIXES_2026-11-10.sql | حزمة إصلاحات متعددة. لا يمكن إعطاؤها رقم migration واحد. |
| QA_FINANCIAL_SUMMARY_LEDGER_FIX_2026-11-11.sql | 20261111085038 align_accounting_summary_revenue_with_posted_ledger_20261111 |
| QA_INDEX_EXPENSES_CANCELLED_BY_2026-11-11.sql | 20261111152400 index_expenses_cancelled_by_20261111 |
| QA_NOTIFICATION_ADMIN_ONLY_2026-11-11.sql | 20261111084255 restrict_notification_management_to_system_admin_20261111 |
| QA_PARTNER_CAPITAL_OUT_GUARD_2026-11-10.sql | 20261110164949 block_unaccounted_partner_in_kind_contribution_20261110 و20261110170047 revoke_direct_partner_transaction_dml_20261110 |
| QA_RESERVED_STOCK_GUARDS_2026-11-11.sql | 20261111142941 protect_reserved_stock_from_outbound_movements_20261111 |
| QA_REVERSE_STOCK_TRANSFER_EXACT_LOTS_2026-11-11.sql | 20261111152231 preserve_exact_lots_when_reversing_stock_transfers_20261111 |
| QA_STOCK_VALUATION_GUARD_2026-11-11.sql | 20261111142420 reject_negative_stock_inventory_value_20261111 |
| QA_TREASURY_STATEMENT_RUNNING_BALANCE_2026-11-11.sql | 20261111161314 fix_treasury_statement_running_balance_order_20261111 |
| QA_TRIP_SURPLUS_RETURN_LOT_SCOPE_2026-11-11.sql | 20261111151446 scope_trip_surplus_lot_restore_to_surplus_receipt |

## سلسلة تتبع التشغيلات

اللقطة الوظيفية المستردة تذكر صراحة:

- 20261111143858 create_lot_traceability_foundation_20261111
- 20261111143927 backfill_legacy_opening_lot_balances_20261111
- 20261111144102 link_lot_traceability_to_purchase_sales_and_returns_20261111
- 20261111144111 link_single_lot_sales_invoice_items_20261111
- 20261111144157 complete_purchase_lot_idempotency_and_production_expiry_20261111
- 20261111144627 enable_sales_return_lot_selection_and_validation_20261111
- 20261111144756 reverse_customer_return_lots_exactly_on_cancel_20261111
- 20261111145048 allow_legacy_purchase_return_without_historical_lot_20261111
- 20261111145204 preserve_legacy_stock_reversals_without_lot_history_20261111
- 20261111145238 validate_purchase_lot_dates_and_classify_trip_returns_20261111
- 20261111145357 scope_sales_lot_lookup_to_return_permissions_20261111
- 20261111151446 scope_trip_surplus_lot_restore_to_surplus_receipt
- 20261111151926 restore_exact_sales_invoice_lots_and_cost_on_cancel_20261111
- 20261111152231 preserve_exact_lots_when_reversing_stock_transfers_20261111

هذه روابط قوية لأنها مذكورة داخل المصدر التاريخي نفسه.

## القاعدة

لا يتم نقل أي مصدر مسترد إلى `supabase/migrations` لمجرد معرفة رقم migration.

السبب أن المصدر قد يكون snapshot أو bundle أو تعريفًا نهائيًا بعد عدة migrations.

الهدف هنا استعادة التاريخ وربط المصادر، وليس إعادة تنفيذها.

## ما بقي غير محسوم

المصدر `QA_DATABASE_FIXES_2026-11-10.sql` يحتوي عدة إصلاحات واختبارات وبيانات QA في ملف واحد.

لذلك بقي مصنفًا كحزمة تاريخية متعددة الإصلاحات.

ولا يوجد دليل كافٍ لادعاء أنه يساوي migration واحدة بعينها.

