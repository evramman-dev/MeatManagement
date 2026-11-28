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
    requestedPrintedPages: [firstPage, lastPage],
    startedAt: new Date().toISOString(),
    viewerLoaded: false,
    captures: [],
    error: null
  };

  let browser;
  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({
      viewport: { width: 1600, height: 1200 },
      deviceScaleFactor: 1
    });
    page.setDefaultTimeout(60000);
    await page.setContent(`<!doctype html>
<html><head><meta charset="utf-8"><title>Swete 1907 page capture</title>
<style>html,body{margin:0;width:100%;height:100%;background:#eee}#viewerCanvas{width:100%;height:100vh}</style>
</head><body><div id="viewerCanvas"></div></body></html>`);

    await page.addScriptTag({ url: 'https://www.google.com/books/jsapi.js' });
    await page.evaluate((id) => {
      window.sweteLoadError = null;
      window.sweteViewer = null;
      google.load('books', '0', {
        callback: function () {
          try {
            window.sweteViewer = new google.books.DefaultViewer(
              document.getElementById('viewerCanvas')
            );
            window.sweteViewer.load(
              id,
              function () { window.sweteLoadError = 'Google Books reported that the volume is unavailable for embedding'; },
              function () { window.sweteViewerReady = true; }
            );
          } catch (error) {
            window.sweteLoadError = String(error);
          }
        }
      });
    }, volumeId);

    await page.waitForFunction(
      () => window.sweteViewerReady === true || window.sweteLoadError !== null,
      { timeout: 90000 }
    );
    if (!await page.evaluate(() => window.sweteViewerReady === true)) {
      throw new Error(await page.evaluate(() => window.sweteLoadError || 'Google Books viewer did not initialize'));
    }
    report.viewerLoaded = true;

    for (let printedPage = firstPage; printedPage <= lastPage; printedPage += 1) {
      const accepted = await page.evaluate((n) => window.sweteViewer.goToPage(n), printedPage);
      if (!accepted) {
        report.captures.push({ printedPage, captured: false, reason: 'goToPage returned false' });
        continue;
      }

      try {
        await page.waitForFunction(
          (n) => window.sweteViewer && String(window.sweteViewer.getPageNumber()) === String(n),
          printedPage,
          { timeout: 15000 }
        );
      } catch {
        const observed = await page.evaluate(() => ({
          pageNumber: window.sweteViewer && window.sweteViewer.getPageNumber(),
          pageId: window.sweteViewer && window.sweteViewer.getPageId()
        }));
        report.captures.push({
          printedPage,
          captured: false,
          reason: 'viewer did not report the requested printed page',
          observed
        });
        continue;
      }

      await page.waitForTimeout(900);
      const details = await page.evaluate(() => ({
        pageNumber: window.sweteViewer.getPageNumber(),
        pageId: window.sweteViewer.getPageId()
      }));
      const filename = `swete-vol2-page-${printedPage}.png`;
      await page.screenshot({
        path: path.join(outputDir, filename),
        fullPage: true,
        animations: 'disabled'
      });
      report.captures.push({
        printedPage,
        captured: true,
        filename,
        ...details
      });
    }
  } catch (error) {
    report.error = String(error && error.stack || error);
    console.error(report.error);
  } finally {
    report.finishedAt = new Date().toISOString();
    report.capturedCount = report.captures.filter((entry) => entry.captured).length;
    fs.writeFileSync(path.join(outputDir, 'capture-report.json'), JSON.stringify(report, null, 2) + '\n');
    if (browser) await browser.close();
    console.log(JSON.stringify({
      viewerLoaded: report.viewerLoaded,
      capturedCount: report.capturedCount,
      requestedCount: lastPage - firstPage + 1,
      error: report.error
    }, null, 2));
  }
})();
