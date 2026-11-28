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
        title = soup.title.get_text(" ", strip=True) if soup.title else "(no title)"
        print(f"DEBUG URL={response.url} STATUS={response.status_code} TITLE={title}")
        print(f"DEBUG PAGE TEXT={page_text[:5000]}")
        raise RuntimeError("Official Book of Holy Week attribution was not found on the page")

    attribution_start = page_text.find(ATTRIBUTION)
    if attribution_start < 0:
        raise RuntimeError("Book of Holy Week attribution was not found")
    prayer_start = attribution_start + len(ATTRIBUTION)
    next_heading = page_text.find("صلاة منسى", prayer_start)
    if next_heading < 0:
        raise RuntimeError("Could not find the end marker after the Prayer of Manasseh text")
    raw = clean(page_text[prayer_start:next_heading])
    if "1أيهاالرب" not in raw.replace(" ", "") or "19لكالمجد" not in raw.replace(" ", ""):
        raise RuntimeError("The isolated text does not contain the first and last numbered verses")

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
