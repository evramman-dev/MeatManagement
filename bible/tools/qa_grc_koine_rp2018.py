#!/usr/bin/env python3
"""Full-source QA for the accented RP2018 Unicode corpus and old-corpus lexical parity."""
from __future__ import annotations
import argparse, csv, gzip, json, re, unicodedata
from pathlib import Path
from prepare_grc_koine_rp2018 import (
    BOOK_FILES, CSV_BASE_URL, EDITION, INFO_URL, SOURCE_COMMIT,
    SOURCE_REPOSITORY, TRANSLATION_ID, fetch_csv, parse_csv_text,
)
ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"

def read_jsonl_gz(path):
    rows = {}
    with gzip.open(path, "rt", encoding="utf-8") as stream:
        for line in stream:
            row = json.loads(line)
            key = (row["book_id"], int(row["chapter"]), str(row["verse"]))
            if key in rows:
                raise AssertionError(f"Duplicate corpus key: {key}")
            rows[key] = row
    return rows

def lexical_tokens(text):
    # The previous eBible USFM conversion accidentally retained inline Strong's
    # and morphology annotations (for example "25 V-PAI-3S"). Remove those
    # annotations only for the comparison; never alter the saved display text.
    text = re.sub(r"(?i)\\b\\d+\\s+[A-Z]-[A-Z0-9-]+\\b", " ", text)
    text = re.sub(r"\\b\\d+\\b", " ", text)
    normalized = unicodedata.normalize("NFD", text)
    chars = []
    for char in normalized:
        if unicodedata.category(char) == "Mn":
            continue
        chars.append(char.casefold())
    normalized = "".join(chars).replace("ς", "σ")
    tokens, current = [], []
    for char in normalized:
        if char.isalpha():
            current.append(char)
        elif current:
            tokens.append("".join(current))
            current = []
    if current:
        tokens.append("".join(current))
    return tokens

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--previous-corpus", type=Path, required=True)
    args = parser.parse_args()

    source = {}
    coverage = {}
    source_hashes = {}
    for source_book, filename, book_id in BOOK_FILES:
        raw = fetch_csv(filename)
        import hashlib
        source_hashes[f"{filename}.csv"] = hashlib.sha256(raw).hexdigest()
        rows, chapters = parse_csv_text(source_book, book_id, raw.decode("utf-8-sig"))
        coverage[book_id] = {"source_book_id": source_book, "chapters": chapters}
        for row in rows:
            key = (row["book_id"], row["chapter"], row["verse"])
            if key in source:
                raise AssertionError(f"Duplicate source key: {key}")
            source[key] = row["text"]

    committed_rows = read_jsonl_gz(DATA / "grc-koine-rp-2018.jsonl.gz")
    committed = {key: row["text"] for key, row in committed_rows.items()}
    missing = sorted(set(source) - set(committed))
    extra = sorted(set(committed) - set(source))
    exact_mismatches = sorted(key for key in set(source) & set(committed) if source[key] != committed[key])
    if missing or extra or exact_mismatches:
        raise AssertionError(
            f"Source comparison failed: missing={len(missing)}, extra={len(extra)}, text_mismatches={len(exact_mismatches)}"
        )
    if len(coverage) != 27 or len({(key[0], key[1]) for key in source}) != 260:
        raise AssertionError("Expected exactly 27 books and 260 chapters")

    # Confirm the corpus is genuinely polytonic and retains punctuation.
    john_1_1 = committed.get(("jhn", 1, "1"), "")
    expected = "Ἐν ἀρχῇ ἦν ὁ λόγος, καὶ ὁ λόγος ἦν πρὸς τὸν θεόν, καὶ θεὸς ἦν ὁ λόγος."
    if john_1_1 != expected:
        raise AssertionError(f"John 1:1 did not match the official RP2018 sample: {john_1_1!r}")
    if not any("¶" in text for text in committed.values()):
        raise AssertionError("Paragraph markers were unexpectedly lost")

    previous = read_jsonl_gz(args.previous_corpus)
    old_keys = set(previous)
    new_keys = set(committed_rows)
    if old_keys != new_keys:
        raise AssertionError(
            f"Previous corpus verse keys changed: missing={len(old_keys-new_keys)}, extra={len(new_keys-old_keys)}"
        )
    lexical_mismatches = []
    formatting_changed = 0
    for key in sorted(new_keys):
        old_text = previous[key]["text"]
        new_text = committed[key]
        if old_text != new_text:
            formatting_changed += 1
        old_tokens = lexical_tokens(old_text)
        new_tokens = lexical_tokens(new_text)
        if old_tokens != new_tokens:
            lexical_mismatches.append({
                "key": key,
                "previous_text": old_text,
                "official_byztxt_text": new_text,
                "previous_tokens": old_tokens,
                "official_tokens": new_tokens,
            })
            if len(lexical_mismatches) >= 30:
                break
    if lexical_mismatches:
        print(json.dumps({
            "lexical_mismatch_count_sample": len(lexical_mismatches),
            "first_mismatches": lexical_mismatches,
            "records_with_typographic_changes": formatting_changed,
        }, ensure_ascii=False, indent=2))
        raise AssertionError(
            "Greek word-sequence differences versus the existing eBible RP2018 corpus require manual review"
        )

    audit_path = DATA / "grc-koine-rp-2018_audit.json"
    audit = json.loads(audit_path.read_text(encoding="utf-8"))
    audit["status"] = "FULL_SOURCE_AND_LEXICAL_PARITY_QA_PASSED"
    audit["qa"] = {
        "source_comparison": "FULL_CORPUS_EXACT_KEY_AND_TEXT",
        "source_records_matched": len(source),
        "missing_records": 0,
        "extra_records": 0,
        "source_text_mismatches": 0,
        "verified_books": len(coverage),
        "verified_chapters": 260,
        "previous_corpus_comparison": "EXACT_VERSE_KEYS_AND_NORMALIZED_GREEK_WORD_SEQUENCE",
        "previous_corpus_records": len(previous),
        "previous_corpus_key_mismatches": 0,
        "normalized_word_sequence_mismatches": 0,
        "records_with_typographic_changes": formatting_changed,
        "normalization": "Unicode NFD; remove combining diacritics and punctuation; casefold; normalize final sigma only for comparison. The stored display text is never normalized.",
        "john_1_1_exact_sample": john_1_1,
        "source_commit": SOURCE_COMMIT,
        "source_files_sha256_verified": source_hashes,
    }
    audit_path.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    registry_path = DATA / "multilingual-edition-registry.draft.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    edition = next((item for item in registry["editions"] if item["edition_id"] == "nt_grc_rp_2018"), None)
    if edition is None:
        raise AssertionError("Robinson-Pierpont edition is missing from multilingual registry")
    edition.update({
        "source_url": INFO_URL,
        "license": "Public Domain / Unlicense (as declared by ByzTxt repository)",
        "license_status": "verified_by_official_byztxt_repository",
        "coverage_status": "27_book_nt_full_source_match_passed",
        "corpus_status": "accented_rp2018_unicode_imported_and_qa_passed",
        "notes": (
            "Robinson-Pierpont 2018 Byzantine Majority Text. Uses the official ByzTxt Unicode CCAT no-variants main-text CSVs "
            f"pinned to commit {SOURCE_COMMIT}. Preserves polytonic accents, breathings, punctuation, capitalization and paragraph markers. "
            "Separate PA (John 7:53–8:11) and Acts 24:6–8 alternatives are not merged into the main text. "
            "All 27 books, 260 chapters and verse keys match the official source exactly. "
            "Normalized Greek word sequences match the previous 7,953-verse eBible RP2018 corpus with zero differences."
        ),
        "corpus_file": "bible/data/grc-koine-rp-2018.jsonl.gz",
        "audit_file": "bible/data/grc-koine-rp-2018_audit.json",
        "record_count": len(committed),
        "source_commit": SOURCE_COMMIT,
        "source_files_sha256": source_hashes,
        "last_verified": __import__("datetime").date.today().isoformat(),
    })
    edition.pop("source_archive_sha256", None)
    registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "status": "PASSED",
        "books": len(coverage),
        "chapters": 260,
        "records": len(committed),
        "normalized_word_sequence_mismatches": 0,
        "records_with_typographic_changes": formatting_changed,
        "john_1_1": john_1_1,
        "source_commit": SOURCE_COMMIT,
    }, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
