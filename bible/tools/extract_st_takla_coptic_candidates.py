#!/usr/bin/env python3
"""Extract selected St-Takla Jesuit Arabic books into research-only JSONL files.

This is a source-research tool. It never writes to the application corpus.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path
from urllib.parse import parse_qs, urljoin, urlparse
from urllib.request import Request, urlopen

from bs4 import BeautifulSoup

BASE = "https://st-takla.org/Bibles/BibleSearch/showChapter.php"
TRANSLATION_ID = "ARB-JES-1877"
ARABIC_RE = re.compile(r"[\u0600-\u06FF]")

# Explicit URL book IDs and chapter ranges, verified separately in the book map.
BOOKS = {
    "JDT": {"name": "Judith", "book": 18, "chapters": list(range(1, 17))},
    "WIS": {"name": "Wisdom", "book": 27, "chapters": list(range(1, 20))},
    "SIR": {"name": "Sirach", "book": 28, "chapters": list(range(1, 52))},
    "BAR": {"name": "Baruch", "book": 32, "chapters": list(range(1, 7))},
    "1MA": {"name": "1 Maccabees", "book": 48, "chapters": list(range(1, 17))},
    "2MA": {"name": "2 Maccabees", "book": 49, "chapters": list(range(1, 16))},
    "PS151": {"name": "Psalm 151", "book": 23, "chapters": [1]},
    "DAN-ADD": {"name": "Daniel additions", "book": 35, "chapters": [13, 14]},
}


def fetch(url: str) -> str:
    request = Request(url, headers={"User-Agent": "RehlaBibleSourceAudit/1.0"})
    with urlopen(request, timeout=45) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return response.read().decode(charset, errors="replace")


def verse_number_from_link(anchor) -> int | None:
    query = parse_qs(urlparse(urljoin(BASE, anchor.get("href", ""))).query)
    low = query.get("vmin", [None])[0]
    high = query.get("vmax", [None])[0]
    if low is None or high is None or low != high:
        return None
    try:
        return int(low)
    except (TypeError, ValueError):
        return None


def extract_chapter(book_id: str, spec: dict, chapter: int) -> list[dict]:
    url = f"{BASE}?book={spec['book']}&chapter={chapter}"
    soup = BeautifulSoup(fetch(url), "html.parser")
    anchors = [
        anchor for anchor in soup.select('a[href*="showVerses.php"]')
        if verse_number_from_link(anchor) is not None
    ]
    found: dict[int, str] = {}

    for anchor in anchors:
        number = verse_number_from_link(anchor)
        parent = anchor
        selected_text = None
        for _ in range(6):
            parent = parent.parent
            if parent is None:
                break
            verse_links = [
                item for item in parent.select('a[href*="showVerses.php"]')
                if verse_number_from_link(item) is not None
            ]
            candidate = parent.get_text(" ", strip=True)
            if len(verse_links) == 1 and ARABIC_RE.search(candidate):
                selected_text = candidate
                break

        if not selected_text:
            continue
        text = re.sub(r"\s+", " ", selected_text).strip()
        text = re.sub(rf"^0*{number}[.\s،:：-]+", "", text).strip()
        if not ARABIC_RE.search(text) or len(text) < 8:
            continue
        if number in found and found[number] != text:
            raise RuntimeError(f"{book_id} {chapter}:{number}: conflicting verse text")
        found[number] = text

    if not found:
        raise RuntimeError(f"{book_id} chapter {chapter}: no verses extracted from {url}")
    numbers = sorted(found)
    expected = list(range(1, numbers[-1] + 1))
    if numbers != expected:
        raise RuntimeError(f"{book_id} chapter {chapter}: missing verse numbers; found {numbers}")

    return [
        {
            "translation_id": TRANSLATION_ID,
            "book_id": book_id,
            "chapter": chapter,
            "verse": number,
            "text": found[number],
            "source_url": url,
            "source_label": "St-Takla; Jesuit Old Arabic translation, 1877 marker on page",
            "review_status": "UNVERIFIED_RESEARCH_CANDIDATE",
        }
        for number in numbers
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--books", default="JDT,WIS,BAR,1MA,2MA,PS151,DAN-ADD")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--delay", type=float, default=0.35)
    args = parser.parse_args()

    selected = [item.strip() for item in args.books.split(",") if item.strip()]
    unknown = sorted(set(selected) - set(BOOKS))
    if unknown or not selected:
        parser.error(f"Unknown or empty book selection: {unknown or selected}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    total = 0
    for book_index, book_id in enumerate(selected):
        spec = BOOKS[book_id]
        rows = []
        for chapter_index, chapter in enumerate(spec["chapters"]):
            chapter_rows = extract_chapter(book_id, spec, chapter)
            rows.extend(chapter_rows)
            print(f"{book_id} chapter {chapter}: {len(chapter_rows)} verses", file=sys.stderr)
            if chapter_index + 1 < len(spec["chapters"]):
                time.sleep(max(0.0, args.delay))
        path = args.output_dir / f"{book_id.lower()}-research-candidate.jsonl"
        path.write_text(
            "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows),
            encoding="utf-8",
        )
        print(f"{book_id}: wrote {len(rows)} research-only verses to {path}", file=sys.stderr)
        total += len(rows)
        if book_index + 1 < len(selected):
            time.sleep(max(0.0, args.delay))
    print(f"PASS: {len(selected)} books; {total} research-only verses", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
