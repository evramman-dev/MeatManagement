#!/usr/bin/env python3
"""Structural audit for staged Bible corpus JSONL exports."""
from __future__ import annotations
import argparse, collections, json, pathlib

def load_rows(root):
    result={}
    for path in sorted(pathlib.Path(root).glob("*/verses.jsonl")):
        rows=[]
        with path.open(encoding="utf-8") as f:
            for line_no,line in enumerate(f,1):
                if line.strip():
                    row=json.loads(line); row["_line_no"]=line_no; rows.append(row)
        result[path.parent.name]=rows
    return result

def audit_edition(rows, expected):
    by_book=collections.defaultdict(list); duplicates=collections.Counter(); unmapped=collections.Counter()
    for row in rows:
        by_book[row.get("book_id")].append(row)
        duplicates[(row.get("book_id"),row.get("chapter"),row.get("verse_label"))]+=1
        if not row.get("book_id"): unmapped[str(row.get("source_book_code"))]+=1
    books={}
    for book_id,items in sorted(by_book.items(),key=lambda x:str(x[0])):
        chapters=collections.defaultdict(list)
        for row in items: chapters[row.get("chapter")].append(row)
        nums=sorted(n for n in chapters if isinstance(n,int))
        books[str(book_id)]={
            "chapter_count":len(chapters),"chapter_min":min(nums) if nums else None,
            "chapter_max":max(nums) if nums else None,"chapter_numbers":nums,
            "missing_internal_chapter_numbers":[n for n in range(nums[0],nums[-1]+1) if n not in chapters] if nums else [],
            "record_count":len(items),
            "unique_reference_count":len({(x.get("chapter"),x.get("verse_label")) for x in items}),
            "duplicate_reference_groups":sum(1 for (b,_,_),n in duplicates.items() if b==book_id and n>1),
            "empty_text_records":sum(not bool(x.get("text","").strip()) for x in items),
            "range_reference_records":sum(bool(x.get("verse_end")) for x in items),
            "range_labels":[x.get("verse_label") for x in items if x.get("verse_end")],
            "empty_text_labels":[x.get("verse_label") for x in items if not x.get("text","").strip()]
        }
    present={x for x in by_book if x}
    return {"record_count":len(rows),"book_count":len(present),
        "chapter_pair_count":len({(x.get("book_id"),x.get("chapter")) for x in rows}),
        "present_expected_books":len(present & expected),"missing_expected_books":sorted(expected-present),
        "extra_books":sorted(present-expected),"unmapped_source_book_records":dict(unmapped),
        "duplicate_reference_groups":sum(1 for n in duplicates.values() if n>1),
        "duplicate_extra_records":sum(n-1 for n in duplicates.values() if n>1),
        "empty_text_records":sum(not bool(x.get("text","").strip()) for x in rows),
        "range_reference_records":sum(bool(x.get("verse_end")) for x in rows),"books":books}

def chapter_counts(rows):
    c=collections.Counter()
    for r in rows: c[(r.get("book_id"),r.get("chapter"))]+=1
    return c

def compare(left,right,left_rows,right_rows):
    a,b=chapter_counts(left_rows),chapter_counts(right_rows)
    keys=sorted(set(a)|set(b),key=lambda x:(str(x[0]),x[1] or 0))
    diffs=[{"book_id":book,"chapter":ch,"left_records":a.get((book,ch),0),"right_records":b.get((book,ch),0)}
           for book,ch in keys if a.get((book,ch),0)!=b.get((book,ch),0)]
    return {"left":left,"right":right,"different_book_chapter_pairs":len(diffs),
        "left_record_count":len(left_rows),"right_record_count":len(right_rows),
        "record_count_difference":len(left_rows)-len(right_rows),"differences":diffs}

def build_audit(catalog,manifest,rows):
    all_books=catalog["books"]
    canon={"OT":{x["book_id"] for x in all_books if x["testament"]=="OT"},
           "NT":{x["book_id"] for x in all_books if x["testament"]=="NT"}}
    canon["OT+NT"]=canon["OT"]|canon["NT"]
    hebrew_39=canon["OT"]-{"tob","jdt","wis","sir","bar","1ma","2ma"}
    editions={}
    for name,items in rows.items():
        meta=manifest.get("edition_metadata",{}).get(name,{})
        scope=meta.get("testament","OT+NT")
        expected=hebrew_39 if name in {"wlc_hebrew_ot","wlc_hebrew_ot_csv"} else canon.get(scope,set())
        result=audit_edition(items,expected)
        result.update({"scope":scope,"language":meta.get("language"),"edition_name":meta.get("edition"),
            "coptic_canon_books_outside_source_scope":sorted(canon["OT"]-hebrew_39) if name in {"wlc_hebrew_ot","wlc_hebrew_ot_csv"} else []})
        if name=="rahlfs_lxx_greek":
            result["unresolved_source_id_mapping_candidates"]={"ezr":["1es","2es"],"neh":["1es","2es"],"est":["est_additions"]}
        editions[name]=result
    pairs=[("wlc_hebrew_ot","wlc_hebrew_ot_csv"),("webbe_english_with_deuterocanon","webbe_english_csv_comparison_only"),
        ("coptic_sahidic_nt_candidate","coptic_bohairic_nt_candidate"),("patriarchal_greek_nt_1904","sblgnt_v1_2")]
    comparisons={}
    for left,right in pairs:
        if left in rows and right in rows: comparisons[f"{left}__vs__{right}"]=compare(left,right,rows[left],rows[right])
    return {"schema_version":1,"audit_status":"structural_only_not_textual_approval_or_publication_clearance",
        "catalog_id":catalog.get("corpus_id"),"catalog_book_count":len(all_books),
        "catalog_old_testament_books":len(canon["OT"]),"catalog_new_testament_books":len(canon["NT"]),
        "editions":editions,"comparisons":comparisons,
        "warnings":["A missing book ID can indicate an unresolved source alias, not necessarily an absent text.",
        "No chapter or verse total is certified without an edition-specific verified versification table.",
        "Verse ranges and suffixes remain in source form and are not expanded or normalized.",
        "Duplicate references are preserved and reported; no LXX reading is selected or discarded.",
        "Empty display text can represent an intentional source omission whose explanation remains in raw_inline."]}

def render_markdown(a):
    lines=["# تدقيق بنية corpus — الدفعة الأولى","","الحالة: تدقيق بنيوي، وليس اعتمادًا نصيًا أو ترخيصًا للنشر.",
        f"- الفهرس: {a['catalog_book_count']} سفرًا، منها {a['catalog_old_testament_books']} للعهد القديم و{a['catalog_new_testament_books']} للعهد الجديد.",
        f"- الطبعات المفحوصة: {len(a['editions'])}.","","## ملخص الطبعات","","| الطبعة | النطاق | الكتب | أزواج السفر/الإصحاح | سجلات الأعداد | مجموعات التكرار | نص فارغ |",
        "|---|---|---:|---:|---:|---:|---:|"]
    for name,e in sorted(a["editions"].items()):
        lines.append(f"| {name} | {e['scope']} | {e['book_count']} | {e['chapter_pair_count']} | {e['record_count']} | {e['duplicate_reference_groups']} | {e['empty_text_records']} |")
    lines += ["","## تغطية الأسفار"]
    for name,e in sorted(a["editions"].items()):
        lines += ["",f"### {name}",f"- غير الموجودة من نطاق المصدر: {', '.join(e['missing_expected_books']) if e['missing_expected_books'] else 'لا يوجد'}.",
            f"- معرفات إضافية: {', '.join(e['extra_books']) if e['extra_books'] else 'لا يوجد'}."]
        if e["coptic_canon_books_outside_source_scope"]:
            lines.append("- أسفار القانون القبطي خارج نطاق المصدر العبري: "+", ".join(e["coptic_canon_books_outside_source_scope"])+".")
        if e.get("unresolved_source_id_mapping_candidates"):
            lines.append("- احتمالات ربط غير معتمدة: "+json.dumps(e["unresolved_source_id_mapping_candidates"],ensure_ascii=False)+".")
        anomalies=[f"{b} ({v['chapter_count']} إصحاح، {v['record_count']} سجل)" for b,v in e["books"].items()
            if v["missing_internal_chapter_numbers"] or v["duplicate_reference_groups"] or v["empty_text_records"] or v["range_reference_records"]]
        if anomalies: lines.append("- مواضع بنيوية للفحص: "+"؛ ".join(anomalies))
    lines += ["","## المقارنات"]
    for key,c in a["comparisons"].items():
        lines += ["",f"### {key}",f"- أزواج السفر/الإصحاح المختلفة: {c['different_book_chapter_pairs']}.",
            f"- فرق إجمالي السجلات: {c['record_count_difference']}."]
        for d in c["differences"]: lines.append(f"- {d['book_id']} {d['chapter']}: {d['left_records']} مقابل {d['right_records']}.")
    lines += ["","## ضوابط التدقيق"]+["- "+x for x in a["warnings"]]
    lines += ["","التفاصيل الكاملة لكل سفر وإصحاح في ملف JSON المرافق."]
    return "\n".join(lines)+"\n"

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--input",required=True); p.add_argument("--catalog",required=True); p.add_argument("--manifest",required=True)
    p.add_argument("--output-json",required=True); p.add_argument("--output-md",required=True)
    x=p.parse_args()
    catalog=json.loads(pathlib.Path(x.catalog).read_text(encoding="utf-8"))
    manifest=json.loads(pathlib.Path(x.manifest).read_text(encoding="utf-8"))
    audit=build_audit(catalog,manifest,load_rows(x.input))
    pathlib.Path(x.output_json).parent.mkdir(parents=True,exist_ok=True)
    pathlib.Path(x.output_json).write_text(json.dumps(audit,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    pathlib.Path(x.output_md).write_text(render_markdown(audit),encoding="utf-8")
    print(json.dumps({k:{"books":v["book_count"],"records":v["record_count"],"missing":v["missing_expected_books"],"extras":v["extra_books"]} for k,v in audit["editions"].items()},ensure_ascii=False,indent=2))
if __name__=="__main__": main()
