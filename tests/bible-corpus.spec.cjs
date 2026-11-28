const { test, expect } = require('@playwright/test');

test.use({ serviceWorkers: 'block' });

// Verify the dedicated search screen and its handoff back to the reader.

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

test('long translation labels stay inside the two mobile reader picker columns', async ({ page }) => {
  await page.setViewportSize({ width: 360, height: 800 });
  await page.goto(new URL('bible/', baseURL).toString());
  await page.locator('.nav button[data-view="read"]').click();
  await page.locator('#readerChooseButton').click();
  await expect(page.locator('#readerPickerModal')).toBeVisible();
  await page.locator('#readerPickerPath [data-reader-picker-field="translation"]').click();
  await chooseReaderOption(page, 'GRC-KOINE-RP-2018');

  const layout = await page.evaluate(() => {
    const path = document.querySelector('#readerPickerPath');
    const fields = [...path.querySelectorAll('.reader-picker-field')];
    const viewportWidth = document.documentElement.clientWidth;
    return {
      viewportWidth,
      pathRight: path.getBoundingClientRect().right,
      pathLeft: path.getBoundingClientRect().left,
      fields: fields.map(field => {
        const label = field.querySelector('strong');
        const rect = field.getBoundingClientRect();
        return {
          left: rect.left,
          right: rect.right,
          width: rect.width,
          clientWidth: label.clientWidth,
          scrollWidth: label.scrollWidth,
          whiteSpace: getComputedStyle(label).whiteSpace,
          overflow: getComputedStyle(label).overflow,
          textOverflow: getComputedStyle(label).textOverflow
        };
      })
    };
  });
  expect(layout.fields).toHaveLength(6);
  expect(layout.pathLeft).toBeGreaterThanOrEqual(0);
  expect(layout.pathRight).toBeLessThanOrEqual(layout.viewportWidth + 1);
  for (const field of layout.fields) {
    expect(field.left).toBeGreaterThanOrEqual(0);
    expect(field.right).toBeLessThanOrEqual(layout.viewportWidth + 1);
    expect(field.width).toBeLessThanOrEqual((layout.viewportWidth - 40) / 2 + 2);
    expect(field.whiteSpace).toBe('nowrap');
    expect(field.overflow).toBe('hidden');
    expect(field.textOverflow).toBe('ellipsis');
  }
});

test('Bible reader loads local editions and keeps unavailable books and chapters out of their pickers', async ({ page }) => {
  test.setTimeout(180000);
  const pageErrors = [];
  await page.addInitScript(() => { window.addEventListener('error', event => { console.error('GLOBAL_SCRIPT_ERROR', event.message, event.filename, event.lineno, event.colno); }); });
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
  await expect(page.locator('#bibleSearchCard')).toBeHidden();

  await page.locator('.nav button[data-view="search"]').click();
  await expect(page.locator('#bibleSearchCard')).toBeVisible();
  await page.locator('#bibleSearchTranslation').selectOption('AR-SVD-1865');
  await page.locator('#bibleSearchInput').fill('في البدء');
  await page.locator('#bibleSearchButton').click();
  await expect(page.locator('#bibleSearchStatus')).toContainText('عُثر على');
  await expect(page.locator('#bibleSearchResults')).toContainText('خَلَقَ');
  await page.locator('#bibleSearchResults [data-bible-search-result="0"]').click();
  await expect(page.locator('#readerStatus')).toContainText('تم فتح الآية');
  await expect(page.locator('#chapterContent')).toContainText('خَلَقَ');

  // A broad Arabic search must expose every match in batches, not stop at 100.
  await page.locator('.nav button[data-view="search"]').click();
  await page.locator('#bibleSearchTranslation').selectOption('AR-SVD-1865');
  await page.locator('#bibleSearchInput').fill('يسوع');
  await page.locator('#bibleSearchButton').click();
  await expect(page.locator('#bibleSearchStatus')).toContainText('عُثر على');
  await expect(page.locator('#bibleSearchStatus')).toContainText('نعرض 100 من');
  await expect(page.locator('#bibleSearchResults .result')).toHaveCount(100);
  await expect(page.locator('#bibleSearchLoadMore')).toBeVisible();
  await page.locator('#bibleSearchLoadMore').click();
  await expect(page.locator('#bibleSearchResults .result')).toHaveCount(200);
  await expect(page.locator('#bibleSearchStatus')).toContainText('نعرض 200 من');
  await page.locator('#bibleSearchResults [data-bible-search-result="100"]').click();
  await expect(page.locator('#readerStatus')).toContainText('تم فتح الآية');

  await page.locator('.nav button[data-view="search"]').click();
  await page.locator('#bibleSearchTranslation').selectOption('HE-WLC-2017');
  await page.locator('#bibleSearchInput').fill('בראשית');
  await page.locator('#bibleSearchButton').click();
  await expect(page.locator('#bibleSearchStatus')).toContainText('عُثر على');
  await expect(page.locator('#bibleSearchResults')).toContainText('בְּרֵאשִׁ֖ית');
  await page.locator('#bibleSearchResults [data-bible-search-result="0"]').click();
  await expect(page.locator('#readerStatus')).toContainText('تم فتح الآية');
  await expect(page.locator('#chapterContent')).toContainText('בְּרֵאשִׁ֖ית');

  await page.locator('.nav button[data-view="search"]').click();
  await page.locator('#bibleSearchTranslation').selectOption('GRC-KOINE-RP-2018');
  await page.locator('#bibleSearchInput').fill('λογος');
  await page.locator('#bibleSearchButton').click();
  await expect(page.locator('#bibleSearchStatus')).toContainText('عُثر على');
  await expect(page.locator('#bibleSearchResults')).toContainText('λόγος');
  await page.locator('#bibleSearchResults [data-bible-search-result="0"]').click();
  await expect(page.locator('#readerStatus')).toContainText('تم فتح الآية');
  await expect(page.locator('#chapterContent')).toContainText('λόγος');

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


  await page.locator('#readerPickerClose').click();
  await expect(page.locator('#readerPickerModal')).toBeHidden();

  // Verify all three embedded legacy Coptic fonts against real Bohairic chapter text.
  await openReaderChapter(page, {
    translation: 'COP-BOHAIRIC-HORNER',
    covenant: 'NT',
    section: 'الأناجيل',
    book: 'JHN',
    chapter: 1
  });
  const copticVerse = page.locator('#chapterContent .reader-verse-text').first();
  await expect(copticVerse).toHaveAttribute('lang', 'cop');
  await expect(page.locator('#readerFontCopticNoto')).toBeVisible();
  await expect(page.locator('#readerFontCopticNoto')).toHaveClass(/filter-active/);
  const unicodeSample = '̀ⲙ̀ Ⲙⲙ ⲉ︤ⲛ︥ ⲡ̅ⲛ̅ⲁ̅';
  const originalVerseText = await copticVerse.textContent();
  await copticVerse.evaluate((el, value) => { el.textContent = value; }, unicodeSample);
  const unicodeRender = await copticVerse.evaluate(el => ({
    text: el.textContent,
    family: getComputedStyle(el).fontFamily,
    features: getComputedStyle(el).fontFeatureSettings
  }));
  expect(unicodeRender.text).toBe(unicodeSample);
  expect(unicodeRender.family).toContain('Noto Sans Coptic');
  expect(unicodeRender.features).toContain('mark');
  expect(unicodeRender.features).toContain('mkmk');
  const unicodeFontLoaded = await page.evaluate(async () => {
    await document.fonts.load('20px "Noto Sans Coptic"');
    return document.fonts.check('20px "Noto Sans Coptic"');
  });
  expect(unicodeFontLoaded).toBe(true);
  await copticVerse.screenshot({ path: 'test-results/coptic-font-noto-unicode-marks.png' });
  await copticVerse.evaluate((el, value) => { el.textContent = value; }, originalVerseText);
  await page.locator('#readerFontCopticCopt').click();
  await expect(copticVerse).toHaveAttribute('data-coptic-legacy-applied', '1');
  expect(await copticVerse.getAttribute('data-coptic-unicode')).toMatch(/[Ⲁ-⳿]/);
  await page.locator('#readerOptionsButton').click();
  await expect(page.locator('#readerOptionsModal')).toBeVisible();
  await expect(page.locator('#readerFontCopticGroup')).toBeVisible();

  const copticFonts = [
    { id: 'copt', button: '#readerFontCopticCopt', className: 'reader-font-coptic-copt', family: 'Copt Legacy' },
    { id: 'new-athanasius', button: '#readerFontCopticNewAthanasius', className: 'reader-font-coptic-new-athanasius', family: 'New Athanasius Legacy' },
    { id: 'athanasius-plain', button: '#readerFontCopticAthanasiusPlain', className: 'reader-font-coptic-athanasius-plain', family: 'Athanasius Plain Legacy' }
  ];
  for (let index = 0; index < copticFonts.length; index++) {
    const font = copticFonts[index];
    await page.locator(font.button).click();
    await expect(page.locator('#readerDisplayPreview')).toHaveClass(new RegExp(font.className));
    await expect(copticVerse).toHaveAttribute('data-coptic-legacy-applied', '1');
    const rendered = await copticVerse.evaluate(el => ({
      original: el.dataset.copticUnicode || '',
      displayed: el.textContent || '',
      family: getComputedStyle(el).fontFamily
    }));
    expect(rendered.original).toMatch(/[Ⲁ-⳿]/);
    expect(rendered.displayed).not.toBe(rendered.original);
    expect(rendered.family).toContain(font.family);
    const loaded = await page.evaluate(async family => {
      await document.fonts.load('16px "' + family + '"');
      return document.fonts.check('16px "' + family + '"');
    }, font.family);
    expect(loaded).toBe(true);
    await page.locator('#readerOptionsClose').click();
    await expect(page.locator('#readerOptionsModal')).toBeHidden();
    await copticVerse.screenshot({ path: 'test-results/coptic-font-' + font.id + '.png' });
    if (index < copticFonts.length - 1) {
      await page.locator('#readerOptionsButton').click();
      await expect(page.locator('#readerOptionsModal')).toBeVisible();
    }
  }
  const copyCheck = await page.evaluate(() => {
    const verse = document.querySelector('#chapterContent .reader-verse-text.coptic-script');
    const glyph = verse && verse.querySelector('.coptic-legacy-char');
    if (!glyph) return { copied: '', expected: 'MISSING_GLYPH', prevented: false };
    const range = document.createRange();
    range.selectNodeContents(glyph);
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    const clipboard = new DataTransfer();
    const event = new ClipboardEvent('copy', { clipboardData: clipboard, bubbles: true, cancelable: true });
    document.dispatchEvent(event);
    return { copied: clipboard.getData('text/plain'), expected: glyph.dataset.unicode, prevented: event.defaultPrevented };
  });
  expect(copyCheck.copied).toBe(copyCheck.expected);
  expect(copyCheck.prevented).toBe(true);
  await expect(page.locator('#readerOptionsModal')).toBeHidden();
});
