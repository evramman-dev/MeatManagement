#!/usr/bin/env python3
"""Acquire and parse the Arabic Deuterocanon pages published by St-Takla.org."""
from __future__ import annotations
import hashlib, json, pathlib, re, subprocess, sys, unicodedata

INDEX_URL = "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__0-index_.html"
OUT = pathlib.Path("build/sttakla-deuterocanon")
BOOKS = [
    ("tobit", "سفر طوبيا", 14),
    ("judith", "سفر يهوديت", 16),
    ("esther_additions", "تتمه سفر استير", 16),
    ("wisdom", "سفر الحكمة", 19),
    ("sirach", "سفر حكمة يشوع ابن سيراخ", 51),
    ("baruch", "سفر نبوة باروخ", 6),
    ("daniel_additions", "تتمة سفر دانيال", 14),
    ("1_maccabees", "سفر المكابيين الأول", 16),
    ("2_maccabees", "سفر المكابيين الثاني", 15),
    ("psalm_151", "المزمور 151", 1),
]
WORD_NUMBERS = {
    "الأول":1,"الثاني":2,"الثالث":3,"الرابع":4,"الخامس":5,"السادس":6,
    "السابع":7,"الثامن":8,"التاسع":9,"العاشر":10,"الحادي عشر":11,
    "الثاني عشر":12,"الثالث عشر":13,"الرابع عشر":14,"الخامس عشر":15,
    "السادس عشر":16,"السابع عشر":17,"الثامن عشر":18,"التاسع عشر":19,
    "العشرون":20,"الحادي والعشرون":21,"الثاني والعشرون":22,"الثالث والعشرون":23,
    "الرابع والعشرون":24,"الخامس والعشرون":25,"السادس والعشرون":26,"السابع والعشرون":27,
    "الثامن والعشرون":28,"التاسع والعشرون":29,"الثلاثون":30,"الحادي والثلاثون":31,
    "الثاني والثلاثون":32,"الثالث والثلاثون":33,"الرابع والثلاثون":34,"الخامس والثلاثون":35,
    "السادس والثلاثون":36,"السابع والثلاثون":37,"الثامن والثلاثون":38,"التاسع والثلاثون":39,
    "الأربعون":40,"الحادي والأربعون":41,"الثاني والأربعون":42,"الثالث والأربعون":43,
    "الرابع والأربعون":44,"الخامس والأربعون":45,"السادس والأربعون":46,"السابع والأربعون":47,
    "الثامن والأربعون":48,"التاسع والأربعون":49,"الخمسون":50,"الحادي والخمسون":51,
}
def curl(url, path):
    r=subprocess.run(["curl","--fail","--location","--retry","3","--retry-delay","2",
                      "--connect-timeout","30","--max-time","120",url,"--output",str(path)],check=False)
    if r.returncode: raise RuntimeError(f"curl failed ({r.returncode}) for {url}")
def sha256(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for c in iter(lambda:f.read(1024*1024),b""): h.update(c)
    return h.hexdigest()
def strip_html(html):
    html=re.sub(r"<script\b[^>]*>.*?</script>"," ",html,flags=re.I|re.S)
    html=re.sub(r"<style\b[^>]*>.*?</style>"," ",html,flags=re.I|re.S)
    html=re.sub(r"<br\s*/?>","\n",html,flags=re.I)
    html=re.sub(r"</(?:p|div|li|h[1-6]|tr)>","\n",html,flags=re.I)
    html=re.sub(r"<[^>]+>"," ",html)
    html=re.sub(r"&nbsp;"," ",html,flags=re.I)
    html=re.sub(r"&#160;"," ",html)
    html=re.sub(r"&#x([0-9a-f]+);",lambda m:chr(int(m.group(1),16)),html,flags=re.I)
    html=re.sub(r"&#(\d+);",lambda m:chr(int(m.group(1))),html)
    return [re.sub(r"\s+"," ",unicodedata.normalize("NFC",x)).strip()
            for x in html.splitlines() if re.sub(r"\s+"," ",x).strip()]
def chapter_number(line):
    m=re.search(r"(?:الإصحاح|الأصحاح|الاصحاح)\s+(.+)$",line)
    if not m: return None
    v=m.group(1).strip()
    if v.isdigit(): return int(v)
    norm=lambda s:s.replace("أ","ا").replace("إ","ا").replace("آ","ا")
    nv=norm(v)
    for key,value in WORD_NUMBERS.items():
        if norm(key)==nv: return value
    return None
def parse_page(path, book_id, expected_chapters):
    raw=path.read_bytes()
    candidates=[]
    for enc in ("utf-8","cp1256","iso-8859-6","windows-1252"):
        try:
            decoded=raw.decode(enc)
            score=sum(1 for ch in decoded if "\u0600" <= ch <= "\u06ff")
            candidates.append((score,decoded,enc))
        except UnicodeDecodeError:
            pass
    if not candidates:
        raise UnicodeDecodeError("unknown","",0,1,"no supported encoding")
    _,html,encoding=max(candidates,key=lambda x:x[0])
    lines=strip_html(html)
    merged=[]; i=0
    while i < len(lines):
        if re.fullmatch(r"\d+\.", lines[i]) and i+1 < len(lines):
            merged.append(lines[i] + " " + lines[i+1]); i += 2
        elif re.fullmatch(r"\d+", lines[i]) and i+1 < len(lines) and len(lines[i+1]) > 1:
            merged.append(lines[i] + ". " + lines[i+1]); i += 2
        else:
            merged.append(lines[i]); i += 1
    lines=merged
    records=[]; current=None
    for line in lines:
        ch=chapter_number(line)
        if ch is not None: current=ch; continue
        if current is None: continue
        m=re.match(r"^([^\d]{0,20}?)(\d+)\s*:\s*(\d+)\s+(.+)$",line)
        if m:
            records.append({"book_id":book_id,"chapter":current,"verse":int(m.group(3)),
                            "text":m.group(4).strip(),"source":"St-Takla.org"})
            continue
        m=re.match(r"^(\d+)\.\s+(.+)$",line)
        if m and len(m.group(2).strip())>1:
            records.append({"book_id":book_id,"chapter":current,"verse":int(m.group(1)),
                            "text":m.group(2).strip(),"source":"St-Takla.org"})
    by={}
    for r in records: by.setdefault(r["chapter"],[]).append(r)
    qa=[]
    for ch in range(1,expected_chapters+1):
        rows=by.get(ch,[]); nums=[r["verse"] for r in rows]
        qa.append({"chapter":ch,"verses":len(rows),
                   "first_verse":min(nums) if nums else None,
                   "last_verse":max(nums) if nums else None,
                   "duplicates":sorted({n for n in nums if nums.count(n)>1})})
    return records,qa
BOOK_URLS = {
    "tobit": "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__1-Tobit_.html",
    "judith": "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__2-Judith_.html",
    "esther_additions": "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__3-Esther_.html",
    "wisdom": "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__4-Wisdon-of-Solomon_.html",
    "sirach": "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__5-Wisdon-of-Joshua-Son-of-Sirach_.html",
    "baruch": "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__6-Baruch_.html",
    "daniel_additions": "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__7-Daniel_.html",
    "1_maccabees": "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__8-First-of-Maccabees_.html",
    "2_maccabees": "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__9-Second-of-Maccabees_.html",
    "psalm_151": "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya_10-Psalm151-El-Mazmoor-151_.html",
}
def discover_book_urls(index_html):
    found={}
    for m in re.finditer(r'href=["\']([^"\']+)["\'][^>]*>(.*?)</a>',index_html,flags=re.I|re.S):
        href=m.group(1); label=re.sub(r"<[^>]+>"," ",m.group(2))
        label=re.sub(r"\s+"," ",label).strip()
        if "Deuterocanon" in href and href.lower().endswith(".html"):
            for book_id,title,_ in BOOKS:
                if label==title or title in label: found[book_id]=href
    return found
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    index_path=OUT/"index.html"; curl(INDEX_URL,index_path)
    urls=BOOK_URLS
    all_records=[]; reports=[]
    for book_id,title,expected in BOOKS:
        path=OUT/f"{book_id}.html"; curl(urls[book_id],path)
        rows,qa=parse_page(path,book_id,expected)
        for r in rows: r["source_url"]=urls[book_id]
        all_records.extend(rows)
        reports.append({"book_id":book_id,"title":title,"url":urls[book_id],
                        "expected_chapters":expected,
                        "chapters_found":sorted({x["chapter"] for x in qa if x["verses"]}),
                        "record_count":len(rows),
                        "chapters_with_no_verses":[x["chapter"] for x in qa if not x["verses"]],
                        "duplicate_verses":{str(x["chapter"]):x["duplicates"] for x in qa if x["duplicates"]},
                        "sha256_html":sha256(path)})
    with (OUT/"sttakla-deuterocanon.jsonl").open("w",encoding="utf-8") as f:
        for r in all_records: f.write(json.dumps(r,ensure_ascii=False,separators=(",",":"))+"\n")
    report={"source":"St-Takla.org","source_index":INDEX_URL,
            "source_statement":"The St-Takla Deuterocanon page states that this text is from the old Jesuit translation published in 1877.",
            "not_yet_app_corpus":True,"books":reports,"total_records":len(all_records),
            "total_books":len(reports),
            "total_chapters_expected":sum(x[2] for x in BOOKS),
            "total_chapters_with_verses":sum(len(x["chapters_found"]) for x in reports)}
    (OUT/"qa-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report,ensure_ascii=False,indent=2))
    return 0 if report["total_chapters_with_verses"]==report["total_chapters_expected"] else 2
if __name__=="__main__": sys.exit(main())
