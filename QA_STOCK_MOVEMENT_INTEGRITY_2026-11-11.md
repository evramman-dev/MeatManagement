# QA - Stock movement integrity - 2026-11-11

## Baseline
- Repository: `evramman-dev/MeatManagement`
- Base commit: `72c4ed8074410c55f778618f85709b378ec96c7b`
- App release: v67
- Supabase project: `mklbemoisdkoyrwcrmoj`

## Database review
- 9 stock balance rows.
- No negative quantities, inventory values, or average costs.
- No zero-quantity rows with a non-zero inventory value.
- No average-cost valuation mismatches above 0.01.
- 55 stock movements; none have null or negative unit/total cost and none have zero quantity.
- All stock transfers had matching source/destination movement counts and quantities.
- No active reservations at the time of review.
- Quantity-after sequence matched all 55 movements when ordered by movement_id. Two rows appeared out of sequence when ordered by created_at because a backdated movement was inserted later; this is a timestamp-ordering artifact, not a balance mismatch.
- The current stock transfer and production execution paths use transaction-level advisory locking and row locks. Legacy production v2-v4 and legacy trip stock loader are not executable by authenticated or anon roles.

## Defect found and fixed
The trigger `public.apply_stock_movement_cost()` allowed an inventory value shortfall up to 0.01, then used `GREATEST(...,0)` to hide the deficit. This could silently erase a small valuation shortage.

Migration applied:
`reject_negative_stock_inventory_value_20261111`

The trigger now rejects every negative resulting inventory value. It no longer clamps a deficit to zero.

## Rollback-only tests
- Before the fix, a synthetic issue costing 0.0001 more than the available inventory value was accepted and the value was clamped to zero. The entire probe was rolled back.
- After the fix, the same synthetic shortfall was rejected.
- A valid synthetic issue reduced inventory value by the exact supplied cost.
- Both post-fix probes were rolled back.
- Final checks confirmed the real stock balance was unchanged.

## Lot traceability finding
Lot tracking is not implemented end-to-end yet:
- No lot/batch master table exists in the public schema.
- `sales_invoice_items.lot_id` and `sales_return_items.lot_id` are nullable columns without a foreign key.
- No `lot_id` exists on `stock_movements`.
- Existing sales and return rows have no lot assignment.
- The current frontend passes `p_lot_id: null` for sales returns and does not provide lot selection.

Do not treat the existing `lot_id` columns as working traceability. A proper lot design must track quantities by product, lot, and location, and preserve allocations through receipts, production, transfers, sales, returns, and reversals.

## Security notes
The Supabase security advisor reports broad SECURITY DEFINER execute warnings. The reviewed stock-writing entry points check authenticated identity and application permissions; the old production and trip stock overloads checked in this review are not executable by authenticated or anon roles. The separate leaked-password-protection advisor warning is outside this inventory change.

## Release
- App version: v68
- Service Worker cache: `meat-v101`
- No real financial or inventory records were changed by the QA probes.
