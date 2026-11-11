# QA Partner Other Fixed Assets Contribution — 2026-11-10

## Scope
Added a controlled partner in-kind contribution path for fixed assets that are not production equipment or vehicles.

## Categories
- FURNITURE — account 1530 — أثاث وتجهيزات
- OFFICE_EQUIPMENT — account 1540 — أجهزة ومعدات مكتبية
- OTHER_FIXED_ASSET — account 1590 — أصول ثابتة أخرى

All three accounts are children of account 1500 الأصول الثابتة and are active ASSET accounts.

## Database changes
- Expanded fixed_assets asset_category check to include the three categories.
- Hardened the deferred partner asset-link check to accept all supported partner fixed-asset categories.
- Hardened the partner CAPITAL_OUT guard to accept the same supported categories.
- Added create_partner_other_asset_contribution().
- Added cancel_partner_other_asset_contribution().
- Both new RPCs use SECURITY DEFINER with an empty search_path.
- EXECUTE is granted to authenticated only and revoked from anon and PUBLIC.
- Creation requires an active signed-in user and ACCOUNTING_MANAGE or PARTNERS_TRANSACTIONS_MANAGE.
- Cancellation requires ACCOUNTING_MANAGE and an explicit confirmation that the asset was returned unused.
- Creation posts debit to the mapped asset account and credit to 3100 رأس المال.
- Cancellation reverses the original journal entry and reduces the partner balance.

## QA data
No permanent test contribution was created.
Existing operational data was not modified.

## UI
QA branch updated to MeatManagement v41.
The fixed-asset form now lets a partner contribution select:
- معدات إنتاج
- سيارة أو مركبة
- أثاث وتجهيزات
- أجهزة ومعدات مكتبية
- أصول ثابتة أخرى

The existing equipment and vehicle RPC paths remain separate.
Other fixed assets use the new generic RPC.
Cancellation routes by the stored asset category.

## Static verification
All 5 script blocks in index.html passed JavaScript parse validation.
No browser workflow was available, so browser UI execution remains open.

## Production branch
main and GitHub Pages were not changed.
