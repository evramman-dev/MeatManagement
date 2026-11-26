#!/usr/bin/env python3
"""Prepare the public-domain Hebrew text of the Westminster Leningrad Codex."""
from __future__ import annotations
import argparse, gzip, hashlib, json, urllib.request, zipfile, io
from collections import defaultdict
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_ebible_usfm import parse_usfm

TRANSLATION_ID = "HE-WLC-2017"
EDITION = "Westminster Leningrad Codex — Biblical Hebrew (hboWLC)"
SOURCE_URL = "https://ebible.org/Scriptures/hboWLC_usfm.zip"
LICENSE = "Public Domain — WLC biblical text only; morphology/lemma layers are excluded."
OT_BOOKS = {
 "GEN":"gen","EXO":"exo","LEV":"lev","NUM":"num","DEU":"deu","JOS":"jos","JDG":"jdg","RUT":"rut",
 "1SA":"1sa","2SA":"2sa","1KI":"1ki","2KI":"2ki","1CH":"1ch","2CH":"2ch","EZR":"ezr","NEH":"neh",
 "EST":"est","JOB":"job","PSA":"psa","PRO":"pro","ECC":"ecc","SNG":"sng","ISA":"isa","JER":"jer",
 "LAM":"lam","EZK":"ezk","DAN":"dan","HOS":"hos","JOL":"jol","AMO":"amo","OBA":"oba","JON":"jon",
 "MIC":"mic","NAM":"nam","HAB":"hab","ZEP":"zep","HAG":"hag","ZEC":"zec","MAL":"mal"
}

def fetch_archive():
    req=urllib.request.Request(SOURCE_URL, headers={"User-Agent":"RehlaBibleCorpusPrep/1.0"})
    with urllib.request.urlopen(req, timeout=120) as response:
        data=response.read()
    return data, hashlib.sha256(data).hexdigest()

def parse_archive(data):
    rows=[]
    coverage=defaultdict(lambda: {"chapters":set(),"verses":0})
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        names=[n for n in archive.namelist() if n.lower().endswith((".sfm",".usfm"))]
        if not names:
            raise RuntimeError("No USFM/SFM files found in WLC source archive")
        for name in names:
            raw=archive.read(name).decode("utf-8-sig",errors="replace")
            source_book, parsed=parse_usfm(raw,TRANSLATION_ID,EDITION)
            source_book=(source_book or "").upper()
            if source_book not in OT_BOOKS:
                continue
            book_id=OT_BOOKS[source_book]
            for row in parsed:
                text=str(row["text"]).strip()
                if not text:
                    raise RuntimeError(f"Empty Hebrew verse: {source_book} {row['chapter']}:{row['verse']}")
                rows.append({
                    "translation_id":TRANSLATION_ID,
                    "edition":EDITION,
                    "book_id":book_id,
                    "chapter":int(row["chapter"]),
                    "verse":str(row["verse"]),
                    "text":text
                })
                coverage[book_id]["chapters"].add(int(row["chapter"]))
                coverage[book_id]["verses"]+=1
    keys=[(r["book_id"],r["chapter"],r["verse"]) for r in rows]
    if len(keys)!=len(set(keys)):
        raise RuntimeError("Duplicate verse keys found in WLC source archive")
    missing=sorted(set(OT_BOOKS.values())-{r["book_id"] for r in rows})
    if missing:
        raise RuntimeError("WLC source is missing expected Masoretic books: "+", ".join(missing))
    rows.sort(key=lambda r:(list(OT_BOOKS.values()).index(r["book_id"]),r["chapter"],r["verse"]))
    return rows,coverage

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--output-dir",type=Path,default=Path("bible/data"))
    args=ap.parse_args()
    archive,source_sha=fetch_archive()
    rows,coverage=parse_archive(archive)
    args.output_dir.mkdir(parents=True,exist_ok=True)
    stem="he-wlc-2017"
    output=args.output_dir/(stem+".jsonl.gz")
    with output.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw,mode="wb",compresslevel=9,mtime=0) as gz:
            for row in rows:
                gz.write((json.dumps(row,ensure_ascii=False)+"\n").encode("utf-8"))
    report={
      "translation_id":TRANSLATION_ID,"edition":EDITION,"language":"hbo",
      "source_url":SOURCE_URL,"source_repository":"https://github.com/openscriptures/morphhb",
      "source_license":LICENSE,"source_archive_sha256":source_sha,
      "record_count":len(rows),"book_count":len(coverage),
      "book_coverage":{k:{"chapter_count":len(v["chapters"]),"verse_record_count":v["verses"]} for k,v in sorted(coverage.items())},
      "books_missing_from_wlc":sorted(set(OT_BOOKS.values())-set(coverage)),
      "books_not_in_wlc_including_deuterocanon":True,
      "output_file":output.name,"status":"PREPARED_NOT_YET_QA_APPROVED",
      "text_processing":"USFM structural markers and footnotes/cross-references removed; Hebrew text, vowel points and cantillation retained; no lemma or morphology fields imported."
    }
    (args.output_dir/(stem+"_audit.json")).write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"translation_id":TRANSLATION_ID,"records":len(rows),"books":len(coverage),"source_sha256":source_sha,"output":str(output)},ensure_ascii=False))
if __name__=="__main__": main()
