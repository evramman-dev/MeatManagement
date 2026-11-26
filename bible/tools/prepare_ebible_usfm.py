#!/usr/bin/env python3
"""Download and prepare eBible Arabic USFM editions as verse-level JSONL.

This tool does not merge translations and does not claim that a 66-book source
is the complete Coptic Orthodox canon. It keeps each edition in its own output.
Only Python's standard library is required.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import urllib.request
import zipfile
from collections import defaultdict
from pathlib import Path

SOURCES = {
    "AR-SVD-1865": {
        "edition": "Van Dyck 1865",
        "url": "https://ebible.org/Scriptures/arb-vd_usfm.zip",
        "license": "Public Domain",
    },
    "AR-KEH-2012": {
        "edition": "Biblica Open New Arabic Version 2012",
        "url": "https://ebible.org/Scriptures/arbnav_usfm.zip",
        "license": "CC BY-SA 4.0",
    },
}

# Standard USFM book identifiers for the 66-book source editions.
PROTESTANT_BOOKS = {
    "GEN","EXO","LEV","NUM","DEU","JOS","JDG","RUT","1SA","2SA","1KI","2KI",
    "1CH","2CH","EZR","NEH","EST","JOB","PSA","PRO","ECC","SNG","ISA","JER",
    "LAM","EZK","DAN","HOS","JOL","AMO","OBA","JON","MIC","NAM","HAB","ZEP",
    "HAG","ZEC","MAL","MAT","MRK","LUK","JHN","ACT","ROM","1CO","2CO","GAL",
    "EPH","PHP","COL","1TH","2TH","1TI","2TI","TIT","PHM","HEB","JAS","1PE",
    "2PE","1JN","2JN","3JN","JUD","REV",
}
BOUNDARY = re.compile(r"\\(id|c|v)\s+([^\s]+)")
FOOTNOTE = re.compile(r"\\(?:f|x)\s.*?\\(?:f|x)\*", re.S)
MARKER = re.compile(r"\\\+?[A-Za-z][A-Za-z0-9]*\*?")
WORD_SPAN = re.compile(r"\\\+?w\s+([^|\\]+)(?:\|[^\\]*)?\\\+?w\*")
SPACE = re.compile(r"\s+")


def clean_verse(value: str) -> str:
    value = WORD_SPAN.sub(lambda match: match.group(1), value)
    value = FOOTNOTE.sub(" ", value)
    value = re.sub(r"\|[^\s]+", "", value)
    value = MARKER.sub(" ", value)
    value = value.replace("~", " ").replace("//", " ")
    return SPACE.sub(" ", value).strip()


def parse_usfm(raw: str, translation_id: str, edition: str):
    matches = list(BOUNDARY.finditer(raw))
    book = None
    chapter = None
    rows = []
    for index, match in enumerate(matches):
        marker, value = match.group(1), match.group(2)
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(raw)
        body = raw[start:end]
        if marker == "id":
            book = value.upper()
        elif marker == "c":
            try:
                chapter = int(value)
            except ValueError:
                chapter = None
        elif marker == "v" and book and chapter is not None:
            verse = value
            text = clean_verse(body)
            if text:
                rows.append({
                    "translation_id": translation_id,
                    "edition": edition,
                    "book_id": book,
                    "chapter": chapter,
                    "verse": verse,
                    "text": text,
                })
    return book, rows


def download(url: str, destination: Path) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "JourneyBibleCorpusPrep/1.0"})
    digest = hashlib.sha256()
    with urllib.request.urlopen(request, timeout=60) as response, destination.open("wb") as out:
        while True:
            block = response.read(1024 * 1024)
            if not block:
                break
            digest.update(block)
            out.write(block)
    return digest.hexdigest()


def prepare(translation_id: str, output_dir: Path):
    source = SOURCES[translation_id]
    work_dir = output_dir / "source_zips"
    work_dir.mkdir(parents=True, exist_ok=True)
    archive_path = work_dir / (translation_id.lower() + "_usfm.zip")
    sha256 = download(source["url"], archive_path)

    rows = []
    book_counts = defaultdict(lambda: {"chapters": set(), "verses": 0})
    with zipfile.ZipFile(archive_path) as archive:
        names = [name for name in archive.namelist() if name.lower().endswith((".sfm", ".usfm"))]
        if not names:
            raise RuntimeError(f"No USFM files found in {archive_path}")
        for name in names:
            raw = archive.read(name).decode("utf-8-sig", errors="replace")
            book, book_rows = parse_usfm(raw, translation_id, source["edition"])
            if not book or book not in PROTESTANT_BOOKS:
                continue
            rows.extend(book_rows)
            for row in book_rows:
                book_counts[book]["chapters"].add(row["chapter"])
                book_counts[book]["verses"] += 1

    if not rows:
        raise RuntimeError(f"No verse records parsed for {translation_id}")

    output_dir.mkdir(parents=True, exist_ok=True)
    jsonl_path = output_dir / f"{translation_id.lower()}.jsonl"
    with jsonl_path.open("w", encoding="utf-8", newline="\n") as out:
        for row in rows:
            out.write(json.dumps(row, ensure_ascii=False) + "\n")

    present_books = sorted(book_counts)
    report = {
        "translation_id": translation_id,
        "edition": source["edition"],
        "source_url": source["url"],
        "license": source["license"],
        "source_zip_sha256": sha256,
        "record_count": len(rows),
        "book_count": len(present_books),
        "books_missing_from_66_book_source": sorted(PROTESTANT_BOOKS - set(present_books)),
        "books_outside_66_book_source_not_imported": True,
        "book_coverage": {
            book: {
                "chapter_count": len(values["chapters"]),
                "verse_record_count": values["verses"],
            }
            for book, values in sorted(book_counts.items())
        },
        "output_file": jsonl_path.name,
        "status": "PREPARED_NOT_YET_QA_APPROVED",
    }
    report_path = output_dir / f"{translation_id.lower()}_audit.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "translation_id": translation_id,
        "records": len(rows),
        "books": len(present_books),
        "missing_books": report["books_missing_from_66_book_source"],
        "jsonl": str(jsonl_path),
        "audit": str(report_path),
        "zip_sha256": sha256,
    }, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--translation", choices=["AR-SVD-1865", "AR-KEH-2012", "all"], default="all")
    parser.add_argument("--output-dir", type=Path, default=Path("bible-import-output"))
    args = parser.parse_args()
    selected = list(SOURCES) if args.translation == "all" else [args.translation]
    for translation_id in selected:
        prepare(translation_id, args.output_dir)


if __name__ == "__main__":
    main()
