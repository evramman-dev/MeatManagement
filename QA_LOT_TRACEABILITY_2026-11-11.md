# MeatManagement - Lot Traceability QA
Date: 2026-11-11
Release candidate: v70
Service Worker cache: meat-v103

## Scope
Implemented the first operational Lot traceability layer across purchasing, production, sales, customer returns, stock transfers, trip dispatch/settlement, and stock balance reporting.

## Database structure
- `stock_lots`: lot identity, product, source type, supplier lot code, manufacturing date, expiry date, status, and source document links.
- `stock_lot_balances`: quantity for each lot at each location.
- `stock_movement_lot_allocations`: exact inbound/outbound lot allocations for each stock movement.
- Purchase invoice items now store supplier lot code, manufacture date, and expiry date.
- Products now store optional `shelf_life_days`; production output lots calculate expiry from the configured product shelf life.
- Production orders store the generated `output_lot_id`.
- Stock movements now link sales invoice/return headers and invoice/return item lines.

## Operational behavior
- Purchase receipts create one lot per purchase invoice item.
- Production output creates a lot linked to the production order.
- Production raw material issues use FEFO.
- Sales issues use FEFO and link the exact lot allocations to the sales invoice item.
- A single-lot sales item also populates its legacy `lot_id`; multi-lot lines retain all allocations in the allocation bridge.
- Stock transfers and vehicle load dispatch preserve the same lot identities from source to destination.
- Trip surplus returns reuse the lot allocations consumed by the trip-return issue.
- Customer returns can select a lot sold on the original invoice. The database rejects a tracked return without a lot selection and prevents returning more than the quantity sold from that lot.
- Canceling a customer return removes the same lot quantities that the return previously received.
- Supplier returns consume the lot tied to the original purchase invoice item.
- Purchase invoice cancellation and production reversal use their original movement references to reverse the same lots.
- Outbound movements cannot consume expired, quarantined, or closed lots. FEFO sorts by earliest expiry, then receipt date.

## Legacy stock
Current balances were seeded as 4 opening lots, one per positive product/location balance.
Total lot balance quantity equals the current stock balance quantity for all 9 stock balance rows.
Historical supplier lot codes, production dates, and expiry dates were not fabricated. Opening lots are clearly marked as legacy/untraceable.
Historical movements were not assigned fabricated lot allocations.

## Rollback-only tests
1. Purchase RPC created a lot linked to its invoice item and saved supplier lot code, manufacture date, and expiry date. Invoice, journal, treasury/stock changes, and lot were rolled back.
2. FEFO selected the earliest-expiry lot for an outbound movement. A generic inbound movement created a new lot. All changes were rolled back.
3. Transfer-out and transfer-in retained the same lot ID at the destination. All changes were rolled back.
4. Sales issue movement linked to its sales invoice item; secure lot lookup returned the consumed lot. All changes were rolled back.
5. Customer return item accepted the exact lot sold on the invoice. The same tracked invoice rejected a return without selecting a lot. Both test returns were rolled back.
6. Customer return cancellation movement consumed the exact lot previously received by that return. All changes were rolled back.
7. A customer return tied to a tracked sales invoice was rejected when no lot was selected, and accepted when the exact sold lot was selected. All test return headers/items were rolled back.
8. Canceling a customer return consumed the exact lot that the return had received. All changes were rolled back.
9. A purchase return consumed the exact lot linked to its purchase invoice item. The invoice, supplier credit, journal, stock, and lot changes were rolled back.
10. A historical purchase return without a recorded source lot used the opening lot fallback. All changes were rolled back.
11. Historical reversals without lot allocations used a safe untraced fallback. Historical transfer-in without source allocations created an untraced destination lot. All changes were rolled back.
12. Production receipt created a production lot, linked it to the production order, and calculated expiry from product shelf life. All changes were rolled back.
13. Expired-only stock was rejected for outbound issue. All changes were rolled back.

## Final integrity checks
- Stock movements: 55, unchanged.
- Stock balance rows: 9, unchanged.
- Lot master rows: 4 opening lots.
- Lot balance rows: 4.
- Movement lot allocations persisted: 0. Historical movements were intentionally left unassigned; all test allocations were rolled back.
- Active reservations: 0.
- No real invoice, return, production order, treasury transaction, or stock balance was changed.
- Authenticated users can read lot tables only through RLS policies. Anonymous users cannot read them.
- Trigger function execution is revoked from authenticated users. The sales-invoice lot lookup RPC is permission-checked.

## UI
- Purchase invoice item rows now accept supplier lot code, manufacture date, and expiry date.
- Product form now accepts shelf life in days for manufactured products.
- Stock page now shows lot balances, source, location, supplier lot code, manufacture date, expiry date, and expiry warnings.
- Customer return form loads lot choices from the original invoice and submits the selected lot ID.

## Remaining follow-up
- Run a real end-to-end user acceptance test in the live app after Pages deploys.
- Add optional lot-level history drill-down from the stock card and sales invoice detail screen.
- Review existing historical purchases and returns only where reliable source documents exist. Do not fabricate old lot data.
- Confirm each manufactured product's shelf life with the business before entering values.

## Deployment
- PR #27 was merged into main.
- GitHub Pages deployment workflow succeeded: https://github.com/evramman-dev/MeatManagement/actions/runs/43043035247
- JavaScript check workflow succeeded: https://github.com/evramman-dev/MeatManagement/actions/runs/43043035487
- Main index.html is v70 (583,891 characters; blob SHA 5a4be7ed7642f76d45c775859cf326a43699a4d0).
- sw.js cache is meat-v103 (blob SHA 58b5b5ed2e342fe720f79a4ee7c9cf02c2adaeda).
- The live page has not been visually inspected in a browser session.


## Compatibility and advisors
- Existing pre-v70 purchase returns and stock reversals have no historical lot allocations. The trigger falls back to FEFO/opening lots for these legacy documents instead of blocking valid old workflows or inventing historical lot identities.
- New supplier returns use the exact purchase invoice item lot when one exists.
- New reversals use exact source movement allocations. Legacy reversals with no source allocations use the explicit untraced fallback.
- Added indexes for all new lot-related foreign keys flagged by the Supabase performance advisor. The remaining unindexed foreign-key finding is the pre-existing `expenses.cancelled_by` relation.
- The security advisor reports the new `get_sales_invoice_lot_allocations` RPC because it is SECURITY DEFINER and executable by authenticated users. This is intentional: the RPC requires RETURNS_CREATE or RETURNS_MANAGE and verifies that the source invoice is posted/paid/partial. Anonymous execution is revoked.


## End-to-end purchase → sale → customer return → cancellation test (2026-11-11)
- Executed as an authenticated SYSTEM_ADMIN test context inside one explicit database transaction.
- Created a rollback-only purchase invoice for product 1 (لحمة كولاطة), 0.5 KG, at location 3, with a supplier lot code, manufacture date, and expiry date. The purchase receipt created its linked lot.
- Created a credit sales invoice for customer 3 from location 3, selling 0.25 KG of the same product. FEFO consumed the exact lot created by the test purchase.
- Created a customer return linked to that sales invoice for 0.10 KG, explicitly selecting the same lot. Posting the return received the quantity into that exact lot.
- Cancelled the customer return. The cancellation movement consumed the same lot that the return had received.
- The lot balance after cancellation was 0.25 KG, matching the expected balance after the 0.25 KG sale and before return.
- All assertions passed. The transaction was rolled back in full.

### Post-rollback verification
- Stock movements remained 55.
- Stock lots remained 4.
- Lot balance rows remained 4.
- Purchase invoices remained 6.
- Sales invoices remained 10.
- Sales returns remained 2.
- Product 1 at main warehouse location 3 remained 8.7500 KG.
- No test invoice, return, movement, lot, journal entry, or treasury transaction from this end-to-end test persisted.

### Existing QA production orders visible in the app
- The two completed production orders visible to the user (PRD-20261110-000004 and PRD-20261110-000005) were created on 2026-11-10 before the lot-traceability migration was applied.
- Their output_lot_id values are NULL because their historical production movements predate lot tracking. They were not modified or reversed, and no historical lot identity was fabricated.

### Latest security and performance review
- Public SECURITY DEFINER functions: 133 total.
- SECURITY DEFINER functions executable by authenticated users: 83.
- SECURITY DEFINER functions executable by anon: 0.
- A targeted review found no authenticated-executable SECURITY DEFINER function lacking both an auth.uid() check and a has_permission(...) check. Supabase still reports the 83 authenticated SECURITY DEFINER functions as warnings for manual review; this is not treated as a reason to revoke application RPC access indiscriminately.
- Performance advisor initially identified expenses.cancelled_by as unindexed. Added index idx_expenses_cancelled_by via migration index_expenses_cancelled_by_20261111. The latest advisor no longer reports unindexed foreign keys. It reports 87 unused indexes, including the new index before it has accumulated usage; no indexes were dropped because current usage history is not sufficient evidence that they are unnecessary.
- Health advisor returned no findings.


## End-to-end production execution and reversal test (2026-11-11)
- Executed in a separate authenticated SYSTEM_ADMIN transaction and rolled back in full.
- Received 1.0 KG of raw product 1 into factory location 2 through a rollback-only purchase invoice. The receipt created raw lot 23.
- Created a draft production order from recipe 2 (ground meat, 1 KG output) and executed it using production RPC v5.
- Production consumed 1.0 KG from the exact raw purchase lot 23 and created output lot 24, linked to the production order output_lot_id.
- Reversed the completed production order. The reversal restored the exact raw lot 23 and consumed the exact output lot 24. The production cost journal reversal also succeeded.
- Before transaction rollback, the raw lot balance returned to 1.0000 KG, output lot balance returned to 0.0000 KG, and order status changed to CANCELLED.

### Post-rollback verification for production test
- Stock movements remained 55, stock lots remained 4, and stock lot balance rows remained 4.
- Production orders remained 2. The temporary order PRD-20261111-000006 did not persist.
- No temporary QA-PRD lot, production journal, or production order remained.
- Factory raw product 1 and finished product 2 balances both remained 0.0000 KG.


## Trip sale, settlement, and completed-trip customer return regression (2026-11-11)
- The first end-to-end attempt exposed a trigger-order bug: the trip-surplus branch treated every RETURN movement with a trip_id as a surplus receipt. A customer return after trip settlement therefore compared the customer-return quantity against the earlier surplus movement quantity and raised a false mismatch.
- Applied Supabase migration scope_trip_surplus_lot_restore_to_surplus_receipt. The surplus-lot restoration branch now requires sales_return_id IS NULL and a receipt note beginning with the exact prefix 'استلام فائض جولة '. Customer-return movements proceed to the dedicated customer-return lot restoration branch.
- Re-ran the full rollback-only path: management requested and approved 0.5 KG, WAREHOUSE_KEEPER confirmed dispatch, a trip invoice sold 0.2 KG from the dispatched lot, settlement returned 0.3 KG surplus, a completed-trip customer return received 0.1 KG into the same lot, and cancellation consumed that same lot.
- All assertions passed. The trip completed, the invoice balance returned to 60.000 after return cancellation, warehouse stock was 8.5500 KG during the transaction, and vehicle stock was 0.0000 KG. The lot balances matched each movement exactly.
- The entire test transaction was rolled back. Post-rollback counts remained 55 stock movements, 4 lots, 4 lot-balance rows, 4 trips, 10 sales invoices, 2 sales returns, and 3 trip-load rows. Product 1 stock remained 8.7500 KG in the main warehouse and 0.0000 KG in the vehicle.
- The standalone surplus-only dispatch and settlement test also passed before the fix. The post-fix end-to-end test confirms surplus restoration still works while customer returns no longer enter that branch.
- No index.html or sw.js change was needed. Application release remains v70 / meat-v103; this was a database trigger correction only.


## Trip-load role separation regression (2026-11-11)
- Tested with separate SYSTEM_ADMIN and WAREHOUSE_KEEPER authentication contexts inside a rollback-only transaction.
- WAREHOUSE_KEEPER was denied when attempting to approve a load request.
- SYSTEM_ADMIN was denied when attempting to confirm the physical dispatch.
- SYSTEM_ADMIN successfully approved the request, and WAREHOUSE_KEEPER successfully confirmed the actual dispatch.
- The two denied attempts created no stock movements and did not change the APPROVED load state. The authorized dispatch then created the expected two transfer movements and changed the load to LOADED.
- All test rows and movements were rolled back.

## Auth security advisor limitation (2026-11-11)
- Supabase Auth advisor reports leaked-password protection disabled.
- Supabase documentation confirms this feature is available on Pro and higher plans. The MeatManagement organization is currently on the Free plan, so this setting cannot be enabled without a paid plan change.
- No plan upgrade or billing change was made. This remains a documented Free-plan limitation.


## Sales invoice cancellation exact-lot and cost reversal regression (2026-11-11)
- The first rollback-only test found that cancelling a sales invoice restored quantity into a newly created RETURN lot instead of the exact lot consumed by the invoice.
- Applied Supabase migration restore_exact_sales_invoice_lots_and_cost_on_cancel_20261111. Each cancellation movement now links to the matching original ISSUE movement by sales_invoice_id and sales_invoice_item_id, and copies its original unit_cost and total_cost.
- Re-tested with two separate invoice lines for the same product. Both cancellation movements linked to their own original ISSUE movement and restored the exact purchased lot. This also verified duplicate-product invoice lines are matched independently.
- Both cancellation movements restored the exact original cost. The warehouse inventory value after cancellation matched the value immediately before the sale.
- The existing invoice-status trigger created two posted SALES_COGS_LINE_REV journal entries. No original posted COGS entry remained unreversed.
- The invoice reached CANCELLED status. During the transaction, product stock returned to 9.2500 KG and the original lot balance returned to 0.5000 KG.
- The full test transaction was rolled back. Post-rollback counts remained 55 stock movements, 4 lots, 4 lot-balance rows, 6 purchase invoices, 10 sales invoices, 2 sales returns, and 65 journal entries. No QA-SC lot remained. Main warehouse product 1 stock remained 8.7500 KG with inventory value 424.0384.
- No UI code changed. Application release remains v70 / meat-v103; this was a database cancellation correction only.


## Active-trip sales invoice cancellation regression (2026-11-11)
- Re-tested sales invoice cancellation while the related trip was still ACTIVE.
- The cancellation movement reversed the exact original ISSUE movement and restored the exact dispatched lot.
- Trip-load synchronization removed the cancelled invoice from the sold quantity (quantity_sold returned to 0.0000 KG).
- The trip then settled successfully. The full 0.5 KG load returned from vehicle to source using the same lot.
- Final in-transaction state: trip COMPLETED, main warehouse product 1 = 8.7500 KG, vehicle product 1 = 0.0000 KG, and lot balances matched.
- The complete transaction was rolled back. Post-rollback counts remained 55 stock movements, 4 lots, 4 lot-balance rows, 4 trips, 10 sales invoices, 2 sales returns, 3 trip-load rows, and 65 journal entries. No QA lots remained.


## Stock transfer reversal competing-lot regression (2026-11-11)
- The first rollback-only test exposed a lot-identity defect: reversing a transfer used FEFO at the destination instead of reversing the exact original TRANSFER_IN allocation. With a competing destination lot expiring earlier, the reversal consumed the wrong lot.
- Applied Supabase migration preserve_exact_lots_when_reversing_stock_transfers_20261111. The reverse TRANSFER_OUT now references the original TRANSFER_IN movement, and the reverse TRANSFER_IN references the original TRANSFER_OUT movement through reversal_of_movement_id. Original unit_cost and total_cost remain preserved.
- Re-tested with a destination competing lot expiring in 1 day and a transferred source lot expiring in 30 days. The original transfer used source lot 31. Both reversal movements then used lot 31, and the competing destination lot was not consumed.
- In-transaction balances after reversal: source warehouse 9.2500 KG, destination fridge 3.2500 KG, and the transferred lot was restored to 0.5000 KG at source with 0 at destination.
- The full transaction was rolled back. Post-rollback counts remained 55 stock movements, 4 lots, 4 lot-balance rows, 6 stock transfers, 0 transfer-reversal records, and 6 purchase invoices. No QA lots remained. Main warehouse product 1 stayed at 8.7500 KG and fridge product 1 at 2.7500 KG.
- This test specifically verifies that reversal does not consume an unrelated earlier-expiry lot.


## Foreign-key index cleanup (2026-11-11)
- Added btree index public.idx_expenses_cancelled_by on public.expenses(cancelled_by) through migration index_expenses_cancelled_by_20261111.
- Confirmed the index exists and the latest Supabase performance advisor no longer reports any unindexed foreign keys.
- No existing indexes were dropped. The unused-index advisory count temporarily increased to 87 because the new index has not yet accumulated query usage.


## Purchase return cancellation exact-lot and accounting regression (2026-11-11)
- Executed a rollback-only purchase of 0.5 KG, followed by a supplier-credit purchase return of 0.2 KG and cancellation of that return.
- The purchase return consumed the exact lot created by the original purchase. Cancellation referenced the original negative return movement and restored the same lot.
- Original and reversal movement costs matched. Inventory value returned to its level immediately before the purchase return.
- The purchase return was marked cancelled and one posted journal reversal was created for the original PURCHASE_RETURN entry.
- During the transaction, the original lot returned to 0.5000 KG and warehouse product 1 returned to 9.2500 KG.
- The full transaction rolled back; no test invoice, return, lot, movement, or journal entry persisted.


## Customer collections, payment methods, expenses, supplier payments, and treasury regression (2026-11-11)
- Reviewed the existing QA record first. The prior recorded rollback tests covered purchase/sales/returns, production, trip dispatch/settlement, and lot reversals; this batch adds financial settlement coverage not previously recorded.
- Cash customer collection: created a rollback-only sales invoice, collected 10 EGP against it, and cancelled the collection. Invoice paid amount returned to 0, remaining amount returned to 30 EGP, status returned to POSTED, treasury deposit and withdrawal both existed, and one posted journal reversal referenced the original COLLECTION journal.
- Bank transfer and Instapay collections: each posted 10 EGP to its mapped treasury, then cancellation restored each treasury and created one posted journal reversal.
- Cheque collection: received a 10 EGP cheque into treasury 10, then cleared it. The cheque status became CLEARED, 10 EGP moved from the cheque treasury to bank treasury 7, and one CHEQUE_CLEARING journal entry posted. After cancelling the bank and Instapay collections, the invoice retained exactly 10 EGP paid through the cleared cheque and 140 EGP remaining.
- Expense: created and cancelled a 5 EGP hospitality expense. Treasury cash was restored and one posted journal reversal referenced the original EXPENSE entry.
- Supplier payment: created and cancelled a 1 EGP supplier payment. The supplier outstanding balance returned exactly to its pre-test value of 0.00 EGP; treasury movements and one posted journal reversal were verified.
- Treasury transfer: transferred 10 EGP from the main cash treasury (ID 5) to bank treasury (ID 7). The source and destination movements were paired, balances changed by the exact amount, and one posted inter-account journal was recorded.
- Idempotency: repeated the same request ID for customer collection, expense, supplier payment, and treasury transfer. Each RPC returned the original record/transaction ID without duplicate rows; treasury transfer retained exactly two paired transactions.
- Reconciliation: all 9 active treasury balances matched opening balance plus treasury transactions exactly (difference 0.00 for every treasury). The posted journal-entry lines contained 0 unbalanced entries.
- All tests ran in explicit transactions and were rolled back. Post-test counts remained 55 stock movements, 4 lots, 6 purchase invoices, 10 sales invoices, 2 sales returns, 11 customer collections, 1 expense, 2 supplier payments, 29 treasury transactions, 65 journal entries, and 2 customer cheques. No test invoice, collection, expense, payment, transfer, cheque, or journal entry from this batch persisted.
- No production database correction was required in this batch. Application remains v70 / meat-v103; no index.html or sw.js update was necessary.


## Treasury statement running-balance ordering fix (2026-11-11)
- Financial workflow regression covered customer cash collection and cancellation, bank transfer and cancellation, Instapay and cancellation, cheque receipt and clearing, expense creation/cancellation, supplier payment/cancellation, and cash-to-bank treasury transfer. All passed in rollback-only transactions.
- Idempotency checks passed for customer collection, expense, supplier payment, and treasury transfer: retrying an identical request ID returned the original ID and created no duplicate transaction.
- Reconciled all 9 active treasuries. Every current_balance exactly matched opening_balance plus the net of DEPOSIT, WITHDRAW, TRANSFER_IN, and TRANSFER_OUT movements; all differences were 0.00.
- Posted journal-entry lines contained zero unbalanced entries.
- Reviewing get_treasury_statement exposed a running-balance issue for multiple transactions sharing the same created_at timestamp. The prior window used the default RANGE frame and ordered only by created_at, causing peer rows to display the same cumulative balance.
- Applied migration fix_treasury_statement_running_balance_order_20261111. The statement now orders by created_at and transaction_id and uses ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW, giving every transaction its own sequential balance.
- Re-tested treasury 5. Two deposits sharing one timestamp now show 695.00 then 845.00, two withdrawals sharing one timestamp show 950.00 then 940.00, and the final running balance equals the live treasury balance 1065.00.
- All financial workflow tests rolled back. Counts remained 55 stock movements, 4 lots, 6 purchases, 10 sales, 2 sales returns, 11 collections, 1 expense, 2 supplier payments, 29 treasury transactions, 65 journal entries, and 2 cheques. No test data persisted.
- Database-only function correction. App remains v70 / meat-v103; no index.html or sw.js update was needed.


## Financial reports and trial balance reconciliation (2026-11-11)
- Called both get_aged_receivables and get_aged_receivables_v2 as SYSTEM_ADMIN. Both returned zero rows, consistent with no currently overdue/open receivable rows in these reports.
- get_supplier_payable_balances returned supplier 1 payable 967.50 EGP; suppliers 2 and 3 returned 0.00 EGP. This agrees with the current supplier payable total of 967.50 EGP.
- get_financial_summary returned revenue 1,265.00 EGP, COGS 239.8846 EGP, expenses 10.00 EGP, cash 1,145.00 EGP, accounts receivable 0.00 EGP, accounts payable 967.50 EGP, and net profit 1,015.1154 EGP. Net profit equals revenue minus COGS minus expenses.
- get_trial_balance for 2000-01-01 through 2026-11-11 returned total debits 10,098.77 EGP and total credits 10,098.77 EGP; difference 0.00 EGP.
- get_treasury_statement permission check: anon EXECUTE=false; authenticated EXECUTE=true. The function still requires TREASURIES_VIEW or ACCOUNTING_VIEW internally.
- The earlier financial workflow QA and treasury statement fix are documented in this same QA record. No live financial data was changed.


## Partner capital and fixed-assets QA (2026-11-11)
- Reviewed the existing partner and fixed-asset schema/functions before testing. The production database currently has 0 partner rows, 0 partner transactions, 0 partner inventory contributions, and 1 fixed-asset row. The existing fixed-asset row is an already-cancelled QA supplier-credit asset; it was not modified.
- Found a confirmed defect in `set_partner_opening_balance_v2`: the function created a manual journal adjustment and updated `partners.current_balance`, while the `post_partner_opening_balance_adjustment` trigger independently created a second journal entry and increased `current_balance` again. A rollback-only reproduction with an opening-balance change of 100 produced `opening_balance=100`, `current_balance=200`, one manual adjustment, and one trigger-generated entry.
- Applied migration `fix_partner_opening_balance_double_post_20261111`. The v2 RPC now sets a transaction-local guard around its update. The trigger skips only that guarded update; the RPC retains the idempotent manual adjustment and its own single balance update. Direct use of the legacy opening-balance setter continues to use the trigger path.
- Re-tested the v2 setter in a rollback-only transaction: opening balance 0 → 100 → 80, then repeated the same request ID. Final in-transaction values were opening_balance=80 and current_balance=80, with exactly 2 manual adjustments/entries and 0 duplicate trigger entries. The legacy setter was separately tested and correctly produced opening_balance=40, current_balance=40, and exactly one trigger-generated journal entry.
- Tested partner cash movements in a rollback-only transaction: CAPITAL_IN 50, WITHDRAWAL 10, and PROFIT 5. Result: partner balance 35, treasury 5 balance 1100 from 1065, 3 partner transactions, 3 posted journal entries, and 0 unbalanced entries.
- Tested a partner equipment contribution of 70 and its cancellation. The fixed asset linked to its partner transaction, cancellation marked the asset CANCELLED, partner balance returned to 0, and the original partner transaction/journal linkage remained traceable.
- Tested fixed-asset cash purchase, same-request idempotent replay, and cancellation. Tested supplier-credit asset purchase and cancellation. Both assets reached CANCELLED, cash purchase produced exactly one reversal entry, and treasury 5 returned to its starting balance of 1065.
- All partner and fixed-asset test transactions were rolled back. No partner, asset, treasury, supplier, or journal test rows persisted.
- No depreciation schedule, depreciation posting function, asset disposal/sale function, or partner summary view was found in the current public schema. Depreciation and disposal remain unimplemented follow-up scope; no unsupported accounting workflow was invented.
- No `index.html` or `sw.js` change was required. Application release remains v70 / meat-v103.


### Post-fix integrity and advisor checks
- After all rollback-only tests, partners remained 0, partner_transactions 0, partner_inventory_contributions 0, fixed_assets remained 1 (the pre-existing cancelled QA asset), and active fixed assets remained 0.
- Treasury 5 remained 1065.00. Journal entries remained 65. No test rows persisted.
- Trial balance remained balanced: debit 10098.77, credit 10098.77, difference 0.00.
- Latest Supabase security advisor: 83 existing authenticated SECURITY DEFINER RPC warnings and 1 leaked-password-protection warning. The latter is the previously documented Free-plan limitation. No new public/anon execution issue was introduced by this migration.
- Latest performance advisor: no unindexed foreign-key finding; 86 unused-index informational findings remain. No index was removed.
- Latest health advisor: no findings.
- Migration history confirms `20261111174625 fix_partner_opening_balance_double_post_20261111` is applied.


## Partner accounts and fixed-assets accounting completion (2026-11-11)
- Implemented partner ledger reporting through `get_partner_ledger(partner_id)`. The ledger starts from the partner opening balance and calculates a deterministic running balance ordered by transaction date and transaction ID.
- Added profit-distribution records and item detail tables. `create_partner_profit_distribution` calculates the period profit from the existing P&L report, distributes it by active partner ownership percentages, assigns any rounding remainder to the final partner, creates one balanced journal entry for the distribution, and records each partner allocation.
- Added `PROFIT_ALLOCATION` and `PROFIT_ALLOCATION_REVERSAL` partner transaction types. Profit allocation increases the partner balance without withdrawing cash. Cancellation reverses the distribution journal and removes the allocated amount from partner balances.
- Implemented straight-line fixed-asset depreciation. Assets now support useful life in months, residual value, depreciation method, accumulated depreciation, and depreciation history. Each asset can be depreciated once per month, with request-id idempotency. The monthly amount is capped at the remaining depreciable value.
- Implemented depreciation cancellation using a posted reversal journal and reduction of accumulated depreciation.
- Implemented fixed-asset disposal/sale. The workflow calculates net book value and gain/loss, records proceeds in the selected treasury, removes the asset cost and accumulated depreciation from the books, and marks the asset DISPOSED. Gain uses account 4400 and loss uses account 5700.
- Added account 1580 for accumulated depreciation and 5800 for depreciation expense, plus 4400 for disposal gains and 5700 for disposal losses.
- Expanded fixed-asset status to ACTIVE, CANCELLED, and DISPOSED.
- Added RLS policies for the new accounting tables and restricted their reads to users with ACCOUNTING_VIEW. New write functions require ACCOUNTING_MANAGE.
- Added indexes for the two new partner-profit foreign keys after the performance advisor identified them.
- Fixed a mid-month accounting-period compatibility issue in depreciation: the period check uses the actual depreciation date while the stored depreciation month remains the calendar month.
- Rollback-only partner tests passed for ledger movement, profit distribution with rounding, and distribution cancellation. Partner rows and transactions returned to zero after rollback.
- Rollback-only fixed-asset tests passed for purchase, straight-line depreciation, idempotent depreciation retry, depreciation cancellation, disposal for a 20 EGP gain, treasury movement, and balanced disposal journal. Treasury 5 returned to 1065.00 after rollback.
- Post-test database state: partners 0, partner_transactions 0, profit_distributions 0, depreciation_entries 0, fixed_assets 1, active fixed assets 0, treasury 5 = 1065.00.
- Full journal-line reconciliation remains balanced at debit 10098.77, credit 10098.77, difference 0.00.
- Latest performance advisor reports no remaining unindexed foreign keys from the new partner-profit tables. The existing unused-index findings remain informational and no indexes were removed.
- Latest security advisor warnings are the existing authenticated SECURITY DEFINER review set plus the newly added accounting RPCs. The new RPCs require auth.uid() and ACCOUNTING_MANAGE or ACCOUNTING_VIEW as appropriate. Anonymous execution is revoked for the new write/report functions.
- No index.html or sw.js change was required. Application remains v70 / meat-v103.


## Accounting UI integration (2026-11-11)
- Updated index.html to expose the completed partner and fixed-asset accounting workflows inside the existing Android-first screens.
- Partner screen now opens the deterministic partner ledger RPC, shows ownership percentage and current balance, and provides profit-distribution and cancellation actions for users with ACCOUNTING_MANAGE.
- Fixed-asset screen now exposes depreciation configuration, monthly depreciation posting, disposal/sale, gain/loss handling, and book-value information.
- Fixed-asset depreciation configuration is saved through the protected `configure_fixed_asset_depreciation` RPC and cannot be changed after depreciation has started.
- Existing purchase and cancellation workflows were retained. No existing transaction or accounting UI was removed.
- PWA cache was bumped from meat-v103 to meat-v104 so the new index.html is refreshed for clients.
- No live accounting data was changed by the UI integration.
- DB regression state remains: partners 0, partner_transactions 0, profit_distributions 0, depreciation_entries 0, fixed_assets 1, active fixed assets 0, treasury 5 = 1065.00, journal lines balanced with difference 0.00.
