const { test, expect } = require('@playwright/test');

test.use({ serviceWorkers: 'block' });

const baseURL = process.env.BASE_URL || 'http://127.0.0.1:4173/';

test('Bible reader loads both local Arabic editions and preserves missing-book behavior', async ({ page }) => {
  test.setTimeout(90000);
  await page.goto(new URL('bible/', baseURL).toString());
  await page.locator('.nav button[data-view="read"]').click();
  await expect(page.locator('#chapterTranslation')).toBeVisible();

  await page.locator('#chapterTranslation').selectOption('AR-SVD-1865');
  await page.locator('#chapterReference').fill('يوحنا 1');
  await page.locator('#loadChapterButton').click();
  await expect(page.locator('#chapterStatus')).toContainText('تم تحميل فان دايك 1865 داخل التطبيق');
  await expect(page.locator('#chapterContent > .verse-card')).toHaveCount(1);
  await expect(page.locator('#chapterContent')).toContainText('فان دايك 1865');

  await page.locator('#chapterTranslation').selectOption('AR-KEH-2012');
  await page.locator('#loadChapterButton').click();
  await expect(page.locator('#chapterStatus')).toContainText('تم تحميل كتاب الحياة 2012 داخل التطبيق');
  await expect(page.locator('#chapterContent > .verse-card')).toHaveCount(1);
  await expect(page.locator('#chapterContent')).toContainText('كتاب الحياة 2012');

  await page.locator('#chapterTranslation').selectOption('AR-SVD-1865');
  await page.locator('#chapterReference').fill('طوبيا 1');
  await page.locator('#loadChapterButton').click();
  await expect(page.locator('#chapterStatus')).toContainText('هذا السفر غير متوفر');
  await expect(page.locator('#chapterContent')).toContainText('لن نستبدل نصه بترجمة أخرى');
});
