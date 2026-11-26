#!/usr/bin/env python3
"""Prepare the accented Robinson-Pierpont 2018 Greek NT corpus from official ByzTxt Unicode CSV."""
from __future__ import annotations
import argparse, csv, gzip, hashlib, io, json, re, urllib.request
from collections import defaultdict
from pathlib import Path

TRANSLATION_ID = "GRC-KOINE-RP-2018"
EDITION = "Greek New Testament — Robinson-Pierpont 2018 (Greek Majority Text)"
SOURCE_REPOSITORY = "https://github.com/byztxt/byzantine-majority-text"
SOURCE_COMMIT = "3b2b0806cc8af4144313ea70ec9cf654141e5996"
CSV_BASE_URL = f"https://raw.githubusercontent.com/byztxt/byzantine-majority-text/{SOURCE_COMMIT}/csv-unicode/ccat/no-variants"
INFO_URL = f"{SOURCE_REPOSITORY}/tree/{SOURCE_COMMIT}/csv-unicode/ccat/no-variants"
LICENSE_URL = f"{SOURCE_REPOSITORY}/blob/{SOURCE_COMMIT}/LICENSE.txt"
LICENSE = "Public Domain / Unlicense (as declared by the source repository)"

# Source CSV filename -> existing app book_id. Special alternative files PA.csv
# (John 7:53–8:11) and ACT24.csv (Acts 24:6–8) are intentionally not imported
# into the main text; the repository publishes them separately as alternatives.
BOOK_FILES = [
    ("MAT", "MAT", "mat"), ("MRK", "MAR", "mrk"), ("LUK", "LUK", "luk"),
    ("JHN", "JOH", "jhn"), ("ACT", "ACT", "act"), ("ROM", "ROM", "rom"),
    ("1CO", "1CO", "1co"), ("2CO", "2CO", "2co"), ("GAL", "GAL", "gal"),
    ("EPH", "EPH", "eph"), ("PHP", "PHP", "php"), ("COL", "COL", "col"),
    ("1TH", "1TH", "1th"), ("2TH", "2TH", "2th"), ("1TI", "1TI", "1ti"),
    ("2TI", "2TI", "2ti"), ("TIT", "TIT", "tit"), ("PHM", "PHM", "phm"),
    ("HEB", "HEB", "heb"), ("JAS", "JAM", "jas"), ("1PE", "1PE", "1pe"),
    ("2PE", "2PE", "2pe"), ("1JN", "1JO", "1jn"), ("2JN", "2JO", "2jn"),
    ("3JN", "3JO", "3jn"), ("JUD", "JUD", "jud"), ("REV", "REV", "rev"),
]
SOURCE_BOOK_IDS = [item[0] for item in BOOK_FILES]
BOOK_ORDER = {item[2]: i for i, item in enumerate(BOOK_FILES)}

def fetch_csv(filename: str) -> bytes:
    url = f"{CSV_BASE_URL}/{filename}.csv"
    request = urllib.request.Request(url, headers={"User-Agent": "RehlaBibleCorpusPrep/2.0"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()

def parse_csv_text(source_book: str, book_id: str, raw: str):
    reader = csv.DictReader(io.StringIO(raw))
    if reader.fieldnames != ["chapter", "verse", "text"]:
        raise ValueError(f"Unexpected CSV columns for {source_book}: {reader.fieldnames}")
    rows = []
    chapters = set()
    for line_number, item in enumerate(reader, start=2):
        chapter = int(item["chapter"])
        verse = str(item["verse"]).strip()
        text = item["text"]
        if not verse or not text or not text.strip():
            raise ValueError(f"Empty verse data in {source_book}.csv line {line_number}")
        rows.append({
            "translation_id": TRANSLATION_ID,
            "edition": EDITION,
            "book_id": book_id,
            "chapter": chapter,
            "verse": verse,
            # Preserve the Unicode text exactly, including polytonic accents,
            # breathings, punctuation, capitalization and paragraph marker ¶.
            "text": text,
        })
        chapters.add(chapter)
    if not rows:
        raise ValueError(f"No verse rows found for {source_book}")
    return rows, chapters

def verse_sort_key(value):
    match = re.match(r"(\d+)(.*)", str(value))
    return (int(match.group(1)) if match else 0, match.group(2) if match else str(value))

def prepare_rows(download=fetch_csv):
    all_rows = []
    coverage = {}
    source_hashes = {}
    seen_keys = set()
    for source_book, filename, book_id in BOOK_FILES:
        raw_bytes = download(filename)
        source_hashes[f"{filename}.csv"] = hashlib.sha256(raw_bytes).hexdigest()
        raw = raw_bytes.decode("utf-8-sig")
        rows, chapters = parse_csv_text(source_book, book_id, raw)
        for row in rows:
            key = (row["book_id"], row["chapter"], row["verse"])
            if key in seen_keys:
                raise ValueError(f"Duplicate verse key: {key}")
            seen_keys.add(key)
            all_rows.append(row)
        coverage[book_id] = {
            "source_book_id": source_book,
            "chapter_count": len(chapters),
            "verse_record_count": len(rows),
            "chapters": sorted(chapters),
        }
    if len(coverage) != 27:
        raise ValueError(f"Expected 27 NT books, received {len(coverage)}")
    all_rows.sort(key=lambda row: (
        BOOK_ORDER[row["book_id"]], row["chapter"], verse_sort_key(row["verse"])
    ))
    return all_rows, coverage, source_hashes

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=Path("bible/data"))
    args = parser.parse_args()
    rows, coverage, source_hashes = prepare_rows()
    chapter_total = sum(item["chapter_count"] for item in coverage.values())
    if chapter_total != 260:
        raise RuntimeError(f"Expected 260 chapters, received {chapter_total}")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir / "grc-koine-rp-2018.jsonl.gz"
    with output.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=9, mtime=0) as gz:
            for row in rows:
                gz.write((json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8"))
    paragraph_verses = sum("¶" in row["text"] for row in rows)
    audit = {
        "translation_id": TRANSLATION_ID,
        "edition": EDITION,
        "language": "grc",
        "dialect": "Koine",
        "textual_tradition": "Byzantine / Majority Text",
        "editor_or_translators": "Maurice A. Robinson and William G. Pierpont",
        "edition_year": 2018,
        "source_repository": SOURCE_REPOSITORY,
        "source_commit": SOURCE_COMMIT,
        "source_url": INFO_URL,
        "source_license": LICENSE,
        "source_license_url": LICENSE_URL,
        "source_files_sha256": source_hashes,
        "record_count": len(rows),
        "book_count": len(coverage),
        "source_book_ids": SOURCE_BOOK_IDS,
        "book_coverage": coverage,
        "expected_new_testament_chapter_total": 260,
        "actual_chapter_total": chapter_total,
        "books_missing_from_source": [],
        "separate_alternatives_not_in_main_text": {
            "PA.csv": "John 7:53–8:11",
            "ACT24.csv": "Acts 24:6–8",
        },
        "paragraph_marker": "¶ is preserved in the corpus and rendered as a line break, not as a printed glyph.",
        "paragraph_marker_verse_count": paragraph_verses,
        "output_file": output.name,
        "status": "PREPARED_PENDING_QA",
        "text_processing": "Official ByzTxt Unicode CSV main text, no-variants set. Polytonic accents, breathings, punctuation, capitalization, verse labels and paragraph markers are preserved. Separate PA and Acts 24 alternatives are not merged into the main text.",
    }
    (args.output_dir / "grc-koine-rp-2018_audit.json").write_text(
        json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({
        "records": len(rows), "books": len(coverage), "chapters": chapter_total,
        "paragraph_marker_verses": paragraph_verses, "source_commit": SOURCE_COMMIT,
    }, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
