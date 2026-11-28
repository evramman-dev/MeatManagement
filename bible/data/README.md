# Arabic Bible text assets

Each translation is stored as an independent gzip-compressed JSONL file. Records retain translation_id, edition, book_id, chapter, verse, and text.

## AR-SVD-1865 — Smith-Van Dyck 1865
Source: https://ebible.org/arb-vd/
License status: Public Domain.

## AR-KEH-2012 — Biblica Open New Arabic Version 2012
Source: https://ebible.org/arbnav/
Copyright: Biblica.
License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0): https://creativecommons.org/licenses/by-sa/4.0/

The source USFM was converted to JSONL and gzip. USFM formatting markers, footnotes, and cross-reference notes were omitted. No intentional wording edits were made. The converted data remains under the applicable source license.

Both source editions contain 66 books only. They do not include the Deuterocanonical books and must not be presented as the complete Coptic Orthodox canon. The application must display its unavailable-translation message for books absent from an edition.



## HE-WLC-2017 — Westminster Leningrad Codex (Biblical Hebrew)

Source: https://ebible.org/find/details.php?id=hboWLC
Download: https://ebible.org/Scriptures/hboWLC_usfm.zip
License: Public Domain for the WLC biblical text. The separate OSHB lemma/morphology layer is not imported.
Attribution/source repository: https://github.com/openscriptures/morphhb
Coverage: 39 Masoretic Old Testament books; no Deuterocanonical books.
QA: Full exact-key and verse-text comparison passed, 23,213 records, zero missing, extra, or mismatched records. See `he-wlc-2017_audit.json`.


## GRC-LXX-BRENTON-1851 — Brenton Greek Septuagint 1851

Source: https://ebible.org/find/details.php?id=grcbrent
USFM download: https://ebible.org/Scriptures/grcbrent_usfm.zip
License: Public Domain, as declared by eBible.
Corpus: `grc-lxx-brenton-1851.jsonl.gz`.
Audit: `grc-lxx-brenton-1851_audit.json`.
The edition's source book set is retained independently, including its Deuterocanonical and additional books. It is not asserted to be identical to the Coptic Orthodox 73-book navigation catalog. Greek text is displayed left-to-right. Source chapter and verse labels are retained; no silent renumbering or Arabic supplementation is performed.


### Import and QA result

28,597 verse records across all 52 source books/texts. Full exact-key and text comparison against the downloaded source archive passed: zero missing, extra, or mismatched records. Source archive SHA256: `9de434f4922f85a475276e4754f6d114dee0f3bf5323d90dcd559a1f8286e9a4`. See `grc-lxx-brenton-1851_audit.json` for book-by-book coverage.


The Brenton corpus import and full source comparison passed in workflow run 45810436651. The corpus is now committed to the public repository. Reader browser QA passed, including Greek LTR rendering and Deuterocanonical book checks. GitHub Pages build and deployment also passed.


## GRC-KOINE-RP-2018 — Robinson–Pierpont 2018 Greek New Testament

Official source repository: https://github.com/byztxt/byzantine-majority-text  
Pinned commit: `3b2b0806cc8af4144313ea70ec9cf654141e5996`  
Source files: `csv-unicode/ccat/no-variants` (27 canonical NT books).  
License: Public Domain / Unlicense, as declared by the source repository.  
Corpus: `grc-koine-rp-2018.jsonl.gz`.  
Audit: `grc-koine-rp-2018_audit.json`.

The imported Unicode main text preserves polytonic accents, breathings, punctuation, capitalization, source verse labels and paragraph markers. The reader renders the paragraph marker as a line break. The source's separate alternatives `PA.csv` (John 7:53–8:11) and `ACT24.csv` (Acts 24:6–8) remain separate and are not merged into the main text.

QA passed: 7,953 verse records, 27 books, 260 chapters, zero missing/extra/source-mismatched records. Verse keys match the previous corpus exactly, and normalized Greek word sequences match with zero differences after excluding legacy Strong's/morphology annotations from comparison only. See `GREEK_NT_TEXT_DISPLAY_AUDIT.md`.

## Local parallel-reader corpora

## EN-WEB — World English Bible

The New Testament used by the parallel reader is stored locally under en-web/ as one JSONL file per book. The source text is the World English Bible and is public domain.

## HE-DELITZSCH-1885 — Hebrew New Testament

The Hebrew New Testament used by the parallel reader is stored locally under he-delitzsch/ as one JSONL file per book. Source: HebrewNewTestament/HebDelitzsch, based on the Delitzsch translation from 1885.

## COP-BOHAIRIC-OT — Bohairic Old Testament

The local import is not enabled yet. The Coptic SCRIPTORIUM source contains 637 chapter files and requires a direct source-preserving import and validation. The reader does not fall back to a remote translation source.
