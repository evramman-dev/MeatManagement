# Hebrew Westminster Leningrad Codex

Translation ID: HE-WLC-2017

Text edition: Westminster Leningrad Codex, Biblical Hebrew (hboWLC)

Text source: https://ebible.org/Scriptures/hboWLC_usfm.zip

Text source information: https://ebible.org/find/details.php?id=hboWLC

Text license: Public Domain.

The Hebrew text displayed by the reader is imported from the eBible hboWLC USFM archive. The conversion removes USFM structural markers, footnotes, and cross-reference notes. It preserves Hebrew text, vowel points, cantillation, and source verse references. No wording changes are intended.

## Word-level study data

The local word-level lemma and morphology data is a separate source. It comes from the Open Scriptures Hebrew Bible (OSHB), based on the Westminster Leningrad Codex:

- Repository: https://github.com/openscriptures/morphhb
- Pinned source commit: db6c5c9b46b8f39346f10915ddb1a70dcd429901
- Text basis: WLC, Public Domain
- Lemma and morphology data: CC BY 4.0
- Attribution: Original work of the Open Scriptures Hebrew Bible available at https://github.com/openscriptures/morphhb

The application does not import the separate lemma or morphology layer from the eBible archive. It packages the OSHB lemma and morphology layer into local per-book compressed files under `./word-study/wlc/`. The OSHB Strong's references are retained as Hebrew Strong's identifiers where present. The source lemma code and morphology code are preserved.

Some Ketiv/Qere alternatives are represented in the OSHB source as note readings. The current local conversion excludes nested note/readings from the primary word sequence. This is not a complete Ketiv/Qere apparatus.

## Coverage and versification

The text archive contains 39 Masoretic books and 23,213 verse records. Its book-level audit records Esther as 10 chapters, Daniel as 12 chapters, and Psalms as 150 psalms. It does not contain the Greek additions to Esther or Daniel, Psalm 151, or the Deuterocanonical books.

The reader keeps these edition limits visible and does not fill them from the Septuagint or another edition. The word-study layer follows the 39-book OSHB/WLC corpus and is not a substitute for the Coptic Orthodox canon.
