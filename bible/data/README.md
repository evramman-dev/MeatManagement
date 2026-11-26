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
