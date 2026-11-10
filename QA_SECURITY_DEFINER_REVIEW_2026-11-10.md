# QA Security Definer Review — 2026-11-10

## Scope
Read-only review of public-schema SECURITY DEFINER functions in the MeatManagement QA Supabase project. No database objects, grants, RLS policies, business records, or application runtime code were changed during this review.

## Verified results
The catalog query reviewed 122 SECURITY DEFINER functions in schema public.

| Check | Result |
|---|---:|
| SECURITY DEFINER functions reviewed | 122 |
| Functions executable by anon | 0 |
| Functions executable by authenticated | 73 |
| Functions with pinned search_path | 122 |
| Authenticated-executable functions missing both auth.uid() and has_permission() checks in their function source | 0 |

The 73 authenticated-executable functions each contain either a direct auth.uid() check or a has_permission() check. The remaining SECURITY DEFINER functions are not executable by authenticated or anon according to has_function_privilege checks. This is a source/catalog-level screening, not a substitute for reviewing the business logic of every function.

Supabase Security Advisor currently reports 73 WARN entries for authenticated SECURITY DEFINER execution. The count aligns with the 73 authenticated-executable functions. The warning alone does not establish an exploitable vulnerability. Do not apply blanket REVOKE or convert these functions to SECURITY INVOKER without dependency and behavior testing.

## Other advisor results
- Health advisor: 0 findings.
- Performance advisor: 93 unused_index INFO findings. Do not drop indexes solely on this basis; confirm workload and query plans first.
- Security advisor: 1 auth_leaked_password_protection WARN. This feature is unavailable on the current Free plan according to the previously verified plan limitation. No plan upgrade is assumed.

## Related data-integrity spot checks
At the time of review:
- partner_transactions row count: 0 (temporary partner tests were rolled back).
- negative stock balance rows: 0.
- vehicle stock movements without trip_id: 0.
- active fixed_assets rows: 0.

## Open design item: in-kind partner contributions
Do not enable CAPITAL_OUT or in-kind contributions as a generic fixed-asset entry. Current fixed_assets constraints allow only asset_category = PRODUCTION_EQUIPMENT, and the current purchase RPCs post to account 1510. This is not sufficient for inventory, vehicles, and other asset classes.

Before implementation, define separate validated paths:
1. Inventory contribution: product, base quantity, unit conversion, receiving location, valuation, stock movement, inventory accounting.
2. Production equipment: asset category, asset account, acquisition details, valuation, and reversal.
3. Vehicle: vehicle/asset identity, vehicle location or fleet linkage, valuation, and reversal.
4. Other assets: approved category-to-account mapping and documented valuation.

Each path must create balanced accounting entries, prevent duplicate request IDs, validate user permission and accounting period, and provide a complete cancellation/reversal path that reverses both accounting and the linked operational record. No account code should be assumed for new asset classes.

## Change status
- Database changes in this review: none.
- Application changes in this review: none.
- Main branch and GitHub Pages: untouched.
- QA branch documentation only.
