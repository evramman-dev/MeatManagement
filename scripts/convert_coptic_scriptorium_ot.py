#!/usr/bin/env python3
"""Convert Coptic SCRIPTORIUM OT TreeTagger corpora to research-only JSONL."""
from __future__ import annotations
import argparse, collections, hashlib, json, pathlib, re, zipfile
from lxml import etree

BOOK_MAP = {
    "gen":"gen","exod":"exo","lev":"lev","num":"num","deut":"deu","josh":"jos","judg":"jdg","ruth":"rut",
    "1sam":"1sa","2sam":"2sa","1kgs":"1ki","2kgs":"2ki","1chr":"1ch","2chr":"2ch","esth":"est","job":"job",
    "pss":"psa","prov":"pro","eccl":"ecc","song":"sng","wis":"wis","sir":"sir","isa":"isa","jer":"jer","lam":"lam",
    "bar":"bar","ezek":"ezk","dan":"dan","hos":"hos","joel":"jol","amos":"amo","obad":"oba","jonah":"jon",
    "mic":"mic","nah":"nam","hab":"hab","zeph":"zep","hag":"hag","zech":"zec","zach":"zec","mal":"mal",
    "tob":"tob","jdt":"jdt","2macc":"2ma"
}
TEXTUAL_UNITS = {"bel":("dan","dan_bel_dragon"),"sus":("dan","dan_susanna"),
                 "epjer":("bar","bar_letter_jeremiah"),"prman":(None,"pr_manasseh")}

def sha256(data): return hashlib.sha256(data).hexdigest()

def extract_norm_text(verse):
    tokens=[]
    for node in verse.iter("norm"):
        value="".join(node.itertext()).strip()
        if value: tokens.append(value)
    return " ".join(tokens)

def extract_original_text(verse,dialect):
    if dialect=="sahidic":
        return " ".join(n.attrib.get("orig","") for n in verse.iter("norm") if n.attrib.get("orig"))
    return " ".join(n.attrib.get("orig","") for n in verse.iter("orig") if n.attrib.get("orig"))

def parse_archive(path,edition_id):
    records=[]; documents=[]; issues=[]
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            if not name.lower().endswith(".tt"): continue
            raw=archive.read(name)
            parser=etree.XMLParser(recover=True,encoding="utf-8")
            root=etree.fromstring(raw,parser); meta=dict(root.attrib)
            urn=meta.get("document_cts_urn","")
            match=re.search(r":ot\.([^.]+)\.[^:]+:([^:]+)$",urn)
            source_book=match.group(1) if match else None
            source_chapter_label=meta.get("chapter") or (match.group(2) if match else "")
            chapter=int(source_chapter_label) if str(source_chapter_label).isdigit() else None
            unit_parent,unit_id=TEXTUAL_UNITS.get(source_book,(None,None))
            book_id=unit_parent if source_book in TEXTUAL_UNITS else BOOK_MAP.get(source_book)
            verses=list(root.iter("verse_n"))
            raw_verse_count=len(re.findall(rb"<verse_n\b",raw))
            raw_norm_count=len(re.findall(rb"<norm\b",raw))
            parsed_norm_count=len(list(root.iter("norm")))
            raw_orig_count=len(re.findall(rb"<orig\b",raw))
            parsed_orig_count=len(list(root.iter("orig")))
            doc={"edition_id":edition_id,"source_file":name,"source_document_urn":urn,
                "source_book_id":source_book,"book_id":book_id,"textual_unit_id":unit_id,
                "source_chapter_label":str(source_chapter_label),"chapter":chapter,
                "title":meta.get("title"),"language":meta.get("languages"),"license":meta.get("license"),
                "source":meta.get("source"),"annotation":meta.get("annotation"),"version":meta.get("version_n"),
                "version_date":meta.get("version_date"),"project":meta.get("project"),
                "translation_alignment_source":meta.get("translation"),"versification_note":meta.get("note"),
                "verse_markers_raw":raw_verse_count,"verse_markers_parsed":len(verses),
                "norm_markers_raw":raw_norm_count,"norm_markers_parsed":parsed_norm_count,
                "orig_markers_raw":raw_orig_count,"orig_markers_parsed":parsed_orig_count,
                "xml_recovery_error_count":len(parser.error_log),"raw_sha256":sha256(raw)}
            if raw_verse_count!=len(verses) or raw_norm_count!=parsed_norm_count or raw_orig_count!=parsed_orig_count:
                issues.append({"source_file":name,"issue":"recovery_marker_count_mismatch",
                    "raw_verse_markers":raw_verse_count,"parsed_verse_markers":len(verses),
                    "raw_norm_markers":raw_norm_count,"parsed_norm_markers":parsed_norm_count,
                    "raw_orig_markers":raw_orig_count,"parsed_orig_markers":parsed_orig_count})
            documents.append(doc)
            for index,verse in enumerate(verses,1):
                vname=verse.attrib.get("vname",""); verse_attr=verse.attrib.get("verse_n","")
                source_verse_label=vname.rsplit(":",1)[-1] if vname else (verse_attr or str(index))
                english=verse.attrib.get("translation","")
                if not english:
                    for tr in verse.iter("translation"):
                        english=tr.attrib.get("translation","")
                        if english: break
                records.append({"edition_id":edition_id,"source_document_urn":urn,"source_file":name,
                    "source_book_id":source_book,"book_id":book_id,"textual_unit_id":unit_id,
                    "source_chapter_label":str(source_chapter_label),"chapter":chapter,
                    "source_verse_label":source_verse_label,"verse_order":index,
                    "display_candidate_text":extract_norm_text(verse),
                    "original_text":extract_original_text(verse,edition_id.split("_")[1]),
                    "english_alignment_candidate":english,"source_license":meta.get("license"),
                    "source_version":meta.get("version_n"),"source_version_date":meta.get("version_date"),
                    "xml_recovery_error_count":len(parser.error_log)})
    return records,documents,issues

def summarize(records,documents,expected_books):
    by_book=collections.defaultdict(lambda:{"chapters":set(),"chapter_labels":set(),"records":0,"empty":0})
    duplicate=collections.Counter()
    for r in records:
        key=r.get("textual_unit_id") or r.get("book_id") or f"unmapped:{r.get('source_book_id')}"
        item=by_book[key]; item["chapters"].add(r.get("chapter")); item["chapter_labels"].add(r.get("source_chapter_label"))
        item["records"]+=1; item["empty"]+=not bool(r.get("display_candidate_text","").strip())
        duplicate[(r.get("source_book_id"),key,r.get("source_chapter_label"),r.get("source_verse_label"))]+=1
    present={r.get("book_id") for r in records if r.get("book_id") and not r.get("textual_unit_id")}
    parent_by_unit={}
    for r in records:
        key=r.get("textual_unit_id") or r.get("book_id") or f"unmapped:{r.get('source_book_id')}"
        parent_by_unit[key]=r.get("book_id")
    books={}
    for book,stats in sorted(by_book.items()):
        chapters=sorted(x for x in stats["chapters"] if isinstance(x,int))
        books[book]={"parent_book_id":parent_by_unit.get(book),"chapter_count":len(stats["chapters"]),
            "chapter_numbers":chapters,
            "missing_internal_chapter_numbers":[n for n in range(chapters[0],chapters[-1]+1) if n not in chapters] if chapters else [],
            "non_numeric_chapter_labels":sorted(x for x in stats["chapter_labels"] if not str(x).isdigit()),
            "has_chapter_zero":0 in stats["chapters"],"verse_records":stats["records"],
            "empty_display_candidate_records":stats["empty"]}
    return {"document_count":len(documents),"chapter_document_count":sum(d["chapter"] is not None for d in documents),
        "nonchapter_document_count":sum(d["chapter"] is None for d in documents),"verse_record_count":len(records),
        "book_id_count":len(present),"canonical_books_present":len(present & expected_books),
        "missing_canonical_book_ids":sorted(expected_books-present),
        "unmapped_source_book_ids":sorted({d.get("source_book_id") for d in documents if d.get("source_book_id") and d.get("source_book_id") not in BOOK_MAP and d.get("source_book_id") not in TEXTUAL_UNITS}),
        "extra_textual_unit_ids":sorted({r["textual_unit_id"] for r in records if r.get("textual_unit_id")}),
        "duplicate_reference_groups":sum(1 for n in duplicate.values() if n>1),
        "duplicate_extra_records":sum(n-1 for n in duplicate.values() if n>1),
        "empty_display_candidate_records":sum(not bool(r.get("display_candidate_text","").strip()) for r in records),
        "documents_with_xml_recovery":sum(d["xml_recovery_error_count"]>0 for d in documents),
        "total_xml_recovery_errors":sum(d["xml_recovery_error_count"] for d in documents),
        "source_book_ids":sorted({d.get("source_book_id") for d in documents if d.get("source_book_id")}),
        "marker_count_mismatch_documents":sum(d["verse_markers_raw"]!=d["verse_markers_parsed"] or d["norm_markers_raw"]!=d["norm_markers_parsed"] or d["orig_markers_raw"]!=d["orig_markers_parsed"] for d in documents),
        "books":books}

def render_report(audit):
    lines=["# تقرير فحص corpus العهد القديم القبطي — بحثي فقط","",
        "هذه الملفات شواهد نصية بحثية وليست طبعة كاملة موحدة أو نصًا معتمدًا لواجهة التطبيق.",
        "المصدر مثبت على commit 6fb51458e7156dd5387c2b2dca207aac1692e4d0.",
        "الترخيص المعلن CC BY-SA 4.0، ويجب تطبيق الإسناد والترخيص بالمثل.",""]
    for name,e in audit["editions"].items():
        lines += [f"## {name}",f"- ملفات الوثائق: {e['document_count']}، منها {e['chapter_document_count']} وثيقة إصحاح و{e['nonchapter_document_count']} وثيقة غير مرتبطة بإصحاح رقمي.",
            f"- علامات الأعداد: {e['verse_record_count']}.",f"- الأسفار القانونية القبطية ذات النصوص الموجودة: {e['canonical_books_present']} من 46.",
            f"- معرفات الأسفار غير الموجودة: {', '.join(e['missing_canonical_book_ids'])}.",
            f"- الوحدات النصية الإضافية: {', '.join(e['extra_textual_unit_ids']) if e['extra_textual_unit_ids'] else 'لا يوجد'}.",
            f"- مجموعات المراجع المكررة: {e['duplicate_reference_groups']}، سجلات نصها فارغ: {e['empty_display_candidate_records']}.",
            f"- ملفات احتاجت استعادة XML: {e['documents_with_xml_recovery']} من {e['document_count']}، مع اختلاف في أعداد علامات verse/norm/orig: {e['marker_count_mismatch_documents']}.",
            "","| السفر أو الوحدة | الإصحاحات الموجودة | علامات الأعداد | إصحاح 0 | فجوات داخلية |","|---|---|---:|---|---|"]
        for book,v in e["books"].items():
            chapters=", ".join(str(x) for x in v["chapter_numbers"])
            if v["non_numeric_chapter_labels"]: chapters += " / "+", ".join(v["non_numeric_chapter_labels"])
            gaps=", ".join(str(x) for x in v["missing_internal_chapter_numbers"]) or "لا يوجد"
            lines.append(f"| {book} | {chapters} | {v['verse_records']} | {'نعم' if v['has_chapter_zero'] else 'لا'} | {gaps} |")
        lines.append("")
    lines += ["## ضوابط الاستخدام","- display_candidate_text نص معياري مقسم إلى كلمات، وoriginal_text يحفظ القراءة الأصلية المتاحة.",
        "- النص الإنجليزي المرفق محاذاة Brenton مرشحة وقد تكون غير متطابقة أو ناقصة، ولا يستخدم كمرجع.",
        "- أعداد الإصحاحات والأعداد تصف ملفات المصدر فقط، ولا تثبت اكتمال السفر أو الترقيم القانوني.",
        "- استعادة XML حافظت على أعداد علامات verse_n وnorm وorig في هذه الدفعة، لكنها لا تعني إعادة بناء كل علاقات التحليل والوسوم المتداخلة.",
        "- لا يتم دمج الصعيدي والبحيري، ولا دمج الإضافات داخل نص السفر الأم."]
    return "\n".join(lines)+"\n"

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--input",required=True); p.add_argument("--catalog",required=True); p.add_argument("--output",required=True)
    a=p.parse_args()
    catalog=json.loads(pathlib.Path(a.catalog).read_text(encoding="utf-8"))
    expected={x["book_id"] for x in catalog["books"] if x["testament"]=="OT"}
    root=pathlib.Path(a.input); out=pathlib.Path(a.output); out.mkdir(parents=True,exist_ok=True)
    summaries={}
    for filename,edition in [("ot_cop_sahidic_scriptorium_tt.zip","coptic_sahidic_ot_scriptorium_research"),
        ("ot_cop_bohairic_scriptorium_tt.zip","coptic_bohairic_ot_scriptorium_research")]:
        path=root/filename
        if not path.exists(): raise FileNotFoundError(path)
        records,documents,issues=parse_archive(path,edition)
        (out/edition).mkdir(parents=True,exist_ok=True)
        with (out/edition/"verses.jsonl").open("w",encoding="utf-8") as f:
            for row in records: f.write(json.dumps(row,ensure_ascii=False,separators=(",",":"))+"\n")
        (out/edition/"documents.jsonl").write_text("".join(json.dumps(row,ensure_ascii=False,separators=(",",":"))+"\n" for row in documents),encoding="utf-8")
        (out/edition/"parse-issues.json").write_text(json.dumps(issues,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        summaries[edition]=summarize(records,documents,expected)
    result={"schema_version":1,"status":"research_only_not_canonical_complete_bible_or_app_text",
        "source_repository":"CopticScriptorium/corpora","source_commit":"6fb51458e7156dd5387c2b2dca207aac1692e4d0",
        "license":"CC BY-SA 4.0; verify each document attribution and license metadata",
        "policy":"Keep dialects, manuscript witnesses, source chapter labels and versification separate. Do not publish as a complete Coptic Bible.",
        "editions":summaries}
    (out/"coptic-ot-research-audit.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (out/"coptic-ot-research-audit.md").write_text(render_report(result),encoding="utf-8")
    print(json.dumps({k:{"documents":v["document_count"],"chapters":v["chapter_document_count"],
        "verses":v["verse_record_count"],"books":v["book_id_count"],
        "missing":v["missing_canonical_book_ids"],"marker_mismatches":v["marker_count_mismatch_documents"]}
        for k,v in summaries.items()},ensure_ascii=False,indent=2))
if __name__=="__main__": main()
