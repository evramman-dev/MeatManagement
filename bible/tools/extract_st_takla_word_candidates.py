#!/usr/bin/env python3
"""Parse St-Takla legacy Word deuterocanonical files into research-only JSONL."""
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from pathlib import Path

TRANSLATION_ID = "ARB-JES-1877"
REVIEW_STATUS = "UNVERIFIED_RESEARCH_CANDIDATE"

BOOKS = {
    "tobit": {"book_id": "TOB", "chapters": list(range(1, 15)), "url": "https://st-takla.org/Bibles/Arabic-Bible-with-Diacritics/17-Tobit__Deu.doc"},
    "judith": {"book_id": "JDT", "chapters": list(range(1, 17)), "url": "https://st-takla.org/Bibles/Arabic-Bible-with-Diacritics/18-Judith__Deu.doc"},
    "esther-additions": {"book_id": "EST-ADD", "chapters": list(range(10, 17)), "url": "https://st-takla.org/Bibles/Arabic-Bible-with-Diacritics/19-2-Esther-the-rest__Deu.doc"},
    "psalm-151": {"book_id": "PS151", "chapters": [1], "url": "https://st-takla.org/Bibles/Arabic-Bible-with-Diacritics/21-2-Psalm-151__Deu.doc"},
    "wisdom": {"book_id": "WIS", "chapters": list(range(1, 20)), "url": "https://st-takla.org/Bibles/Arabic-Bible-with-Diacritics/25-Wisdom__Deu.doc"},
    "sirach": {"book_id": "SIR", "chapters": list(range(1, 52)), "url": "https://st-takla.org/Bibles/Arabic-Bible-with-Diacritics/26-Sirach__Deu.doc"},
    "baruch": {"book_id": "BAR", "chapters": list(range(1, 7)), "url": "https://st-takla.org/Bibles/Arabic-Bible-with-Diacritics/30-Baruch__Deu.doc"},
    "daniel-additions": {"book_id": "DAN-ADD", "chapters": [3, 13, 14], "url": "https://st-takla.org/Bibles/Arabic-Bible-with-Diacritics/32-2-Daniel-the-rest__Deu.doc"},
    "1-maccabees": {"book_id": "1MA", "chapters": list(range(1, 17)), "url": "https://st-takla.org/Bibles/Arabic-Bible-with-Diacritics/45-First-Maccabees__Deu.doc"},
    "2-maccabees": {"book_id": "2MA", "chapters": list(range(1, 16)), "url": "https://st-takla.org/Bibles/Arabic-Bible-with-Diacritics/46-Second-Maccabees__Deu.doc"},
}

ORDINALS = {
    "الاول": 1, "الثاني": 2, "الثالث": 3, "الرابع": 4, "الخامس": 5,
    "السادس": 6, "السابع": 7, "الثامن": 8, "التاسع": 9, "العاشر": 10,
    "الحادي عشر": 11, "الثاني عشر": 12, "الثالث عشر": 13, "الرابع عشر": 14,
    "الخامس عشر": 15, "السادس عشر": 16, "السابع عشر": 17, "الثامن عشر": 18,
    "التاسع عشر": 19, "العشرون": 20, "الحادي والعشرون": 21,
    "الثاني والعشرون": 22, "الثالث والعشرون": 23, "الرابع والعشرون": 24,
    "الخامس والعشرون": 25, "السادس والعشرون": 26, "السابع والعشرون": 27,
    "الثامن والعشرون": 28, "التاسع والعشرون": 29, "الثلاثون": 30,
    "الحادي والثلاثون": 31, "الثاني والثلاثون": 32, "الثالث والثلاثون": 33,
    "الرابع والثلاثون": 34, "الخامس والثلاثون": 35, "السادس والثلاثون": 36,
    "السابع والثلاثون": 37, "الثامن والثلاثون": 38, "التاسع والثلاثون": 39,
    "الاربعون": 40, "الحادي والاربعون": 41, "الثاني والاربعون": 42,
    "الثالث والاربعون": 43, "الرابع والاربعون": 44, "الخامس والاربعون": 45,
    "السادس والاربعون": 46, "السابع والاربعون": 47, "الثامن والاربعون": 48,
    "التاسع والاربعون": 49, "الخمسون": 50, "الحادي والخمسون": 51,
}

VERSE_LINE = re.compile(r"^\s*(\d{1,3})(?:\s*[،,]\s*(\d{1,3}))?\s+(.+?)\s*$")
ARABIC_RE = re.compile(r"[\u0600-\u06ff]")


def normalize_arabic(value: str) -> str:
    value = unicodedata.normalize("NFKC", value)
    value = re.sub(r"[\u064b-\u065f\u0670\u0640]", "", value)
    value = value.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ٱ", "ا")
    return re.sub(r"\s+", " ", value).strip()


def parse_book(text: str, filename: str, spec: dict) -> tuple[list[dict], list[dict]]:
    chapter = None
    current_start = current_end = None
    current_parts: list[str] = []
    rows: list[dict] = []
    notes: list[dict] = []

    def flush() -> None:
        nonlocal current_start, current_end, current_parts
        if current_start is None:
            return
        verse_text = re.sub(r"\s+", " ", " ".join(current_parts)).strip()
        if not verse_text or not ARABIC_RE.search(verse_text):
            raise ValueError(f"{filename} {chapter}:{current_start}-{current_end}: empty/non-Arabic text")
        row = {
            "translation_id": TRANSLATION_ID,
            "book_id": spec["book_id"],
            "chapter": chapter,
            "verse_start": current_start,
            "verse_end": current_end,
            "text": verse_text,
            "source_url": spec["url"],
            "source_label": "St-Takla downloadable Word file; first-verse readings cross-checked against 1877-marked HTML pages",
            "review_status": REVIEW_STATUS,
        }
        if current_start == current_end:
            row["verse"] = current_start
        rows.append(row)
        current_start = current_end = None
        current_parts = []

    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        normalized = normalize_arabic(stripped)
        if "الاصحاح" in normalized:
            flush()
            suffix = normalized.split("الاصحاح", 1)[1].strip(" :：-")
            if suffix not in ORDINALS:
                raise ValueError(f"{filename}: unknown chapter heading {stripped!r} ({suffix!r})")
            chapter = ORDINALS[suffix]
            continue

        if filename == "psalm-151" and chapter is None:
            chapter = 1

        match = VERSE_LINE.match(stripped)
        if match and chapter is not None:
            flush()
            start = int(match.group(1))
            end = int(match.group(2)) if match.group(2) else start
            if end < start or end - start > 1:
                raise ValueError(f"{filename} {chapter}: unsupported grouped verse marker {stripped!r}")
            if start == 0:
                notes.append({"chapter": chapter, "type": "un-numbered_superscription", "text": match.group(3)})
                continue
            current_start, current_end = start, end
            current_parts = [match.group(3)]
        elif current_start is not None:
            current_parts.append(stripped)

    flush()
    return rows, notes


def validate(rows: list[dict], spec: dict, filename: str) -> dict:
    by_chapter: dict[int, list[tuple[int, int]]] = {}
    seen = set()
    for row in rows:
        chapter = row["chapter"]
        start, end = row["verse_start"], row["verse_end"]
        key = (chapter, start, end)
        if key in seen:
            raise ValueError(f"{filename}: duplicate range {key}")
        seen.add(key)
        by_chapter.setdefault(chapter, []).append((start, end))

    if sorted(by_chapter) != spec["chapters"]:
        raise ValueError(f"{filename}: chapter set {sorted(by_chapter)} != {spec['chapters']}")

    counts = {}
    for chapter, ranges in by_chapter.items():
        ranges.sort()
        expected = 4 if filename == "esther-additions" and chapter == 10 else 1
        for start, end in ranges:
            if start != expected:
                raise ValueError(f"{filename} {chapter}: gap/overlap before {start}; expected {expected}")
            expected = end + 1
        counts[str(chapter)] = expected - (4 if filename == "esther-additions" and chapter == 10 else 1)
    return counts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--text-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    grand_total = 0
    summary = {}
    for filename, spec in BOOKS.items():
        source = args.text_dir / f"{filename}.txt"
        if not source.exists():
            raise FileNotFoundError(source)
        text = source.read_text(encoding="utf-8", errors="replace")
        rows, notes = parse_book(text, filename, spec)
        counts = validate(rows, spec, filename)
        output = args.output_dir / f"{spec['book_id'].lower()}-word-research-candidate.jsonl"
        output.write_text(
            "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows),
            encoding="utf-8",
        )
        summary[spec["book_id"]] = {
            "chapters": len(counts),
            "verse_groups": len(rows),
            "chapter_verse_counts": counts,
            "non_verse_notes": notes,
            "file": output.name,
        }
        grand_total += len(rows)
        print(f"PASS {spec['book_id']}: {len(counts)} chapters, {len(rows)} verse groups")
    (args.output_dir / "word-extraction-summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"PASS: {len(BOOKS)} files; {grand_total} verse groups; research-only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
