#!/usr/bin/env python3
"""Research-only extractor for St-Takla's Jesuit Arabic Tobit chapter pages.

Install: python -m pip install beautifulsoup4
This tool writes a local JSONL candidate. It does not add text to the app corpus.
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
BOOK_NUMBER = 17
BOOK_ID = "TOB"
TRANSLATION_ID = "ARB-JES-1877"
EXPECTED_CHAPTERS = 14
ARABIC_RE = re.compile(r"[\u0600-\u06FF]")


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


def extract_chapter(chapter: int) -> list[dict]:
    url = f"{BASE}?book={BOOK_NUMBER}&chapter={chapter}"
    soup = BeautifulSoup(fetch(url), "html.parser")
    anchors = [
        a for a in soup.select('a[href*="showVerses.php"]')
        if verse_number_from_link(a) is not None
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
                a for a in parent.select('a[href*="showVerses.php"]')
                if verse_number_from_link(a) is not None
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
            raise RuntimeError(
                f"Chapter {chapter}, verse {number}: conflicting extracted text"
            )
        found[number] = text

    if not found:
        raise RuntimeError(
            f"Chapter {chapter}: no verses extracted. The site's HTML structure "
            "may have changed; inspect the page before adapting the parser."
        )
    numbers = sorted(found)
    expected = list(range(1, numbers[-1] + 1))
    if numbers != expected:
        raise RuntimeError(
            f"Chapter {chapter}: verse sequence has gaps or duplicates; "
            f"found {numbers}"
        )

    return [
        {
            "translation_id": TRANSLATION_ID,
            "book_id": BOOK_ID,
            "chapter": chapter,
            "verse": number,
            "text": found[number],
            "source_url": url,
            "source_label": "St-Takla; page identifies Jesuit Old Arabic translation, 1877",
            "review_status": "UNVERIFIED_RESEARCH_CANDIDATE",
        }
        for number in numbers
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chapter", type=int, help="Extract one chapter; default: all 14")
    parser.add_argument("--output", type=Path, help="Write JSONL to this local path")
    parser.add_argument("--delay", type=float, default=0.5, help="Delay between requests")
    args = parser.parse_args()

    chapters = [args.chapter] if args.chapter else list(range(1, EXPECTED_CHAPTERS + 1))
    if any(chapter < 1 or chapter > EXPECTED_CHAPTERS for chapter in chapters):
        parser.error("Tobit chapter must be between 1 and 14")

    rows = []
    for index, chapter in enumerate(chapters):
        chapter_rows = extract_chapter(chapter)
        rows.extend(chapter_rows)
        print(f"chapter {chapter}: {len(chapter_rows)} verses", file=sys.stderr)
        if index + 1 < len(chapters):
            time.sleep(max(0.0, args.delay))

    serialized = "".join(
        json.dumps(row, ensure_ascii=False) + "\n" for row in rows
    )
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(serialized, encoding="utf-8")
        print(f"wrote {len(rows)} research rows to {args.output}", file=sys.stderr)
    else:
        sys.stdout.write(serialized)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
