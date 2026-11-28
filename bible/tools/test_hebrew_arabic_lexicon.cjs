"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const root = __dirname + "/..";
const dictionary = JSON.parse(fs.readFileSync(root + "/data/strongs-ar.json", "utf8"));
const metadata = JSON.parse(fs.readFileSync(root + "/data/original-language-sources.json", "utf8"));
const html = fs.readFileSync(root + "/index.html", "utf8");
const sw = fs.readFileSync(root + "/sw.js", "utf8");

const expected = {
  H0347: ["أيوب", "أَيُّوب"],
  H5780: ["عوص", "عُوص"],
  H8034: ["اسم", "شِم"],
  H1931: ["هو", "هُو"],
  H8535: ["تام", "تَام"],
  H3477: ["مستقيم", "يَشَر"],
  H3373: ["يتقي", "يَارِئ"],
  H5493: ["يحيد", "سُور"],
  H7451: ["شر", "رَع"]
};

for (const [id, [meaning, pronunciation]] of Object.entries(expected)) {
  const entry = dictionary[id];
  assert.ok(entry, id + " must exist in the Arabic dictionary");
  assert.ok(entry.arabic.includes(meaning), id + " must include reviewed Arabic meaning");
  assert.equal(entry.pronunciation, pronunciation, id + " Arabic pronunciation");
  assert.equal(entry.language, "hebrew", id + " language");
}

assert.equal(metadata.hebrewLocalLexicon.arabicCoverage.entries, 40);
assert.equal(metadata.arabicLocalLexicon.entries, 489, "local Arabic lexicon total coverage");
assert.equal(metadata.arabicLocalLexicon.hebrewEntries, 40, "local Arabic Hebrew coverage");
assert.equal(metadata.arabicLocalLexicon.greekEntries, 449, "local Arabic Greek coverage");


const pronunciationCorrections = {
  H0001: "آڤ",
  H1697: "داڤار",
  H2822: "حوشِخ",
  H7363: "راحاف"
};
for (const [id, pronunciation] of Object.entries(pronunciationCorrections)) {
  assert.equal(dictionary[id]?.pronunciation, pronunciation, id + " reviewed Arabic pronunciation");
}
assert.equal(
  Object.values(dictionary).filter(entry => entry.language === "hebrew").length,
  40,
  "the local Hebrew Arabic lexicon must contain 40 explicitly tagged entries"
);
assert.equal(dictionary.H7225.language, "hebrew", "H7225 must be tagged as Hebrew");
assert.ok(dictionary.H7363.arabic.includes("يضعف"), "H7363 must retain the Qal sense of growing weak");
assert.ok(dictionary.H7363.arabic.includes("يحوم"), "H7363 must retain the Piel sense of hovering");
assert.match(dictionary.H7363.meaning, /تكوين 1:2/, "H7363 must explain its Genesis 1:2 contextual sense");
assert.equal(metadata._meta.version, 17, "original-language metadata version");

const cacheVersion = Number(sw.match(/const CACHE="rehla-v(\\d+)"/)?.[1] || 0);
assert.ok(cacheVersion >= 123, "Rehla service worker cache must be refreshed after reader changes");

const start = html.indexOf("function arabicPronunciationFromTransliteration");
const end = html.indexOf("\nlet READER_LOCAL_STRONGS_AR", start);
assert.ok(start >= 0 && end > start, "Hebrew pronunciation converter must exist");
const source = html.slice(start, end);
const sandbox = {};
vm.runInNewContext(source + "\nthis.convert = arabicPronunciationFromTransliteration;", sandbox);

assert.equal(sandbox.convert("ya.shar", "H3477"), "يَشَر");
assert.equal(sandbox.convert("uts", "H5780"), "أُتس");
assert.equal(sandbox.convert("sh", "H0001"), "ش");
assert.equal(sandbox.convert("av", "H0001"), "أَڤ");
assert.ok(!sandbox.convert("ya.shar", "H3477").includes("."), "syllable separators must not appear in Arabic output");

console.log("Rehla Hebrew Arabic lexicon checks passed: 9 Job 1:1 entries, 4 pronunciation corrections, 40 Hebrew entries, transliteration rules, metadata, and cache version.");
