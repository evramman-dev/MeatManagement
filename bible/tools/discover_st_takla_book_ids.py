#!/usr/bin/env python3
"""Discover St-Takla BibleSearch book IDs and chapter navigation.

Research only: this does not import or publish Bible text.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urljoin, urlparse
from urllib.request import Request, urlopen

from bs4 import BeautifulSoup

BASE = "https://st-takla.org/Bibles/BibleSearch/showChapter.php"
ARABIC_RE = re.compile(r"[\u0600-\u06FF]")
TRANSLATION_MARKERS = (
    "الترجمة اليسوعية القديمة 1877 م",
    "الترجمة اليسوعية القديمة",
)


def fetch(url: str) -> str:
    request = Request(url, headers={"User-Agent": "RehlaBibleSourceAudit/1.0"})
    with urlopen(request, timeout=45) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return response.read().decode(charset, errors="replace")


def inspect_book(book_number: int) -> dict:
    url = f"{BASE}?book={book_number}&chapter=1"
    try:
        html = fetch(url)
    except (HTTPError, URLError, TimeoutError) as exc:
        return {"book_number": book_number, "status": "FETCH_FAILED", "error": str(exc), "url": url}

    soup = BeautifulSoup(html, "html.parser")
    page_text = soup.get_text(" ", strip=True)
    english = re.search(r"Book of\s+(.+?)\s+1\s+in Arabic", page_text, re.I)
    arabic = re.search(r"(سفر\s+.{1,50}?)\s*1", page_text)
    chapter_numbers = set()
    for anchor in soup.select('a[href*="showChapter.php"]'):
        parsed = urlparse(urljoin(BASE, anchor.get("href", "")))
        query = parse_qs(parsed.query)
        if query.get("book", [None])[0] != str(book_number):
            continue
        value = query.get("chapter", [None])[0]
        if value and value.isdigit():
            chapter_numbers.add(int(value))

    verse_numbers = set()
    for anchor in soup.select('a[href*="showVerses.php"]'):
        query = parse_qs(urlparse(urljoin(BASE, anchor.get("href", ""))).query)
        low = query.get("vmin", [None])[0]
        high = query.get("vmax", [None])[0]
        if low and high and low == high and low.isdigit():
            verse_numbers.add(int(low))

    translation = next((marker for marker in TRANSLATION_MARKERS if marker in page_text), None)
    return {
        "book_number": book_number,
        "status": "PAGE_FOUND",
        "english_title": english.group(1).strip() if english else None,
        "arabic_heading": arabic.group(1).strip() if arabic else None,
        "chapter_links_found": len(chapter_numbers),
        "highest_chapter_link": max(chapter_numbers) if chapter_numbers else 1,
        "chapter_one_verse_links": len(verse_numbers),
        "translation_marker": translation,
        "translation_1877_confirmed_on_page": bool(translation and "1877" in translation),
        "url": url,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--first", type=int, default=17)
    parser.add_argument("--last", type=int, default=50)
    parser.add_argument("--delay", type=float, default=0.35)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.first < 1 or args.last < args.first or args.last > 100:
        parser.error("Expected 1 <= first <= last <= 100")

    rows = []
    for number in range(args.first, args.last + 1):
        row = inspect_book(number)
        rows.append(row)
        print(
            f"{number}: {row.get('english_title') or row.get('status')} "
            f"chapters={row.get('highest_chapter_link', '?')} "
            f"1877={row.get('translation_1877_confirmed_on_page', False)}",
            file=sys.stderr,
        )
        if number < args.last:
            time.sleep(max(0.0, args.delay))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows),
        encoding="utf-8",
    )
    found = [row for row in rows if row["status"] == "PAGE_FOUND"]
    print(f"wrote {len(rows)} book-ID observations; {len(found)} pages found", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
