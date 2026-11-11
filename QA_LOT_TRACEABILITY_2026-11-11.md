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
PR is the release candidate. GitHub Pages deployment/live UI has not been confirmed yet.


## Compatibility and advisors
- Existing pre-v70 purchase returns and stock reversals have no historical lot allocations. The trigger falls back to FEFO/opening lots for these legacy documents instead of blocking valid old workflows or inventing historical lot identities.
- New supplier returns use the exact purchase invoice item lot when one exists.
- New reversals use exact source movement allocations. Legacy reversals with no source allocations use the explicit untraced fallback.
- Added indexes for all new lot-related foreign keys flagged by the Supabase performance advisor. The remaining unindexed foreign-key finding is the pre-existing `expenses.cancelled_by` relation.
- The security advisor reports the new `get_sales_invoice_lot_allocations` RPC because it is SECURITY DEFINER and executable by authenticated users. This is intentional: the RPC requires RETURNS_CREATE or RETURNS_MANAGE and verifies that the source invoice is posted/paid/partial. Anonymous execution is revoked.
