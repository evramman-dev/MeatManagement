const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const volumeId = 'WYZn1xHeD-IC';
const queries = [
  'ΡΗΜΑΤΑ',
  'Εἶπα ἐγὼ',
  'Πάντα τῷ χρόνῳ',
  'Καὶ ἐπέστρεψα',
  'Φύλαξον τὸν πόδα',
  'Ἔστιν κακόν',
  'Τί ἀγαθὸν',
  'Τίς ὁ σοφός',
  'Ὅτι πάντα',
  'Μυῖαι θανάτου',
  'Ἀπόστειλον',
  'Καὶ μνήσθητι'
];
const outputDir = path.join(process.cwd(), 'test-results', 'swete-ecclesiastes-chapter-probe');
fs.mkdirSync(outputDir, { recursive: true });

(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1600, height: 1200 } });
    page.setDefaultTimeout(30000);
    const results = [];
    for (const q of queries) {
      const url = 'https://books.google.com/books?id=' + volumeId +
        '&jscmd=SearchWithinVolume2&q=' + encodeURIComponent(q);
      const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
      await page.waitForTimeout(1000);
      const body = await page.locator('body').innerText().catch(() => '');
      const item = {
        query: q,
        url,
        httpStatus: response && response.status(),
        contentType: response && response.headers()['content-type'],
        finalUrl: page.url(),
        bodyText: body.slice(0, 16000)
      };
      results.push(item);
      fs.writeFileSync(
        path.join(outputDir, 'query-' + results.length + '.json'),
        JSON.stringify(item, null, 2) + '\n'
      );
    }
    fs.writeFileSync(path.join(outputDir, 'probe-report.json'), JSON.stringify(results, null, 2) + '\n');
    console.log(JSON.stringify(results.map(({query, httpStatus, contentType, finalUrl, bodyText}) => ({
      query, httpStatus, contentType, finalUrl, bodyText
    })), null, 2));
  } finally {
    await browser.close();
  }
})();
