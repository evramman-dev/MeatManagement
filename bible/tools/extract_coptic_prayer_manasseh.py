#!/usr/bin/env python3
"""Extract the official Coptic site's complete Prayer of Manasseh as a research candidate."""
from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

import requests
from bs4 import BeautifulSoup

SOURCE_URL = "https://copticorthodox.church/bible/%D8%B3%D9%90%D9%81%D9%92%D8%B1%D9%8F-%D8%A3%D9%8E%D8%AE%D9%92%D8%A8%D9%8E%D8%A7%D8%B1%D9%90-%D8%A7%D9%84%D8%A3%D9%8E%D9%8A%D9%91%D9%8E%D8%A7%D9%85%D9%90-%D8%A7%D9%84%D8%AB%D9%91%D9%8E%D8%A7%D9%86-33/"
TRANSLATION_ID = "ARB-COPTIC-LITURGICAL-MANASSEH"
REVIEW_STATUS = "UNVERIFIED_RESEARCH_CANDIDATE"
ATTRIBUTION = "هذا النص منقول من كتاب صلوات أسبوع الآلام للكنيسة القبطية الأرثوذكسية"
ARABIC_RE = re.compile(r"[\u0600-\u06ff]")
VERSE_MARKER = re.compile(r"(?<!\d)(1[0-9]|[1-9])\s*")


def clean(value: str) -> str:
    value = unicodedata.normalize("NFKC", value)
    return re.sub(r"\s+", " ", value).strip()


def main() -> int:
    response = requests.get(
        SOURCE_URL,
        headers={"User-Agent": "RehlaBibleResearch/1.0 (research-only; contact via repository)"},
        timeout=45,
    )
    response.raise_for_status()
    soup = BeautifulSoup(response.text, "html.parser")
    page_text = clean(soup.get_text(" ", strip=True))
    if ATTRIBUTION not in page_text:
        raise RuntimeError("Official Book of Holy Week attribution was not found on the page")

    candidates = []
    for tag in soup.find_all(["p", "div", "section", "blockquote"]):
        value = clean(tag.get_text(" ", strip=True))
        if "1أيها الرب" in value.replace(" ", "") and "19لك المجد" in value.replace(" ", ""):
            candidates.append((len(value), value))
    if not candidates:
        raise RuntimeError("Could not isolate a single element containing Prayer of Manasseh verses 1 and 19")

    raw = min(candidates, key=lambda item: item[0])[1]
    matches = list(VERSE_MARKER.finditer(raw))
    selected = []
    expected = 1
    for match in matches:
        number = int(match.group(1))
        if number == expected:
            selected.append(match)
            expected += 1
            if expected == 20:
                break
    if expected != 20:
        raise RuntimeError(f"Expected numbered verses 1–19 in order; stopped before verse {expected}")

    rows = []
    for index, match in enumerate(selected):
        start = match.end()
        end = selected[index + 1].start() if index + 1 < len(selected) else len(raw)
        verse_text = clean(raw[start:end]).strip(" ،؛.ـ")
        if len(verse_text) < 8 or not ARABIC_RE.search(verse_text):
            raise RuntimeError(f"Verse {index + 1} is empty or not Arabic")
        rows.append({
            "translation_id": TRANSLATION_ID,
            "book_id": "MAN",
            "chapter": 1,
            "verse": index + 1,
            "text": verse_text,
            "source_url": SOURCE_URL,
            "source_label": "Official Coptic Orthodox Church website; attributed on page to the Coptic Orthodox Book of Holy Week",
            "rights_status": "UNCONFIRMED",
            "review_status": REVIEW_STATUS,
        })

    if [row["verse"] for row in rows] != list(range(1, 20)):
        raise RuntimeError("Verse numbering validation failed")

    output = Path(sys.argv[1] if len(sys.argv) > 1 else "manasseh-research-candidate.jsonl")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows),
        encoding="utf-8",
    )
    print(f"PASS: extracted {len(rows)} numbered verses as a separate research candidate")
    print("PASS: source attribution present; digital redistribution rights remain unconfirmed")
    print(f"Output: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
