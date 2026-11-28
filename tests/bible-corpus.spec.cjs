const { test, expect } = require('@playwright/test');

test.use({ serviceWorkers: 'block' });

const baseURL = process.env.BASE_URL || 'http://127.0.0.1:4173/';

async function chooseReaderOption(page, value) {
  const option = page.locator(`#readerPickerOptions [data-reader-option="${value}"]`);
  await expect(option).toBeVisible();
  await option.click();
}

async function openReaderChapter(page, { translation, covenant, section, book, chapter }) {
  await page.locator('#readerChooseButton').click();
  await expect(page.locator('#readerPickerModal')).toBeVisible();

  await page.locator('#readerPickerPath [data-reader-picker-field="translation"]').click();
  await chooseReaderOption(page, translation);
  await chooseReaderOption(page, covenant);
  await chooseReaderOption(page, section);
  await chooseReaderOption(page, book);
  await chooseReaderOption(page, String(chapter));
  await chooseReaderOption(page, 'all');

  await expect(page.locator('#readerPickerModal')).toBeHidden();
  await expect(page.locator('#chapterContent .reader-verse')).not.toHaveCount(0);
  await expect(page.locator('#chapterContent .reader-verse-text').first()).toBeVisible();
}

async function openReaderBookOptions(page, { translation, covenant, section }) {
  await page.locator('#readerChooseButton').click();
  await expect(page.locator('#readerPickerModal')).toBeVisible();
  await page.locator('#readerPickerPath [data-reader-picker-field="translation"]').click();
  await chooseReaderOption(page, translation);
  await chooseReaderOption(page, covenant);
  await chooseReaderOption(page, section);
}

test('Bible reader loads local editions and keeps unavailable books and chapters out of their pickers', async ({ page }) => {
  test.setTimeout(90000);
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(error.stack || error.message));
  page.on('console', message => { if (message.type() === 'error') pageErrors.push(message.text() + ' ' + JSON.stringify(message.location())); });
  await page.goto(new URL('bible/', baseURL).toString());
  await page.waitForTimeout(100);
  expect(pageErrors).toEqual([]);

  await page.locator('.nav button[data-view="verses"]').click();
  await page.locator('#verseReference').fill('يوحنا 1:1');
  await page.locator('#verseText').fill('في البدء كان الكلمة');
  await page.locator('#saveVerseButton').click();
  await expect(page.locator('#verseSaveStatus')).toContainText('تم حفظ الآية');
  await expect(page.locator('#savedVerseCount')).toHaveText('1');

  await page.locator('.nav button[data-view="me"]').click();
  await page.locator('#notesJournal').fill('اختبار حفظ المذكرات');
  await page.locator('#notesSaveButton').click();
  await expect(page.locator('#notesSaveStatus')).toContainText('تم الحفظ');
  await expect(page.locator('#notesList')).toContainText('اختبار حفظ المذكرات');

  await page.locator('.nav button[data-view="read"]').click();
  await expect(page.locator('#readerChooseButton')).toBeVisible();

  await page.locator('#bibleSearchTranslation').selectOption('AR-SVD-1865');
  await page.locator('#bibleSearchInput').fill('في البدء');
  await page.locator('#bibleSearchButton').click();
  await expect(page.locator('#bibleSearchStatus')).toContainText('عُثر على');
  await expect(page.locator('#bibleSearchResults')).toContainText('في البدء');
  await page.locator('#bibleSearchResults [data-bible-search-result="0"]').click();
  await expect(page.locator('#readerStatus')).toContainText('تم فتح الآية');
  await expect(page.locator('#chapterContent')).toContainText('في البدء');

  await openReaderChapter(page, {
    translation: 'AR-SVD-1865',
    covenant: 'NT',
    section: 'الأناجيل',
    book: 'JHN',
    chapter: 1
  });
  await expect(page.locator('#chapterContent .reader-verse-text').first()).toHaveAttribute('lang', 'ar');

  await openReaderChapter(page, {
    translation: 'AR-KEH-2012',
    covenant: 'NT',
    section: 'الأناجيل',
    book: 'JHN',
    chapter: 1
  });
  await expect(page.locator('#chapterContent .reader-verse-text').first()).toHaveAttribute('lang', 'ar');

  await openReaderBookOptions(page, {
    translation: 'AR-SVD-1865',
    covenant: 'OT',
    section: 'التاريخية'
  });
  await expect(page.locator('#readerPickerOptions [data-reader-option="TOB"]')).toHaveCount(0);
  await page.locator('#readerPickerClose').click();
  await expect(page.locator('#readerPickerModal')).toBeHidden();

  await openReaderChapter(page, {
    translation: 'HE-WLC-2017',
    covenant: 'OT',
    section: 'الشريعة',
    book: 'GEN',
    chapter: 1
  });
  await expect(page.locator('#chapterContent .reader-verse-text').first()).toHaveAttribute('lang', 'he');
  await expect(page.locator('#chapterContent')).toContainText('בְּרֵאשִׁ֖ית');

  await openReaderChapter(page, {
    translation: 'HE-WLC-2017',
    covenant: 'OT',
    section: 'التاريخية',
    book: 'EST',
    chapter: 1
  });
  await page.locator('#readerChooseButton').click();
  await page.locator('#readerPickerPath [data-reader-picker-field="chapter"]').click();
  await expect(page.locator('#readerPickerOptions [data-reader-option="11"]')).toHaveCount(0);
  await page.locator('#readerPickerClose').click();

  await openReaderChapter(page, {
    translation: 'GRC-LXX-BRENTON-1851',
    covenant: 'OT',
    section: 'الشريعة',
    book: 'GEN',
    chapter: 1
  });
  await expect(page.locator('#chapterContent .reader-verse-text').first()).toHaveAttribute('lang', 'grc');
  await expect(page.locator('#chapterContent .reader-verse-text').first()).toHaveAttribute('dir', 'ltr');

  await openReaderChapter(page, {
    translation: 'GRC-LXX-BRENTON-1851',
    covenant: 'OT',
    section: 'التاريخية',
    book: 'TOB',
    chapter: 1
  });

  await openReaderChapter(page, {
    translation: 'GRC-LXX-BRENTON-1851',
    covenant: 'OT',
    section: 'إضافات السبعينية',
    book: '3MA',
    chapter: 1
  });

  await openReaderChapter(page, {
    translation: 'GRC-LXX-SWETE-1907-ECC',
    covenant: 'OT',
    section: 'الشعرية والحكمية',
    book: 'ECC',
    chapter: 12
  });
  await expect(page.locator('#chapterContent .reader-verse-text').first()).toHaveAttribute('lang', 'grc');
  await expect(page.locator('#chapterContent .reader-verse-text').first()).toHaveAttribute('dir', 'ltr');
  await expect(page.locator('#chapterContent')).toContainText('Τέλος');
  await expect(page.locator('#chapterStatus')).toContainText('سويتي 1907');

  await openReaderChapter(page, {
    translation: 'GRC-KOINE-RP-2018',
    covenant: 'NT',
    section: 'الأناجيل',
    book: 'JHN',
    chapter: 1
  });
  await expect(page.locator('#chapterContent .reader-verse-text').first()).toHaveAttribute('lang', 'grc');
  await expect(page.locator('#chapterContent .reader-verse-text').first()).toHaveAttribute('dir', 'ltr');
  await expect(page.locator('#chapterContent')).toContainText('λόγος');

  await openReaderChapter(page, {
    translation: 'GRC-KOINE-RP-2018',
    covenant: 'NT',
    section: 'السفر النبوي',
    book: 'REV',
    chapter: 22
  });

  await page.locator('#readerChooseButton').click();
  await page.locator('#readerPickerPath [data-reader-picker-field="translation"]').click();
  await chooseReaderOption(page, 'GRC-KOINE-RP-2018');
  await chooseReaderOption(page, 'OT');
  await expect(page.locator('#readerPickerOptions [data-reader-option="GEN"]')).toHaveCount(0);
});
