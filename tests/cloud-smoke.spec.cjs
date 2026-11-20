const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');
const qaHtml = fs.readFileSync(path.resolve(__dirname, '..', 'index.html'), 'utf8');
const returnInspectionMigrationSql = fs.readFileSync(path.resolve(__dirname, '..', 'supabase', 'migrations', '20261115230000_sales_return_joint_inspection_rework.sql'), 'utf8');
const packagingRecoveryMigrationSql = fs.readFileSync(path.resolve(__dirname, '..', 'supabase', 'migrations', '20261115232000_support_packaging_recovery_and_partial_rework.sql'), 'utf8');

const exchangeMigrationSql = fs.readFileSync(path.resolve(__dirname, '..', 'supabase', 'migrations', '20261115144036_fix_sales_exchange_request_idempotency.sql'), 'utf8');
const exchangeCancellationMigrationSql = fs.readFileSync(path.resolve(__dirname, '..', 'supabase', 'migrations', '20261115144743_fix_sales_exchange_cancellation_accounting.sql'), 'utf8');
const exchangeCancellationOrderMigrationSql = fs.readFileSync(path.resolve(__dirname, '..', 'supabase', 'migrations', '20261115144800_fix_sales_exchange_cancellation_stock_reversal_order.sql'), 'utf8');
const legacyExchangeCancelGuardSql = fs.readFileSync(path.resolve(__dirname, '..', 'supabase', 'migrations', '20261115145032_guard_legacy_sales_return_cancel_from_exchanges.sql'), 'utf8');
const fixedAssetsPolicyMigrationSql = fs.readFileSync(path.resolve(__dirname, '..', 'supabase', 'migrations', '20261115145626_consolidate_fixed_assets_select_policies.sql'), 'utf8');
const openingBalanceAdminMigrationSql = fs.readFileSync(path.resolve(__dirname, '..', 'supabase', 'migrations', '20261115150500_restrict_stock_opening_balance_to_system_admin.sql'), 'utf8');
const salesReturnIdempotencyMigrationSql = fs.readFileSync(path.resolve(__dirname, '..', 'supabase', 'migrations', '20261115160755_guard_sales_return_request_number_idempotency.sql'), 'utf8');

test.use({ serviceWorkers: 'block' });

const baseURL = process.env.BASE_URL;
const username = process.env.TEST_USERNAME;
const password = process.env.TEST_PASSWORD;

const sections = [
  'products', 'locations', 'stock', 'stockTransfers', 'recipes',
  'production', 'reservations', 'suppliers', 'purchases',
  'purchaseReturns', 'landedCosts', 'fixedAssets', 'supplierPayments',
  'expenses', 'customers', 'sales', 'priceLists', 'collections',
  'trips', 'salesReps', 'treasuries', 'treasuryTransfers',
  'partners', 'accounting', 'reports', 'settings'
];

const menuIds = {
  products: 'menuProducts', locations: 'menuLocations', stock: 'menuStock',
  stockTransfers: 'menuStockTransfers', recipes: 'menuRecipes',
  production: 'menuProduction', reservations: 'menuReservations',
  suppliers: 'menuSuppliers', purchases: 'menuPurchases',
  purchaseReturns: 'menuPurchaseReturns', landedCosts: 'menuLandedCosts',
  fixedAssets: 'menuFixedAssets', supplierPayments: 'menuSupplierPayments',
  expenses: 'menuExpenses', customers: 'menuCustomers', sales: 'menuSales',
  priceLists: 'menuPriceLists', collections: 'menuCollections',
  trips: 'menuTrips', salesReps: 'menuSalesReps', treasuries: 'menuTreasuries',
  treasuryTransfers: 'menuTreasuryTransfers', partners: 'menuPartners',
  accounting: 'menuAccounting', reports: 'menuReports', settings: 'menuSettings'
};


test('Regular stock transfer selectors exclude vehicle locations and show location codes', () => {
  const start = qaHtml.indexOf('function fillStockTransferSelects(){');
  const end = qaHtml.indexOf('function fillPartnerSelect(){', start);
  expect(start, 'Stock transfer selector function should exist.').toBeGreaterThanOrEqual(0);
  expect(end, 'Stock transfer selector function should have a clear boundary.').toBeGreaterThan(start);
  const source = qaHtml.slice(start, end);

  expect(source).toContain('locationsCache.filter(l=>l.is_active && l.location_type!=="VEHICLE")');
  expect(source).toContain('l.location_name+" ("+l.location_code+")"');
  expect(source).toContain('op1.textContent=label');
  expect(source).toContain('op2.textContent=label');
  expect(source).toContain('s.appendChild(op1)');
  expect(source).toContain('d.appendChild(op2)');
  expect(source).not.toContain('locationsCache.filter(l=>l.is_active).forEach');
});



test('Purchase and purchase-return preview matches database rounding rules', () => {
  expect(qaHtml).toContain('let priorGrossTotal = 0;');
  expect(qaHtml).toContain('Math.round((priorGrossTotal * invoiceDiscount / invoiceSubtotal + Number.EPSILON) * 100) / 100');
  expect(qaHtml).toContain('Math.round(((priorGrossTotal + grossTotal) * invoiceDiscount / invoiceSubtotal + Number.EPSILON) * 100) / 100');
  expect(qaHtml).toContain('priorGrossTotal += grossTotal;');
  expect(qaHtml).toContain('subtotal+=Math.round((q*p+Number.EPSILON)*100)/100;');
  expect(qaHtml).toContain('const t=Math.round((q*p+Number.EPSILON)*100)/100;');
});

test('Purchase return retries reuse the same request ID and reject changed payloads', () => {
  const start=qaHtml.indexOf('const requestStorageKey = "mm_purchase_return_pending_request_" + currentUserId;');
  const end=qaHtml.indexOf('localStorage.removeItem(requestStorageKey);',start);
  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);
  const source=qaHtml.slice(start,end);
  expect(source).toContain('JSON.stringify(pendingRequest.payload) !== JSON.stringify(requestPayload)');
  expect(source).toContain('request_id: createSupplierPaymentRequestId()');
  expect(source).toContain('p_request_id: pendingRequest.request_id');
  expect(source).toContain('if(error) throw error;');
  expect(source).toContain('db.rpc("create_purchase_return"');
});

test('Purchase return cancellation requires a reason and confirms reversal of stock, journal and treasury', () => {
  const start=qaHtml.indexOf('cancel.onclick = async () => {',qaHtml.indexOf('async function loadPurchaseReturns'));
  const end=qaHtml.indexOf('actions.appendChild(cancel);',start);
  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);
  const source=qaHtml.slice(start,end);
  expect(source).toContain('if(!reason.trim())');
  expect(source).toContain('سيتم عكس كمية المخزون والقيد المحاسبي');
  expect(source).toContain('db.rpc("cancel_purchase_return"');
  expect(source).toContain('p_return_id: Number(r.return_id)');
  expect(source).toContain('p_reason: reason.trim()');
  expect(source).toContain('await loadStock()');
  expect(source).toContain('await loadTreasuries()');
  expect(source).toContain('await loadSuppliers()');
});

test('Supplier workflow guards: cancelled documents, supplier profile and payment idempotency', () => {
  expect(qaHtml).toContain('address:$("supplierAddress").value.trim()||null');
  expect(qaHtml).toContain('$("supplierAddress").value=s.address||""');
  expect(qaHtml).toContain('if(result.error) throw result.error;');
  expect(qaHtml).toContain('.eq("is_cancelled", false).order("payment_id", {ascending:false})');
  expect(qaHtml).toContain('.eq("is_cancelled", false).order("payment_date", {ascending:true})');
  expect(qaHtml).toContain('.order("return_id", {ascending:false})');
  expect(qaHtml).toContain('.eq("is_cancelled", false).order("return_date", {ascending:true})');
  expect(qaHtml).toContain('requestStorageKey += "_" + currentUserId');
  expect(qaHtml).toContain('JSON.stringify(pendingRequest.payload) !== JSON.stringify(requestPayload)');
  expect(qaHtml).toContain('notes: notes || null');
});

test('Sales invoice retries reuse the same request ID and only clear it after success', () => {
  expect(qaHtml).toContain('const requestStorageKey="mm_sales_invoice_pending";');
  expect(qaHtml).toContain('const requestPayload={customer_id:Number(customerId),location_id:Number(locationId),invoice_date:$("invoiceDate").value,discount:(subTotal*(discount/100)),notes:$("invoiceNotes").value||null,items:items,trip_id:tripId,payments:payments};');
  expect(qaHtml).toContain('const requestId=getRequestId(requestStorageKey,requestPayload);');
  expect(qaHtml).toContain('p_request_id: requestId');
  expect(qaHtml).toContain('if(!error) clearRequestId(requestStorageKey);');
  expect(qaHtml).toContain('if(error) throw error;');

  const start=qaHtml.indexOf('if($("invoiceForm")) $("invoiceForm").addEventListener("submit"');
  const end=qaHtml.indexOf('// ========== فواتير المشتريات ==========',start);
  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);
  const invoiceSource=qaHtml.slice(start,end);
  expect(invoiceSource).toContain('getRequestId(requestStorageKey,requestPayload)');
  expect(invoiceSource).toContain('p_request_id: requestId');
  expect(invoiceSource).toContain('if(!error) clearRequestId(requestStorageKey);');
  expect(invoiceSource).toContain('if(error) throw error;');
});

test('Sales return retries reuse the same return number and item request IDs', () => {
  expect(qaHtml).toContain('function getSalesReturnRequest(storageKey,payload,itemCount)');
  expect(qaHtml).toContain('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx');
  expect(qaHtml).toContain('pending={request_id:makeId(),return_number:"RET-"+Date.now()+"-"+Math.random().toString(36).slice(2,8).toUpperCase(),item_request_ids:Array.from({length:itemCount},()=>makeId()),payload:normalized}');
  expect(qaHtml).toContain('returnRequest=getSalesReturnRequest(returnRequestKey,returnPayload,rows.length);');
  expect(qaHtml).toContain('p_return_number:returnRequest.return_number');
  expect(qaHtml).toContain('for(let itemIndex=0;itemIndex<rows.length;itemIndex++){');
  expect(qaHtml).toContain('p_request_id:returnRequest.item_request_ids[itemIndex]');
  expect(qaHtml).toContain('lot_id:r.querySelector(".return-lot")?.value||null,package_option_id:r.querySelector(".return-package-option")?.value||null');

  expect(qaHtml).not.toContain('p_return_number:"RET-"+Date.now()');
  expect(qaHtml).not.toContain('const itemRequestId=(crypto.randomUUID?crypto.randomUUID():Date.now()+');
});

test('Regular sales return idempotency rejects changed return numbers', () => {
  expect(salesReturnIdempotencyMigrationSql).toContain('v_existing.return_number IS DISTINCT FROM p_return_number');
  expect(salesReturnIdempotencyMigrationSql).toContain("RAISE EXCEPTION 'رقم طلب المرتجع مستخدم من قبل مع بيانات مختلفة'");
});

test('Sales exchange retries reuse stable request and item IDs', () => {
  const start=qaHtml.indexOf('if(type==="EXCHANGE"){');
  const end=qaHtml.indexOf('await salesReturnLotOptionsPromise;',start);
  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);
  const exchangeSource=qaHtml.slice(start,end);
  expect(exchangeSource).toContain('const req=getSalesReturnRequest(requestKey,payload,returnItemsBase.length+exchangeItemsBase.length);');
  expect(exchangeSource).toContain('request_id:req.item_request_ids[index]');
  expect(exchangeSource).toContain('request_id:req.item_request_ids[returnItemsBase.length+index]');
  expect(exchangeSource).not.toContain('request_id:crypto.randomUUID()');
  expect(exchangeSource).toContain('else{clearRequestId(requestKey);showToast("تم حفظ طلب الاستبدال. ينتظر الاعتماد."');
});

test('Sales exchange RPC serializes retries and rejects request ID payload changes', () => {
  expect(exchangeMigrationSql).toContain('pg_advisory_xact_lock(hashtextextended(p_request_id::text,0))');
  expect(exchangeMigrationSql).toContain('رقم طلب الاستبدال مستخدم من قبل مع بيانات مختلفة');
  expect(exchangeMigrationSql).toContain('sales_return_exchange_items');
});

test('Sales exchange cancellation reverses the main journal and both COGS sides once', () => {
  expect(exchangeCancellationMigrationSql).toContain("NEW.return_type IS DISTINCT FROM 'EXCHANGE'");
  expect(exchangeCancellationMigrationSql).toContain("'account','4100','debit',r.total_exchange_value,'credit',0");
  expect(exchangeCancellationMigrationSql).toContain("'account','1200','debit',0,'credit',r.total_exchange_value");
  expect(exchangeCancellationMigrationSql).toContain("'SALES_RETURN_COGS_LINE'");
  expect(exchangeCancellationMigrationSql).toContain("'SALES_COGS_LINE'");
});

test('Same-product exchange cancellation reverses stock movements in reverse order', () => {
  expect(exchangeCancellationOrderMigrationSql).toContain('ORDER BY movement_id DESC LOOP');
});

test('Legacy sales return cancellation cannot bypass the exchange-specific reversal', () => {
  expect(legacyExchangeCancelGuardSql).toContain("IF v_return.return_type='EXCHANGE' THEN");
  expect(legacyExchangeCancelGuardSql).toContain('استخدم دالة إلغاء الاستبدال المخصصة.');
});

test('Fixed asset SELECT permissions are consolidated without losing either access path', () => {
  expect(fixedAssetsPolicyMigrationSql).toContain("has_permission('ACCOUNTING_VIEW')");
  expect(fixedAssetsPolicyMigrationSql).toContain("has_permission('ACCOUNTING_MANAGE')");
  expect(fixedAssetsPolicyMigrationSql).toContain("source_type='SUPPLIER_CREDIT'");
  expect(fixedAssetsPolicyMigrationSql).toContain("has_permission('SUPPLIERS_VIEW')");
  expect(fixedAssetsPolicyMigrationSql).toContain("has_permission('SUPPLIERS_MANAGE')");
});
test('Stock opening balance is restricted to SYSTEM_ADMIN', () => {
  expect(openingBalanceAdminMigrationSql).toContain("IF v_role IS DISTINCT FROM 'SYSTEM_ADMIN' THEN");
  expect(openingBalanceAdminMigrationSql).toContain("AND u.is_active = true");
  expect(openingBalanceAdminMigrationSql).toContain("AND r.is_active = true");
  expect(openingBalanceAdminMigrationSql).toContain('تسجيل الرصيد الافتتاحي للمخزون متاح لمدير النظام فقط');
});

test('Collection views label cancelled records and exclude them from posted totals', () => {
  expect(qaHtml).toContain('const statusLabel=col.status==="POSTED"?"مرحّل":col.status==="CANCELLED"?"ملغى":"غير مرحّل";');
  expect(qaHtml).toContain('if(row.status==="POSTED") totalPosted += Number(row.amount||0);');
  expect(qaHtml).toContain('if(row.status==="CANCELLED") totalCancelled += Number(row.amount||0);');
  expect(qaHtml).toContain('إجمالي التحصيلات المرحلة:');
  expect(qaHtml).toContain('إجمالي التحصيلات الملغاة (مستبعدة من الإجمالي):');
});

test('Customer cheque management shows statuses and gates clearing and bounce actions by permissions', () => {
  expect(qaHtml).toContain('id="customerChequesCard"');
  expect(qaHtml).toContain('db.from("customer_cheques").select("*")');
  expect(qaHtml).toContain('db.rpc("clear_customer_cheque"');
  expect(qaHtml).toContain('db.rpc("bounce_customer_cheque"');
  expect(qaHtml).toContain('if(canPostCollections)');
  expect(qaHtml).toContain('if(canManageCollections)');
  expect(qaHtml).toContain('سبب ارتداد الشيك:');
});

test('Trip load approval and dispatch quantities explicitly show the product base unit', () => {
  expect(qaHtml).toContain('const baseUnit=unitName(product?.base_unit_id);');
  expect(qaHtml).toContain('الوحدة الأساسية: "+baseUnit');
  expect(qaHtml).toContain('+" ("+baseUnit+")"');
});

test('Admin notifications support selected users and all active users', () => {
  expect(qaHtml).toContain('id="notificationSendAll"');
  expect(qaHtml).toContain('إرسال إشعار عام إلى جميع المستخدمين النشطين');
  expect(qaHtml).toContain('sendAll=$("notificationSendAll")?.checked===true');
  expect(qaHtml).toContain('Array.from(select?.options||[]).map(o=>o.value)');
  expect(qaHtml).toContain('notificationType=sendAll?"GENERAL":"MANUAL"');
  expect(qaHtml).toContain('audience:sendAll?"ALL_ACTIVE_USERS":"SELECTED_USERS"');
  expect(qaHtml).toContain('if(!isSystemAdmin)throw new Error("إرسال التنبيهات متاح لمدير النظام فقط.")');
  expect(qaHtml).toContain('select.disabled=$("notificationSendAll").checked');
});

test('Task notifications are delivered only to selected users and shown on My Tasks', () => {
  expect(qaHtml).toContain('id="taskNotificationsList"');
  expect(qaHtml).toContain('id="taskNotificationSendPanel"');
  expect(qaHtml).toContain('notification_type==="TASK"');
  expect(qaHtml).toContain('p_notification_type:"TASK"');
  expect(qaHtml).toContain('p_user_ids:users');
  expect(qaHtml).toContain('audience:"SELECTED_USERS"');
  expect(qaHtml).toContain('if(!isSystemAdmin)throw new Error("إرسال تنبيهات المهام متاح لمدير النظام فقط.")');
  expect(qaHtml).toContain('await loadTaskNotifications();');
  expect(qaHtml).toContain('notification_type!=="TASK"');
  expect(qaHtml).toContain('row.notifications?.notification_type!=="TASK"');
});

test('Accounting summary uses ledger totals and does not show an inaccurate fallback', () => {
  expect(qaHtml).toContain('if(periodErr) throw periodErr;');
  expect(qaHtml).toContain('if(!periodData) throw new Error("لم تُرجع قاعدة البيانات ملخص الفترة.")');
  expect(qaHtml).not.toContain('fmt(rev - purch - exp)');
  expect(qaHtml).toContain('if(trialErr) throw trialErr;');
  expect(qaHtml).toContain('if(journalErr) throw journalErr;');
});

test('Profit and loss report never substitutes purchase totals for cost of sales', () => {
  const start = qaHtml.indexOf('window.loadProfitLoss = async function()');
  const end = qaHtml.indexOf('window.switchReportTab = function(tabId)', start);
  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);
  const reportSource = qaHtml.slice(start, end);
  expect(reportSource).toContain('db.rpc("get_profit_loss"');
  expect(reportSource).toContain('if(!row)');
  expect(reportSource).toContain('لا توجد بيانات محاسبية مسجلة في هذه الفترة');
  expect(reportSource).not.toContain('purchase_invoices');
  expect(reportSource).not.toContain('const cogs =');
  expect(reportSource).not.toContain('تكلفة المبيعات (المشتريات)');
});

test('Partner workflow UI and permission-gated operations are wired', () => {
  expect(qaHtml).toContain('if(canManagePartners)');
  expect(qaHtml).toContain('permission("PARTNERS_TRANSACTIONS_MANAGE")');
  expect(qaHtml).toContain('!canManagePartnerTransactions');
  expect(qaHtml).toContain('db.from("partners").insert(payload)');
  expect(qaHtml).toContain('db.rpc("create_partner_transaction_v2"');
  expect(qaHtml).toContain('db.rpc("create_partner_inventory_contribution"');
  expect(qaHtml).toContain('create_partner_vehicle_contribution');
  expect(qaHtml).toContain('db.rpc("create_partner_profit_distribution"');
  expect(qaHtml).toContain('db.rpc("pay_partner_profit_distribution_item"');
  expect(qaHtml).toContain('db.rpc("cancel_partner_profit_payout"');
  expect(qaHtml).toContain('if(d.status==="POSTED"&&canManageAccounting){');
  expect(qaHtml).toContain('if(Number(item.paid_amount)>0.009)hasPayouts=true;');
  expect(qaHtml).toContain('!hasPayouts');
  expect(qaHtml).toContain('if(payoutRowsError){\n     hasPayouts=true;');
  expect(qaHtml).toContain('لا توجد توزيعات أرباح.');
});

test('MeatManagement read-only navigation, permissions and session smoke test', async ({ page }) => {
  test.setTimeout(300000);

  if (!baseURL || !username || !password) {
    throw new Error('BASE_URL, TEST_USERNAME and TEST_PASSWORD must be configured as environment variables.');
  }

  const pageErrors = [];
  const consoleErrors = [];
  const networkErrors = [];
  let currentSection = 'initial';

  const isAppRequest = url => {
    try {
      const parsed = new URL(url);
      return parsed.origin === new URL(baseURL).origin || parsed.hostname.endsWith('.supabase.co');
    } catch {
      return false;
    }
  };

  page.on('pageerror', error => {
    pageErrors.push({ section: currentSection, message: error.message, stack: error.stack || '', url: page.url() });
  });

  page.on('console', message => {
    if (message.type() === 'error') {
      const text = message.text();
      // Playwright blocks service workers so QA HTML cannot be served from the deployed PWA cache.
      // Ignore only the resulting registration-scope TypeError; keep collecting all other console errors.
      if (text.startsWith("[PWA] failed TypeError: Cannot read properties of undefined (reading 'scope')")) return;
      consoleErrors.push({ section: currentSection, message: text, location: message.location() });
    }
  });

  page.on('requestfailed', request => {
    const reason = String(request.failure()?.errorText || '');
    if (isAppRequest(request.url()) && !reason.includes('ERR_ABORTED')) {
      networkErrors.push({ section: currentSection, kind: 'requestfailed', url: request.url(), error: reason || 'unknown' });
    }
  });

  page.on('response', response => {
    if (response.status() >= 400 && isAppRequest(response.url())) {
      networkErrors.push({ section: currentSection, kind: 'http', status: response.status(), url: response.url() });
    }
  });

  const deployedResponse = await page.goto(baseURL, { waitUntil: 'domcontentloaded' });
  expect(deployedResponse, 'The deployed application should return a document response.').not.toBeNull();
  expect(deployedResponse.status(), 'The deployed application should return HTTP 200.').toBe(200);
  expect(deployedResponse.headers()['content-type'] || '').toContain('text/html');
  expect(await page.title()).toMatch(/^MeatManagement v\d+$/);
  await expect(page.locator('#loginForm')).toBeVisible({ timeout: 60000 });
  await page.locator('#email').fill(username);
  await page.locator('#password').fill(password);
  await page.locator('#loginBtn').click();
  await expect(page.locator('#home')).toBeVisible({ timeout: 60000 });
  await expect(page.locator('#userInfo')).not.toContainText('جارٍ تحميل بيانات الحساب', { timeout: 30000 });
  await expect(page.locator('#notificationsList')).not.toContainText('جارٍ تحميل التنبيهات...', { timeout: 30000 });
  await page.screenshot({ path: 'test-results/home.png', fullPage: true });

  currentSection = 'partner-management-summary';
  const partnerSummaryButton = page.locator('#openPartnerManagementSummary');
  await expect(partnerSummaryButton, 'Partner management summary should be visible to the signed-in partner or system administrator.').toBeVisible();
  await partnerSummaryButton.click();
  await expect(page.locator('#homePartnerSummaryPanel')).toBeVisible();
  await expect(page.locator('#partnerSummaryFrom')).toHaveValue(/[0-9]{4}-[0-9]{2}-[0-9]{2}/);
  await expect(page.locator('#partnerSummaryTo')).toHaveValue(/[0-9]{4}-[0-9]{2}-[0-9]{2}/);
  await page.locator('#refreshPartnerSummary').click();
  const partnerSummaryContent = page.locator('#partnerManagementSummaryContent');
  await expect(partnerSummaryContent).not.toContainText('جارٍ إعداد التقرير ومراجعة الأرقام...', { timeout: 90000 });
  await expect(partnerSummaryContent).toContainText('صافي الربح', { timeout: 30000 });
  await expect(partnerSummaryContent).toContainText('مستحقات العملاء');
  await expect(partnerSummaryContent).toContainText('مستحقات الموردين');
  await expect(partnerSummaryContent).toContainText('قيمة المخزون');
  await page.screenshot({ path: 'test-results/partner-management-summary.png', fullPage: true });
  await page.locator('#homePartnerSummaryPanel .home-detail-back').click();
  await expect(page.locator('#homeOverview')).toBeVisible();

  currentSection = 'session-restore';
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.locator('#home')).toBeVisible({ timeout: 60000 });
  await page.screenshot({ path: 'test-results/session-restored-home.png', fullPage: true });

  currentSection = 'tasks';
  await page.locator('.navbtn[data-page="tasks"]').click();
  await expect(page.locator('#tasks')).toBeVisible();
  await expect(page.locator('#tasksDashboard')).toBeVisible();
  await expect(page.locator('#taskNotificationsList')).toBeVisible();
  await expect(page.locator('#taskNotificationsList')).not.toContainText('جارٍ تحميل تنبيهات المهام...', { timeout: 30000 });
  await expect(page.locator('#taskNotificationSendPanel')).toBeHidden();
  await page.screenshot({ path: 'test-results/tasks.png', fullPage: true });

  currentSection = 'data';
  await page.locator('.navbtn[data-page="data"]').click();
  await expect(page.locator('#data')).toBeVisible();
  await page.screenshot({ path: 'test-results/data.png', fullPage: true });

  currentSection = 'permissions';
  await expect(page.locator('#ptType option[value="CAPITAL_OUT"]')).toHaveJSProperty('disabled', true);
  await expect(page.locator('#ptTreasury')).toHaveJSProperty('required', true);
  await expect(page.locator('#ptTreasury option').first()).toHaveText('اختر الخزنة');
  if (await page.locator('#menuUsers').count()) {
    await expect(page.locator('#menuUsers')).toBeHidden();
  }

  const accessibleSections = await page.evaluate(ids => {
    return Object.keys(ids).filter(section => {
      const element = document.getElementById(ids[section]);
      return !!element && !element.classList.contains('hidden') && element.getClientRects().length > 0;
    });
  }, menuIds);
  const visitedSections = [];
  const restrictedSections = sections.filter(section => !accessibleSections.includes(section));

  for (const section of accessibleSections) {
    const targetId = '#section' + section.charAt(0).toUpperCase() + section.slice(1);
    const target = page.locator(targetId);

    currentSection = section;
    await page.evaluate(route => {
      if (typeof window.openSection !== 'function') throw new Error('openSection function not found');
      window.openSection(route);
    }, section);

    await expect(target, 'Section ' + section + ' should open when its menu is visible').toBeVisible({ timeout: 15000 });
    await page.waitForTimeout(800);
    if (section === 'partners') {
      await expect(page.locator('#partnersList')).not.toContainText('جارٍ تحميل الشركاء...', { timeout: 30000 });
      await expect(page.locator('#partnersList')).not.toContainText('تعذر تحميل', { timeout: 30000 });
      await expect(page.locator('#partnerTransactionsList')).not.toContainText('جارٍ تحميل حركات الشركاء...', { timeout: 30000 });
      await expect(page.locator('#partnerTransactionsList')).not.toContainText('تعذر تحميل', { timeout: 30000 });
      const profitList = page.locator('#mmProfitList');
      if (await profitList.count()) {
        await expect(profitList).not.toContainText('جارٍ التحميل...', { timeout: 30000 });
        await expect(profitList).not.toContainText('تعذر تحميل توزيعات الأرباح', { timeout: 30000 });
      }
      await page.screenshot({ path: 'test-results/partners-read-only.png', fullPage: true });
    }
    if (section === 'suppliers') {
      const supplierList = page.locator('#suppliersList');
      const supplierCards = supplierList.locator(':scope > .product');
      await expect(supplierList).not.toContainText('جارٍ تحميل الموردين...', { timeout: 30000 });

      if (await supplierCards.count()) {
        await supplierCards.first().getByRole('button', { name: 'كشف حساب' }).click();
        await expect(page.locator('#supplierStatementModal')).toBeVisible();
        await expect(page.locator('#modalSupplierHeader')).not.toContainText('جارٍ تحميل البيانات...', { timeout: 30000 });
        await expect(page.locator('#modalSupplierHeader')).not.toContainText('خطأ:', { timeout: 30000 });
        await expect(page.locator('#modalSupplierSummary')).toContainText('الرصيد الافتتاحي:');
        await expect(page.locator('#modalSupplierSummary')).toContainText('المشتريات الآجلة:');
        await expect(page.locator('#modalSupplierSummary')).toContainText('تكاليف نقل آجلة على المورد:');
        await expect(page.locator('#modalSupplierSummary')).toContainText('أصول مشتراة آجلًا من المورد:');
        await expect(page.locator('#modalSupplierSummary')).toContainText('الرصيد النهائي:');
        await expect(page.locator('#modalSupplierItems')).toContainText('الرصيد');
        await page.screenshot({ path: 'test-results/supplier-statement.png', fullPage: true });
        await page.locator('#supplierStatementModal .close-btn').click();
        await expect(page.locator('#supplierStatementModal')).toBeHidden();
      } else {
        await expect(supplierList).toContainText('لا يوجد موردون.');
        console.log('SUPPLIER_STATEMENT_CHECK_SKIPPED: no supplier master data exists after factory reset.');
      }
    }
    if (section === 'products') {
      const productCards = page.locator('#products > .product');
      if (await productCards.count()) {
        await expect(productCards.first()).toContainText('الوحدات:');
        await expect(productCards.first()).toContainText('حد إعادة الطلب:');
      }
    }
    if (section === 'sales') {
      const salesList = page.locator('#salesList');
      await expect(salesList).not.toContainText('جارٍ تحميل الفواتير...', { timeout: 30000 });
      const invoiceCard = salesList.locator('.product').filter({ hasText: 'INV-000042' }).first();
      if (await invoiceCard.count()) {
        await expect(invoiceCard).toBeVisible();
        await invoiceCard.getByRole('button', { name: 'عرض التفاصيل' }).click();
        await expect(page.locator('#invoiceDetailsModal')).toBeVisible();
        const lotDetails = page.locator('#modalInvoiceLots');
        await expect(lotDetails).toContainText('تخصيصات التشغيلات', { timeout: 30000 });
        await expect(lotDetails).not.toContainText('جارٍ تحميل تخصيصات التشغيلات...', { timeout: 30000 });
        await expect(lotDetails).toContainText('LOT-20261115-000031', { timeout: 30000 });
        await expect(lotDetails).toContainText('٠٫٥');
        await page.screenshot({ path: 'test-results/sales-invoice-lot-allocations.png', fullPage: true });
        await page.locator('#invoiceDetailsModal .close-btn').click();
        await expect(page.locator('#invoiceDetailsModal')).toBeHidden();
      } else {
        console.log('LOT_ALLOCATION_ACCEPTANCE_SKIPPED: fixture INV-000042 is absent after factory reset; no replacement data was created.');
      }
    }
    await page.screenshot({ path: 'test-results/sections/' + section + '.png', fullPage: true });
    visitedSections.push(section);
  }

  currentSection = 'logout';
  await page.locator('.navbtn[data-page="home"]').click();
  await expect(page.locator('#home')).toBeVisible();
  page.once('dialog', dialog => dialog.accept());
  await page.locator('#logoutBtn').click();
  await expect(page.locator('#loginForm')).toBeVisible({ timeout: 30000 });
  await page.screenshot({ path: 'test-results/logout.png', fullPage: true });

  const report = { visitedSections, restrictedSections, pageErrors, consoleErrors, networkErrors };
  console.log('MEATMANAGEMENT_READ_ONLY_REPORT:', JSON.stringify(report, null, 2));

  expect(visitedSections.length, 'At least one permitted business section should be tested.').toBeGreaterThan(0);
  expect(pageErrors, 'Uncaught JavaScript errors detected.').toEqual([]);
  expect(consoleErrors, 'Browser console errors detected.').toEqual([]);
  expect(networkErrors, 'Application or Supabase network errors detected.').toEqual([]);
});


test('MeatManagement Android-sized layout and horizontal overflow check', async ({ page }) => {
  test.setTimeout(240000);
  if (!baseURL || !username || !password) {
    throw new Error('BASE_URL, TEST_USERNAME and TEST_PASSWORD must be configured as environment variables.');
  }

  await page.setViewportSize({ width: 390, height: 844 });
  const deployedResponse = await page.goto(baseURL, { waitUntil: 'domcontentloaded' });
  expect(deployedResponse, 'The deployed application should return a document response.').not.toBeNull();
  expect(deployedResponse.status(), 'The deployed application should return HTTP 200.').toBe(200);
  expect(deployedResponse.headers()['content-type'] || '').toContain('text/html');
  expect(await page.title()).toMatch(/^MeatManagement v\d+$/);
  await expect(page.locator('#loginForm')).toBeVisible({ timeout: 60000 });
  await page.locator('#email').fill(username);
  await page.locator('#password').fill(password);
  await page.locator('#loginBtn').click();
  await expect(page.locator('#home')).toBeVisible({ timeout: 60000 });

  const widths = [];
  for (const viewport of [{ width: 390, height: 844 }, { width: 360, height: 800 }]) {
    await page.setViewportSize(viewport);
    for (const section of ['home', 'tasks', 'data']) {
      await page.locator('.navbtn[data-page="' + section + '"]').click();
      await expect(page.locator('#' + section)).toBeVisible();
      await page.waitForTimeout(300);
      const metrics = await page.evaluate(() => ({
        viewport: document.documentElement.clientWidth,
        document: document.documentElement.scrollWidth,
        body: document.body.scrollWidth
      }));
      widths.push({ ...viewport, section, ...metrics });
      await page.screenshot({ path: 'test-results/mobile-' + viewport.width + '-' + section + '.png', fullPage: true });
      expect(metrics.document, 'Horizontal page overflow at ' + viewport.width + 'px in ' + section).toBeLessThanOrEqual(metrics.viewport + 2);
      expect(metrics.body, 'Horizontal body overflow at ' + viewport.width + 'px in ' + section).toBeLessThanOrEqual(metrics.viewport + 2);
    }
  }

  const report = { mobileWidths: widths };
  console.log('MEATMANAGEMENT_MOBILE_LAYOUT_REPORT:', JSON.stringify(report, null, 2));
});


test('Sales return inspection, rework inputs and packaging recovery are wired', async () => {
  expect(qaHtml).toContain('salesReturnInspectionModal');
  expect(qaHtml).toContain('record_sales_return_item_inspection');
  expect(qaHtml).toContain('add_production_order_extra_material');
  expect(qaHtml).toContain('production-packaging-waste-row');
  expect(qaHtml).toContain('productionPackagingWasteModal');
  expect(qaHtml).toContain('get_sales_return_rework_stock');
  expect(qaHtml).toContain('packaging_items:packagingItems');
  expect(qaHtml).toContain('["RAW","SEMI_FINISHED"].includes(p.product_type)');
  expect(qaHtml).toContain('Number(p.category_id)===16');
  expect(qaHtml).toContain('p.product_name.startsWith("طبق")');
  expect(qaHtml).toContain('WAREHOUSE_KEEPER: ["menuProducts","menuLocations","menuStock","menuStockLots","menuStockTransfers","menuTrips","menuSalesReturns"]');
  expect(qaHtml).toContain('PRODUCTION_MANAGER: ["menuProducts","menuLocations","menuStock","menuStockLots","menuRecipes","menuProduction","menuSalesReturns"]');
  expect(returnInspectionMigrationSql).toContain('source_return_item_id');
  expect(returnInspectionMigrationSql).toContain('warehouse_inspected_by');
  expect(returnInspectionMigrationSql).toContain('production_inspected_by');
  expect(returnInspectionMigrationSql).toContain('warehouse_sellable_quantity');
  expect(returnInspectionMigrationSql).toContain('production_rework_quantity');
  expect(returnInspectionMigrationSql).toContain('p_sellable_quantity');
  expect(qaHtml).toContain('p_sellable_quantity:sv');
  expect(qaHtml).toContain('p_rework_quantity:rv');
  expect(qaHtml).toContain('p_scrap_quantity:xv');
  expect(returnInspectionMigrationSql).toContain('RETURN_PENDING:%');
  expect(returnInspectionMigrationSql).toContain('RETURN_REWORK:%');
  expect(packagingRecoveryMigrationSql).toContain('packaging_items');
  expect(packagingRecoveryMigrationSql).toContain('p.category_id=16');
  expect(packagingRecoveryMigrationSql).toContain("has_permission('INVENTORY_ADJUST')");
  expect(packagingRecoveryMigrationSql).toContain("has_permission('PRODUCTION_MANAGE')");
  expect(packagingRecoveryMigrationSql).toContain('REVOKE ALL ON FUNCTION public.create_stock_transfer');
});
