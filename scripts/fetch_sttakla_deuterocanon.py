#!/usr/bin/env python3
"""Acquire and parse the Arabic Deuterocanon pages published by St-Takla.org."""
from __future__ import annotations
import hashlib, json, pathlib, re, subprocess, sys, unicodedata
from urllib.parse import urljoin
from bs4 import BeautifulSoup

INDEX_URL = "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__0-index_.html"
OUT = pathlib.Path("build/sttakla-deuterocanon")
BOOKS = [
    ("tobit", "سفر طوبيا", 14),
    ("judith", "سفر يهوديت", 16),
    ("esther_additions", "تتمه سفر استير", [10,11,12,13,14,15,16]),
    ("wisdom", "سفر الحكمة", 19),
    ("sirach", "سفر حكمة يشوع ابن سيراخ", 51),
    ("baruch", "سفر نبوة باروخ", 6),
    ("daniel_additions", "تتمة سفر دانيال", [3,13,14]),
    ("1_maccabees", "سفر المكابيين الأول", 16),
    ("2_maccabees", "سفر المكابيين الثاني", 15),
    ("psalm_151", "المزمور 151", 1),
]
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
def read_html(path):
    raw=path.read_bytes()
    candidates=[]
    for enc in ("utf-8","cp1256","iso-8859-6","windows-1252"):
        try:
            decoded=raw.decode(enc)
            score=sum(1 for ch in decoded if "\u0600" <= ch <= "\u06ff")
            candidates.append((score,decoded,enc))
        except UnicodeDecodeError:
            pass
    return max(candidates,key=lambda x:x[0])[1]

def sha256(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for c in iter(lambda:f.read(1024*1024),b""): h.update(c)
    return h.hexdigest()
def strip_html(html):
    soup=BeautifulSoup(html,"html.parser")
    text=soup.get_text("\n",strip=True)
    return [re.sub(r"\s+"," ",unicodedata.normalize("NFC",x)).strip()
            for x in text.splitlines() if re.sub(r"\s+"," ",x).strip()]
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
def split_chapter_line(line):
    norm=lambda s:s.replace("أ","ا").replace("إ","ا").replace("آ","ا")
    n=norm(line.strip())
    for key,value in sorted(WORD_NUMBERS.items(),key=lambda x:-len(norm(x[0]))):
        for heading in ("الاصحاح","الأصحاح","الإصحاح"):
            prefix=norm(heading+" "+key)
            if n==prefix:
                return value,""
            if n.startswith(prefix+" "):
                return value,line.strip()[len(heading+" "+key):].strip()
    return None,line

def discover_chapter_index_url(html):
    soup=BeautifulSoup(html,"html.parser")
    for a in soup.find_all("a",href=True):
        label=re.sub(r"\s+"," ",a.get_text(" ",strip=True))
        if "مقسم بالأصحاحات" in label:
            return urljoin(INDEX_URL,a["href"])
    return None

def discover_chapter_urls(index_html, base_url):
    soup=BeautifulSoup(index_html,"html.parser")
    found={}
    for a in soup.find_all("a",href=True):
        label=re.sub(r"\s+"," ",a.get_text(" ",strip=True))
        m=re.search(r"(?:أصحاح|اصحاح)\s+(\d+)$",label)
        if not m: continue
        found[int(m.group(1))]=urljoin(base_url,a["href"])
    return found

def parse_chapter_page(path, book_id, chapter):
    html=read_html(path)
    lines=strip_html(html)
    rows=[]
    for line in lines:
        m=re.match(r"^(\d+)\s+(.+)$",line)
        if m and len(m.group(2).strip())>1:
            rows.append({"book_id":book_id,"chapter":chapter,"verse":int(m.group(1)),
                         "text":m.group(2).strip(),"source":"St-Takla.org"})
    return rows

def parse_full_page_chapters(html, book_id, wanted):
    lines=strip_html(html)
    wanted=set(wanted)
    current=None
    rows=[]
    for line in lines:
        ch,remainder=split_chapter_line(line)
        if ch is not None:
            current=ch
            line=remainder
            if not line: continue
        if current not in wanted: continue
        m=re.match(r"^(?:\d+\.|\d+)\s+(.+)$",line)
        if m and len(m.group(1).strip())>1:
            token=re.match(r"^(\d+)",line).group(1)
            rows.append({"book_id":book_id,"chapter":current,"verse":int(token),
                         "text":m.group(1).strip(),"source":"St-Takla.org"})
    return rows

def parse_showchapter_url(book_id, chapter):
    book_num={"esther_additions":20,"daniel_additions":35}.get(book_id)
    if not book_num: return None
    domain="relay.st-takla.org" if book_id=="daniel_additions" else "st-takla.org"
    return f"https://{domain}/Bibles/BibleSearch/showChapter.php?book={book_num}&chapter={chapter}"

def parse_showchapter_page(path, book_id, chapter):
    lines=strip_html(read_html(path))
    rows=[]
    for line in lines:
        m=re.match(r"^(\d+)\s+(.+)$",line)
        if m and len(m.group(2).strip())>1:
            rows.append({"book_id":book_id,"chapter":chapter,"verse":int(m.group(1)),
                         "text":m.group(2).strip(),"source":"St-Takla.org"})
    return rows

def parse_page(path, book_id, expected_chapters):
    if book_id in ("esther_additions","daniel_additions"):
        expected=list(range(1,expected_chapters+1)) if isinstance(expected_chapters,int) else list(expected_chapters)
        records=[]; qa=[]
        for ch in expected:
            url=parse_showchapter_url(book_id,ch)
            if not url:
                continue
            cp=OUT/f"{book_id}-chapter-{ch}.html"; curl(url,cp)
            rows=parse_showchapter_page(cp,book_id,ch)
            for r in rows: r["source_url"]=url
            records.extend(rows)
            nums=[r["verse"] for r in rows]
            qa.append({"chapter":ch,"verses":len(nums),"first_verse":min(nums) if nums else None,
                       "last_verse":max(nums) if nums else None,"duplicates":sorted({n for n in nums if nums.count(n)>1})})
        return records,qa,None
    raw=path.read_bytes()
    candidates=[]
    for enc in ("utf-8","cp1256","iso-8859-6","windows-1252"):
        try:
            decoded=raw.decode(enc)
            score=sum(1 for ch in decoded if "\u0600" <= ch <= "\u06ff")
            candidates.append((score,decoded,enc))
        except UnicodeDecodeError:
            pass
    _,html,_=max(candidates,key=lambda x:x[0])
    idx_url=discover_chapter_index_url(html)
    if book_id == "psalm_151":
        url="https://st-takla.org/Bibles/BibleSearch/showChapters.php?book=23&from=1&to=1"
        cp=OUT/"psalm_151-chapter.html"; curl(url,cp)
        lines=strip_html(read_html(cp))
        rows=[]; i=0
        while i < len(lines):
            m=re.fullmatch(r"(\d+)",lines[i])
            if m and i+1 < len(lines):
                txt=lines[i+1].strip()
                if len(txt)>20:
                    rows.append({"book_id":book_id,"chapter":1,"verse":int(m.group(1)),
                                 "text":txt,"source":"St-Takla.org","source_url":url})
                    i += 2; continue
            m=re.match(r"^(\d+)\s+(.+)$",lines[i])
            if m and len(m.group(2).strip())>20:
                rows.append({"book_id":book_id,"chapter":1,"verse":int(m.group(1)),
                             "text":m.group(2).strip(),"source":"St-Takla.org","source_url":url})
            i += 1
        return rows,[{"chapter":1,"verses":len(rows),"first_verse":min([r["verse"] for r in rows]) if rows else None,
                      "last_verse":max([r["verse"] for r in rows]) if rows else None,
                      "duplicates":sorted({n for n in [r["verse"] for r in rows] if [r["verse"] for r in rows].count(n)>1})}],url
    if not idx_url:
        return [],[],None
    idx_path=OUT/f"{book_id}-chapters.html"
    curl(idx_url,idx_path)
    chapter_urls=discover_chapter_urls(read_html(idx_path),idx_url)
    expected=list(range(1,expected_chapters+1)) if isinstance(expected_chapters,int) else list(expected_chapters)
    records=[]; qa=[]
    found_from_index=set()
    for ch in expected:
        url=chapter_urls.get(ch)
        if not url:
            qa.append({"chapter":ch,"verses":0,"first_verse":None,"last_verse":None,"duplicates":[]})
            continue
        cp=OUT/f"{book_id}-chapter-{ch}.html"
        curl(url,cp)
        rows=parse_chapter_page(cp,book_id,ch)
        for r in rows: r["source_url"]=url
        records.extend(rows)
        if rows: found_from_index.add(ch)
        nums=[r["verse"] for r in rows]
        qa.append({"chapter":ch,"verses":len(rows),
                   "first_verse":min(nums) if nums else None,
                   "last_verse":max(nums) if nums else None,
                   "duplicates":sorted({n for n in nums if nums.count(n)>1})})
    missing=[ch for ch in expected if ch not in found_from_index]
    if missing:
        fallback=parse_full_page_chapters(html,book_id,missing)
        records.extend(fallback)
        by={ch:[] for ch in expected}
        for r in records: by.setdefault(r["chapter"],[]).append(r)
        qa=[]
        for ch in expected:
            nums=[r["verse"] for r in by.get(ch,[])]
            qa.append({"chapter":ch,"verses":len(nums),
                       "first_verse":min(nums) if nums else None,
                       "last_verse":max(nums) if nums else None,
                       "duplicates":sorted({n for n in nums if nums.count(n)>1})})
    return records,qa,idx_url

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
        rows,qa,index_url=parse_page(path,book_id,expected)
        all_records.extend(rows)
        reports.append({"book_id":book_id,"title":title,"url":urls[book_id],
                        "chapter_index_url":index_url,
                        "expected_chapters":list(range(1,expected+1)) if isinstance(expected,int) else list(expected),
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
            "total_chapters_expected":sum(x[2] if isinstance(x[2],int) else len(x[2]) for x in BOOKS),
            "total_chapters_with_verses":sum(len(x["chapters_found"]) for x in reports)}
    (OUT/"qa-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report,ensure_ascii=False,indent=2))
    return 0 if report["total_chapters_with_verses"]==report["total_chapters_expected"] else 2
if __name__=="__main__": sys.exit(main())
