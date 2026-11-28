#!/usr/bin/env python3
import argparse
import gzip
import hashlib
import json
import re
from pathlib import Path

BOOKS = {
    "MAT":"mat","MRK":"mar","MAR":"mar","LUK":"luk","JHN":"joh","JOH":"joh","ACT":"act","ROM":"rom",
    "1CO":"1co","2CO":"2co","GAL":"gal","EPH":"eph","PHP":"php","COL":"col",
    "1TH":"1th","2TH":"2th","1TI":"1ti","2TI":"2ti","TIT":"tit","PHM":"phm",
    "HEB":"heb","JAS":"jas","1PE":"1pe","2PE":"2pe","1JN":"1jo","1JO":"1jo",
    "2JN":"2jo","2JO":"2jo","3JN":"3jo","3JO":"3jo","JUD":"jud","REV":"rev",
}

def clean(text):
    text = re.sub(r"\\[+]?[-a-zA-Z]+\*?", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()

def parse_file(path):
    code = None
    chapter = None
    records = []
    try:
        raw_text = path.read_text(encoding="utf-8-sig", errors="replace")
    except Exception:
        return records
    for raw in raw_text.splitlines():
        m = re.match(r"\s*\\id\s+(\S+)", raw)
        if m:
            code = m.group(1).upper()
            continue
        m = re.match(r"\s*\\c\s+(\d+)", raw)
        if m:
            chapter = int(m.group(1))
            continue
        m = re.match(r"\s*\\v\s+(\d+(?:-\d+)?)\s+(.+)$", raw)
        if not m or code not in BOOKS or chapter is None:
            continue
        verse_raw, text = m.groups()
        if "-" in verse_raw:
            start, end = map(int, verse_raw.split("-", 1))
        else:
            start = end = int(verse_raw)
        text = clean(text)
        if text:
            records.append({
                "edition_id":"nt_cop_bohairic_horner_pd",
                "translation_id":"COP-BOHAIRIC-HORNER",
                "source_book_id":code,
                "canonical_book_id":BOOKS[code],
                "chapter":chapter,
                "verse_start":start,
                "verse_end":end,
                "text":text,
                "review_status":"UNVERIFIED_RESEARCH_CANDIDATE",
                "rights_status":"PUBLIC_DOMAIN_SOURCE_CLAIM",
            })
    return records

def write_app_corpus(records, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(path, "wt", encoding="utf-8", newline="\n", compresslevel=9) as f:
        for r in records:
            if r["verse_start"] != r["verse_end"]:
                raise SystemExit(
                    f"Unsupported verse range for app corpus: {r['canonical_book_id']} "
                    f"{r['chapter']}:{r['verse_start']}-{r['verse_end']}"
                )
            row = {
                "book_id": r["canonical_book_id"],
                "chapter": r["chapter"],
                "verse": r["verse_start"],
                "text": r["text"],
            }
            f.write(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--audit", required=True)
    ap.add_argument("--archive", required=True)
    ap.add_argument("--app-out")
    args = ap.parse_args()

    src = Path(args.src)
    files = sorted(p for p in src.rglob("*") if p.is_file() and p.suffix.lower() in {".usfm", ".sfm", ".txt"})
    records = []
    files_with_records = []
    for path in files:
        parsed = parse_file(path)
        if parsed:
            files_with_records.append(path.name)
            records.extend(parsed)

    keys = [(r["canonical_book_id"], r["chapter"], r["verse_start"], r["verse_end"]) for r in records]
    dup = len(keys) - len(set(keys))
    books = sorted({r["canonical_book_id"] for r in records})
    chapters = sorted({(r["canonical_book_id"], r["chapter"]) for r in records})
    missing_books = sorted(set(BOOKS.values()) - set(books))

    archive_sha = hashlib.sha256(Path(args.archive).read_bytes()).hexdigest()

    audit = {
        "translation_id":"COP-BOHAIRIC-HORNER",
        "edition_id":"nt_cop_bohairic_horner_pd",
        "source":"Digital Bible Society COPSNT / George Horner Bohairic New Testament",
        "source_url":"https://bibles.dbs.org/COPSNT/pdf/COPSNT.pdf",
        "usfm_source_url":"https://ebible.org/Scriptures/copbhc_usfm.zip",
        "source_archive_sha256":archive_sha,
        "files_seen":len(files),
        "files_with_records":files_with_records,
        "record_count":len(records),
        "book_count":len(books),
        "chapter_count":len(chapters),
        "duplicate_keys":dup,
        "missing_books":missing_books,
        "review_status":"UNVERIFIED_RESEARCH_CANDIDATE",
        "rights_status":"PUBLIC_DOMAIN_SOURCE_CLAIM",
    }

    with Path(args.out).open("w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False, separators=(",", ":")) + "\n")
    Path(args.audit).write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if len(books) != 27 or missing_books or dup:
        raise SystemExit("Bohairic NT coverage QA failed")
    if args.app_out:
        write_app_corpus(records, args.app_out)

if __name__ == "__main__":
    main()
