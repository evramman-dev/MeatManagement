#!/usr/bin/env python3
"""Convert candidate Bible source exports into auditable, edition-separated JSONL."""
from __future__ import annotations
import argparse, collections, csv, json, pathlib, re, zipfile, xml.etree.ElementTree as ET

BOOKS = {
'GEN':'gen','EXO':'exo','LEV':'lev','NUM':'num','DEU':'deu','JOS':'jos','JDG':'jdg','RUT':'rut',
'1SA':'1sa','2SA':'2sa','1KI':'1ki','2KI':'2ki','1CH':'1ch','2CH':'2ch','EZR':'ezr','NEH':'neh',
'EST':'est','JOB':'job','PSA':'psa','PRO':'pro','ECC':'ecc','SNG':'sng','ISA':'isa','JER':'jer','LAM':'lam',
'EZK':'ezk','DAN':'dan','HOS':'hos','JOL':'jol','AMO':'amo','OBA':'oba','JON':'jon','MIC':'mic','NAM':'nam',
'HAB':'hab','ZEP':'zep','HAG':'hag','ZEC':'zec','MAL':'mal','MAT':'mat','MRK':'mrk','LUK':'luk','JHN':'jhn',
'ACT':'act','ROM':'rom','1CO':'1co','2CO':'2co','GAL':'gal','EPH':'eph','PHP':'php','COL':'col',
'1TH':'1th','2TH':'2th','1TI':'1ti','2TI':'2ti','TIT':'tit','PHM':'phm','HEB':'heb','JAS':'jas',
'1PE':'1pe','2PE':'2pe','1JN':'1jn','2JN':'2jn','3JN':'3jn','JUD':'jud','REV':'rev','TOB':'tob','JDT':'jdt','WIS':'wis','SIR':'sir','BAR':'bar',
'1MA':'1ma','2MA':'2ma','3MA':'3ma','4MA':'4ma','1ES':'1es','2ES':'2es','DAG':'dan_additions',
'ESG':'est_additions','MAN':'pr_manasseh','PS2':'psalm_151',
}
CSV_BOOKS = {
'genesis':'gen','exodus':'exo','leviticus':'lev','numbers':'num','deuteronomy':'deu','joshua':'jos','judges':'jdg','ruth':'rut',
'1-samuel':'1sa','2-samuel':'2sa','1-kings':'1ki','2-kings':'2ki','1-chronicles':'1ch','2-chronicles':'2ch',
'ezra':'ezr','nehemiah':'neh','esther':'est','job':'job','psalms':'psa','proverbs':'pro','ecclesiastes':'ecc',
'song-of-solomon':'sng','isaiah':'isa','jeremiah':'jer','lamentations':'lam','ezekiel':'ezk','daniel':'dan','hosea':'hos',
'joel':'jol','amos':'amo','obadiah':'oba','jonah':'jon','micah':'mic','nahum':'nam','habakkuk':'hab','zephaniah':'zep',
'haggai':'hag','zechariah':'zec','malachi':'mal','matthew':'mat','mark':'mrk','luke':'luk','john':'jhn','acts':'act',
'romans':'rom','1-corinthians':'1co','2-corinthians':'2co','galatians':'gal','ephesians':'eph','philippians':'php',
'colossians':'col','1-thessalonians':'1th','2-thessalonians':'2th','1-timothy':'1ti','2-timothy':'2ti','titus':'tit',
'philemon':'phm','hebrews':'heb','james':'jas','1-peter':'1pe','2-peter':'2pe','1-john':'1jn','2-john':'2jn',
'3-john':'3jn','jude':'jud','revelation':'rev','tobit':'tob','judith':'jdt','wisdom':'wis','sirach':'sir',
'baruch':'bar','1-maccabees':'1ma','2-maccabees':'2ma','3-maccabees':'3ma','4-maccabees':'4ma',
'1-esdras':'1es','2-esdras':'2es','esther-greek':'est_additions','susanna':'dan_susanna',
'bel-and-the-dragon':'dan_bel_dragon','letter-of-jeremiah':'bar_letter_jeremiah','prayer-of-manasseh':'pr_manasseh',
'psalms-of-solomon':'ps_solomon','odes':'odes'
}
VERSE_START = re.compile(r'^\\v\s+([^\s]+)\s*(.*)$')
CHAPTER_START = re.compile(r'^\\c\s+(\d+)')

def parse_verse_label(label):
    m=re.fullmatch(r'(\d+)([a-zA-Z]?)(?:[-–](\d+)([a-zA-Z]?))?',str(label).strip())
    if not m: raise ValueError(f'Unsupported verse label: {label!r}')
    return int(m.group(1)),m.group(2) or None,int(m.group(3)) if m.group(3) else None,m.group(4) or None

def clean_usfm_inline(s):
    text=re.sub(r"\\w\s+([^|\\]+)\|[^\\]*?\\w\*",r"\1",s)
    text=re.sub(r"\\(?:f|fe|x)\s*.*?\\(?:f|fe|x)\*"," ",text,flags=re.S)
    text=re.sub(r"\\fig\s*.*?\\fig\*"," ",text,flags=re.S)
    text=re.sub(r"\\[+a-zA-Z0-9]+\*?"," ",text)
    return re.sub(r"\s+"," ",text).strip()

def usfm_records(blob,edition,source_id,filename):
    raw=blob.decode('utf-8-sig',errors='replace'); book_code=None; chapter=None; current=None; records=[]
    def flush():
        if current:
            try: start,suffix,end,end_suffix=parse_verse_label(current['verse_label'])
            except ValueError: start=suffix=end=end_suffix=None
            base={k:v for k,v in current.items() if not k.startswith('_')}
            records.append({**base,'verse_start':start,'verse_suffix':suffix,'verse_end':end,'verse_end_suffix':end_suffix,
              'text':clean_usfm_inline(' '.join(current['_parts'])),'raw_inline':current['_raw']})
    for line in raw.splitlines():
        mid=re.match(r'^\\id\s+([^\s]+)',line)
        if mid: book_code=mid.group(1).upper(); continue
        cm=CHAPTER_START.match(line)
        if cm: flush(); current=None; chapter=int(cm.group(1)); continue
        vm=VERSE_START.match(line)
        if vm:
            flush(); label=vm.group(1); content=vm.group(2)
            current={'edition_id':edition,'source_id':source_id,'source_file':filename,'source_book_code':book_code,
              'book_id':BOOKS.get(book_code),'chapter':chapter,'verse_label':label,'record_id':f'{edition}:{book_code}:{chapter}:{label}',
              '_parts':[content],'_raw':content}
        elif current and not re.match(r'^\\(?:id|c|v|p|m|q\d*|s\d*|r|d|sp|mt\d*|ms\d*|ip|im|ili\d*|b|nb|pi\d*|pc|pr)\b',line):
            current['_parts'].append(line); current['_raw']+='\n'+line
        elif current and line.startswith('\\'):
            tail=re.sub(r'^\\[+a-zA-Z0-9]+\s*','',line)
            if tail: current['_parts'].append(tail); current['_raw']+='\n'+tail
    flush()
    return records

def csv_records(path,edition,source_id,preserve_duplicates=False):
    out=[]
    with open(path,encoding='utf-8-sig',newline='') as f:
        for rownum,row in enumerate(csv.DictReader(f),start=2):
            label=row.get('label','').strip()
            m=re.fullmatch(r'(\d+):(\d+[a-zA-Z]?)(?:[-–](\d+[a-zA-Z]?))?',label)
            if not m: continue
            chapter=int(m.group(1)); verse_label=m.group(2)+(('-'+m.group(3)) if m.group(3) else '')
            try: start,suffix,end,end_suffix=parse_verse_label(verse_label)
            except ValueError: continue
            rawbook=row.get('book','').strip().lower(); bid=CSV_BOOKS.get(rawbook)
            group=f'{edition}:{rawbook}:{label}' if preserve_duplicates else None
            out.append({'edition_id':edition,'source_id':source_id,'source_file':pathlib.Path(path).name,
              'source_row':rownum,'source_book_code':rawbook,'book_id':bid,'chapter':chapter,'verse_label':verse_label,
              'verse_start':start,'verse_suffix':suffix,'verse_end':end,'verse_end_suffix':end_suffix,
              'record_id':f'{edition}:{rawbook}:{label}:{rownum}','text':row.get('body',''),'reading_group':group})
    if preserve_duplicates:
        counts=collections.Counter(r['reading_group'] for r in out); variants=collections.Counter()
        for r in out:
            variants[r['reading_group']]+=1; r['variant_index']=variants[r['reading_group']]; r['variant_count']=counts[r['reading_group']]
    return out

def sbl_records(zip_path,edition='sblgnt_v1_2'):
    out=[]
    with zipfile.ZipFile(zip_path) as z:
        for name in z.namelist():
            if not name.endswith('.xml') or '/xml/' not in name: continue
            root=ET.fromstring(z.read(name).decode('utf-8-sig')); nodes=list(root.iter()); node_index={id(node):i for i,node in enumerate(nodes)}
            for el in root.iter('verse-number'):
                m=re.match(r'(.+?)\s+(\d+):(\d+)([a-z]?)$',el.attrib.get('id',''))
                if not m: continue
                bookname,chapter,verse,suffix=m.groups(); parts=[]; idx=node_index[id(el)]
                if el.tail: parts.append(el.tail)
                for node in nodes[idx+1:]:
                    if node.tag=='verse-number': break
                    if node.text: parts.append(node.text)
                    if node.tail: parts.append(node.tail)
                text=' '.join(' '.join(parts).split()); bid=CSV_BOOKS.get(bookname.lower().replace(' ','-'))
                out.append({'edition_id':edition,'source_id':'sblgnt_official_github_xml','source_file':name,
                  'source_book_code':bookname,'book_id':bid,'chapter':int(chapter),'verse_label':verse+suffix,
                  'verse_start':int(verse),'verse_suffix':suffix or None,'verse_end':None,'verse_end_suffix':None,
                  'record_id':f'{edition}:{bookname}:{chapter}:{verse}{suffix}','text':text})
    return out

def write_jsonl(path,records):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('w',encoding='utf-8') as f:
        for row in records: f.write(json.dumps(row,ensure_ascii=False,separators=(',',':'))+'\n')

def summarize(records):
    books=collections.defaultdict(set); refs=collections.Counter(); unknown=collections.Counter(); duplicate=collections.Counter()
    for r in records:
        bid=r.get('book_id')
        if not bid: unknown[r.get('source_book_code')]+=1
        else: books[bid].add(r.get('chapter'))
        refs[(bid,r.get('chapter'))]+=1
        if r.get('reading_group'): duplicate[r['reading_group']]+=1
    return {'records':len(records),'book_count':len(books),'chapter_pairs':sum(map(len,books.values())),
      'books':{k:{'chapters':len(v),'records':sum(n for (b,_),n in refs.items() if b==k)} for k,v in sorted(books.items())},
      'unmapped_source_books':dict(sorted(unknown.items())),
      'duplicate_reading_groups':sum(1 for n in duplicate.values() if n>1),
      'extra_duplicate_records':sum(n-1 for n in duplicate.values() if n>1)}

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--input',required=True); ap.add_argument('--output',required=True); args=ap.parse_args()
    src=pathlib.Path(args.input); out=pathlib.Path(args.output); out.mkdir(parents=True,exist_ok=True)
    manifest={'schema_version':1,'stage':'candidate_corpus_not_approved_for_app_or_publication','sources':{},
      'edition_metadata':{
        'wlc_hebrew_ot':{'language':'hbo','testament':'OT','edition':'Westminster Leningrad Codex','license':'Public Domain per eBible source listing','status':'candidate','canon_scope':'Hebrew 39-book collection; not the complete Coptic Orthodox Old Testament'},
        'wlc_hebrew_ot_csv':{'language':'hbo','testament':'OT','edition':'WLC OpenScriptorium CSV','license':'Public Domain per source listing','status':'comparison_export_only','canon_scope':'Hebrew 39-book collection; not the complete Coptic Orthodox Old Testament'},
        'rahlfs_lxx_greek':{'language':'grc','testament':'OT','edition':'Rahlfs Septuagint 1935','license':'Public Domain per source listing','status':'candidate_with_unresolved_duplicate_readings','book_mapping_status':'unresolved_aliases_and_recensions; do not auto-map 1ES/2ES or duplicate readings'},
        'patriarchal_greek_nt_1904':{'language':'grc','testament':'NT','edition':'Patriarchal Greek New Testament 1904','license':'Public Domain per source listing','status':'candidate'},
        'sblgnt_v1_2':{'language':'grc','testament':'NT','edition':'SBL Greek New Testament v1.2','license':'CC BY 4.0','status':'candidate; no Greek-English diglot without separate SBL permission'},
        'coptic_sahidic_nt_candidate':{'language':'cop-sah','testament':'NT','edition':'Coptic New Testament Sahidic candidate','license':'Public Domain per eBible listing','status':'lineage_and_textual_review_required'},
        'coptic_bohairic_nt_candidate':{'language':'cop-boh','testament':'NT','edition':'Coptic New Testament Bohairic candidate','license':'Public Domain per eBible listing','status':'lineage_and_textual_review_required'},
        'webbe_english_with_deuterocanon':{'language':'en','testament':'OT+NT','edition':'World English Bible British Edition with Deuterocanon','license':'Public Domain; preserve trademark naming conditions','status':'candidate; canon mapping still required'},
        'webbe_english_csv_comparison_only':{'language':'en','testament':'OT+NT','edition':'WEBBE OpenScriptorium CSV export','license':'Public Domain per source listing','status':'comparison_only_due_to_coverage_mismatch'}
      },'limitations':['No canon equivalence or translation accuracy is asserted.','Conversion does not grant publication permission.',
      'Source verse labels are retained; no versification harmonization is performed.','USFM raw_inline is retained; display text does not fully render poetic/structural markup.',
      'CSV chapter/verse columns are ignored; label is parsed because chapter currently contains a malformed value.']}
    for zpath in src.glob('*.zip'):
        stem=zpath.stem
        edition={'ot_he_wlc_usfm':'wlc_hebrew_ot','nt_cop_sahidic_usfm':'coptic_sahidic_nt_candidate',
          'nt_cop_bohairic_usfm':'coptic_bohairic_nt_candidate','en_webbe_usfm':'webbe_english_with_deuterocanon'}.get(stem)
        if not edition: continue
        records=[]; source_files=[]
        with zipfile.ZipFile(zpath) as z:
            for name in z.namelist():
                if name.lower().endswith(('.usfm','.sfm')):
                    records.extend(usfm_records(z.read(name),edition,stem,name)); source_files.append(name)
        dest=out/edition/'verses.jsonl'; write_jsonl(dest,records)
        manifest['sources'][edition]={'file':str(dest.relative_to(out)),'source_archive':zpath.name,'source_files':len(source_files),**summarize(records)}
    for fname,edition,source,preserve in [
      ('ot_he_wlc_csv.csv','wlc_hebrew_ot_csv','openscriptorium_wlc_csv',False),
      ('ot_grc_rahlfs_csv.csv','rahlfs_lxx_greek','openscriptorium_rahlfs_lxx_csv',True),
      ('nt_grc_patriarchal_csv.csv','patriarchal_greek_nt_1904','openscriptorium_patriarchal_1904_csv',False),
      ('en_webbe_csv.csv','webbe_english_csv_comparison_only','openscriptorium_webbe_csv',False)]:
        p=src/fname
        if p.exists():
            records=csv_records(p,edition,source,preserve); dest=out/edition/'verses.jsonl'; write_jsonl(dest,records)
            manifest['sources'][edition]={'file':str(dest.relative_to(out)),**summarize(records)}
    sblzip=src/'nt_grc_sblgnt_source.zip'
    if sblzip.exists():
        records=sbl_records(sblzip); dest=out/'sblgnt_v1_2'/'verses.jsonl'; write_jsonl(dest,records)
        manifest['sources']['sblgnt_v1_2']={'file':str(dest.relative_to(out)),**summarize(records)}
    (out/'conversion-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:{'records':v['records'],'books':v['book_count'],'chapters':v['chapter_pairs'],'unmapped':len(v['unmapped_source_books'])} for k,v in manifest['sources'].items()},ensure_ascii=False,indent=2))
if __name__=='__main__': main()
