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
- Performance advisor: one unindexed foreign key remains, expenses.cancelled_by, already tracked as a pre-existing item. It also reports 86 unused indexes; no indexes were dropped because current usage history is not sufficient evidence that they are unnecessary.
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
