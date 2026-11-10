
const { test, expect } = require('@playwright/test');

const baseURL = process.env.BASE_URL;
const username = process.env.TEST_USERNAME;
const password = process.env.TEST_PASSWORD;

const sections = [
  'products',
  'locations',
  'stock',
  'stockTransfers',
  'recipes',
  'production',
  'reservations',
  'suppliers',
  'purchases',
  'purchaseReturns',
  'landedCosts',
  'fixedAssets',
  'supplierPayments',
  'expenses',
  'customers',
  'sales',
  'priceLists',
  'collections',
  'trips',
  'salesReps',
  'treasuries',
  'treasuryTransfers',
  'partners',
  'accounting',
  'reports',
  'settings'
];

test('MeatManagement read-only browser smoke test', async ({ page }) => {
  test.setTimeout(180000);

  const errors = [];
  let currentSection = 'login';

  page.on('pageerror', error => {
    errors.push({
      section: currentSection,
      message: error.message
    });
  });

  await page.goto(baseURL, {
    waitUntil: 'domcontentloaded'
  });

  await expect(page.locator('#loginForm')).toBeVisible();

  await page.locator('#email').fill(username);
  await page.locator('#password').fill(password);
  await page.locator('#loginBtn').click();

  await expect(page.locator('#home')).toBeVisible({
    timeout: 60000
  });

  await page.screenshot({
    path: 'test-results/home.png',
    fullPage: true
  });

  currentSection = 'tasks';

  await page.locator('.navbtn[data-page="tasks"]').click();
  await expect(page.locator('#tasks')).toBeVisible();

  await page.screenshot({
    path: 'test-results/tasks.png',
    fullPage: true
  });

  currentSection = 'data';

  await page.locator('.navbtn[data-page="data"]').click();
  await expect(page.locator('#data')).toBeVisible();

  await page.screenshot({
    path: 'test-results/data.png',
    fullPage: true
  });

  const usersMenu = await page.locator('#menuUsers').count();

  if (usersMenu > 0) {
    await expect(page.locator('#menuUsers')).toBeHidden();
  }

  for (const section of sections) {
    currentSection = section;

    await page.evaluate((route) => {
      if (typeof window.openSection === 'function') {
        window.openSection(route);
      } else {
        throw new Error('openSection function not found');
      }
    }, section);

    await page.waitForTimeout(700);

    await page.screenshot({
      path: `test-results/${section}.png`,
      fullPage: true
    });
  }

  console.log(
    'Browser JavaScript errors:',
    JSON.stringify(errors, null, 2)
  );

  expect(errors, 'JavaScript errors detected').toEqual([]);
});
