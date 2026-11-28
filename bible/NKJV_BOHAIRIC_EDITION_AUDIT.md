# NKJV and Bohairic New Testament edition audit

## Requested editions

The project now tracks two requested English and Coptic editions as separate edition records.

## English NKJV

Edition ID: `en_nkjv`

Thomas Nelson states that the New King James Version is copyrighted and owned by Thomas Nelson, Inc. The publisher also states that limited free use is allowed under conditions, including a limit of up to 500 verses or 25 percent of a work for specified non-commercial uses.

A complete NKJV Bible corpus is therefore not imported into the repository at this stage.

Official source for licensing review:

https://www.thomasnelsonbibles.com/nkjv-bible/

Acceptance gate:

- obtain redistribution permission or a license covering the Rehla PWA
- record the exact permission scope
- import only the licensed edition

Until that gate passes, NKJV remains `blocked_pending_redistribution_license`.

## Bohairic New Testament

Primary candidate: George Horner's Bohairic New Testament witness.

Digital Bible Society identifies its Coptic New Testament as corresponding to Horner's critical edition of the Bohairic Northern dialect, begun in 1898, and marks it Public Domain.

Source:

https://bibles.dbs.org/COPSNT/pdf/COPSNT.pdf

A separate eBible record for Bohairica 1.2 also labels its standardized Wells edition Public Domain, but other secondary catalogs describe the 2006 Wells standardized edition with a copyright notice. The project will not silently treat the Wells edition as equivalent to Horner's public-domain witness.

The planned app corpus will use the Horner witness as the primary Bohairic candidate.

Required QA before app import:

- verify all 27 New Testament books
- verify chapter coverage
- verify verse keys
- detect duplicate verses
- preserve Coptic Unicode text exactly
- record source checksum
- compare samples against the printed Horner edition
- keep source edition identity separate from other Bohairic witnesses

## Canon rule

The Bohairic edition is New Testament only. It does not change the project's Coptic Orthodox full-canon navigation.

The NKJV is an English edition and must remain independent from the Arabic, Greek, Hebrew, and Coptic text fields.

## Current status

`en_nkjv`: blocked pending redistribution license

`nt_cop_bohairic_horner_pd`: research import candidate

No NKJV text has been copied into the repository.
