# QA - Reserved stock protection - 2026-11-11

## Finding
The reservation feature already prevented users from reserving more than on-hand stock and locked the matching stock balance. However, several stock-out paths only checked on-hand quantity and could consume stock reserved for a customer.

The active reservation count was zero before and after this review.

## Database changes
Added internal helper `public.assert_stock_available(location, product, quantity)`. It locks the stock balance, subtracts active unexpired reservations, and rejects an outbound quantity that would consume reserved stock. Direct EXECUTE was revoked from PUBLIC, anon, and authenticated.

Integrated the helper into:
- Sales invoice posting (the request-id overload calls the guarded implementation).
- Regular stock transfers.
- Actual vehicle load dispatch.
- Production raw-material consumption.
- Purchase returns to suppliers.
- Trip settlement when returning remaining vehicle stock.
- Downward manual stock adjustments.
- Cancellation of posted customer returns.
- Reversal of completed production orders.
- Cancellation of partner inventory contributions, with a second check after the stock row is locked.

Existing stock-transfer reversal already checks active reservations after locking the destination balance and remains protected.

## Additional defect fixed
`reverse_production_order` referenced `stock_balances.reserved_quantity`, but that column does not exist. The function now checks on-hand quantity in its preflight and uses the shared reservation helper for each stock quantity it removes.

## Rollback-only tests
A temporary 8.0-unit reservation was inserted for product 1 at location 3, where on-hand quantity was 8.75:
- A 1.0-unit stock transfer was rejected because only 0.75 was unreserved.
- A 1.0-unit downward stock adjustment was rejected for the same reason.
- A 0.5-unit downward adjustment was accepted because it remained within unreserved stock.
- The temporary reservation, stock movement, accounting entry, and balance change were all rolled back.

After rollback:
- No QA reservation remained.
- Active reservation count remained 0.
- Stock quantity remained 8.7500.
- Inventory value remained 424.0384.
- Stock movement count remained 55.

## Verification
- All active stock-out functions listed above now reference the shared guard or an existing reservation check.
- The helper is not executable by authenticated or anon roles.
- The production reversal function no longer references the missing `reserved_quantity` column.
- No real stock, financial, or reservation records were changed.

## Release
- App version: v69
- Service Worker cache: `meat-v102`
- Lot traceability remains the next phase. No Lot schema or historical stock data has been changed yet.
