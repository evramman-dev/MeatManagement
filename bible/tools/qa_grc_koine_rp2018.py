#!/usr/bin/env python3
"""Compare every committed RP 2018 Greek NT verse to its exact eBible USFM source."""
from __future__ import annotations
import gzip,hashlib,json,urllib.request
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from prepare_grc_koine_rp2018 import SOURCE_URL,parse_archive,TRANSLATION_ID,EDITION
ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"data"
def main():
 audit=json.loads((DATA/"grc-koine-rp-2018_audit.json").read_text(encoding="utf-8"))
 req=urllib.request.Request(SOURCE_URL,headers={"User-Agent":"RehlaBibleCorpusQA/1.0"})
 with urllib.request.urlopen(req,timeout=120) as response: archive=response.read()
 sha=hashlib.sha256(archive).hexdigest()
 if sha!=audit["source_archive_sha256"]: raise AssertionError("Source archive SHA changed")
 source_rows,coverage=parse_archive(archive)
 source={(r["book_id"],r["chapter"],str(r["verse"])):r["text"] for r in source_rows}
 committed={}
 with gzip.open(DATA/"grc-koine-rp-2018.jsonl.gz","rt",encoding="utf-8") as stream:
  for line in stream:
   row=json.loads(line)
   if row["translation_id"]!=TRANSLATION_ID or row["edition"]!=EDITION: raise AssertionError("Unexpected translation metadata")
   key=(row["book_id"],int(row["chapter"]),str(row["verse"]))
   if key in committed: raise AssertionError(f"Duplicate committed key: {key}")
   committed[key]=row["text"]
 missing=sorted(set(source)-set(committed)); extra=sorted(set(committed)-set(source))
 mismatch=sorted(k for k in set(source)&set(committed) if source[k]!=committed[k])
 if missing or extra or mismatch: raise AssertionError(f"Mismatch missing={len(missing)} extra={len(extra)} text={len(mismatch)}")
 chapter_total=sum(len(v["chapters"]) for v in coverage.values())
 if len(coverage)!=27 or chapter_total!=260: raise AssertionError(f"Expected 27 books / 260 chapters, got {len(coverage)} / {chapter_total}")
 audit["status"]="FULL_SOURCE_MATCH_PASSED"
 audit["qa"]={"comparison":"FULL_CORPUS_EXACT_KEY_AND_TEXT","matched_records":len(committed),
  "missing_records":0,"extra_records":0,"text_mismatches":0,"source_archive_sha256_verified":sha,
  "verified_books":len(coverage),"verified_chapters":chapter_total}
 (DATA/"grc-koine-rp-2018_audit.json").write_text(json.dumps(audit,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 registry_path=DATA/"multilingual-edition-registry.draft.json"
 registry=json.loads(registry_path.read_text(encoding="utf-8"))
 edition=next((item for item in registry["editions"] if item["edition_id"]=="nt_grc_rp_2018"),None)
 if edition is None: raise AssertionError("Robinson-Pierpont edition is missing from multilingual registry")
 edition.update({"coverage_status":"27_book_nt_full_source_match_passed",
  "corpus_status":"imported_and_full_source_match_passed",
  "notes":f"Robinson-Pierpont 2018 Greek Majority Text NT. eBible declares dialect Koine and license Public Domain. Verified {len(coverage)} books and {chapter_total} chapters with {len(committed)} verse records. Full exact-key and text comparison against the downloaded USFM archive passed: zero missing, extra, or mismatched records. Preserves the Byzantine / Majority Text witness independently from SBLGNT and Brenton LXX.",
  "corpus_file":"bible/data/grc-koine-rp-2018.jsonl.gz",
  "audit_file":"bible/data/grc-koine-rp-2018_audit.json",
  "record_count":len(committed),"source_archive_sha256":sha,"last_verified":__import__("datetime").date.today().isoformat()})
 registry_path.write_text(json.dumps(registry,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print(json.dumps({"status":"PASSED","books":len(coverage),"chapters":chapter_total,
  "matched_records":len(committed),"source_sha256":sha},ensure_ascii=False,indent=2))
if __name__=="__main__": main()
