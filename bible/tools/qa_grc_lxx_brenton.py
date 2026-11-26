#!/usr/bin/env python3
"""Full exact-key and text comparison of Brenton corpus against eBible source."""
from __future__ import annotations
import gzip,hashlib,json,urllib.request
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from prepare_grc_lxx_brenton import SOURCE_URL,parse_archive,TRANSLATION_ID,EDITION
ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"data"
def main():
 audit=json.loads((DATA/"grc-lxx-brenton-1851_audit.json").read_text(encoding="utf-8"))
 req=urllib.request.Request(SOURCE_URL,headers={"User-Agent":"RehlaBibleCorpusQA/1.0"})
 with urllib.request.urlopen(req,timeout=120) as response: archive=response.read()
 sha=hashlib.sha256(archive).hexdigest()
 if sha!=audit["source_archive_sha256"]: raise AssertionError("Source archive SHA changed")
 source_rows,coverage=parse_archive(archive)
 source={(r["book_id"],r["chapter"],r["verse"]):r["text"] for r in source_rows}
 committed={}
 with gzip.open(DATA/"grc-lxx-brenton-1851.jsonl.gz","rt",encoding="utf-8") as stream:
  for line in stream:
   row=json.loads(line)
   if row["translation_id"]!=TRANSLATION_ID or row["edition"]!=EDITION: raise AssertionError("Unexpected edition metadata")
   key=(row["book_id"],int(row["chapter"]),str(row["verse"]))
   if key in committed: raise AssertionError(f"Duplicate committed key: {key}")
   committed[key]=row["text"]
 missing=sorted(set(source)-set(committed)); extra=sorted(set(committed)-set(source))
 mismatch=sorted(k for k in set(source)&set(committed) if source[k]!=committed[k])
 if missing or extra or mismatch: raise AssertionError(f"Mismatch missing={len(missing)} extra={len(extra)} text={len(mismatch)}")
 audit["status"]="FULL_SOURCE_MATCH_PASSED"
 audit["qa"]={"comparison":"FULL_CORPUS_EXACT_KEY_AND_TEXT","matched_records":len(committed),
  "missing_records":0,"extra_records":0,"text_mismatches":0,"source_archive_sha256_verified":sha}
 (DATA/"grc-lxx-brenton-1851_audit.json").write_text(json.dumps(audit,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print(json.dumps({"status":"PASSED","books":len(coverage),"matched_records":len(committed),"source_sha256":sha},ensure_ascii=False,indent=2))
if __name__=="__main__": main()
