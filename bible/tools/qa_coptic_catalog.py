#!/usr/bin/env python3
"""Validate the 73-book Coptic Orthodox navigation catalog draft."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "data" / "coptic-canon-catalog.draft.json"
INDEX = ROOT / "index.html"


def main():
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    books = catalog["books"]
    ids = [book["book_id"] for book in books]
    orders = [book["canonical_order"] for book in books]
    old = [book for book in books if book["testament"] == "OT"]
    new = [book for book in books if book["testament"] == "NT"]

    assert len(books) == 73, f"expected 73 books, got {len(books)}"
    assert len(set(ids)) == 73, "duplicate book_id"
    assert [book["canonical_order"] for book in old] == list(range(1, 47)), "OT canonical_order must be sequential 1..46"
    assert [book["canonical_order"] for book in new] == list(range(1, 28)), "NT canonical_order must be sequential 1..27"
    assert len(old) == 46, f"expected 46 OT books, got {len(old)}"
    assert len(new) == 27, f"expected 27 NT books, got {len(new)}"
    assert all(isinstance(book["chapter_count"], int) and book["chapter_count"] > 0 for book in books), "missing/invalid chapter_count"

    ot_chapters = sum(book["chapter_count"] for book in old)
    nt_chapters = sum(book["chapter_count"] for book in new)
    assert ot_chapters == 1075, f"OT chapter total mismatch: {ot_chapters}"
    assert nt_chapters == 260, f"NT chapter total mismatch: {nt_chapters}"

    audit = catalog["chapter_count_audit"]
    assert audit["new_testament"]["discrepancy"]["official_coptic_church_page_claims"] == 270
    assert audit["new_testament"]["discrepancy"]["per_book_count_sum"] == 260
    assert catalog["historical_or_appendix_texts"], "historical/appendix texts must remain explicitly separate"

    # The reader's canonical navigation must stay in lockstep with this reviewed draft.
    index_text = INDEX.read_text(encoding="utf-8")
    reader_start = index_text.index("const readerSections={")
    nt_start = index_text.index(" NT:[", reader_start)
    reader_end = index_text.index("\n};\nconst readerBookNames=", nt_start)
    ot_reader_ids = re.findall(r'\["([A-Z0-9]+)","', index_text[reader_start:nt_start])
    nt_reader_ids = re.findall(r'\["([A-Z0-9]+)","', index_text[nt_start:reader_end])
    assert ot_reader_ids == [book["book_id"].upper() for book in old], "reader OT order/IDs differ from Coptic canon draft"
    assert nt_reader_ids == [book["book_id"].upper() for book in new], "reader NT order/IDs differ from Coptic canon draft"
    lxx_start = index_text.index("const LXX_SOURCE_BOOK_IDS")
    lxx_end = index_text.index("]);", lxx_start)
    lxx_source_ids = set(re.findall(r'"([A-Z0-9]+)"', index_text[lxx_start:lxx_end]))
    assert {"LJE", "3MA"}.issubset(lxx_source_ids), "Septuagint source-only books must remain in the source catalog"
    available_start = index_text.index("function readerSectionsAvailable()")
    available_end = index_text.index("function readerFieldLabel(", available_start)
    available_logic = index_text[available_start:available_end]
    assert 'sections.push({id:"إضافات السبعينية"' in available_logic, "Septuagint-only texts must remain separately accessible"

    print(json.dumps({
        "status": "PASSED",
        "books": len(books),
        "old_testament_books": len(old),
        "new_testament_books": len(new),
        "old_testament_chapters": ot_chapters,
        "new_testament_chapters": nt_chapters,
        "official_new_testament_total_discrepancy_recorded": True,
        "historical_or_appendix_entries": len(catalog["historical_or_appendix_texts"]),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
