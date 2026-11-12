const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');
const qaHtml = fs.readFileSync(path.resolve(__dirname, '..', 'index.html'), 'utf8');

test.use({ serviceWorkers: 'block' });

test('Factory reset readiness inventory through the application UI', async ({ page }) => {
  test.setTimeout(240000);
  const baseURL = process.env.BASE_URL;
  const username = process.env.TEST_USERNAME;
  const password = process.env.TEST_PASSWORD;
  if (!baseURL || !username || !password) throw new Error('Browser test credentials are not configured.');

  const deployed = new URL(baseURL);
  await page.route('**/*', async route => {
    const request = route.request();
    const url = new URL(request.url());
    if (request.isNavigationRequest() && url.origin === deployed.origin && url.pathname === deployed.pathname) {
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

  const snapshot = await page.evaluate(() => ({
    displayName: document.getElementById('userInfo')?.textContent || '',
    roleCode: typeof currentRoleCode !== 'undefined' ? currentRoleCode : null,
    isSystemAdmin: typeof isSystemAdmin !== 'undefined' ? isSystemAdmin : null
  }));

  const wait = ms => page.waitForTimeout(ms);
  const open = async section => {
    await page.evaluate(name => window.openSection(name), section);
    await wait(900);
  };
  const countOptions = async selector => page.locator(selector + ' option').count();
  const countChildren = async selector => page.locator(selector + ' > *').count();

  await open('products');
  if (await page.locator('#addBtn').isVisible().catch(() => false)) await page.locator('#addBtn').click();
  await wait(500);
  snapshot.productCategories = await countOptions('#category');
  snapshot.productUnits = await countOptions('#baseUnit');
  snapshot.productFormAvailable = await page.locator('#productFormModal').evaluate(el => el.classList.contains('active'));

  await open('suppliers');
  snapshot.suppliers = await countChildren('#suppliersList');
  snapshot.canAddSupplier = await page.locator('#addSupplierBtn').isVisible().catch(() => false);

  await open('customers');
  snapshot.customers = await countChildren('#customersList');
  snapshot.canAddCustomer = await page.locator('#addCustomerBtn').isVisible().catch(() => false);
  if (snapshot.canAddCustomer) {
    await page.locator('#addCustomerBtn').click();
    await wait(500);
    snapshot.governorates = await countOptions('#customerGovernorate');
    snapshot.customerCitiesInitially = await countOptions('#customerCity');
    await page.locator('#customerFormModal .close-btn').click();
  }

  await open('salesReps');
  snapshot.salesReps = await countChildren('#salesRepsList');
  snapshot.canAddSalesRep = await page.locator('#addSalesRepBtn').isVisible().catch(() => false);

  await open('locations');
  snapshot.locations = await countChildren('#locationsList');
  snapshot.canAddLocation = await page.locator('#addLocationBtn').isVisible().catch(() => false);

  await open('treasuries');
  snapshot.treasuries = await countChildren('#treasuriesList');
  snapshot.canAddTreasury = await page.locator('#addTreasuryBtn').isVisible().catch(() => false);

  await open('expenses');
  snapshot.expenseTypes = await countOptions('#expenseType');

  await open('purchases');
  snapshot.purchaseSuppliers = await countOptions('#purchaseSupplier');
  snapshot.purchaseLocations = await countOptions('#purchaseLocation');

  await open('trips');
  snapshot.tripReps = await countOptions('#tripRepSelect');
  snapshot.tripSources = await countOptions('#tripSource');
  snapshot.tripVehicles = await countOptions('#tripVehicle');

  console.log('MEATMANAGEMENT_FACTORY_RESET_READINESS:', JSON.stringify(snapshot, null, 2));
  await page.screenshot({ path: 'test-results/factory-reset-readiness.png', fullPage: true });
  expect(snapshot.displayName).not.toContain('جارٍ تحميل بيانات الحساب');
});
