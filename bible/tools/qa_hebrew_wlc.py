#!/usr/bin/env python3
"""Full exact-key and text comparison of the committed WLC corpus to its source."""
from __future__ import annotations
import gzip, hashlib, io, json, urllib.request, zipfile
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from prepare_hebrew_wlc import TRANSLATION_ID,EDITION,SOURCE_URL,OT_BOOKS,parse_archive

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"data"

def main():
    audit=json.loads((DATA/"he-wlc-2017_audit.json").read_text(encoding="utf-8"))
    req=urllib.request.Request(SOURCE_URL,headers={"User-Agent":"RehlaBibleCorpusQA/1.0"})
    with urllib.request.urlopen(req,timeout=120) as response: archive=response.read()
    sha=hashlib.sha256(archive).hexdigest()
    if sha!=audit["source_archive_sha256"]:
        raise AssertionError(f"Source archive SHA changed: {sha}")
    source_rows,coverage=parse_archive(archive)
    source={(r["book_id"],r["chapter"],r["verse"]):r["text"] for r in source_rows}
    committed={}
    with gzip.open(DATA/"he-wlc-2017.jsonl.gz","rt",encoding="utf-8") as stream:
        for line in stream:
            row=json.loads(line)
            if row["translation_id"]!=TRANSLATION_ID or row["edition"]!=EDITION:
                raise AssertionError("Unexpected translation metadata")
            key=(row["book_id"],row["chapter"],str(row["verse"]))
            if key in committed: raise AssertionError(f"Duplicate committed key: {key}")
            committed[key]=row["text"]
    missing=sorted(set(source)-set(committed))
    extra=sorted(set(committed)-set(source))
    mismatches=sorted(k for k in set(source)&set(committed) if source[k]!=committed[k])
    if missing or extra or mismatches:
        raise AssertionError(f"Full WLC mismatch missing={len(missing)} extra={len(extra)} text={len(mismatches)}")
    audit["status"]="FULL_SOURCE_MATCH_PASSED"
    audit["qa"]={"comparison":"FULL_CORPUS_EXACT_KEY_AND_TEXT","matched_records":len(committed),"missing_records":0,"extra_records":0,"text_mismatches":0,"source_archive_sha256_verified":sha}
    (DATA/"he-wlc-2017_audit.json").write_text(json.dumps(audit,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"status":"PASSED","translation_id":TRANSLATION_ID,"books":len(coverage),"matched_records":len(committed),"source_sha256":sha},ensure_ascii=False,indent=2))
if __name__=="__main__": main()
