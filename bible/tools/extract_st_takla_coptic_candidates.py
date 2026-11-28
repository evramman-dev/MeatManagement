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
    "EST-ADD": {"name": "Esther additions", "book": 20, "chapters": list(range(10, 17))},
    "WIS": {"name": "Wisdom", "book": 27, "chapters": list(range(1, 20))},
    "SIR": {"name": "Sirach", "book": 28, "chapters": [*range(1, 29), *range(30, 52)]},
    "BAR": {"name": "Baruch", "book": 32, "chapters": list(range(1, 7))},
    "1MA": {"name": "1 Maccabees", "book": 48, "chapters": list(range(1, 17))},
    "2MA": {"name": "2 Maccabees", "book": 49, "chapters": list(range(1, 16))},
    "PS151": {"name": "Psalm 151", "book": 23, "chapters": [1]},
    "DAN-ADD": {"name": "Daniel additions", "book": 35, "chapters": [3, 13, 14]},
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



def extract_single_verse_page(book_id: str, spec: dict, chapter: int, verse: int) -> dict:
    """Read one isolated verse page; used where chapter markup crosses verse boundaries."""
    url = (
        "https://st-takla.org/Bibles/BibleSearch/showVerses.php"
        f"?book={spec['book']}&chapter={chapter}&vmin={verse}&vmax={verse}"
    )
    soup = BeautifulSoup(fetch(url), "html.parser")
    page_text = soup.get_text(" ", strip=True)
    if "الترجمة اليسوعية القديمة 1877 م" not in page_text:
        raise RuntimeError(f"{book_id} {chapter}:{verse}: 1877 translation marker missing")
    anchors = [
        anchor for anchor in soup.select('a[href*="showVerses.php"]')
        if verse_number_from_link(anchor) == verse
    ]
    candidates = []
    for anchor in anchors:
        parent = anchor
        for _ in range(7):
            parent = parent.parent
            if parent is None:
                break
            links = [
                item for item in parent.select('a[href*="showVerses.php"]')
                if verse_number_from_link(item) is not None
            ]
            if len(links) != 1:
                continue
            candidate = re.sub(r"\s+", " ", parent.get_text(" ", strip=True)).strip()
            label = anchor.get_text(" ", strip=True)
            if label:
                candidate = candidate.replace(label, " ", 1).strip()
            candidate = re.sub(r"^\s*[0-9٠-٩]+[.،,:：\s-]*", "", candidate).strip()
            if ARABIC_RE.search(candidate) and len(candidate) >= 8:
                candidates.append(candidate)
    if not candidates:
        raise RuntimeError(f"{book_id} {chapter}:{verse}: no isolated verse text in {url}")
    text = min(candidates, key=len)
    return {
        "translation_id": TRANSLATION_ID,
        "book_id": book_id,
        "chapter": chapter,
        "verse": verse,
        "text": text,
        "source_url": url,
        "source_label": "St-Takla; Jesuit Old Arabic translation, 1877 marker on page",
        "review_status": "UNVERIFIED_RESEARCH_CANDIDATE",
    }

def extract_chapter(book_id: str, spec: dict, chapter: int) -> list[dict]:
    if book_id == "BAR" and chapter == 6:
        rows = []
        for verse in range(1, 73):
            rows.append(extract_single_verse_page(book_id, spec, chapter, verse))
            if verse < 72:
                time.sleep(0.12)
        return rows
    url = f"{BASE}?book={spec['book']}&chapter={chapter}"
    soup = BeautifulSoup(fetch(url), "html.parser")
    page_text = soup.get_text(" ", strip=True)
    if "الترجمة اليسوعية القديمة 1877 م" not in page_text:
        raise RuntimeError(f"{book_id} chapter {chapter}: 1877 translation marker missing")
    anchors = [
        anchor for anchor in soup.select('a[href*="showVerses.php"]')
        if verse_number_from_link(anchor) is not None
    ]
    candidates: dict[int, list[str]] = {}

    for anchor in anchors:
        if anchor.find_parent(["h1", "h2", "h3", "h4", "h5", "h6"]):
            continue
        number = verse_number_from_link(anchor)
        parent = anchor
        ancestor_candidates = []
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
                normalized = re.sub(r"\s+", " ", candidate).strip()
                if normalized not in ancestor_candidates:
                    ancestor_candidates.append(normalized)

        if not ancestor_candidates:
            continue
        selected_text = max(ancestor_candidates, key=len)
        text = re.sub(r"\s+", " ", selected_text).strip()
        text = re.sub(rf"^0*{number}[.\s،:：-]+", "", text).strip()
        if not ARABIC_RE.search(text) or len(text) < 8:
            continue
        candidates.setdefault(number, [])
        if text not in candidates[number]:
            candidates[number].append(text)

    if not candidates:
        raise RuntimeError(f"{book_id} chapter {chapter}: no verses extracted from {url}")
    found: dict[int, str] = {}
    for number, options in candidates.items():
        if len(options) == 1:
            found[number] = options[0]
            continue
        longest = max(options, key=len)
        second_longest = sorted((len(option) for option in options), reverse=True)[1]
        if all(option in longest for option in options) or len(longest) >= 1.5 * second_longest:
            found[number] = longest
        else:
            raise RuntimeError(
                f"{book_id} {chapter}:{number}: ambiguous verse candidates: "
                + " || ".join(repr(option) for option in options)
            )

    numbers = sorted(found)
    linked_numbers = sorted({verse_number_from_link(anchor) for anchor in anchors})
    expected = list(range(1, numbers[-1] + 1))
    if numbers != expected or numbers != linked_numbers:
        raise RuntimeError(
            f"{book_id} chapter {chapter}: extracted verse numbers {numbers} "
            f"do not match linked numbers {linked_numbers}"
        )

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
