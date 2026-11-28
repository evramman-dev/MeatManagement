const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const volumeId = 'WYZn1xHeD-IC';
const firstPage = 479;
const lastPage = 504;
const outputDir = path.join(process.cwd(), 'test-results', 'swete-ecclesiastes');
fs.mkdirSync(outputDir, { recursive: true });

(async () => {
  const report = {
    volumeId,
    edition: 'Swete, volume II, third edition, 1907',
    method: 'Google Books full-view page URL (pg=PA<number>)',
    requestedPrintedPages: [firstPage, lastPage],
    startedAt: new Date().toISOString(),
    captures: [],
    error: null
  };
  let browser;
  try {
    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
      viewport: { width: 1600, height: 1200 },
      deviceScaleFactor: 1
    });
    const page = await context.newPage();
    page.setDefaultTimeout(30000);

    for (let printedPage = firstPage; printedPage <= lastPage; printedPage += 1) {
      const url = `https://books.google.com/books?id=${volumeId}&pg=PA${printedPage}&jscmd=SearchWithinVolume2&q=`;
      const entry = { printedPage, url, captured: false };
      try {
        const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
        entry.httpStatus = response && response.status();
        await page.waitForTimeout(2500);
        const state = await page.evaluate(() => {
          const bodyText = (document.body && document.body.innerText || '').slice(0, 1800);
          const canvases = Array.from(document.querySelectorAll('canvas')).map((canvas) => ({
            width: canvas.width, height: canvas.height
          }));
          const images = Array.from(document.images).map((image) => ({
            src: image.currentSrc || image.src, complete: image.complete,
            naturalWidth: image.naturalWidth, naturalHeight: image.naturalHeight
          })).filter((image) => image.naturalWidth > 0);
          return { title: document.title, bodyText, canvases, images, pageUrl: location.href };
        });
        entry.title = state.title;
        entry.bodyText = state.bodyText;
        entry.canvasCount = state.canvases.length;
        entry.canvases = state.canvases;
        entry.loadedImageCount = state.images.length;
        entry.images = state.images.slice(0, 8);
        entry.finalUrl = state.pageUrl;
        const denial = /not available|no preview|access denied|unusual traffic|sorry/i.test(state.bodyText);
        const visualContent = state.canvases.some((canvas) => canvas.width > 300 && canvas.height > 300) ||
          state.images.some((image) => image.naturalWidth > 300 && image.naturalHeight > 300);
        if (response && response.ok() && !denial && visualContent) {
          const filename = `swete-vol2-page-${printedPage}.png`;
          await page.screenshot({ path: path.join(outputDir, filename), fullPage: true, animations: 'disabled' });
          entry.filename = filename;
          entry.captured = true;
        } else {
          entry.reason = !response || !response.ok()
            ? 'Google Books page did not return a successful HTTP response'
            : denial
              ? 'Google Books page displayed an access or availability message'
              : 'No loaded page-image canvas or image was detected';
        }
      } catch (error) {
        entry.reason = String(error && error.message || error);
      }
      report.captures.push(entry);
      console.log(`Swete printed page ${printedPage}: ${entry.captured ? 'captured' : 'not captured'}`);
    }
  } catch (error) {
    report.error = String(error && error.stack || error);
    console.error(report.error);
  } finally {
    report.finishedAt = new Date().toISOString();
    report.capturedCount = report.captures.filter((entry) => entry.captured).length;
    fs.writeFileSync(path.join(outputDir, 'capture-report.json'), JSON.stringify(report, null, 2) + '\n');
    if (browser) await browser.close();
    console.log(JSON.stringify({ capturedCount: report.capturedCount, requestedCount: lastPage - firstPage + 1, error: report.error }, null, 2));
  }
})();
