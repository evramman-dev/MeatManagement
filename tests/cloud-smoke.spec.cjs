const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');
const qaHtml = fs.readFileSync(path.resolve(__dirname, '..', 'index.html'), 'utf8');

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



test('Purchase and purchase-return preview matches database rounding rules', () => {
  expect(qaHtml).toContain('let priorGrossTotal = 0;');
  expect(qaHtml).toContain('Math.round((priorGrossTotal * invoiceDiscount / invoiceSubtotal + Number.EPSILON) * 100) / 100');
  expect(qaHtml).toContain('Math.round(((priorGrossTotal + grossTotal) * invoiceDiscount / invoiceSubtotal + Number.EPSILON) * 100) / 100');
  expect(qaHtml).toContain('priorGrossTotal += grossTotal;');
  expect(qaHtml).toContain('subtotal+=Math.round((q*p+Number.EPSILON)*100)/100;');
  expect(qaHtml).toContain('const t=Math.round((q*p+Number.EPSILON)*100)/100;');
});

test('Supplier workflow guards: cancelled documents, supplier profile and payment idempotency', () => {
  expect(qaHtml).toContain('address:$("supplierAddress").value.trim()||null');
  expect(qaHtml).toContain('$("supplierAddress").value=s.address||""');
  expect(qaHtml).toContain('if(result.error) throw result.error;');
  expect(qaHtml).toContain('.eq("is_cancelled", false).order("payment_id", {ascending:false})');
  expect(qaHtml).toContain('.eq("is_cancelled", false).order("payment_date", {ascending:true})');
  expect(qaHtml).toContain('.eq("is_cancelled", false).order("return_id", {ascending:false})');
  expect(qaHtml).toContain('.eq("is_cancelled", false).order("return_date", {ascending:true})');
  expect(qaHtml).toContain('requestStorageKey += "_" + currentUserId');
  expect(qaHtml).toContain('JSON.stringify(pendingRequest.payload) !== JSON.stringify(requestPayload)');
  expect(qaHtml).toContain('notes: notes || null');
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

  const deployedUrl = new URL(baseURL);
  const deployedPath = deployedUrl.pathname;
  await page.route('**/*', async route => {
    const request = route.request();
    const requestUrl = new URL(request.url());
    if (request.isNavigationRequest() && requestUrl.origin === deployedUrl.origin && requestUrl.pathname === deployedPath) {
      await route.fulfill({ status: 200, contentType: 'text/html; charset=utf-8', body: qaHtml });
    } else {
      await route.continue();
    }
  });

  await page.goto(baseURL, { waitUntil: 'domcontentloaded' });
  await expect(page.locator('#loginForm')).toBeVisible({ timeout: 60000 });
  await page.locator('#email').fill(username);
  await page.locator('#password').fill(password);
  await page.locator('#loginBtn').click();
  await expect(page.locator('#home')).toBeVisible({ timeout: 60000 });
  await expect(page.locator('#userInfo')).not.toContainText('جارٍ تحميل بيانات الحساب', { timeout: 30000 });
  await expect(page.locator('#notificationsList')).not.toContainText('جارٍ تحميل التنبيهات...', { timeout: 30000 });
  await page.screenshot({ path: 'test-results/home.png', fullPage: true });

  currentSection = 'session-restore';
  await page.reload({ waitUntil: 'domcontentloaded' });
  await expect(page.locator('#home')).toBeVisible({ timeout: 60000 });
  await page.screenshot({ path: 'test-results/session-restored-home.png', fullPage: true });

  currentSection = 'tasks';
  await page.locator('.navbtn[data-page="tasks"]').click();
  await expect(page.locator('#tasks')).toBeVisible();
  await expect(page.locator('#tasksDashboard')).toBeVisible();
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
    if (section === 'suppliers') {
      const supplierCards = page.locator('#suppliersList > .product');
      await expect(supplierCards.first(), 'At least one supplier should be available for statement testing').toBeVisible({ timeout: 30000 });
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
    }
    if (section === 'products') {
      const productCards = page.locator('#products > .product');
      if (await productCards.count()) {
        await expect(productCards.first()).toContainText('الوحدات:');
        await expect(productCards.first()).toContainText('حد إعادة الطلب:');
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

  const deployedUrl = new URL(baseURL);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.route('**/*', async route => {
    const request = route.request();
    const requestUrl = new URL(request.url());
    if (request.isNavigationRequest() && requestUrl.origin === deployedUrl.origin && requestUrl.pathname === deployedUrl.pathname) {
      await route.fulfill({ status: 200, contentType: 'text/html; charset=utf-8', body: qaHtml });
    } else {
      await route.continue();
    }
  });

  await page.goto(baseURL, { waitUntil: 'domcontentloaded' });
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
