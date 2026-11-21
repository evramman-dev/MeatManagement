# تقرير فجوة ملفات ترحيلات Supabase

تاريخ الفحص: 2026-11-21
المشروع: `mklbemoisdkoyrwcrmoj`
المستودع: `evramman-dev/MeatManagement`
الفرع المرجعي: `main`
Commit المرجعي: `4ba3ec851eb985fd1e5550c81dbcf459fe4e8f90`

## النتيجة

| البند | العدد |
|---|---:|
| الترحيلات المسجلة في Supabase | 326 |
| ملفات SQL التنفيذية في `supabase/migrations` | 46 |
| أرقام الملفات التنفيذية المطابقة لسجل Supabase | 46 |
| ملفات تنفيذية بأرقام غير موجودة في Supabase | 0 |
| ترحيلات مطبقة لا يوجد لها ملف SQL تنفيذي مطابق | 280 |
| ملفات SQL داخل الأرشيف | 17 |

جميع ملفات الترحيل التنفيذية الموجودة في GitHub تطابق أرقامًا مسجلة في Supabase. لا توجد ملفات محلية معلقة يمكن أن يحاول Supabase تنفيذها باعتبارها ترحيلات جديدة.

## تفسير الفجوة

سجل Supabase يحفظ رقم الترحيل واسمه، لكنه لا يحتفظ بنص SQL الأصلي ولا ببصمة يمكن استخدامها لإعادة بناء النص. لذلك فإن وجود اسم الترحيل في السجل لا يكفي لاستعادة ملفه التنفيذي.

الأرشيف الحالي يضم 14 مصدرًا تاريخيًا مستردًا من QA وثلاثة ملفات ذات أرقام غير مطابقة. بعض المصادر توثق تغييرات تنتمي إلى عدة ترحيلات أو تمثل لقطة نهائية بعد تنفيذها. لا يمكن اعتبارها بديلًا مطابقًا لملفات SQL الأصلية، ولا يجوز نقلها إلى `supabase/migrations` أو تشغيلها على قاعدة التشغيل.

تم فحص فروع GitHub المرتبطة بمراجعة واسترداد الترحيلات، وسجل تغييرات المسار `supabase/migrations`. لم يظهر مصدر تنفيذي إضافي موثوق للترحيلات المفقودة. هذا لا يثبت استحالة وجود نسخة في نسخة احتياطية خارج GitHub، لكنه يحدد ما أمكن إثباته من المصادر المتاحة.

## قائمة الترحيلات التي ينقصها ملف SQL تنفيذي

الأرقام والأسماء أدناه من سجل Supabase الفعلي، بعد استبعاد كل رقم له ملف تنفيذي مطابق في GitHub.

### 2026-11-06 (8)

| Version | Name |
|---|---|
| 20261106211801 | `add_production_order_output_snapshot` |
| 20261106212203 | `create_and_execute_production_orders` |
| 20261106222532 | `add_product_packaging_options` |
| 20261106222546 | `separate_trip_load_approval_and_dispatch_permissions` |
| 20261106222619 | `add_package_aware_trip_load_workflow` |
| 20261106222703 | `support_package_weights_in_sales_invoices` |
| 20261106222710 | `reset_package_weight_per_sales_invoice_item` |
| 20261106222949 | `allow_approved_trip_load_status` |

### 2026-11-07 (26)

| Version | Name |
|---|---|
| 20261107073006 | `remove_legacy_trip_load_approval_function` |
| 20261107082200 | `grant_system_admin_all_permissions_and_trip_load_workflow_view` |
| 20261107085037 | `repair_trip_cash_lifecycle_v1` |
| 20261107144657 | `harden_existing_workflows_and_reports` |
| 20261107144945 | `replace_permissive_table_policies` |
| 20261107145018 | `restrict_audit_reservation_and_stock_policies` |
| 20261107145107 | `restore_accounting_read_reports` |
| 20261107150535 | `accounting_role_idempotent_posting_and_ledger_pl` |
| 20261107150656 | `actual_production_and_weighted_average_stock_cost` |
| 20261107150808 | `restrict_internal_journal_writers_and_correct_financial_summary` |
| 20261107151222 | `repair_sales_return_request_approval_and_inventory_flow` |
| 20261107151231 | `post_cost_of_sales_for_sales_returns_and_exchanges` |
| 20261107151406 | `add_package_option_validation_for_sales_returns` |
| 20261107151455 | `carry_weighted_average_cost_across_stock_transfers_and_returns` |
| 20261107151506 | `preserve_cost_fallback_for_receipts` |
| 20261107151519 | `reverse_return_inventory_at_original_cost` |
| 20261107151535 | `restore_original_cost_when_cancelling_sales_invoice` |
| 20261107151608 | `lock_down_new_sales_return_rpc_overloads` |
| 20261107151705 | `secure_rpc_wrappers_and_consolidate_location_policies` |
| 20261107151718 | `index_unindexed_foreign_key_columns` |
| 20261107151742 | `consolidate_overlapping_rls_policies` |
| 20261107151811 | `remove_remaining_overlapping_permissive_policies` |
| 20261107151915 | `prevent_cash_refund_while_invoice_debt_remains` |
| 20261107151936 | `validate_return_price_against_net_original_line_price` |
| 20261107152108 | `pin_search_path_for_all_security_definer_functions` |
| 20261107152255 | `complete_minya_city_sections_neighborhoods` |

### 2026-11-08 (4)

| Version | Name |
|---|---|
| 20261108132024 | `remove_orphaned_sales_order_rpc_functions` |
| 20261108132046 | `remove_unused_sales_return_rpc_overloads` |
| 20261108132215 | `extend_audit_triggers_to_financial_workflows` |
| 20261108132316 | `split_price_management_rls_policies` |

### 2026-11-09 (41)

| Version | Name |
|---|---|
| 20261109093015 | `allow_negotiated_sales_invoice_prices_within_limits` |
| 20261109094124 | `allow_returns_view_permission_on_sales_return_headers` |
| 20261109095849 | `block_vehicle_locations_in_regular_stock_transfers` |
| 20261109105342 | `add_safe_stock_transfer_reversal` |
| 20261109114015 | `validate_sales_return_item_trip_location` |
| 20261109125723 | `add_cancel_purchase_return_supplier_credit` |
| 20261109125734 | `fix_cancel_purchase_return_location_and_cancel_flag` |
| 20261109125744 | `correct_cancel_purchase_return_invoice_location` |
| 20261109125807 | `harden_cancel_purchase_return_stock_validation` |
| 20261109130157 | `support_cash_bank_purchase_return_cancellation` |
| 20261109130905 | `support_purchase_invoice_cancellation_and_ignore_cancelled_returns` |
| 20261109130930 | `index_purchase_invoice_cancelled_by` |
| 20261109131335 | `secure_adjust_treasury_balance_internal_only` |
| 20261109131945 | `validate_purchase_return_cancellation_totals` |
| 20261109135327 | `link_purchase_documents_to_stock_movements` |
| 20261109135355 | `use_purchase_invoice_id_for_stock_cost` |
| 20261109135411 | `write_purchase_movement_links_explicitly` |
| 20261109142227 | `add_production_cost_allocation_v3` |
| 20261109143329 | `add_source_tracked_production_cost_allocation_v4` |
| 20261109143346 | `tighten_production_v4_source_quantity_checks` |
| 20261109143940 | `restrict_production_execution_to_current_date` |
| 20261109144434 | `normalize_production_v4_quantity_and_cost_precision` |
| 20261109144657 | `normalize_production_input_quantity_precision` |
| 20261109145445 | `add_recovered_source_quantity_tracking_v5` |
| 20261109150021 | `unify_production_inventory_balance_lock_order` |
| 20261109153125 | `remove_orphaned_legacy_inventory_functions` |
| 20261109153438 | `align_supplier_treasury_lock_order_in_purchase_return_cancel` |
| 20261109153755 | `align_cheque_clearing_period_and_treasury_lock_order` |
| 20261109154156 | `align_collection_cheque_period_treasury_lock_order` |
| 20261109154420 | `check_expense_period_before_trip_and_treasury_locks` |
| 20261109154538 | `check_purchase_period_before_invoice_and_return_locks` |
| 20261109154852 | `check_purchase_cancel_period_before_record_locks` |
| 20261109155134 | `check_supplier_payment_period_before_supplier_and_treasury_locks` |
| 20261109155512 | `check_sales_invoice_cancel_period_before_record_locks` |
| 20261109155645 | `check_sales_return_cancel_period_before_record_locks` |
| 20261109155940 | `check_current_period_before_sales_invoice_cancel_stock_locks` |
| 20261109160339 | `include_zero_sales_trips_in_vehicle_load_suggestions` |
| 20261109161503 | `fix_manual_stock_balance_double_adjustment` |
| 20261109161645 | `prevent_opening_stock_balance_double_quantity` |
| 20261109162242 | `fix_sales_return_double_stock_quantity_update` |
| 20261109165658 | `link_stock_movements_to_production_orders` |

### 2026-11-10 (28)

| Version | Name |
|---|---|
| 20261110004117 | `expense_types_and_account_mapping` |
| 20261110010309 | `purchase_landed_cost_workflow` |
| 20261110010328 | `guard_landed_cost_return_reversal` |
| 20261110010423 | `fixed_asset_register_and_purchase` |
| 20261110145028 | `fix_sales_returns_trip_load_sync_expense_journal` |
| 20261110145108 | `harden_trip_load_sync_trigger_functions` |
| 20261110150915 | `fix_trip_settlement_vehicle_return_accounting` |
| 20261110151647 | `add_missing_foreign_key_indexes_2026_11_10` |
| 20261110153337 | `block_vehicle_purchase_invoice_location` |
| 20261110153916 | `block_untracked_vehicle_stock_movements` |
| 20261110164155 | `require_idempotency_for_landed_costs_and_fixed_assets_20261110` |
| 20261110164446 | `normalize_landed_cost_amount_before_cash_posting_20261110` |
| 20261110164548 | `check_permissions_in_idempotent_financial_wrappers_20261110` |
| 20261110164949 | `block_unaccounted_partner_in_kind_contribution_20261110` |
| 20261110170047 | `revoke_direct_partner_transaction_dml_20261110` |
| 20261110172656 | `partner_equipment_in_kind_contribution_20261110` |
| 20261110172926 | `harden_partner_equipment_contribution_link_20261110` |
| 20261110173100 | `harden_partner_equipment_contribution_cancellation_20261110` |
| 20261110173958 | `partner_inventory_in_kind_contribution_20261110` |
| 20261110174011 | `fix_partner_inventory_contribution_integrity_check_20261110` |
| 20261110174102 | `add_partner_inventory_contribution_read_policy_20261110` |
| 20261110174210 | `block_partner_inventory_contribution_cancel_with_active_reservations_20261110` |
| 20261110174325 | `index_partner_inventory_contribution_foreign_keys_20261110` |
| 20261110175616 | `partner_vehicle_in_kind_contribution_20261110` |
| 20261110192829 | `correct_vehicle_asset_account_parent_20261110` |
| 20261110205142 | `partner_other_fixed_assets_contribution_20261110` |
| 20261110211947 | `allow_sales_reps_to_create_customers_in_assigned_areas_20261110` |
| 20261110212115 | `restrict_sales_rep_customer_creation_financial_fields_20261110` |

### 2026-11-11 (48)

| Version | Name |
|---|---|
| 20261111080016 | `allow_supplier_advance_payments_20261111` |
| 20261111084255 | `restrict_notification_management_to_system_admin_20261111` |
| 20261111084901 | `consolidate_customer_insert_rls_policy_20261111` |
| 20261111085038 | `align_accounting_summary_revenue_with_posted_ledger_20261111` |
| 20261111111605 | `add_customer_responsible_sales_rep` |
| 20261111132639 | `enforce_sales_return_cashback_from_representatives_treasury` |
| 20261111135125 | `fix_purchase_return_cancel_cost_validation_scope_20261111` |
| 20261111135703 | `fix_purchase_invoice_cancelled_payments_balance_20261111` |
| 20261111140507 | `strict_landed_cost_cancellation_inventory_value` |
| 20261111141143 | `add_safe_expense_cancellation` |
| 20261111141445 | `exclude_cancelled_expenses_from_financial_summaries` |
| 20261111141512 | `store_expense_cancellation_user_name` |
| 20261111142420 | `reject_negative_stock_inventory_value_20261111` |
| 20261111142941 | `protect_reserved_stock_from_outbound_movements_20261111` |
| 20261111143103 | `complete_reservation_guards_and_fix_production_reversal_20261111` |
| 20261111143858 | `create_lot_traceability_foundation_20261111` |
| 20261111143927 | `backfill_legacy_opening_lot_balances_20261111` |
| 20261111144102 | `link_lot_traceability_to_purchase_sales_and_returns_20261111` |
| 20261111144111 | `link_single_lot_sales_invoice_items_20261111` |
| 20261111144157 | `complete_purchase_lot_idempotency_and_production_expiry_20261111` |
| 20261111144627 | `enable_sales_return_lot_selection_and_validation_20261111` |
| 20261111144756 | `reverse_customer_return_lots_exactly_on_cancel_20261111` |
| 20261111145017 | `index_lot_traceability_foreign_keys_20261111` |
| 20261111145048 | `allow_legacy_purchase_return_without_historical_lot_20261111` |
| 20261111145204 | `preserve_legacy_stock_reversals_without_lot_history_20261111` |
| 20261111145238 | `validate_purchase_lot_dates_and_classify_trip_returns_20261111` |
| 20261111145357 | `scope_sales_lot_lookup_to_return_permissions_20261111` |
| 20261111151446 | `scope_trip_surplus_lot_restore_to_surplus_receipt` |
| 20261111151926 | `restore_exact_sales_invoice_lots_and_cost_on_cancel_20261111` |
| 20261111152231 | `preserve_exact_lots_when_reversing_stock_transfers_20261111` |
| 20261111152400 | `index_expenses_cancelled_by_20261111` |
| 20261111161314 | `fix_treasury_statement_running_balance_order_20261111` |
| 20261111174625 | `fix_partner_opening_balance_double_post_20261111` |
| 20261111181021 | `partner_and_fixed_asset_accounting_20261111` |
| 20261111181100 | `complete_partner_asset_accounting_20261111` |
| 20261111181126 | `partner_profit_transaction_types_20261111` |
| 20261111181135 | `partner_profit_item_request_ids_20261111` |
| 20261111181146 | `partner_profit_distribution_single_journal_20261111` |
| 20261111181211 | `fix_depreciation_mid_month_period_20261111` |
| 20261111181227 | `allow_fixed_asset_disposed_status_20261111` |
| 20261111181241 | `fix_fixed_asset_disposal_treasury_posting_20261111` |
| 20261111181255 | `remove_duplicate_fixed_asset_select_policy_20261111` |
| 20261111181307 | `exact_profit_distribution_rounding_20261111` |
| 20261111181327 | `index_partner_profit_distribution_fks_20261111` |
| 20261111181932 | `fixed_asset_depreciation_configuration_rpc_20261111` |
| 20261111193837 | `product_shelf_life_calendar_months` |
| 20261111195803 | `daily_lot_expiry_notifications` |
| 20261111195903 | `lot_expiry_alert_on_expiry_date` |

### 2026-11-12 (49)

| Version | Name |
|---|---|
| 20261112084411 | `add_direct_production_cost_allocation_v1` |
| 20261112084421 | `improve_sales_return_cost_traceability` |
| 20261112084624 | `tighten_direct_production_cost_validation_v1` |
| 20261112110230 | `revoke_public_execution_from_invoice_status_trigger` |
| 20261112110800 | `secure_fixed_asset_disposal_wrapper` |
| 20261112111021 | `quarantine_unverified_opening_lots` |
| 20261112111101 | `exclude_quarantined_lots_from_expiry_alerts` |
| 20261112111203 | `require_verified_lot_dates_and_shelf_life_for_production` |
| 20261112124959 | `allow_cancel_invoice_after_exact_cancelled_return_reversal` |
| 20261112130714 | `add_system_admin_reset_preview_rpc` |
| 20261112130847 | `fix_admin_reset_preview_purchase_return_flag` |
| 20261112131335 | `expand_admin_reset_preview_blocker_details` |
| 20261112132640 | `add_admin_reset_plan_preparation` |
| 20261112132658 | `fix_admin_reset_plan_hash_extension_schema` |
| 20261112135536 | `separate_admin_reset_phase_plans` |
| 20261112135639 | `isolate_admin_reset_prepare_engine` |
| 20261112140306 | `add_reset_plan_row_backups_and_audit` |
| 20261112140536 | `build_admin_reset_phase1_execution_engine` |
| 20261112140626 | `allow_reset_only_journal_self_link_cleanup` |
| 20261112140712 | `fix_reset_phase1_fk_delete_order` |
| 20261112140806 | `allow_production_delete_only_in_approved_reset` |
| 20261112140848 | `allow_reset_only_movement_self_link_cleanup` |
| 20261112140856 | `delete_reset_user_logs_after_all_audited_updates` |
| 20261112141030 | `include_fixed_asset_links_in_phase1_reset` |
| 20261112141206 | `restrict_internal_reset_audit_rpcs` |
| 20261112141347 | `verify_fixed_assets_removed_in_phase1` |
| 20261112141415 | `lock_down_reset_hash_helpers` |
| 20261112141435 | `include_reset_balance_masters_in_phase1_backup` |
| 20261112141542 | `keep_phase1_execution_locked_until_final_test` |
| 20261112142227 | `allow_admin_reset_vehicle_asset_unlink` |
| 20261112143148 | `add_phase2_reset_engine_locked` |
| 20261112143209 | `fix_phase2_reset_rows_hash_delimiter` |
| 20261112143241 | `normalize_phase2_reset_hash_delimiter` |
| 20261112143318 | `align_phase2_reset_hash_newline` |
| 20261112143329 | `guard_phase2_against_new_operations` |
| 20261112143339 | `grant_scoped_phase2_reset_functions` |
| 20261112143932 | `preserve_sales_rep_master_data_in_phase2_reset` |
| 20261112144609 | `align_phase2_report_preserved_assets_and_fk_blockers` |
| 20261112144743 | `clarify_phase2_preserved_vs_phase1_cleared_assets` |
| 20261112144924 | `classify_recipes_as_phase2_master_data` |
| 20261112145933 | `fix_phase1_stock_balance_reset_order` |
| 20261112150229 | `remove_duplicate_phase1_lot_balance_delete` |
| 20261112153556 | `add_secure_latest_phase1_plan_restore` |
| 20261112153716 | `use_invoker_for_phase1_plan_restore_rpc` |
| 20261112154832 | `preserve_user_logs_in_phase1_reset_and_refresh_plan_hashes` |
| 20261112160818 | `add_single_operation_factory_reset_engine` |
| 20261112160852 | `add_factory_reset_report_restore` |
| 20261112161024 | `correct_factory_reset_preserved_counts` |
| 20261112161305 | `grant_scoped_factory_reset_trigger_guard` |

### 2026-11-13 (25)

| Version | Name |
|---|---|
| 20261113102712 | `add_multi_location_inventory_count_workflow` |
| 20261113102727 | `add_inventory_count_session_list` |
| 20261113102826 | `protect_inventory_count_from_concurrent_movements` |
| 20261113104049 | `register_inventory_locations_and_scope_general_count` |
| 20261113105441 | `add_product_refrigeration_and_location_scoped_inventory_count` |
| 20261113110034 | `fix_inventory_count_create_created_by_insert` |
| 20261113111403 | `add_package_unit_inventory_counting` |
| 20261113111411 | `correct_package_count_conversion_total` |
| 20261113111522 | `include_packaging_plate_units_in_count_details` |
| 20261113113220 | `add_finished_jar_bottle_products_and_complete_container_items` |
| 20261113113255 | `include_jar_and_bottle_units_in_inventory_count` |
| 20261113113441 | `limit_jar_bottle_count_units_to_finished_products` |
| 20261113113547 | `create_exact_boms_for_jar_and_bottle_finished_products` |
| 20261113115200 | `organize_oil_honey_tahini_product_categories` |
| 20261113115241 | `rename_recipe_components_category` |
| 20261113122343 | `add_dynamic_purchase_package_weight` |
| 20261113122556 | `support_dynamic_actual_weights_on_purchase_and_sales` |
| 20261113122940 | `add_fish_frozen_vegetable_cheese_and_pickle_catalog` |
| 20261113123154 | `support_dynamic_weight_units_in_inventory_count` |
| 20261113123334 | `add_duck_count_and_actual_weight_product` |
| 20261113123402 | `add_duck_count_and_actual_weight_product` |
| 20261113141525 | `split_sealed_cheese_products_by_fixed_package_weight` |
| 20261113175654 | `add_finished_poultry_products_and_packaging` |
| 20261113175719 | `correct_poultry_finished_product_codes_and_options` |
| 20261113180011 | `align_gizzards_packaging_options_with_sale_units` |

### 2026-11-14 (26)

| Version | Name |
|---|---|
| 20261114153403 | `factory_reset_data_policy_registry` |
| 20261114153443 | `factory_reset_policy_v3` |
| 20261114153511 | `factory_reset_policy_ui_compat_v2` |
| 20261114153540 | `factory_reset_policy_mode_compat` |
| 20261114153619 | `factory_reset_policy_keep_counts` |
| 20261114163332 | `show_latest_completed_factory_reset_without_auto_prepare` |
| 20261114171320 | `allow_missing_lot_dates_for_packaging_products` |
| 20261114173335 | `harden_cancel_collection_v2_cheque_and_paid_status_20261114` |
| 20261114173516 | `block_cash_collection_on_completed_trips_20261114` |
| 20261114173550 | `align_trip_summary_with_settlement_document_statuses_20261114` |
| 20261114175217 | `add_vehicle_open_trip_guard_and_route_cheque_bounce_through_v2_20261114` |
| 20261114175631 | `grant_authenticated_select_customer_cheques` |
| 20261114182129 | `harden_legacy_reset_and_restore_treasury_master_20261114` |
| 20261114182229 | `restrict_sales_rep_sales_invoice_lot_lookup_20261114` |
| 20261114182750 | `remove_verified_legacy_reset_and_unused_rpc_20261114` |
| 20261114183239 | `persist_sales_rep_on_sales_invoice_creation_20261114` |
| 20261114183626 | `fix_production_waste_json_normalization_20261114` |
| 20261114183725 | `allow_exact_lot_restoration_without_new_shelf_life_check_20261114` |
| 20261114184040 | `release_production_expense_allocations_on_reversal_20261114` |
| 20261114205725 | `set_product_shelf_life_defaults_20261114` |
| 20261114210246 | `set_semi_finished_and_recipe_spices_shelf_life_20261114` |
| 20261114210743 | `require_customer_cheque_due_date_20261114` |
| 20261114212027 | `allow_selected_treasury_for_closed_trip_cashback_20261114` |
| 20261114212154 | `include_partial_invoices_in_customer_receivables_20261114` |
| 20261114212355 | `return_empty_customer_returns_for_sales_rep_20261114` |
| 20261114212609 | `exclude_draft_sales_invoices_from_aged_receivables_20261114` |

### 2026-11-15 (11)

| Version | Name |
|---|---|
| 20261115101357 | `register_customer_credit_tables_for_factory_reset` |
| 20261115103214 | `fix_sales_exchange_conversion_lots_and_journal` |
| 20261115110801 | `preserve_exchange_balance_in_customer_collections` |
| 20261115110824 | `guard_null_trip_record_in_collection` |
| 20261115111120 | `clear_operational_lot_links_before_factory_reset` |
| 20261115114626 | `automatic_master_record_codes` |
| 20261115115037 | `sequential_sales_return_and_inventory_codes` |
| 20261115115301 | `factory_reset_keep_profiles_clear_opening_balances` |
| 20261115122657 | `index_uncovered_foreign_keys_and_remove_duplicate_exchange_index` |
| 20261115141432 | `secure_inventory_count_approval_and_stock_adjustment` |
| 20261115142104 | `separate_inventory_count_entry_from_stock_adjustment` |

### 2026-11-16 (6)

| Version | Name |
|---|---|
| 20261116070146 | `allow_mixed_sales_return_inspection_disposition` |
| 20261116103938 | `final_readiness_security_and_fk_indexes` |
| 20261116103955 | `restrict_accounting_reports_to_authenticated` |
| 20261116140300 | `expose_trip_rep_names_to_trip_viewers` |
| 20261116194916 | `customer_account_collection_auto_allocation` |
| 20261116230948 | `sales_rep_trip_financial_visibility` |

### 2026-11-18 (1)

| Version | Name |
|---|---|
| 20261118170540 | `validate_sales_return_inspection_disposition` |

### 2026-11-19 (6)

| Version | Name |
|---|---|
| 20261119083328 | `add_partner_share_percentage_range_check` |
| 20261119105101 | `fix_trip_stock_reconciliation_customer_returns` |
| 20261119105223 | `add_authorized_sales_return_customer_labels` |
| 20261119121910 | `make_factory_reset_approval_idempotent_and_restore_active_plan` |
| 20261119122052 | `classify_new_operational_tables_for_factory_reset` |
| 20261119134901 | `fix_factory_reset_partner_operational_cycle` |

### 2026-11-20 (1)

| Version | Name |
|---|---|
| 20261120125421 | `fix_factory_reset_treasury_balances_20261120` |

## ملفات الأرشيف الحالية

- `supabase/migration_archive/recovered_2026-11-11/LOT_TRACEABILITY_FUNCTIONS_2026-11-11.sql`
- `supabase/migration_archive/recovered_2026-11-11/LOT_TRACEABILITY_SCHEMA_2026-11-11.sql`
- `supabase/migration_archive/recovered_2026-11-11/QA_CANCEL_SALES_INVOICE_EXACT_LOT_2026-11-11.sql`
- `supabase/migration_archive/recovered_2026-11-11/QA_CUSTOMER_INSERT_RLS_CONSOLIDATION_2026-11-11.sql`
- `supabase/migration_archive/recovered_2026-11-11/QA_DATABASE_FIXES_2026-11-10.sql`
- `supabase/migration_archive/recovered_2026-11-11/QA_FINANCIAL_SUMMARY_LEDGER_FIX_2026-11-11.sql`
- `supabase/migration_archive/recovered_2026-11-11/QA_INDEX_EXPENSES_CANCELLED_BY_2026-11-11.sql`
- `supabase/migration_archive/recovered_2026-11-11/QA_NOTIFICATION_ADMIN_ONLY_2026-11-11.sql`
- `supabase/migration_archive/recovered_2026-11-11/QA_PARTNER_CAPITAL_OUT_GUARD_2026-11-10.sql`
- `supabase/migration_archive/recovered_2026-11-11/QA_RESERVED_STOCK_GUARDS_2026-11-11.sql`
- `supabase/migration_archive/recovered_2026-11-11/QA_REVERSE_STOCK_TRANSFER_EXACT_LOTS_2026-11-11.sql`
- `supabase/migration_archive/recovered_2026-11-11/QA_STOCK_VALUATION_GUARD_2026-11-11.sql`
- `supabase/migration_archive/recovered_2026-11-11/QA_TREASURY_STATEMENT_RUNNING_BALANCE_2026-11-11.sql`
- `supabase/migration_archive/recovered_2026-11-11/QA_TRIP_SURPLUS_RETURN_LOT_SCOPE_2026-11-11.sql`
- `supabase/migration_archive/unmatched_version/20261114220000_fix_customer_receivables_summary.sql`
- `supabase/migration_archive/unmatched_version/20261114224500_guard_closed_trip_cash_reversals.sql`
- `supabase/migration_archive/unmatched_version/20261116090000_fix_sales_return_cancel_full_received_quantity.sql`

## القرار

1. إبقاء ملفات الأرشيف خارج `supabase/migrations`.
2. عدم إعادة تنفيذ أي ملف أرشيف على قاعدة Supabase الحالية.
3. عدم إنشاء ملفات ترحيل فارغة أو تخمينية لتعويض الأرقام المفقودة.
4. استعادة SQL فقط عند العثور على مصدر أصلي يمكن ربطه برقم الترحيل والتحقق من محتواه.
5. استخدام لقطة المخطط الحالية والنسخ الاحتياطية الموثوقة عند الحاجة إلى إعادة بناء قاعدة جديدة، بدل افتراض أن مجلد الترحيلات الحالي يكفي لإعادة البناء من الصفر.

## نطاق الفحص

- قراءة سجل الترحيلات من Supabase.
- قراءة شجرة ملفات GitHub على commit المرجعي.
- مقارنة رقم كل ملف تنفيذي بأرقام الترحيلات المسجلة.
- مراجعة ملفات الأرشيف وملف ربط المصادر التاريخية.
- فحص فروع GitHub المرتبطة باسترداد ومطابقة الترحيلات.
- لم يتم تنفيذ SQL أو تعديل بيانات أو مخطط قاعدة البيانات أو سجل الترحيلات.


## استكمال البحث في المصادر التاريخية — 2026-11-21

تم تنفيذ بحث إضافي عن أول 8 ترحيلات المفقودة بتاريخ 2026-11-06، وهي ترحيلات الإنتاج والتعبئة وأحمال الجولات.

### نتائج فحص تاريخ GitHub

- تمت مراجعة سجل تغييرات المستودع بين 2026-11-06 و2026-11-08، وظهرت 41 عملية commit.
- شجرة المستودع عند commits ممثلة من 2026-11-06 و2026-11-07 تحتوي فقط على `index.html` و`manifest.json` و`sw.js`. لم تكن هناك مجلدات `supabase` أو ملفات SQL في تلك اللقطات.
- سجل تغييرات المسار `supabase/migrations` على الفرع الافتراضي يحتوي 40 commit فقط، وأقدم تغيير ظاهر فيه بتاريخ 2026-11-14. لذلك لا يقدم هذا المسار نسخة أقدم من ترحيلات 2026-11-06.
- البحث عن أسماء الترحيلات الثمانية في ملفات المستودع ورسائل commits لم يُظهر ملفات SQL أصلية.
- البحث في ملفات Library المتاحة عن ملفات SQL تاريخية لم يُظهر أي ملف SQL مطابق يمكن التحقق منه.

### نتيجة أول 8 ترحيلات

لم يتم العثور على نص SQL أصلي موثوق لأي من الترحيلات الثمانية التالية:

- `20261106211801_add_production_order_output_snapshot`
- `20261106212203_create_and_execute_production_orders`
- `20261106222532_add_product_packaging_options`
- `20261106222546_separate_trip_load_approval_and_dispatch_permissions`
- `20261106222619_add_package_aware_trip_load_workflow`
- `20261106222703_support_package_weights_in_sales_invoices`
- `20261106222710_reset_package_weight_per_sales_invoice_item`
- `20261106222949_allow_approved_trip_load_status`

هذا يثبت فقط عدم وجود مصدر مطابق في لقطات GitHub والملفات المتاحة التي فُحصت. لا يثبت عدم وجود نسخة لدى مزود النسخ الاحتياطية أو في جهاز محلي أو تصدير سابق غير متاح.

### القرار

- لا تُنشأ ملفات SQL بديلة اعتمادًا على أسماء الترحيلات أو حالة المخطط الحالية.
- لا تُنقل أي نسخة من كود الواجهة إلى مجلد الترحيلات.
- يبقى استرداد هذه الملفات معلقًا إلى أن يظهر تصدير SQL أصلي أو نسخة احتياطية موثوقة يمكن ربطها برقم الترحيل والتحقق منها.
- لم يتم تنفيذ أي SQL أو تعديل Supabase أو بيانات التشغيل.
