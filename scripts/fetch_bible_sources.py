#!/usr/bin/env python3
"""Fetch candidate Bible source files for private QA; never commits or publishes text."""
from __future__ import annotations

import csv
import hashlib
import json
import pathlib
import subprocess
import sys
import zipfile

OUT = pathlib.Path("build/bible-source-batch-01")
SOURCES = [
    ("ot_he_wlc_usfm", "https://ebible.org/Scriptures/hboWLC_usfm.zip", "zip", "WLC Hebrew OT, eBible USFM"),
    ("ot_he_wlc_csv", "https://openscriptorium.org/downloads/csv/wlc.csv", "csv", "WLC export, Open Scriptorium"),
    ("ot_grc_rahlfs_csv", "https://openscriptorium.org/downloads/csv/rahlfs-lxx.csv", "csv", "Rahlfs Septuagint 1935 export"),
    ("nt_grc_patriarchal_csv", "https://openscriptorium.org/downloads/csv/patriarchal-1904.csv", "csv", "Patriarchal Greek NT 1904 export"),
    ("nt_grc_sblgnt_source", "https://github.com/Faithlife/SBLGNT/archive/refs/heads/master.zip", "zip", "SBLGNT official source repository archive"),
    ("nt_cop_sahidic_usfm", "https://ebible.org/Scriptures/copcnt_usfm.zip", "zip", "Coptic NT candidate, Sahidic"),
    ("nt_cop_bohairic_usfm", "https://ebible.org/Scriptures/copbhc_usfm.zip", "zip", "Coptic NT, Bohairic"),
    ("en_webbe_usfm", "https://ebible.org/Scriptures/eng-webbe_usfm.zip", "zip", "World English Bible British Edition with Deuterocanon"),
    ("en_webbe_csv", "https://openscriptorium.org/downloads/csv/webbe.csv", "csv", "WEBBE export, Open Scriptorium"),
]

def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    failed = []
    for source_id, url, kind, description in SOURCES:
        suffix = ".zip" if kind == "zip" else ".csv"
        path = OUT / f"{source_id}{suffix}"
        print(f"Downloading {source_id} ...", flush=True)
        result = subprocess.run(
            ["curl", "--fail", "--location", "--retry", "3", "--retry-delay", "2",
             "--connect-timeout", "30", "--max-time", "600", url, "--output", str(path)],
            check=False,
        )
        record = {
            "source_id": source_id,
            "description": description,
            "url": url,
            "format": kind,
            "downloaded": result.returncode == 0 and path.exists() and path.stat().st_size > 0,
        }
        if not record["downloaded"]:
            failed.append(source_id)
            record["error"] = f"curl exit {result.returncode}"
        else:
            record["bytes"] = path.stat().st_size
            record["sha256"] = sha256(path)
            if kind == "zip":
                try:
                    with zipfile.ZipFile(path) as archive:
                        bad = archive.testzip()
                        record["zip_entries"] = len(archive.infolist())
                        record["zip_test"] = "passed" if bad is None else f"failed:{bad}"
                        if bad is not None:
                            failed.append(source_id)
                except zipfile.BadZipFile:
                    record["zip_test"] = "invalid_zip"
                    failed.append(source_id)
            else:
                try:
                    with path.open("r", encoding="utf-8-sig", newline="") as f:
                        reader = csv.reader(f)
                        header = next(reader, [])
                        count = sum(1 for _ in reader)
                    record["csv_header"] = header
                    record["data_rows"] = count
                    record["csv_test"] = "passed" if count > 0 else "empty"
                    if count == 0:
                        failed.append(source_id)
                except Exception as exc:
                    record["csv_test"] = f"failed:{type(exc).__name__}:{exc}"
                    failed.append(source_id)
        records.append(record)
        print(json.dumps(record, ensure_ascii=False), flush=True)

    manifest = {
        "batch_id": "bible-source-batch-01",
        "purpose": "private source acquisition and QA only",
        "not_for_publication": True,
        "records": records,
        "failed_source_ids": failed,
        "note": "Downloaded source files are not yet approved app corpus. Each edition requires book/chapter/verse and license review.",
    }
    (OUT / "download-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Manifest written. Failed sources: {len(failed)}", flush=True)
    return 1 if failed else 0

if __name__ == "__main__":
    sys.exit(main())
