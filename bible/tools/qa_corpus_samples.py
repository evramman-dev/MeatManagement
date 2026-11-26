#!/usr/bin/env python3
"""Compare every committed verse with the exact eBible USFM source archive."""
from __future__ import annotations

import gzip
import hashlib
import json
import sys
import urllib.request
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_ebible_usfm import PROTESTANT_BOOKS, SOURCES, parse_usfm

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"


def load_source_rows(translation_id: str, expected_sha: str):
    source = SOURCES[translation_id]
    request = urllib.request.Request(
        source["url"], headers={"User-Agent": "RehlaBibleCorpusQA/1.0"}
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        archive_bytes = response.read()
    actual_sha = hashlib.sha256(archive_bytes).hexdigest()
    if actual_sha != expected_sha:
        raise AssertionError(
            f"{translation_id}: source archive SHA changed: "
            f"expected {expected_sha}, got {actual_sha}"
        )

    rows = {}
    with zipfile.ZipFile(__import__("io").BytesIO(archive_bytes)) as archive:
        names = [
            name for name in archive.namelist()
            if name.lower().endswith((".sfm", ".usfm"))
        ]
        if not names:
            raise AssertionError(f"{translation_id}: no USFM files in source archive")
        for name in names:
            raw = archive.read(name).decode("utf-8-sig", errors="replace")
            book, parsed = parse_usfm(raw, translation_id, source["edition"])
            if book in PROTESTANT_BOOKS:
                for row in parsed:
                    key = (row["book_id"], row["chapter"], row["verse"])
                    if key in rows:
                        raise AssertionError(f"{translation_id}: duplicate source key {key}")
                    rows[key] = row["text"]
    return rows, actual_sha


def load_committed_rows(translation_id: str):
    path = DATA / f"{translation_id.lower()}.jsonl.gz"
    rows = {}
    with gzip.open(path, "rt", encoding="utf-8") as stream:
        for line in stream:
            row = json.loads(line)
            key = (row["book_id"], row["chapter"], row["verse"])
            if key in rows:
                raise AssertionError(f"{translation_id}: duplicate committed key {key}")
            rows[key] = row["text"]
    return rows


def main():
    report = {
        "status": "PASSED",
        "comparison_mode": "FULL_CORPUS_EXACT_KEY_AND_TEXT",
        "translations": {},
    }
    for translation_id in SOURCES:
        audit_path = DATA / f"{translation_id.lower()}_audit.json"
        audit = json.loads(audit_path.read_text(encoding="utf-8"))
        source_rows, source_sha = load_source_rows(
            translation_id, audit["source_zip_sha256"]
        )
        committed_rows = load_committed_rows(translation_id)
        if len(committed_rows) != audit["record_count"]:
            raise AssertionError(
                f"{translation_id}: committed count {len(committed_rows)} "
                f"does not match audit {audit['record_count']}"
            )

        source_keys = set(source_rows)
        committed_keys = set(committed_rows)
        missing_keys = sorted(source_keys - committed_keys)
        extra_keys = sorted(committed_keys - source_keys)
        mismatched_keys = sorted(
            key for key in source_keys & committed_keys
            if source_rows[key] != committed_rows[key]
        )
        if missing_keys or extra_keys or mismatched_keys:
            raise AssertionError(
                f"{translation_id}: full corpus mismatch: "
                f"missing={len(missing_keys)}, extra={len(extra_keys)}, "
                f"text_mismatch={len(mismatched_keys)}; "
                f"first_missing={missing_keys[:10]}, "
                f"first_extra={extra_keys[:10]}, "
                f"first_text_mismatch={mismatched_keys[:10]}"
            )

        report["translations"][translation_id] = {
            "source_zip_sha256": source_sha,
            "source_record_count": len(source_rows),
            "committed_record_count": len(committed_rows),
            "matched_records": len(committed_rows),
            "missing_records": 0,
            "extra_records": 0,
            "text_mismatches": 0,
            "result": "PASSED",
        }

    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
