#!/usr/bin/env python3
"""Build offline word-study datasets for Rehla from licensed source corpora."""
import argparse
import gzip
import json
import re
import subprocess
import unicodedata
from pathlib import Path
import xml.etree.ElementTree as ET

LXX_REPO = "https://github.com/OpenScriptorium/lxx-morph.git"
LXX_COMMIT = "c91f6b1e8fb3ba37df701e6ae31f675ace71a2b2"
OSHB_REPO = "https://github.com/openscriptures/morphhb.git"
OSHB_COMMIT = "db6c5c9b46b8f39346f10915ddb1a70dcd429901"

OSIS_TO_CODE = {
    "Gen":"GEN","Exod":"EXO","Lev":"LEV","Num":"NUM","Deut":"DEU",
    "Josh":"JOS","Judg":"JDG","Ruth":"RUT","1Sam":"1SA","2Sam":"2SA",
    "1Kgs":"1KI","2Kgs":"2KI","1Chr":"1CH","2Chr":"2CH","Ezra":"EZR",
    "Neh":"NEH","Esth":"EST","Job":"JOB","Ps":"PSA","Prov":"PRO",
    "Eccl":"ECC","Song":"SNG","Isa":"ISA","Jer":"JER","Lam":"LAM",
    "Ezek":"EZK","Dan":"DAN","Hos":"HOS","Joel":"JOL","Amos":"AMO",
    "Obad":"OBA","Jonah":"JON","Mic":"MIC","Nah":"NAM","Hab":"HAB",
    "Zeph":"ZEP","Hag":"HAG","Zech":"ZEC","Mal":"MAL"
}

def run(*args):
    subprocess.run(args, check=True)

def clone_at(url, commit, dest):
    run("git", "clone", "--filter=blob:none", "--no-checkout", url, str(dest))
    run("git", "-C", str(dest), "fetch", "--depth", "1", "origin", commit)
    run("git", "-C", str(dest), "checkout", "--detach", commit)
    return run("git", "-C", str(dest), "rev-parse", "HEAD")

def write_gzip_jsonl(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", mtime=0, compresslevel=9) as gz:
            for row in rows:
                gz.write((json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8"))

def norm_greek(value):
    value = unicodedata.normalize("NFD", str(value or "").lower())
    value = "".join(ch for ch in value if unicodedata.category(ch) != "Mn")
    return re.sub(r"[^\w\u0370-\u03ff\u1f00-\u1fff]", "", value)

def build_greek_lemma_index(repo_root, output_dir):
    index = {}
    for path in sorted((repo_root / "bible" / "data").glob("greek-strongs-*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        for strongs, entry in data.items():
            raw = str(entry.get("lemma") or "")
            candidates = [x.strip() for x in raw.split(",") if x.strip()]
            for lemma in candidates:
                key = norm_greek(lemma)
                if not key:
                    continue
                item = {
                    "strongs": strongs,
                    "lemma": lemma,
                    "transliteration": entry.get("transliteration", ""),
                    "gloss": entry.get("gloss", ""),
                    "definition": entry.get("definition", "")
                }
                old = index.get(key)
                if old is None or (not old.get("gloss") and item.get("gloss")):
                    index[key] = item
    path = output_dir / "greek-lemma-index.json.gz"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", mtime=0, compresslevel=9) as gz:
            gz.write(json.dumps(index, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
    return {"path": "./data/word-study/greek-lemma-index.json.gz", "entries": len(index), "bytes": path.stat().st_size}

def build_lxx(source_root, output_dir):
    source_dir = source_root / "db" / "seeds" / "lxx_morph"
    out_dir = output_dir / "lxx"
    manifest = {}
    totals = {"books": 0, "verses": 0, "words": 0}
    excluded = (".auto.", ".worklist.", ".resolved.", ".residue.", "_null", ".review.")
    for path in sorted(source_dir.glob("*.json")):
        if any(token in path.name for token in excluded):
            continue
        slug = path.stem
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            raise ValueError(f"LXX book is not an array: {path.name}")
        rows = []
        for verse in data:
            ref = str(verse.get("ref") or verse.get("reference") or "")
            match = re.search(r"(\d+)[.:](\d+[a-z]?)$", ref, re.I)
            if not match:
                raise ValueError(f"Cannot parse LXX verse reference {ref!r} in {path.name}")
            chapter = int(match.group(1))
            verse_label = match.group(2)
            verse_number = int(re.match(r"\d+", verse_label).group(0))
            words = []
            for word in verse.get("words", []):
                surface = str(word.get("surface") or "").strip()
                if not surface:
                    continue
                words.append({
                    "surface": surface,
                    "lemma": word.get("lemma"),
                    "parsing": word.get("parsing"),
                    "pos": word.get("pos"),
                    "confidence": word.get("confidence"),
                    "source": word.get("source"),
                    "reasoning": word.get("reasoning"),
                    "strongs": None
                })
            if not words:
                continue
            rows.append({
                "chapter": chapter,
                "verse": verse_number,
                "verse_label": verse_label,
                "reference": ref,
                "words": words
            })
            totals["verses"] += 1
            totals["words"] += len(words)
        if not rows:
            raise ValueError(f"No word records parsed from {path.name}")
        target = out_dir / f"{slug}.jsonl.gz"
        write_gzip_jsonl(target, rows)
        manifest[slug] = {
            "path": f"./data/word-study/lxx/{slug}.jsonl.gz",
            "verses": len(rows),
            "words": sum(len(x["words"]) for x in rows),
            "bytes": target.stat().st_size
        }
        totals["books"] += 1
    if totals["books"] < 50:
        raise ValueError(f"Unexpected LXX coverage: only {totals['books']} books")
    return manifest, totals

def local_name(tag):
    return tag.rsplit("}", 1)[-1]

def visible_words(verse):
    result = []
    def walk(node):
        for child in list(node):
            name = local_name(child.tag)
            if name in ("note", "rdg"):
                continue
            if name == "w":
                result.append(child)
            else:
                walk(child)
    walk(verse)
    return result

def strongs_from_oshb_lemma(lemma):
    raw = str(lemma or "").split("/")[-1].strip()
    match = re.search(r"(\d+)", raw)
    return "H" + match.group(1) if match else None

def build_wlc(source_root, output_dir):
    source_dir = source_root / "wlc"
    out_dir = output_dir / "wlc"
    manifest = {}
    totals = {"books": 0, "verses": 0, "words": 0}
    for path in sorted(source_dir.glob("*.xml")):
        if path.name == "VerseMap.xml":
            continue
        osis = path.stem
        code = OSIS_TO_CODE.get(osis)
        if not code:
            continue
        rows = []
        for _, element in ET.iterparse(path, events=("end",)):
            if local_name(element.tag) != "verse":
                continue
            osis_id = element.attrib.get("osisID", "")
            parts = osis_id.split(".")
            if len(parts) < 3:
                element.clear()
                continue
            try:
                chapter, verse_number = int(parts[-2]), int(parts[-1])
            except ValueError:
                element.clear()
                continue
            words = []
            for node in visible_words(element):
                surface = "".join(node.itertext()).strip()
                if not surface:
                    continue
                lemma = node.attrib.get("lemma", "")
                morph = node.attrib.get("morph", "")
                words.append({
                    "surface": surface,
                    "lemma": lemma,
                    "strongs": strongs_from_oshb_lemma(lemma),
                    "parsing": morph,
                    "pos": None,
                    "confidence": "source-reviewed",
                    "source": "Open Scriptures Hebrew Bible (OSHB) 2.2"
                })
            if words:
                rows.append({"chapter": chapter, "verse": verse_number, "verse_label": str(verse_number), "reference": osis_id, "words": words})
                totals["verses"] += 1
                totals["words"] += len(words)
            element.clear()
        if not rows:
            raise ValueError(f"No WLC word records parsed from {path.name}")
        target = out_dir / f"{code}.jsonl.gz"
        write_gzip_jsonl(target, rows)
        manifest[code] = {
            "path": f"./data/word-study/wlc/{code}.jsonl.gz",
            "verses": len(rows),
            "words": sum(len(x["words"]) for x in rows),
            "bytes": target.stat().st_size
        }
        totals["books"] += 1
    if totals["books"] != 39:
        raise ValueError(f"Expected 39 WLC books, found {totals['books']}")
    return manifest, totals

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", default="bible/data/word-study")
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--work-dir", default="/tmp/rehla-word-study-sources")
    args = parser.parse_args()
    repo_root = Path(args.repo_root).resolve()
    output_dir = Path(args.output_dir).resolve()
    work_dir = Path(args.work_dir).resolve()
    work_dir.mkdir(parents=True, exist_ok=True)
    lxx_root = clone_at(LXX_REPO, LXX_COMMIT, work_dir / "lxx-morph")
    oshb_root = clone_at(OSHB_REPO, OSHB_COMMIT, work_dir / "morphhb")
    lxx_manifest, lxx_totals = build_lxx(work_dir / "lxx-morph", output_dir)
    wlc_manifest, wlc_totals = build_wlc(work_dir / "morphhb", output_dir)
    greek_index = build_greek_lemma_index(repo_root, output_dir)
    manifest = {
        "version": 1,
        "generated_at": "reproducible-build",
        "sources": {
            "lxx": {"repository": LXX_REPO, "commit": LXX_COMMIT, "license": "CC BY 4.0 for morphology; Rahlfs 1935 text is Public Domain"},
            "wlc": {"repository": OSHB_REPO, "commit": OSHB_COMMIT, "license": "CC BY 4.0 for lemma and morphology; WLC text is Public Domain"},
            "greek_lexicon": {"source": "Existing Rehla STEPBible TBESG local chunks", "license": "CC BY 4.0"}
        },
        "lxx": lxx_manifest,
        "wlc": wlc_manifest,
        "greek_lemma_index": greek_index,
        "totals": {"lxx": lxx_totals, "wlc": wlc_totals}
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest["totals"], ensure_ascii=False, indent=2))
    print("Greek lemma index:", greek_index)

if __name__ == "__main__":
    main()
