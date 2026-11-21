# Supabase Migration History

تاريخ اللقطة: 2026-11-20  
المشروع: `mklbemoisdkoyrwcrmoj`  
GitHub: `evramman-dev/MeatManagement`  
الفرع المرجعي: `main` بعد دمج PR #180  
Commit: `1041981952e2f57e27f0d0d6f46c7c717a2986a7`

## نتيجة المطابقة

- عدد الترحيلات المسجلة في Supabase: **318**.
- عدد ملفات SQL التنفيذية في `supabase/migrations`: **38**.
- ملفات GitHub التي لا يقابل رقمها ترحيل مسجل في Supabase: **0**.
- ترحيلات Supabase التي لا يوجد لها ملف SQL مطابق في GitHub: **280**.
- كل الملفات الـ38 داخل مجلد الترحيلات تحمل الآن أرقامًا موجودة في سجل Supabase. لذلك لا توجد ملفات محلية معلقة سيحاول Supabase تنفيذها كترحيلات جديدة عند مزامنة هذا المجلد.

## حدود ما تم إصلاحه

سجل Supabase يحتفظ برقم الترحيل واسمه، ولا يحتفظ بنص SQL الأصلي. لذلك لا يمكن استخراج نصوص الترحيلات الـ280 المفقودة من سجل قاعدة البيانات وحده.

تمت مطابقة 9 ملفات محلية مع أرقام الترحيلات المسجلة اعتمادًا على تطابق أسماء الترحيلات أو اسمها الوظيفي، ثم التحقق من وجود آثار التغييرات الأساسية في مخطط قاعدة البيانات الحالي. هذه مطابقة تشغيلية وليست مقارنة ببصمة SQL أصلية، لأن قاعدة البيانات لا تخزن تلك البصمة.

تم نقل 3 ملفات لا يمكن ربط أرقامها بسجل الترحيلات إلى `supabase/migration_archive/unmatched_version/`. فحص الدوال الحالية أكد وجود آثار التغييرات الرئيسية التي تحتويها، لكن لا يوجد دليل في سجل الترحيلات يثبت رقم التنفيذ الأصلي لها. لذلك لا يجوز تشغيلها تلقائيًا.

## مصادر SQL التاريخية المستردة من QA

بعد دمج PR #180 تم فحص 14 ملف SQL تاريخيًا مستردًا من الفرع `qa/full-cycle-v108` مقابل سجل Supabase الحالي.

النتيجة:

| المصدر التاريخي | التصنيف | الربط |
|---|---|---|
| LOT_TRACEABILITY_SCHEMA_2026-11-11.sql | مصدر مؤرخ قابل للربط | يغطي أساس تتبع التشغيلات وما يرتبط به من migrations بتاريخ 2026-11-11. |
| LOT_TRACEABILITY_FUNCTIONS_2026-11-11.sql | لقطة نهائية متعددة الترحيلات | يذكر صراحة ترحيلات تتبع التشغيلات ومنها `create_lot_traceability_foundation_20261111` و`backfill_legacy_opening_lot_balances_20261111` و`link_lot_traceability_to_purchase_sales_and_returns_20261111` و`link_single_lot_sales_invoice_items_20261111` و`complete_purchase_lot_idempotency_and_production_expiry_20261111` و`enable_sales_return_lot_selection_and_validation_20261111` و`reverse_customer_return_lots_exactly_on_cancel_20261111` و`allow_legacy_purchase_return_without_historical_lot_20261111` و`preserve_legacy_stock_reversals_without_lot_history_20261111` و`validate_purchase_lot_dates_and_classify_trip_returns_20261111` و`scope_sales_lot_lookup_to_return_permissions_20261111`. كما يذكر صراحة ترحيلات عكس التحويل وإلغاء فاتورة البيع ونطاق مرتجع فائض الجولة. |
| QA_CANCEL_SALES_INVOICE_EXACT_LOT_2026-11-11.sql | ربط مؤكد | `20261111151926_restore_exact_sales_invoice_lots_and_cost_on_cancel_20261111` |
| QA_CUSTOMER_INSERT_RLS_CONSOLIDATION_2026-11-11.sql | ربط مؤكد | `20261111084901_consolidate_customer_insert_rls_policy_20261111` |
| QA_DATABASE_FIXES_2026-11-10.sql | حزمة إصلاحات متعددة | لا يمثل migration واحدًا. يحتوي إصلاحات من أكثر من ترحيل في 2026-11-10. لذلك لا نعطيه رقمًا واحدًا. |
| QA_FINANCIAL_SUMMARY_LEDGER_FIX_2026-11-11.sql | ربط مؤكد وظيفيًا | `20261111085038_align_accounting_summary_revenue_with_posted_ledger_20261111` |
| QA_INDEX_EXPENSES_CANCELLED_BY_2026-11-11.sql | ربط مؤكد | `20261111152400_index_expenses_cancelled_by_20261111` |
| QA_NOTIFICATION_ADMIN_ONLY_2026-11-11.sql | ربط مؤكد وظيفيًا | `20261111084255_restrict_notification_management_to_system_admin_20261111` |
| QA_PARTNER_CAPITAL_OUT_GUARD_2026-11-10.sql | ربط مؤكد لعدة ترحيلات | `20261110164949_block_unaccounted_partner_in_kind_contribution_20261110` و`20261110170047_revoke_direct_partner_transaction_dml_20261110` |
| QA_RESERVED_STOCK_GUARDS_2026-11-11.sql | ربط مؤكد | `20261111142941_protect_reserved_stock_from_outbound_movements_20261111` |
| QA_REVERSE_STOCK_TRANSFER_EXACT_LOTS_2026-11-11.sql | ربط مؤكد | `20261111152231_preserve_exact_lots_when_reversing_stock_transfers_20261111` |
| QA_STOCK_VALUATION_GUARD_2026-11-11.sql | ربط مؤكد | `20261111142420_reject_negative_stock_inventory_value_20261111` |
| QA_TREASURY_STATEMENT_RUNNING_BALANCE_2026-11-11.sql | ربط مؤكد | `20261111161314_fix_treasury_statement_running_balance_order_20261111` |
| QA_TRIP_SURPLUS_RETURN_LOT_SCOPE_2026-11-11.sql | ربط مؤكد | `20261111151446_scope_trip_surplus_lot_restore_to_surplus_receipt` |

### قرار الأرشفة

لم يتم نقل أي ملف إلى `supabase/migrations`.

ملفات الربط المؤكد أصبحت موثقة برقم migration الأصلي، لكن بقيت في الأرشيف لأن النص المسترد قد يكون لقطة نهائية أو حزمة QA وليس بالضرورة النص الأصلي الكامل لذلك migration.

`QA_DATABASE_FIXES_2026-11-10.sql` بقي مصدرًا تاريخيًا متعدد الإصلاحات ولا يُنسب إلى رقم واحد.

لا يزال سجل Supabase يحتوي 280 migration لا يوجد لها ملف SQL أصلي مطابق في المستودع.

## أثر ذلك على الاستخدام

- مزامنة الترحيلات المحلية مع قاعدة البيانات الحالية لا تحتوي على ملفات محلية ذات أرقام غير مطبقة.
- إعادة بناء قاعدة البيانات من الصفر باستخدام مجلد الترحيلات وحده **غير مضمونة**، لأن SQL الأصلي لـ280 ترحيلًا غير موجود في المستودع.
- لا تحذف ملفات الأرشيف ولا تنقلها إلى `supabase/migrations` قبل تحديد رقمها الأصلي ومطابقة محتواها.
- لا تعِد تنفيذ أي من ملفات الأرشيف على قاعدة البيانات الحالية.

## ترحيل #177

تم تطبيق الترحيل `20261120154853_add_accounting_period_closure_fk_indexes` على Supabase، وحُفظ ملفه في مجلد الترحيلات. وهو يضيف فهرسين على `accounting_period_closures.closing_entry_id` و`created_by`.

## سجل الترحيلات المسجل حاليًا

| Version | Name | ملف SQL في GitHub |
|---|---|---|
| 20261106211801 | `add_production_order_output_snapshot` | غير موجود |
| 20261106212203 | `create_and_execute_production_orders` | غير موجود |
| 20261106222532 | `add_product_packaging_options` | غير موجود |
| 20261106222546 | `separate_trip_load_approval_and_dispatch_permissions` | غير موجود |
| 20261106222619 | `add_package_aware_trip_load_workflow` | غير موجود |
| 20261106222703 | `support_package_weights_in_sales_invoices` | غير موجود |
| 20261106222710 | `reset_package_weight_per_sales_invoice_item` | غير موجود |
| 20261106222949 | `allow_approved_trip_load_status` | غير موجود |
| 20261107073006 | `remove_legacy_trip_load_approval_function` | غير موجود |
| 20261107082200 | `grant_system_admin_all_permissions_and_trip_load_workflow_view` | غير موجود |
| 20261107085037 | `repair_trip_cash_lifecycle_v1` | غير موجود |
| 20261107144657 | `harden_existing_workflows_and_reports` | غير موجود |
| 20261107144945 | `replace_permissive_table_policies` | غير موجود |
| 20261107145018 | `restrict_audit_reservation_and_stock_policies` | غير موجود |
| 20261107145107 | `restore_accounting_read_reports` | غير موجود |
| 20261107150535 | `accounting_role_idempotent_posting_and_ledger_pl` | غير موجود |
| 20261107150656 | `actual_production_and_weighted_average_stock_cost` | غير موجود |
| 20261107150808 | `restrict_internal_journal_writers_and_correct_financial_summary` | غير موجود |
| 20261107151222 | `repair_sales_return_request_approval_and_inventory_flow` | غير موجود |
| 20261107151231 | `post_cost_of_sales_for_sales_returns_and_exchanges` | غير موجود |
| 20261107151406 | `add_package_option_validation_for_sales_returns` | غير موجود |
| 20261107151455 | `carry_weighted_average_cost_across_stock_transfers_and_returns` | غير موجود |
| 20261107151506 | `preserve_cost_fallback_for_receipts` | غير موجود |
| 20261107151519 | `reverse_return_inventory_at_original_cost` | غير موجود |
| 20261107151535 | `restore_original_cost_when_cancelling_sales_invoice` | غير موجود |
| 20261107151608 | `lock_down_new_sales_return_rpc_overloads` | غير موجود |
| 20261107151705 | `secure_rpc_wrappers_and_consolidate_location_policies` | غير موجود |
| 20261107151718 | `index_unindexed_foreign_key_columns` | غير موجود |
| 20261107151742 | `consolidate_overlapping_rls_policies` | غير موجود |
| 20261107151811 | `remove_remaining_overlapping_permissive_policies` | غير موجود |
| 20261107151915 | `prevent_cash_refund_while_invoice_debt_remains` | غير موجود |
| 20261107151936 | `validate_return_price_against_net_original_line_price` | غير موجود |
| 20261107152108 | `pin_search_path_for_all_security_definer_functions` | غير موجود |
| 20261107152255 | `complete_minya_city_sections_neighborhoods` | غير موجود |
| 20261108132024 | `remove_orphaned_sales_order_rpc_functions` | غير موجود |
| 20261108132046 | `remove_unused_sales_return_rpc_overloads` | غير موجود |
| 20261108132215 | `extend_audit_triggers_to_financial_workflows` | غير موجود |
| 20261108132316 | `split_price_management_rls_policies` | غير موجود |
| 20261109093015 | `allow_negotiated_sales_invoice_prices_within_limits` | غير موجود |
| 20261109094124 | `allow_returns_view_permission_on_sales_return_headers` | غير موجود |
| 20261109095849 | `block_vehicle_locations_in_regular_stock_transfers` | غير موجود |
| 20261109105342 | `add_safe_stock_transfer_reversal` | غير موجود |
| 20261109114015 | `validate_sales_return_item_trip_location` | غير موجود |
| 20261109125723 | `add_cancel_purchase_return_supplier_credit` | غير موجود |
| 20261109125734 | `fix_cancel_purchase_return_location_and_cancel_flag` | غير موجود |
| 20261109125744 | `correct_cancel_purchase_return_invoice_location` | غير موجود |
| 20261109125807 | `harden_cancel_purchase_return_stock_validation` | غير موجود |
| 20261109130157 | `support_cash_bank_purchase_return_cancellation` | غير موجود |
| 20261109130905 | `support_purchase_invoice_cancellation_and_ignore_cancelled_returns` | غير موجود |
| 20261109130930 | `index_purchase_invoice_cancelled_by` | غير موجود |
| 20261109131335 | `secure_adjust_treasury_balance_internal_only` | غير موجود |
| 20261109131945 | `validate_purchase_return_cancellation_totals` | غير موجود |
| 20261109135327 | `link_purchase_documents_to_stock_movements` | غير موجود |
| 20261109135355 | `use_purchase_invoice_id_for_stock_cost` | غير موجود |
| 20261109135411 | `write_purchase_movement_links_explicitly` | غير موجود |
| 20261109142227 | `add_production_cost_allocation_v3` | غير موجود |
| 20261109143329 | `add_source_tracked_production_cost_allocation_v4` | غير موجود |
| 20261109143346 | `tighten_production_v4_source_quantity_checks` | غير موجود |
| 20261109143940 | `restrict_production_execution_to_current_date` | غير موجود |
| 20261109144434 | `normalize_production_v4_quantity_and_cost_precision` | غير موجود |
| 20261109144657 | `normalize_production_input_quantity_precision` | غير موجود |
| 20261109145445 | `add_recovered_source_quantity_tracking_v5` | غير موجود |
| 20261109150021 | `unify_production_inventory_balance_lock_order` | غير موجود |
| 20261109153125 | `remove_orphaned_legacy_inventory_functions` | غير موجود |
| 20261109153438 | `align_supplier_treasury_lock_order_in_purchase_return_cancel` | غير موجود |
| 20261109153755 | `align_cheque_clearing_period_and_treasury_lock_order` | غير موجود |
| 20261109154156 | `align_collection_cheque_period_treasury_lock_order` | غير موجود |
| 20261109154420 | `check_expense_period_before_trip_and_treasury_locks` | غير موجود |
| 20261109154538 | `check_purchase_period_before_invoice_and_return_locks` | غير موجود |
| 20261109154852 | `check_purchase_cancel_period_before_record_locks` | غير موجود |
| 20261109155134 | `check_supplier_payment_period_before_supplier_and_treasury_locks` | غير موجود |
| 20261109155512 | `check_sales_invoice_cancel_period_before_record_locks` | غير موجود |
| 20261109155645 | `check_sales_return_cancel_period_before_record_locks` | غير موجود |
| 20261109155940 | `check_current_period_before_sales_invoice_cancel_stock_locks` | غير موجود |
| 20261109160339 | `include_zero_sales_trips_in_vehicle_load_suggestions` | غير موجود |
| 20261109161503 | `fix_manual_stock_balance_double_adjustment` | غير موجود |
| 20261109161645 | `prevent_opening_stock_balance_double_quantity` | غير موجود |
| 20261109162242 | `fix_sales_return_double_stock_quantity_update` | غير موجود |
| 20261109165658 | `link_stock_movements_to_production_orders` | غير موجود |
| 20261110004117 | `expense_types_and_account_mapping` | غير موجود |
| 20261110010309 | `purchase_landed_cost_workflow` | غير موجود |
| 20261110010328 | `guard_landed_cost_return_reversal` | غير موجود |
| 20261110010423 | `fixed_asset_register_and_purchase` | غير موجود |
| 20261110145028 | `fix_sales_returns_trip_load_sync_expense_journal` | غير موجود |
| 20261110145108 | `harden_trip_load_sync_trigger_functions` | غير موجود |
| 20261110150915 | `fix_trip_settlement_vehicle_return_accounting` | غير موجود |
| 20261110151647 | `add_missing_foreign_key_indexes_2026_11_10` | غير موجود |
| 20261110153337 | `block_vehicle_purchase_invoice_location` | غير موجود |
| 20261110153916 | `block_untracked_vehicle_stock_movements` | غير موجود |
| 20261110164155 | `require_idempotency_for_landed_costs_and_fixed_assets_20261110` | غير موجود |
| 20261110164446 | `normalize_landed_cost_amount_before_cash_posting_20261110` | غير موجود |
| 20261110164548 | `check_permissions_in_idempotent_financial_wrappers_20261110` | غير موجود |
| 20261110164949 | `block_unaccounted_partner_in_kind_contribution_20261110` | غير موجود |
| 20261110170047 | `revoke_direct_partner_transaction_dml_20261110` | غير موجود |
| 20261110172656 | `partner_equipment_in_kind_contribution_20261110` | غير موجود |
| 20261110172926 | `harden_partner_equipment_contribution_link_20261110` | غير موجود |
| 20261110173100 | `harden_partner_equipment_contribution_cancellation_20261110` | غير موجود |
| 20261110173958 | `partner_inventory_in_kind_contribution_20261110` | غير موجود |
| 20261110174011 | `fix_partner_inventory_contribution_integrity_check_20261110` | غير موجود |
| 20261110174102 | `add_partner_inventory_contribution_read_policy_20261110` | غير موجود |
| 20261110174210 | `block_partner_inventory_contribution_cancel_with_active_reservations_20261110` | غير موجود |
| 20261110174325 | `index_partner_inventory_contribution_foreign_keys_20261110` | غير موجود |
| 20261110175616 | `partner_vehicle_in_kind_contribution_20261110` | غير موجود |
| 20261110192829 | `correct_vehicle_asset_account_parent_20261110` | غير موجود |
| 20261110205142 | `partner_other_fixed_assets_contribution_20261110` | غير موجود |
| 20261110211947 | `allow_sales_reps_to_create_customers_in_assigned_areas_20261110` | غير موجود |
| 20261110212115 | `restrict_sales_rep_customer_creation_financial_fields_20261110` | غير موجود |
| 20261111080016 | `allow_supplier_advance_payments_20261111` | غير موجود |
| 20261111084255 | `restrict_notification_management_to_system_admin_20261111` | غير موجود |
| 20261111084901 | `consolidate_customer_insert_rls_policy_20261111` | غير موجود |
| 20261111085038 | `align_accounting_summary_revenue_with_posted_ledger_20261111` | غير موجود |
| 20261111111605 | `add_customer_responsible_sales_rep` | غير موجود |
| 20261111132639 | `enforce_sales_return_cashback_from_representatives_treasury` | غير موجود |
| 20261111135125 | `fix_purchase_return_cancel_cost_validation_scope_20261111` | غير موجود |
| 20261111135703 | `fix_purchase_invoice_cancelled_payments_balance_20261111` | غير موجود |
| 20261111140507 | `strict_landed_cost_cancellation_inventory_value` | غير موجود |
| 20261111141143 | `add_safe_expense_cancellation` | غير موجود |
| 20261111141445 | `exclude_cancelled_expenses_from_financial_summaries` | غير موجود |
| 20261111141512 | `store_expense_cancellation_user_name` | غير موجود |
| 20261111142420 | `reject_negative_stock_inventory_value_20261111` | غير موجود |
| 20261111142941 | `protect_reserved_stock_from_outbound_movements_20261111` | غير موجود |
| 20261111143103 | `complete_reservation_guards_and_fix_production_reversal_20261111` | غير موجود |
| 20261111143858 | `create_lot_traceability_foundation_20261111` | غير موجود |
| 20261111143927 | `backfill_legacy_opening_lot_balances_20261111` | غير موجود |
| 20261111144102 | `link_lot_traceability_to_purchase_sales_and_returns_20261111` | غير موجود |
| 20261111144111 | `link_single_lot_sales_invoice_items_20261111` | غير موجود |
| 20261111144157 | `complete_purchase_lot_idempotency_and_production_expiry_20261111` | غير موجود |
| 20261111144627 | `enable_sales_return_lot_selection_and_validation_20261111` | غير موجود |
| 20261111144756 | `reverse_customer_return_lots_exactly_on_cancel_20261111` | غير موجود |
| 20261111145017 | `index_lot_traceability_foreign_keys_20261111` | غير موجود |
| 20261111145048 | `allow_legacy_purchase_return_without_historical_lot_20261111` | غير موجود |
| 20261111145204 | `preserve_legacy_stock_reversals_without_lot_history_20261111` | غير موجود |
| 20261111145238 | `validate_purchase_lot_dates_and_classify_trip_returns_20261111` | غير موجود |
| 20261111145357 | `scope_sales_lot_lookup_to_return_permissions_20261111` | غير موجود |
| 20261111151446 | `scope_trip_surplus_lot_restore_to_surplus_receipt` | غير موجود |
| 20261111151926 | `restore_exact_sales_invoice_lots_and_cost_on_cancel_20261111` | غير موجود |
| 20261111152231 | `preserve_exact_lots_when_reversing_stock_transfers_20261111` | غير موجود |
| 20261111152400 | `index_expenses_cancelled_by_20261111` | غير موجود |
| 20261111161314 | `fix_treasury_statement_running_balance_order_20261111` | غير موجود |
| 20261111174625 | `fix_partner_opening_balance_double_post_20261111` | غير موجود |
| 20261111181021 | `partner_and_fixed_asset_accounting_20261111` | غير موجود |
| 20261111181100 | `complete_partner_asset_accounting_20261111` | غير موجود |
| 20261111181126 | `partner_profit_transaction_types_20261111` | غير موجود |
| 20261111181135 | `partner_profit_item_request_ids_20261111` | غير موجود |
| 20261111181146 | `partner_profit_distribution_single_journal_20261111` | غير موجود |
| 20261111181211 | `fix_depreciation_mid_month_period_20261111` | غير موجود |
| 20261111181227 | `allow_fixed_asset_disposed_status_20261111` | غير موجود |
| 20261111181241 | `fix_fixed_asset_disposal_treasury_posting_20261111` | غير موجود |
| 20261111181255 | `remove_duplicate_fixed_asset_select_policy_20261111` | غير موجود |
| 20261111181307 | `exact_profit_distribution_rounding_20261111` | غير موجود |
| 20261111181327 | `index_partner_profit_distribution_fks_20261111` | غير موجود |
| 20261111181932 | `fixed_asset_depreciation_configuration_rpc_20261111` | غير موجود |
| 20261111193837 | `product_shelf_life_calendar_months` | غير موجود |
| 20261111195803 | `daily_lot_expiry_notifications` | غير موجود |
| 20261111195903 | `lot_expiry_alert_on_expiry_date` | غير موجود |
| 20261112084411 | `add_direct_production_cost_allocation_v1` | غير موجود |
| 20261112084421 | `improve_sales_return_cost_traceability` | غير موجود |
| 20261112084624 | `tighten_direct_production_cost_validation_v1` | غير موجود |
| 20261112110230 | `revoke_public_execution_from_invoice_status_trigger` | غير موجود |
| 20261112110800 | `secure_fixed_asset_disposal_wrapper` | غير موجود |
| 20261112111021 | `quarantine_unverified_opening_lots` | غير موجود |
| 20261112111101 | `exclude_quarantined_lots_from_expiry_alerts` | غير موجود |
| 20261112111203 | `require_verified_lot_dates_and_shelf_life_for_production` | غير موجود |
| 20261112124959 | `allow_cancel_invoice_after_exact_cancelled_return_reversal` | غير موجود |
| 20261112130714 | `add_system_admin_reset_preview_rpc` | غير موجود |
| 20261112130847 | `fix_admin_reset_preview_purchase_return_flag` | غير موجود |
| 20261112131335 | `expand_admin_reset_preview_blocker_details` | غير موجود |
| 20261112132640 | `add_admin_reset_plan_preparation` | غير موجود |
| 20261112132658 | `fix_admin_reset_plan_hash_extension_schema` | غير موجود |
| 20261112135536 | `separate_admin_reset_phase_plans` | غير موجود |
| 20261112135639 | `isolate_admin_reset_prepare_engine` | غير موجود |
| 20261112140306 | `add_reset_plan_row_backups_and_audit` | غير موجود |
| 20261112140536 | `build_admin_reset_phase1_execution_engine` | غير موجود |
| 20261112140626 | `allow_reset_only_journal_self_link_cleanup` | غير موجود |
| 20261112140712 | `fix_reset_phase1_fk_delete_order` | غير موجود |
| 20261112140806 | `allow_production_delete_only_in_approved_reset` | غير موجود |
| 20261112140848 | `allow_reset_only_movement_self_link_cleanup` | غير موجود |
| 20261112140856 | `delete_reset_user_logs_after_all_audited_updates` | غير موجود |
| 20261112141030 | `include_fixed_asset_links_in_phase1_reset` | غير موجود |
| 20261112141206 | `restrict_internal_reset_audit_rpcs` | غير موجود |
| 20261112141347 | `verify_fixed_assets_removed_in_phase1` | غير موجود |
| 20261112141415 | `lock_down_reset_hash_helpers` | غير موجود |
| 20261112141435 | `include_reset_balance_masters_in_phase1_backup` | غير موجود |
| 20261112141542 | `keep_phase1_execution_locked_until_final_test` | غير موجود |
| 20261112142227 | `allow_admin_reset_vehicle_asset_unlink` | غير موجود |
| 20261112143148 | `add_phase2_reset_engine_locked` | غير موجود |
| 20261112143209 | `fix_phase2_reset_rows_hash_delimiter` | غير موجود |
| 20261112143241 | `normalize_phase2_reset_hash_delimiter` | غير موجود |
| 20261112143318 | `align_phase2_reset_hash_newline` | غير موجود |
| 20261112143329 | `guard_phase2_against_new_operations` | غير موجود |
| 20261112143339 | `grant_scoped_phase2_reset_functions` | غير موجود |
| 20261112143932 | `preserve_sales_rep_master_data_in_phase2_reset` | غير موجود |
| 20261112144609 | `align_phase2_report_preserved_assets_and_fk_blockers` | غير موجود |
| 20261112144743 | `clarify_phase2_preserved_vs_phase1_cleared_assets` | غير موجود |
| 20261112144924 | `classify_recipes_as_phase2_master_data` | غير موجود |
| 20261112145933 | `fix_phase1_stock_balance_reset_order` | غير موجود |
| 20261112150229 | `remove_duplicate_phase1_lot_balance_delete` | غير موجود |
| 20261112153556 | `add_secure_latest_phase1_plan_restore` | غير موجود |
| 20261112153716 | `use_invoker_for_phase1_plan_restore_rpc` | غير موجود |
| 20261112154832 | `preserve_user_logs_in_phase1_reset_and_refresh_plan_hashes` | غير موجود |
| 20261112160818 | `add_single_operation_factory_reset_engine` | غير موجود |
| 20261112160852 | `add_factory_reset_report_restore` | غير موجود |
| 20261112161024 | `correct_factory_reset_preserved_counts` | غير موجود |
| 20261112161305 | `grant_scoped_factory_reset_trigger_guard` | غير موجود |
| 20261113102712 | `add_multi_location_inventory_count_workflow` | غير موجود |
| 20261113102727 | `add_inventory_count_session_list` | غير موجود |
| 20261113102826 | `protect_inventory_count_from_concurrent_movements` | غير موجود |
| 20261113104049 | `register_inventory_locations_and_scope_general_count` | غير موجود |
| 20261113105441 | `add_product_refrigeration_and_location_scoped_inventory_count` | غير موجود |
| 20261113110034 | `fix_inventory_count_create_created_by_insert` | غير موجود |
| 20261113111403 | `add_package_unit_inventory_counting` | غير موجود |
| 20261113111411 | `correct_package_count_conversion_total` | غير موجود |
| 20261113111522 | `include_packaging_plate_units_in_count_details` | غير موجود |
| 20261113113220 | `add_finished_jar_bottle_products_and_complete_container_items` | غير موجود |
| 20261113113255 | `include_jar_and_bottle_units_in_inventory_count` | غير موجود |
| 20261113113441 | `limit_jar_bottle_count_units_to_finished_products` | غير موجود |
| 20261113113547 | `create_exact_boms_for_jar_and_bottle_finished_products` | غير موجود |
| 20261113115200 | `organize_oil_honey_tahini_product_categories` | غير موجود |
| 20261113115241 | `rename_recipe_components_category` | غير موجود |
| 20261113122343 | `add_dynamic_purchase_package_weight` | غير موجود |
| 20261113122556 | `support_dynamic_actual_weights_on_purchase_and_sales` | غير موجود |
| 20261113122940 | `add_fish_frozen_vegetable_cheese_and_pickle_catalog` | غير موجود |
| 20261113123154 | `support_dynamic_weight_units_in_inventory_count` | غير موجود |
| 20261113123334 | `add_duck_count_and_actual_weight_product` | غير موجود |
| 20261113123402 | `add_duck_count_and_actual_weight_product` | غير موجود |
| 20261113141525 | `split_sealed_cheese_products_by_fixed_package_weight` | غير موجود |
| 20261113175654 | `add_finished_poultry_products_and_packaging` | غير موجود |
| 20261113175719 | `correct_poultry_finished_product_codes_and_options` | غير موجود |
| 20261113180011 | `align_gizzards_packaging_options_with_sale_units` | غير موجود |
| 20261114153403 | `factory_reset_data_policy_registry` | غير موجود |
| 20261114153443 | `factory_reset_policy_v3` | غير موجود |
| 20261114153511 | `factory_reset_policy_ui_compat_v2` | غير موجود |
| 20261114153540 | `factory_reset_policy_mode_compat` | غير موجود |
| 20261114153619 | `factory_reset_policy_keep_counts` | غير موجود |
| 20261114163332 | `show_latest_completed_factory_reset_without_auto_prepare` | غير موجود |
| 20261114171320 | `allow_missing_lot_dates_for_packaging_products` | غير موجود |
| 20261114173335 | `harden_cancel_collection_v2_cheque_and_paid_status_20261114` | غير موجود |
| 20261114173516 | `block_cash_collection_on_completed_trips_20261114` | غير موجود |
| 20261114173550 | `align_trip_summary_with_settlement_document_statuses_20261114` | غير موجود |
| 20261114175217 | `add_vehicle_open_trip_guard_and_route_cheque_bounce_through_v2_20261114` | غير موجود |
| 20261114175631 | `grant_authenticated_select_customer_cheques` | غير موجود |
| 20261114182129 | `harden_legacy_reset_and_restore_treasury_master_20261114` | غير موجود |
| 20261114182229 | `restrict_sales_rep_sales_invoice_lot_lookup_20261114` | غير موجود |
| 20261114182750 | `remove_verified_legacy_reset_and_unused_rpc_20261114` | غير موجود |
| 20261114183239 | `persist_sales_rep_on_sales_invoice_creation_20261114` | غير موجود |
| 20261114183626 | `fix_production_waste_json_normalization_20261114` | غير موجود |
| 20261114183725 | `allow_exact_lot_restoration_without_new_shelf_life_check_20261114` | غير موجود |
| 20261114184040 | `release_production_expense_allocations_on_reversal_20261114` | غير موجود |
| 20261114205725 | `set_product_shelf_life_defaults_20261114` | غير موجود |
| 20261114210246 | `set_semi_finished_and_recipe_spices_shelf_life_20261114` | غير موجود |
| 20261114210743 | `require_customer_cheque_due_date_20261114` | غير موجود |
| 20261114212027 | `allow_selected_treasury_for_closed_trip_cashback_20261114` | غير موجود |
| 20261114212154 | `include_partial_invoices_in_customer_receivables_20261114` | غير موجود |
| 20261114212355 | `return_empty_customer_returns_for_sales_rep_20261114` | غير موجود |
| 20261114212609 | `exclude_draft_sales_invoices_from_aged_receivables_20261114` | غير موجود |
| 20261114215201 | `guard_supplier_payment_cancellation_20261114` | موجود |
| 20261114215610 | `supplier_statement_credit_asset_visibility_20261114` | موجود |
| 20261114220327 | `customer_receivables_signed_opening_and_inactive_20261114` | موجود |
| 20261114220543 | `include_customer_credit_balances_in_aged_report_20261114` | موجود |
| 20261114221509 | `trip_stock_reconciliation_and_exact_vehicle_close_20261114` | موجود |
| 20261114221636 | `include_post_close_returns_in_trip_reconciliation_20261114` | موجود |
| 20261115085859 | `sales_return_exchange_complete_v1` | موجود |
| 20261115085953 | `sales_return_exchange_post_cancel_fix` | موجود |
| 20261115090236 | `sales_return_exchange_cashback_journal_fix` | موجود |
| 20261115090926 | `sales_return_exchange_accounting_cost_fix` | موجود |
| 20261115091003 | `sales_return_exchange_final_accounting_fix` | موجود |
| 20261115091421 | `validate_sales_return_exchange_cash_action_direction` | موجود |
| 20261115091713 | `validate_sales_return_exchange_product_conversions` | موجود |
| 20261115091811 | `allow_historical_package_option_on_sales_return_exchange` | موجود |
| 20261115091922 | `allow_fefo_remainder_for_same_product_exchange` | موجود |
| 20261115092120 | `include_exchange_type_in_customer_returns_statement` | موجود |
| 20261115101357 | `register_customer_credit_tables_for_factory_reset` | غير موجود |
| 20261115103214 | `fix_sales_exchange_conversion_lots_and_journal` | غير موجود |
| 20261115110801 | `preserve_exchange_balance_in_customer_collections` | غير موجود |
| 20261115110824 | `guard_null_trip_record_in_collection` | غير موجود |
| 20261115111120 | `clear_operational_lot_links_before_factory_reset` | غير موجود |
| 20261115114626 | `automatic_master_record_codes` | غير موجود |
| 20261115115037 | `sequential_sales_return_and_inventory_codes` | غير موجود |
| 20261115115301 | `factory_reset_keep_profiles_clear_opening_balances` | غير موجود |
| 20261115122657 | `index_uncovered_foreign_keys_and_remove_duplicate_exchange_index` | غير موجود |
| 20261115141432 | `secure_inventory_count_approval_and_stock_adjustment` | غير موجود |
| 20261115142104 | `separate_inventory_count_entry_from_stock_adjustment` | غير موجود |
| 20261115144036 | `fix_sales_exchange_request_idempotency` | موجود |
| 20261115144743 | `fix_sales_exchange_cancellation_accounting` | موجود |
| 20261115144800 | `fix_sales_exchange_cancellation_stock_reversal_order` | موجود |
| 20261115145032 | `guard_legacy_sales_return_cancel_from_exchanges` | موجود |
| 20261115145626 | `consolidate_fixed_assets_select_policies` | موجود |
| 20261115150347 | `restrict_stock_opening_balance_to_system_admin` | موجود |
| 20261115152852 | `restrict_notification_recipient_updates_to_read_at` | موجود |
| 20261115160755 | `guard_sales_return_request_number_idempotency` | موجود |
| 20261115163741 | `allow_semi_finished_recovered_production_products` | موجود |
| 20261116065753 | `sales_return_joint_inspection_rework` | موجود |
| 20261116065754 | `support_packaging_recovery_and_partial_rework` | موجود |
| 20261116070146 | `allow_mixed_sales_return_inspection_disposition` | غير موجود |
| 20261116103938 | `final_readiness_security_and_fk_indexes` | غير موجود |
| 20261116103955 | `restrict_accounting_reports_to_authenticated` | غير موجود |
| 20261116140300 | `expose_trip_rep_names_to_trip_viewers` | غير موجود |
| 20261116164418 | `use_product_prices_for_sales_invoices` | موجود |
| 20261116170818 | `validate_sales_prices_in_selected_unit` | موجود |
| 20261116170909 | `support_dynamic_weight_sales_price_unit` | موجود |
| 20261116171034 | `guard_price_validation_on_unit_conversion_updates` | موجود |
| 20261116194916 | `customer_account_collection_auto_allocation` | غير موجود |
| 20261116230948 | `sales_rep_trip_financial_visibility` | غير موجود |
| 20261118170540 | `validate_sales_return_inspection_disposition` | غير موجود |
| 20261119083328 | `add_partner_share_percentage_range_check` | غير موجود |
| 20261119105101 | `fix_trip_stock_reconciliation_customer_returns` | غير موجود |
| 20261119105223 | `add_authorized_sales_return_customer_labels` | غير موجود |
| 20261119121910 | `make_factory_reset_approval_idempotent_and_restore_active_plan` | غير موجود |
| 20261119122052 | `classify_new_operational_tables_for_factory_reset` | غير موجود |
| 20261119134901 | `fix_factory_reset_partner_operational_cycle` | غير موجود |
| 20261119194918 | `meat_manufacturing_units_and_recipe_ingredients` | موجود |
| 20261119195052 | `limit_finished_recipe_ingredients_to_meat_products` | موجود |
| 20261119195224 | `enforce_raw_meat_carton_only_sales` | موجود |
| 20261119195304 | `restrict_raw_meat_guard_function_execution` | موجود |
| 20261120125421 | `fix_factory_reset_treasury_balances_20261120` | غير موجود |
| 20261120131810 | `add_partner_read_only_role_20261120` | موجود |
| 20261120132214 | `block_partner_notification_read_updates_20261120` | موجود |
| 20261120154853 | `add_accounting_period_closure_fk_indexes` | موجود |


## مزامنة صلاحيات Sequences – 2026-11-21

تمت مطابقة ترحيلين مطبقين في قاعدة Supabase مع ملفيهما التنفيذيين في GitHub:

| Version | Migration | الحالة |
|---|---|---|
| 20261121071324 | `revoke_anon_public_sequence_access_20261121` | موجود في قاعدة Supabase، وأضيف ملف SQL المطابق إلى GitHub |
| 20261121071909 | `revoke_anon_default_sequence_privileges_20261121` | موجود في قاعدة Supabase، وأضيف ملف SQL المطابق إلى GitHub |

التغييران:
- سحب `USAGE` و`SELECT` و`UPDATE` من `anon` على كل Sequences الحالية في `public`.
- منع منح صلاحيات تلقائية لـ`anon` على Sequences الجديدة التي ينشئها المالك `postgres` داخل `public`.

تم التحقق من إعدادات الصلاحيات الافتراضية بعد التنفيذ. لا يملك `anon` صلاحيات افتراضية على Sequences الخاصة بـ`postgres`. بقيت إعدادات `supabase_admin` دون تغيير، كما بقيت صلاحيات `authenticated` و`service_role` دون تغيير.

هذه الإضافة توثق الحالة الحالية ولا تعيد تنفيذ التغييرات على قاعدة البيانات. لقطة الأعداد الواردة في بداية هذا الملف تخص تاريخ 2026-11-20 ولا تشمل هذين الترحيلين.

| 20261121101207 | scope_partner_read_access_and_link_accounts_20261121 | Add partner account-to-partner mapping and restrict partner-specific rows. Remove partner access to employee profiles, notifications, recipients, and activity logs. Preserve company-wide read-only visibility while limiting partner ledgers, contributions, profit items, and partner-owned assets to the linked partner. Applied to the production project. |

| 20261121101450 | move_partner_scope_helper_to_private_schema_20261121 | Move the partner lookup helper into the non-exposed private schema and update partner row policies to use it, avoiding a public RPC endpoint. Applied to the connected Supabase project. |
