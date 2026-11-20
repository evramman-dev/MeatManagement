const { test, expect } = require('@playwright/test');
const path = require('node:path');
const fs = require('node:fs');
const qaHtml = fs.readFileSync(path.resolve(__dirname, '..', 'index.html'), 'utf8');
const appSupabaseUrl = qaHtml.match(/const URL="(https:\/\/[^\"]+)";/)?.[1] || null;
const productionSupabaseUrl = 'https://mklbemoisdkoyrwcrmoj.supabase.co';

test.use({ serviceWorkers: 'block' });

const baseURL = process.env.BASE_URL;

const roles = [
  { code: 'SYSTEM_ADMIN', username: process.env.QA_SYSTEM_ADMIN_USERNAME, password: process.env.QA_SYSTEM_ADMIN_PASSWORD },
  { code: 'SALES_MANAGER', username: process.env.QA_SALES_MANAGER_USERNAME, password: process.env.QA_SALES_MANAGER_PASSWORD },
  { code: 'SALES_REP', username: process.env.QA_SALES_REP_USERNAME, password: process.env.QA_SALES_REP_PASSWORD },
  { code: 'WAREHOUSE_KEEPER', username: process.env.QA_WAREHOUSE_KEEPER_USERNAME, password: process.env.QA_WAREHOUSE_KEEPER_PASSWORD },
  { code: 'PRODUCTION_MANAGER', username: process.env.QA_PRODUCTION_MANAGER_USERNAME, password: process.env.QA_PRODUCTION_MANAGER_PASSWORD },
  { code: 'ACCOUNTANT', username: process.env.QA_ACCOUNTANT_USERNAME, password: process.env.QA_ACCOUNTANT_PASSWORD },
  { code: 'GENERAL_MANAGER', username: process.env.QA_GENERAL_MANAGER_USERNAME, password: process.env.QA_GENERAL_MANAGER_PASSWORD }
];

const menuIds = [
  'menuProducts', 'menuLocations', 'menuStock', 'menuStockTransfers', 'menuRecipes',
  'menuProduction', 'menuReservations', 'menuSuppliers', 'menuPurchases',
  'menuPurchaseReturns', 'menuLandedCosts', 'menuFixedAssets', 'menuSupplierPayments',
  'menuExpenses', 'menuCustomers', 'menuSales', 'menuPriceLists', 'menuCollections',
  'menuTrips', 'menuSalesReps', 'menuTreasuries', 'menuTreasuryTransfers',
  'menuPartners', 'menuAccounting', 'menuReports', 'menuSettings'
];

for (const role of roles) {
  test('Independent role login and visible-menu report: ' + role.code, async ({ page }) => {
    test.setTimeout(120000);
    test.skip(process.env.QA_ROLE_TESTS_SAFE_ENVIRONMENT !== 'true',
      'Skipped safely: QA_ROLE_TESTS_SAFE_ENVIRONMENT is not true. A separate safe database environment is required.');
    test.skip(!baseURL || !role.username || !role.password,
      'Skipped safely: credentials for ' + role.code + ' are not configured.');
    test.skip(!appSupabaseUrl || appSupabaseUrl === productionSupabaseUrl,
      'Blocked safely: this app build points to the production Supabase project. Role login tests require a separate test-project build.');
    test.skip(!process.env.QA_SUPABASE_URL || appSupabaseUrl !== process.env.QA_SUPABASE_URL,
      'Blocked safely: QA_SUPABASE_URL must exactly match the Supabase URL embedded in the test app build.');

    const pageErrors = [];
    const consoleErrors = [];
    let actualRole = null;
    page.on('pageerror', error => pageErrors.push(error.message));
    page.on('response', async response => {
      try {
        const responseUrl = new URL(response.url());
        if (response.ok() && responseUrl.pathname.endsWith('/rest/v1/app_roles')) {
          const payload = await response.json();
          const row = Array.isArray(payload) ? payload[0] : payload;
          if (row && typeof row.role_code === 'string') actualRole = row.role_code;
        }
      } catch (_) {
        // Ignore unrelated or non-JSON responses; the role assertion below will fail if no role was returned.
      }
    });
    page.on('console', message => {
      if (message.type() === 'error') {
        const value = message.text();
        if (!value.startsWith("[PWA] failed TypeError: Cannot read properties of undefined (reading 'scope')")) {
          consoleErrors.push(value);
        }
      }
    });

    await page.route(baseURL, route => route.fulfill({
      path: path.resolve(__dirname, '..', 'index.html'),
      contentType: 'text/html'
    }));

    const response = await page.goto(baseURL, { waitUntil: 'domcontentloaded' });
    expect(response, 'The app should return a document for ' + role.code).not.toBeNull();
    expect(response.status()).toBe(200);
    await expect(page.locator('#loginForm')).toBeVisible({ timeout: 30000 });
    await page.locator('#email').fill(role.username);
    await page.locator('#password').fill(role.password);
    await page.locator('#loginBtn').click();
    await expect(page.locator('#home')).toBeVisible({ timeout: 60000 });
    await expect(page.locator('#userInfo')).not.toContainText('جارٍ تحميل بيانات الحساب', { timeout: 30000 });

    expect(actualRole, 'The app_roles response must identify the signed-in account as ' + role.code).toBe(role.code);

    const visibleMenus = await page.evaluate(ids => ids.filter(id => {
      const element = document.getElementById(id);
      return !!element && !element.classList.contains('hidden') && element.getClientRects().length > 0;
    }), menuIds);

    const report = {
      expectedRole: role.code,
      actualRole,
      visibleMenus,
      hiddenMenus: menuIds.filter(id => !visibleMenus.includes(id)),
      pageErrors,
      consoleErrors,
      note: 'Menu visibility is observational only. Permission and RLS approval requires a separately approved role matrix and safe test environment.'
    };
    console.log('MEATMANAGEMENT_ROLE_COVERAGE:', JSON.stringify(report));
    await page.screenshot({ path: 'test-results/role-coverage/' + role.code + '.png', fullPage: true });
    expect(pageErrors, 'Uncaught page errors for ' + role.code).toEqual([]);
    expect(consoleErrors, 'Console errors for ' + role.code).toEqual([]);
  });
}
