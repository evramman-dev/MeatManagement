const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const volumeId = 'WYZn1xHeD-IC';
const queries = [
  'Τοῖς πᾶσι χρόνος',
  'Εἶπον ἐγὼ ἐν καρδίᾳ μου',
  'Καὶ ἐπέστρεψα ἐγὼ καὶ εἶδον πάντας',
  'Φύλαξον τὸν πόδα σου',
  'Ἔστιν κακόν ὃ εἶδον ὑπὸ τὸν ἥλιον',
  'Ἀγαθὸν ὄνομα ὑπὲρ ἔλαιον ἀγαθόν',
  'Τίς ὁ σοφός',
  'Ὅτι πάντα ταῦτα ἔδωκα ἐν καρδίᾳ μου',
  'Μυῖαι θανάτου',
  'Ἀπόστειλον τὸν ἄρτον σου',
  'Καὶ μνήσθητι τοῦ κτίσαντός σε',
  'Ματαιότης ματαιοτήτων'
];
const outputDir = path.join(process.cwd(), 'test-results', 'swete-ecclesiastes-exact-chapter-probe');
fs.mkdirSync(outputDir, { recursive: true });
(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1600, height: 1200 } });
    page.setDefaultTimeout(30000);
    const results = [];
    for (const q of queries) {
      const url = 'https://books.google.com/books?id=' + volumeId + '&jscmd=SearchWithinVolume2&q=' + encodeURIComponent(q);
      const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
      await page.waitForTimeout(800);
      const body = await page.locator('body').innerText().catch(() => '');
      const pages = [...new Set((body.match(/Page (\\d+)/g) || []).map(x => Number(x.slice(5))))];
      const item = { query:q, url, httpStatus:response && response.status(), finalUrl:page.url(), pages, bodyText:body.slice(0,12000) };
      results.push(item);
      fs.writeFileSync(path.join(outputDir, 'query-' + results.length + '.json'), JSON.stringify(item,null,2)+'\\n');
    }
    fs.writeFileSync(path.join(outputDir,'probe-report.json'),JSON.stringify(results,null,2)+'\\n');
    console.log(JSON.stringify(results.map(x=>({query:x.query,httpStatus:x.httpStatus,pages:x.pages,bodyText:x.bodyText.slice(0,1800)})),null,2));
  } finally { await browser.close(); }
})();
