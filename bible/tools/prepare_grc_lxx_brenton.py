#!/usr/bin/env python3
"""Prepare the public-domain Brenton Greek Septuagint corpus from eBible USFM."""
from __future__ import annotations
import argparse, gzip, hashlib, io, json, re, urllib.request, zipfile
from collections import defaultdict
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_ebible_usfm import parse_usfm

TRANSLATION_ID = "GRC-LXX-BRENTON-1851"
EDITION = "Brenton Greek Septuagint 1851 (GRCBRE)"
SOURCE_URL = "https://ebible.org/Scriptures/grcbrent_usfm.zip"
INFO_URL = "https://ebible.org/find/details.php?id=grcbrent"
LICENSE = "Public Domain"
# Source USFM identifiers from the eBible Brenton package. The 52-book list
# is independently published in the eBible/DBS book-by-book PDF index.
SOURCE_BOOKS = [
 "GEN","EXO","LEV","NUM","DEU","JOS","JDG","RUT","1SA","2SA","1KI","2KI",
 "1CH","2CH","EZR","JOB","PSA","PRO","ECC","SNG","ISA","JER","LAM","EZK",
 "HOS","JOL","AMO","OBA","JON","MIC","NAM","HAB","ZEP","HAG","ZEC","MAL",
 "TOB","JDT","ESG","WIS","SIR","BAR","LJE","SUS","BEL","1MA","2MA","3MA",
 "4MA","1ES","MAN","DAG"
]
# Internal book IDs stay independent from all other editions. For books in the
# Coptic navigation catalog they use its stable IDs; other Brenton books retain
# their own source-derived IDs and remain visible as extra edition content.
BOOK_ID = {code:code.lower() for code in SOURCE_BOOKS}
BOOK_ID.update({"ESG":"est","DAG":"dan","TOB":"tob","JDT":"jdt","WIS":"wis","SIR":"sir","BAR":"bar","1MA":"1ma","2MA":"2ma"})
EXPECTED_SOURCE_BOOKS=set(SOURCE_BOOKS)

def fetch_archive():
    req=urllib.request.Request(SOURCE_URL,headers={"User-Agent":"RehlaBibleCorpusPrep/1.0"})
    with urllib.request.urlopen(req,timeout=120) as response:
        data=response.read()
    return data,hashlib.sha256(data).hexdigest()

def parse_archive(data):
    rows=[]
    coverage=defaultdict(lambda:{"chapters":set(),"verses":0,"source_book_id":None})
    seen_sources=set()
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        names=[n for n in archive.namelist() if n.lower().endswith((".sfm",".usfm"))]
        if not names: raise RuntimeError("No USFM/SFM files found in Brenton archive")
        for name in names:
            raw=archive.read(name).decode("utf-8-sig",errors="replace")
            source_book,parsed=parse_usfm(raw,TRANSLATION_ID,EDITION)
            source_book=(source_book or "").upper()
            if source_book not in EXPECTED_SOURCE_BOOKS: continue
            if source_book in seen_sources: raise RuntimeError("Duplicate source book file: "+source_book)
            seen_sources.add(source_book)
            book_id=BOOK_ID[source_book]
            for row in parsed:
                verse_text=str(row["text"]).strip()
                if not verse_text: raise RuntimeError(f"Empty verse: {source_book} {row['chapter']}:{row['verse']}")
                rows.append({"translation_id":TRANSLATION_ID,"edition":EDITION,"book_id":book_id,
                    "chapter":int(row["chapter"]),"verse":str(row["verse"]),"text":verse_text})
                coverage[book_id]["chapters"].add(int(row["chapter"]))
                coverage[book_id]["verses"]+=1
                coverage[book_id]["source_book_id"]=source_book
    missing=sorted(EXPECTED_SOURCE_BOOKS-seen_sources)
    if missing: raise RuntimeError("Brenton archive missing expected books: "+", ".join(missing))
    keys=[(r["book_id"],r["chapter"],r["verse"]) for r in rows]
    if len(keys)!=len(set(keys)): raise RuntimeError("Duplicate verse keys in Brenton archive")
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
    output=args.output_dir/"grc-lxx-brenton-1851.jsonl.gz"
    with output.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw,mode="wb",compresslevel=9,mtime=0) as gz:
            for row in rows: gz.write((json.dumps(row,ensure_ascii=False)+"\n").encode("utf-8"))
    report={"translation_id":TRANSLATION_ID,"edition":EDITION,"language":"grc","textual_tradition":"Septuagint",
      "source_url":SOURCE_URL,"source_info_url":INFO_URL,"source_license":LICENSE,"source_archive_sha256":sha,
      "record_count":len(rows),"book_count":len(coverage),
      "source_book_ids":SOURCE_BOOKS,
      "book_coverage":{k:{"source_book_id":v["source_book_id"],"chapter_count":len(v["chapters"]),
        "verse_record_count":v["verses"],"chapters":sorted(v["chapters"])} for k,v in sorted(coverage.items())},
      "books_missing_from_source":[],"extra_books_beyond_73_book_coptic_navigation_catalog":
        ["1es","3ma","4ma","man","lje","sus","bel"],
      "coptic_catalog_books_without_independent_source_book_code":sorted({"gen","exo","lev","num","deu","jos","jdg","rut","1sa","2sa","1ki","2ki","1ch","2ch","ezr","neh","tob","jdt","est","job","psa","pro","ecc","sng","wis","sir","isa","jer","lam","bar","ezk","dan","hos","jol","amo","oba","jon","mic","nam","hab","zep","hag","zec","mal","1ma","2ma"}-set(coverage)),
      "coptic_catalog_coverage_notes":["The source book EZR is the combined Ezra-Nehemiah (2 Esdras) witness and has 23 chapters. NEH has no separate source-book code in this edition. Keep the combined source book intact and do not split it into canonical books without a reviewed alignment."] ,
      "output_file":output.name,"status":"PREPARED_NOT_YET_QA_APPROVED",
      "text_processing":"USFM markers and footnotes/cross-references removed; Greek text and source verse labels retained. Source book codes are preserved in book_coverage."}
    (args.output_dir/"grc-lxx-brenton-1851_audit.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"translation_id":TRANSLATION_ID,"records":len(rows),"books":len(coverage),"source_sha256":sha},ensure_ascii=False))
if __name__=="__main__": main()
