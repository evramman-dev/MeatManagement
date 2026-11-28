#!/usr/bin/env python3
from __future__ import annotations
import gzip
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
CORPUS = DATA / "grc-lxx-swete-1907-ecclesiastes.jsonl.gz"
AUDIT = DATA / "grc-lxx-swete-1907-ecclesiastes_audit.json"
EXPECTED_COUNTS = {1:18, 2:26, 3:22, 4:17, 5:20, 6:12, 7:30, 8:17, 9:18, 10:20, 11:10, 12:14}

def main():
    audit = json.loads(AUDIT.read_text(encoding="utf-8"))
    assert audit["translation_id"] == "GRC-LXX-SWETE-1907"
    assert audit["book_id"] == "ecc"
    assert audit["source_page_range"] == "480-505"
    rows = []
    with gzip.open(CORPUS, "rt", encoding="utf-8") as stream:
        for line in stream:
            row = json.loads(line)
            assert row["translation_id"] == "GRC-LXX-SWETE-1907"
            assert row["edition"] == "Swete Septuagint Volume II third edition 1907"
            assert row["book_id"] == "ecc"
            assert str(row["chapter"]).isdigit()
            assert row["text"].strip()
            rows.append(row)
    keys = [(int(r["chapter"]), str(r["verse"])) for r in rows]
    assert len(rows) == 224
    assert len(keys) == len(set(keys))
    counts = {}
    for chapter, _ in keys:
        counts[chapter] = counts.get(chapter, 0) + 1
    assert counts == EXPECTED_COUNTS
    assert "Ἴδε" in next(r for r in rows if r["chapter"] == 1 and r["verse"] == "10")["text"]
    assert "ἐπικοσμηθῆναι" in next(r for r in rows if r["chapter"] == 1 and r["verse"] == "15")["text"]
    assert "κόσμον" in next(r for r in rows if r["chapter"] == 12 and r["verse"] == "9")["text"]
    for verse in ("27","28","29","30"):
        assert next(r for r in rows if r["chapter"] == 7 and r["verse"] == verse)
    print(json.dumps({"status":"PASSED","records":len(rows),"chapter_counts":counts}, ensure_ascii=False))

if __name__ == "__main__":
    main()
