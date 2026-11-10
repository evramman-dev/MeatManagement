# QA Review — Partner In-Kind Contributions
Date: 2026-11-10
Branch: qa/full-cycle-test
Scope: read-only review of the current QA schema, database routines, triggers, account mappings, and the QA web UI.

## Decision
Do not enable `CAPITAL_OUT` for in-kind contributions yet. The existing database guard is intentional and should remain in place until a complete asset-specific posting and reversal workflow exists.

## Verified current state

### Partner transactions
- `partner_transactions` currently has no rows in QA.
- The transaction type constraint includes `CAPITAL_IN`, `WITHDRAWAL`, `PROFIT`, and `CAPITAL_OUT`.
- A BEFORE INSERT / UPDATE trigger named `trg_block_unaccounted_partner_in_kind_contribution` invokes `block_unaccounted_partner_in_kind_contribution()`.
- That trigger rejects every `CAPITAL_OUT` with an explicit message requiring an asset account and journal entry.
- The existing partner transaction routine updates partner balance for CAPITAL_OUT but does not post a journal entry for that type. Removing the guard alone would therefore create an incomplete accounting transaction.
- The UI currently shows the in-kind option disabled with the explanation that it is paused until linked to an asset account.

### Fixed assets
- QA currently contains zero fixed-asset rows.
- The `fixed_assets_asset_category_check` constraint allows only `PRODUCTION_EQUIPMENT`.
- The allowed source types are only `TREASURY` and `SUPPLIER_CREDIT`; their source checks require a treasury or supplier respectively.
- Existing fixed-asset purchase routines hard-code account code `1510` (production machinery and equipment).
- The chart of accounts currently includes:
  - `1300` Inventory
  - `1500` Fixed assets (parent)
  - `1510` Production machinery and equipment
  - `3100` Capital
  - `3400` Opening balances
- There is no approved account mapping for contributed vehicles, contributed inventory, or other asset classes.
- Existing fixed-asset cancellation routines cover cash purchases and supplier-credit purchases. They do not implement a partner-contribution reversal path.

### Inventory and accounting primitives
- `stock_movements` records product, location, quantity, cost, and a self-reference for reversal, but has no partner-contribution reference column.
- Existing movement types include RECEIVE and RETURN. A new partner-contribution path must not reuse a movement type in a way that bypasses source traceability or duplicates existing accounting.
- `stock_balances` tracks quantity, average unit cost, and inventory value by product and location.
- `post_journal_entry` validates balanced journal lines and supports reference-based idempotency.
- `reverse_journal_entries` creates linked reversing entries, but an in-kind cancellation must also reverse the related fixed-asset or stock record and must prevent reversal after downstream use.

### QA UI
- The fixed-assets UI currently creates production machinery/equipment purchases only.
- The partner transaction form keeps CAPITAL_OUT disabled.
- There are no UI fields for contributed asset class, product/quantity/unit/location, vehicle identity, mapped asset account, valuation evidence, or contribution-specific cancellation.

## Required design before implementation

### 1. Shared contribution header
A contribution record should identify the partner, contribution date, agreed value, request UUID, creator, status, notes, and the accounting journal reference. It must preserve an immutable record of the valuation basis and approval.

### 2. Inventory contribution
Required data:
- Product and base-unit quantity, with validated unit conversion.
- Active receiving location that is not a vehicle location.
- Positive documented unit value and total valuation.
- Stock movement linked to the contribution record, with exact cost and a reversible movement reference.
- Balanced accounting: debit inventory account `1300`, credit partner capital account `3100` (subject to accounting approval).
- Cancellation only if the contributed quantity remains available and has not been consumed, sold, transferred, reserved, or otherwise used. If downstream use exists, block simple cancellation and require a separately designed correction workflow.

### 3. Production equipment and other fixed assets
Required data:
- Explicit asset class and approved account mapping.
- Asset name, serial/identity where applicable, acquisition/contribution date, location, valuation, and supporting notes.
- Balanced accounting: debit the mapped asset account, credit partner capital `3100`.
- Asset register record linked to the contribution and journal.
- Reversal must check depreciation, disposal, transfer, and any downstream references before allowing cancellation.

### 4. Vehicle contribution
Do not classify a vehicle as production equipment by default.
- Require vehicle identity and registration details.
- Link it to the fleet/vehicle-location model only after verifying the existing vehicle schema and trip relationships.
- Use a separately approved vehicle asset account.
- Block cancellation if trips, expenses, stock movements, or other operational records already depend on the vehicle.

### 5. Other assets
Do not accept a generic "other asset" until a controlled asset-category-to-account mapping exists and an accountant can select only active approved mappings.

## Mandatory controls
- Authenticated active user and explicit accounting/partner permission.
- Open accounting period on contribution date.
- Positive valuation, active partner, valid asset/product/location, and approved account mapping.
- Request UUID idempotency with exact payload comparison.
- Consistent advisory locking and row locks to prevent duplicate concurrent contributions.
- One balanced posted journal per contribution.
- No direct table DML from client roles; writes only through a validated RPC.
- Contribution status and linked records must change atomically.
- Reversal must be idempotent, linked to the original journal and stock movement/asset, and blocked when the contributed asset has been used.
- Audit trail for creation, approval, cancellation, and valuation changes. Posted valuation should not be edited in place.

## Safe next implementation sequence
1. Finish read-only inspection of the fleet/vehicle schema, fixed-asset dependencies, stock reservation/use paths, and relevant UI handlers.
2. Agree the chart-of-accounts mapping for each supported asset class.
3. Design the contribution header/detail model and RPC signatures.
4. Implement one asset class at a time, starting with the class whose lifecycle and reversal can be fully proven.
5. Test success, duplicate request, altered duplicate payload, invalid account, closed period, insufficient/invalid stock, downstream-use cancellation block, and exact journal/stock/partner balance effects inside rollback transactions.
6. Only then enable the corresponding UI option.

## Changes made in this review
- No database schema, function, trigger, grant, RLS policy, or operational data was changed.
- No UI behavior was changed.
- The existing CAPITAL_OUT guard and disabled UI option remain in place.
- This document records the verified blockers and the implementation gate.

## Additional lifecycle inspection
- No public base table with a name containing `vehicle` or `fleet` was found in the current QA schema.
- No foreign key currently references `fixed_assets`; there is therefore no database-enforced downstream asset dependency graph to rely on for safe cancellation.
- QA currently has one location of type VEHICLE, alongside FACTORY, FRIDGE, MAIN_WAREHOUSE, and SHOWROOM locations.
- These findings strengthen the decision not to treat a vehicle as a fixed asset or to enable generic in-kind cancellation without first designing the vehicle register and its dependencies.

## Implementation update — production equipment contribution (QA)
Implemented in three database migrations:
- `partner_equipment_in_kind_contribution_20261110`
- `harden_partner_equipment_contribution_link_20261110`
- `harden_partner_equipment_contribution_cancellation_20261110`

### Database changes
- Added `fixed_assets.partner_id` and `fixed_assets.partner_transaction_id`, with foreign keys and a unique constraint on the linked partner transaction.
- Added `PARTNER_CONTRIBUTION` as a fixed-asset source, while retaining the existing `PRODUCTION_EQUIPMENT` asset category and account mapping.
- Added an index on `fixed_assets.partner_id` after the performance advisor identified the missing foreign-key index.
- Updated the partner in-kind trigger guard. A direct `CAPITAL_OUT` write is rejected unless it comes through the dedicated RPC, the user has `ACCOUNTING_MANAGE`, and a matching equipment asset exists.
- Added a deferred constraint trigger that checks the asset and partner transaction match on partner, amount, date, request ID, and creator before transaction commit.
- Added `create_partner_equipment_contribution(...)`. It requires an active authenticated user, `ACCOUNTING_MANAGE`, an active partner, an open accounting period, positive value, and a request UUID. It creates the equipment register record, partner `CAPITAL_OUT` record, increases the partner balance, and posts a balanced journal entry: debit `1510`, credit `3100`.
- Added `cancel_partner_equipment_contribution(p_asset_id,p_reason,p_asset_returned_unused)`. Cancellation requires accounting permission and an explicit confirmation that the equipment was returned to the partner and was not put into operation, disposed of, or depreciated. It reverses the original journal, decreases the partner balance, and marks the asset CANCELLED.
- New RPCs have pinned empty search paths, explicit authenticated grants, and no PUBLIC/anon execute grant.

### UI changes on QA
- Enabled the partner contribution source in the fixed-assets form.
- Added an active-partner selector.
- The form routes partner contributions through the dedicated RPC, not the generic partner transaction RPC.
- The fixed-asset list identifies partner-contributed equipment and its partner.
- The cancellation dialog requires an explicit return/unused confirmation and calls the dedicated reversal RPC.

### Verification
All write tests were executed inside transactions and rolled back. No permanent test records remain.
- Authenticated QA tester successfully created a partner equipment contribution.
- Repeating the same request returned the existing asset instead of duplicating it.
- Reusing the same request UUID with a changed amount was rejected.
- Calling the generic partner transaction RPC directly for `CAPITAL_OUT` was rejected.
- The deferred asset-to-partner-transaction integrity trigger was forced to run immediately and passed.
- Cancellation without the return/unused confirmation was rejected.
- Cancellation with the confirmation succeeded in the test transaction. The asset became CANCELLED, partner balance returned to zero, and the reversal journal balanced exactly (debit 600, credit 600).
- Post-rollback QA counts: `fixed_assets=0`, `partner_transactions=0`, partner contribution assets=0, linked contribution assets=0, negative partner balances=0.
- Health advisor: 0 findings.
- Performance advisor: 0 unindexed foreign keys; 92 unused-index informational findings remain.
- Security advisor: 75 authenticated SECURITY DEFINER warnings (the previous 73 plus the two new RPCs, both with explicit auth/permission checks and pinned search paths), plus the existing leaked-password-protection warning on the Free plan.

### Scope and remaining work
- Only production equipment contributions are enabled.
- Inventory, vehicles, and other asset classes remain disabled and require their own accounting, operational, and reversal workflows.
- The QA HTML was updated and statically checked for the new form fields and RPC calls. No browser workflow run was returned for the latest push, so end-to-end UI interaction is not yet claimed as tested.
- No changes were made to `main` or GitHub Pages.
