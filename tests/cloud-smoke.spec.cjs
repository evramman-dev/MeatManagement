const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');
const qaHtml = fs.readFileSync(path.resolve(__dirname, '..', 'index.html'), 'utf8');

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
      consoleErrors.push({ section: currentSection, message: message.text(), location: message.location() });
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
  await expect(page.locator('#tasksDashboard')).not.toContainText('صافي الربح');
  await expect(page.locator('#tasksDashboard')).toContainText('غير محسوب');
  await page.screenshot({ path: 'test-results/tasks.png', fullPage: true });

  currentSection = 'data';
  await page.locator('.navbtn[data-page="data"]').click();
  await expect(page.locator('#data')).toBeVisible();
  await page.screenshot({ path: 'test-results/data.png', fullPage: true });

  currentSection = 'permissions';
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
