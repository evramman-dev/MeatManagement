#!/usr/bin/env python3
"""Compare St-Takla Word research candidates against chapter HTML pages."""
import argparse,json,re,time,unicodedata
from collections import defaultdict
from pathlib import Path
from urllib.parse import parse_qs,urljoin,urlparse
from urllib.request import Request,urlopen
from bs4 import BeautifulSoup

BASE="https://st-takla.org/Bibles/BibleSearch/showChapter.php"
BOOKS={
"tobit":(17,"TOB",list(range(1,15))),"judith":(18,"JDT",list(range(1,17))),
"esther-additions":(20,"EST-ADD",list(range(10,17))),"psalm-151":(23,"PS151",[1]),
"wisdom":(27,"WIS",list(range(1,20))),"sirach":(28,"SIR",list(range(1,52))),
"baruch":(32,"BAR",list(range(1,7))),"daniel-additions":(35,"DAN-ADD",[3,13,14]),
"1-maccabees":(48,"1MA",list(range(1,17))),"2-maccabees":(49,"2MA",list(range(1,16)))}
ARABIC=re.compile(r"[\u0600-\u06ff]")
def fetch(url):
 req=Request(url,headers={"User-Agent":"RehlaBibleSourceAudit/1.0"})
 with urlopen(req,timeout=35) as r:return r.read().decode(r.headers.get_content_charset() or "utf-8",errors="replace")
def verse_num(a):
 q=parse_qs(urlparse(urljoin(BASE,a.get("href",""))).query);lo=q.get("vmin",[None])[0];hi=q.get("vmax",[None])[0]
 if lo is None or lo!=hi:return None
 try:return int(lo)
 except (ValueError,TypeError):return None
def norm(s):
 s=unicodedata.normalize("NFKC",s);s=re.sub(r"[\u064b-\u065f\u0670\u0640]","",s)
 s=s.translate(str.maketrans({"أ":"ا","إ":"ا","آ":"ا","ٱ":"ا"}))
 s=re.sub(r"[،؛,:.!؟()\[\]{}«»“”\"'ـ…\-–—]"," ",s)
 return re.sub(r"\s+"," ",s).strip()
def extract_html(chapter,book):
 url=f"{BASE}?book={book}&chapter={chapter}";soup=BeautifulSoup(fetch(url),"html.parser")
 body=soup.get_text(" ",strip=True);marker=("1877" in body and ("اليسوعية" in body or "يسوعي" in body))
 found={}
 for a in soup.select('a[href*="showVerses.php"]'):
  n=verse_num(a)
  if n is None:continue
  p=a;chosen=None
  for _ in range(7):
   p=p.parent
   if p is None:break
   links=[x for x in p.select('a[href*="showVerses.php"]') if verse_num(x) is not None]
   candidate=p.get_text(" ",strip=True)
   if len(links)==1 and ARABIC.search(candidate):chosen=candidate;break
  if not chosen:continue
  chosen=re.sub(r"\s+"," ",chosen).strip()
  chosen=re.sub(rf"^0*{n}[.\s،:：\-]+","",chosen).strip()
  if not ARABIC.search(chosen) or len(chosen)<8:continue
  if n not in found or len(norm(chosen))>len(norm(found[n])):found[n]=chosen
 if not found:raise RuntimeError(f"No HTML verses extracted book={book} chapter={chapter}")
 return found,marker,url
def render(report):
 lines=["# Word versus HTML full comparison","","Text comparison removes Arabic diacritics and punctuation and normalizes whitespace. A match does not independently prove edition identity or publication permission.","","| Book | Chapters | Word groups | Exact matches | Mismatches | HTML missing | Word missing | 1877 marker |","|---|---:|---:|---:|---:|---:|---:|---:|"]
 for bid,b in report["books"].items():
  c=list(b["chapters"].values());sm=lambda k:sum(x[k] for x in c)
  lines.append(f"| {bid} | {len(c)} | {b['candidate_groups']} | {sm('exact_matches')} | {sm('text_mismatches')} | {sm('html_verses_missing')} | {sm('word_verses_missing')} | {sm('translation_1877_marker')} |")
 lines+=["","## Differences"]
 for bid,b in report["books"].items():
  for ch,d in b["chapters"].items():
   if d["issues"]:
    lines+=["",f"### {bid} {ch}",d["source_url"]]
    lines += ["- "+json.dumps(i,ensure_ascii=False) for i in d["issues"]]
 lines+=["","## Totals",json.dumps(report["totals"],ensure_ascii=False,indent=2),""]
 return "\n".join(lines)
def main():
 ap=argparse.ArgumentParser();ap.add_argument("--candidate-dir",type=Path,required=True);ap.add_argument("--output-dir",type=Path,required=True);ap.add_argument("--delay",type=float,default=.35);args=ap.parse_args()
 args.output_dir.mkdir(parents=True,exist_ok=True);report={"method":"one HTML request per chapter; normalized exact text comparison","books":{},"totals":defaultdict(int)}
 for name,(book,bid,chapters) in BOOKS.items():
  p=args.candidate_dir/f"{bid.lower()}-word-research-candidate.jsonl"
  rows=[json.loads(x) for x in p.read_text(encoding="utf-8").splitlines() if x.strip()];grouped=defaultdict(list)
  for row in rows:grouped[row["chapter"]].append(row)
  br={"chapters":{},"candidate_groups":len(rows)}
  for ci,ch in enumerate(chapters):
   html,marker,url=extract_html(ch,book);hn={n:norm(t) for n,t in html.items()}
   cr=sorted(grouped.get(ch,[]),key=lambda r:r["verse_start"]);comp=match=mis=hm=0;issues=[];wn=set()
   for r in cr:
    lo,hi=r["verse_start"],r["verse_end"];nums=list(range(lo,hi+1));wn.update(nums)
    missing=[n for n in nums if n not in hn]
    if missing:hm+=len(missing);issues.append({"range":[lo,hi],"type":"html_verse_missing","verses":missing});continue
    comp+=1;actual=norm(" ".join(html[n] for n in nums));expected=norm(r["text"])
    if actual==expected:match+=1
    else:
     mis+=1;issues.append({"range":[lo,hi],"type":"text_mismatch","word":r["text"][:240],"html":" ".join(html[n] for n in nums)[:240]})
   excluded_html={1,2,3} if bid=="EST-ADD" and ch==10 else set()
   absent=sorted(set(html)-wn-excluded_html)
   if absent:issues.append({"type":"word_verse_missing","verses":absent})
   br["chapters"][str(ch)]={"word_groups":len(cr),"html_verses":len(html),"compared_groups":comp,"exact_matches":match,"text_mismatches":mis,"html_verses_missing":hm,"word_verses_missing":len(absent),"translation_1877_marker":marker,"source_url":url,"issues":issues}
   for k,v in [("chapters_checked",1),("groups_compared",comp),("exact_matches",match),("text_mismatches",mis),("html_verses_missing",hm),("word_verses_missing",len(absent)),("chapters_with_1877_marker",int(marker))]:report["totals"][k]+=v
   print(f"{bid} {ch}: exact={match}/{comp}, mismatch={mis}, missing_html={hm}, missing_word={len(absent)}, marker={marker}",flush=True)
   if ci+1<len(chapters):time.sleep(max(0,args.delay))
  report["books"][bid]=br;time.sleep(max(0,args.delay))
 report["totals"]=dict(report["totals"])
 (args.output_dir/"word-html-crosscheck.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
 (args.output_dir/"word-html-crosscheck.md").write_text(render(report),encoding="utf-8")
 for bid,b in report["books"].items():
  for ch,d in b["chapters"].items():
   for issue in d["issues"]:
    if issue.get("type")=="text_mismatch":
     print("DIFF",bid,ch,issue.get("range"),"WORD=",json.dumps(issue.get("word",""),ensure_ascii=False),"HTML=",json.dumps(issue.get("html",""),ensure_ascii=False),flush=True)
    else:
     print("ISSUE",bid,ch,json.dumps(issue,ensure_ascii=False),flush=True)
 print("TOTALS",json.dumps(report["totals"],ensure_ascii=False))
if __name__=="__main__":main()
