"""Read the self-contained research snapshot; never access the original game."""
import argparse
import hashlib
import json
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "materials/scripts.json"
MANIFEST = ROOT / "materials/manifest.json"


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


@lru_cache(maxsize=1)
def load_materials():
    manifest = read(MANIFEST)
    for relative, expected in manifest["artifacts"].items():
        path = (ROOT / "materials" / relative).resolve()
        if not path.is_relative_to((ROOT / "materials").resolve()):
            raise ValueError(f"material path escapes package: {relative}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError(f"material snapshot changed: {relative}")
    catalog = read(CATALOG)
    counts = {"source_files": len(catalog["source_units"]),
              "literal_occurrences": sum(len(unit["literals"]) for unit in catalog["source_units"])}
    if counts != manifest["counts"]:
        raise ValueError("material manifest counts differ from catalog")
    return catalog, manifest


def validate_evidence(evidence, catalog=None):
    if catalog is None:
        catalog = load_materials()[0]
    units = {unit["file"]: unit for unit in catalog["source_units"]}
    for item in evidence:
        if "record_index" in item:
            records = read(ROOT / "materials/enemy_templates.json")["records"]
            if item["file"] != "FOEDATA.DAT" or item["record_index"] not in {r["id"] for r in records}:
                raise ValueError("invalid packaged enemy evidence")
            continue
        unit = units.get(item["file"])
        if not unit:
            raise ValueError(f"unknown packaged source: {item['file']}")
        if not 1 <= item["line_start"] <= item["line_end"] <= len(unit["original_source"].splitlines()):
            raise ValueError("invalid packaged evidence range")


def source_document(file, start_line=None, end_line=None):
    catalog, _ = load_materials()
    index = next((i for i,u in enumerate(catalog['source_units']) if u['file']==file),None)
    if index is None: raise ValueError(f'unknown internal source file: {file}')
    unit = catalog['source_units'][index]
    lines = unit['original_source'].splitlines(keepends=True)
    first, last = 1 if start_line is None else start_line, end_line if end_line is not None else len(lines)
    if not 1 <= first <= last <= len(lines): raise ValueError('source line range is out of bounds')
    return {'file':file,'source_ref':{'file':'materials/scripts.json','pointer':f'/source_units/{index}/original_source'},
            'line_start':first,'line_end':last,'original_source':''.join(lines[first-1:last]),
            'original_file_sha256':unit['sha256'],'external_file_required':False}


def quest_document(quest_id):
    load_materials()
    index = read(ROOT/'materials/quests.json')
    quest = next((q for q in index['quests'] if q['id']==quest_id),None)
    if quest is None: raise ValueError(f'unknown internal quest: {quest_id}')
    path = (ROOT/'materials'/quest['file']).resolve()
    if not path.is_relative_to((ROOT/'materials').resolve()): raise ValueError('quest path escapes package')
    return {'source_ref':{'file':path.relative_to(ROOT).as_posix(),'pointer':''},
            'external_file_required':False,'quest':read(path)}


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',nargs='?',choices=['summary','source','quest'],default='summary')
    parser.add_argument('--file')
    parser.add_argument('--start-line',type=int)
    parser.add_argument('--end-line',type=int)
    parser.add_argument('--quest-id')
    args=parser.parse_args()
    if args.action=='source': result=source_document(args.file,args.start_line,args.end_line)
    elif args.action=='quest': result=quest_document(args.quest_id)
    else: result=load_materials()[1]['counts']
    print(json.dumps(result,ensure_ascii=False,indent=2))
