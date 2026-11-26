#!/usr/bin/env python3
"""Prepare Robinson-Pierpont 2018 Greek Majority Text NT from eBible USFM."""
from __future__ import annotations
import argparse, gzip, hashlib, io, json, re, urllib.request, zipfile
from collections import defaultdict
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_ebible_usfm import parse_usfm

TRANSLATION_ID = "GRC-KOINE-RP-2018"
EDITION = "Greek New Testament — Robinson-Pierpont 2018 (Greek Majority Text)"
SOURCE_URL = "https://ebible.org/Scriptures/grcmt_usfm.zip"
INFO_URL = "https://ebible.org/bible/details.php?id=grcmt"
LICENSE = "Public Domain"
SOURCE_BOOKS = ["MAT","MRK","LUK","JHN","ACT","ROM","1CO","2CO","GAL","EPH","PHP","COL","1TH","2TH","1TI","2TI","TIT","PHM","HEB","JAS","1PE","2PE","1JN","2JN","3JN","JUD","REV"]
BOOK_ID = {code: code.lower() for code in SOURCE_BOOKS}
EXPECTED_SOURCE_BOOKS = set(SOURCE_BOOKS)

def fetch_archive():
    req=urllib.request.Request(SOURCE_URL,headers={"User-Agent":"RehlaBibleCorpusPrep/1.0"})
    with urllib.request.urlopen(req,timeout=120) as response:
        data=response.read()
    return data,hashlib.sha256(data).hexdigest()

def parse_archive(data):
    rows=[]
    coverage=defaultdict(lambda:{"chapters":set(),"verses":0,"source_book_id":None})
    seen=set()
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        names=[n for n in archive.namelist() if n.lower().endswith((".sfm",".usfm"))]
        if not names: raise RuntimeError("No USFM/SFM files found in Greek NT source archive")
        for name in names:
            raw=archive.read(name).decode("utf-8-sig",errors="replace")
            source_book,parsed=parse_usfm(raw,TRANSLATION_ID,EDITION)
            source_book=(source_book or "").upper()
            if source_book not in EXPECTED_SOURCE_BOOKS: continue
            if source_book in seen: raise RuntimeError("Duplicate source book file: "+source_book)
            seen.add(source_book)
            book_id=BOOK_ID[source_book]
            for row in parsed:
                verse_text=str(row["text"]).strip()
                if not verse_text: raise RuntimeError(f"Empty verse: {source_book} {row['chapter']}:{row['verse']}")
                rows.append({"translation_id":TRANSLATION_ID,"edition":EDITION,"book_id":book_id,
                    "chapter":int(row["chapter"]),"verse":str(row["verse"]),"text":verse_text})
                coverage[book_id]["chapters"].add(int(row["chapter"]))
                coverage[book_id]["verses"]+=1
                coverage[book_id]["source_book_id"]=source_book
    missing=sorted(EXPECTED_SOURCE_BOOKS-seen)
    if missing: raise RuntimeError("Greek NT source archive missing expected books: "+", ".join(missing))
    keys=[(r["book_id"],r["chapter"],r["verse"]) for r in rows]
    if len(keys)!=len(set(keys)): raise RuntimeError("Duplicate verse keys in Greek NT source archive")
    order={BOOK_ID[c]:i for i,c in enumerate(SOURCE_BOOKS)}
    def verse_order(value):
        m=re.match(r"(\d+)",str(value))
        return (int(m.group(1)) if m else 0,str(value))
    rows.sort(key=lambda r:(order[r["book_id"]],r["chapter"],verse_order(r["verse"])))
    return rows,coverage

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--output-dir",type=Path,default=Path("bible/data"))
    args=ap.parse_args()
    archive,sha=fetch_archive()
    rows,coverage=parse_archive(archive)
    args.output_dir.mkdir(parents=True,exist_ok=True)
    output=args.output_dir/"grc-koine-rp-2018.jsonl.gz"
    with output.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw,mode="wb",compresslevel=9,mtime=0) as gz:
            for row in rows: gz.write((json.dumps(row,ensure_ascii=False)+"\n").encode("utf-8"))
    report={"translation_id":TRANSLATION_ID,"edition":EDITION,"language":"grc","dialect":"Koine",
      "textual_tradition":"Byzantine / Majority Text","editor_or_translators":"Maurice A. Robinson and William G. Pierpont",
      "edition_year":2018,"source_url":SOURCE_URL,"source_info_url":INFO_URL,"source_license":LICENSE,
      "source_archive_sha256":sha,"record_count":len(rows),"book_count":len(coverage),
      "source_book_ids":SOURCE_BOOKS,
      "book_coverage":{k:{"source_book_id":v["source_book_id"],"chapter_count":len(v["chapters"]),
        "verse_record_count":v["verses"],"chapters":sorted(v["chapters"])} for k,v in sorted(coverage.items())},
      "expected_new_testament_chapter_total":260,
      "actual_chapter_total":sum(len(v["chapters"]) for v in coverage.values()),
      "books_missing_from_source":[],"books_outside_new_testament_source_not_imported":True,
      "output_file":output.name,"status":"PREPARED_NOT_YET_QA_APPROVED",
      "text_processing":"USFM structural markers and footnotes/cross-references removed; Greek source text and original source verse labels retained. No other Greek edition is used to fill gaps."}
    (args.output_dir/"grc-koine-rp-2018_audit.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"translation_id":TRANSLATION_ID,"records":len(rows),"books":len(coverage),
      "chapters":report["actual_chapter_total"],"source_sha256":sha},ensure_ascii=False,indent=2))
if __name__=="__main__": main()
