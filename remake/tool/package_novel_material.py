#!/usr/bin/env python3
"""One-time/manual import of research JSON into the independent novel snapshot.

The novel tools never import this file or the game. Explicit reruns replace the
research snapshot; authoring drafts and existing character cards stay untouched.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def import_materials(input_dir):
    catalog = json.loads((input_dir / "scripts.json").read_text(encoding="utf-8"))
    destination = ROOT / "novel/materials"
    artifacts = {}
    files = [Path(name) for name in ("scripts.json", "progression.json", "quests.json", "coverage.json")]
    files += [Path("quests") / path.name for path in sorted((input_dir / "quests").glob("*.json"))]
    for relative in files:
        data = json.loads((input_dir / relative).read_text(encoding="utf-8"))
        write(destination / relative, data)
        artifacts[str(relative)] = hashlib.sha256((destination / relative).read_bytes()).hexdigest()
    literals = [l for unit in catalog["source_units"] for l in unit["literals"]]
    if len({l["id"] for l in literals}) != len(literals):
        raise ValueError("duplicate imported literal id")
    coverage = json.loads((destination / "coverage.json").read_text())
    if coverage["missing_literal_ids"] or coverage["unassigned_scene_ids"]:
        raise ValueError("research snapshot has missing source material")
    manifest = {"version": 1, "policy": "frozen_research_snapshot_manual_updates_only",
                "artifacts": artifacts,
                "counts": {"source_files": len(catalog["source_units"]), "literal_occurrences": len(literals)},
                "original_files": {unit["file"]: unit["sha256"] for unit in catalog["source_units"]}}
    write(destination / "manifest.json", manifest)
    return catalog, manifest


def seed_initial_candidates(catalog):
    registry_path = ROOT / "novel/characters/registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    unit = next(u for u in catalog["source_units"] if u["file"] == "LORECRET.PAS")
    roster = [l for l in unit["literals"] if l["source"]["line"] in (8, 9)]
    match = re.search(r"Character\s*:\s*array\[1\.\.10,1\.\.10\].*?=\s*\((.*?)\);", unit["original_source"], re.S)
    rows = [[int(number) for number in re.findall(r"\d+", row)] for row in re.findall(r"\(([^()]*)\)", match.group(1))]
    if len(rows) != 10 or len(roster) != 10:
        raise ValueError("initial character table changed: review importer")
    classes = {1: "기사", 2: "마법사", 4: "전사", 5: "전투승", 6: "닌자"}
    for index, (literal, values) in enumerate(zip(roster, rows), 1):
        key = "initial_" + re.sub(r"\W+", "_", literal["text"].lower())
        if key in registry["characters"]:
            continue
        evidence = [{"file": "LORECRET.PAS", "line_start": 8, "line_end": 21}]
        facts = {"candidate_index": index, "gender": "female" if values[0] == 1 else "male",
                 "class": classes[values[1]],
                 "initial_abilities": dict(zip(["strength", "mentality", "concentration", "endurance", "resistance", "agility", "accuracy", "luck"], values[2:]))}
        registry["characters"][key] = {
            "revision": 1, "kind": "initial_candidate",
            "canonical_name": {"value": literal["text"], "origin": "source_exact", "literal_ids": [literal["id"]], "evidence": evidence},
            "display_name": literal["text"], "aliases": [],
            "source_facts": [{"field": field, "value": value, "origin": "source_adaptation", "status": "confirmed", "evidence": evidence} for field, value in facts.items()],
            "writing": {"status": "outline", "traits": [], "speech": [], "goals": [], "boundaries": ["원작 능력 수치만으로 성격을 단정하지 않는다."], "notes": "시작 동료 후보. 실제 합류 여부는 경로 상태에 기록한다."},
            "relationships": []}
    write(registry_path, registry)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=ROOT / "story_material")
    parser.add_argument("--seed-initial-candidates", action="store_true")
    args = parser.parse_args()
    catalog, manifest = import_materials(args.input)
    if args.seed_initial_candidates:
        seed_initial_candidates(catalog)
    print(json.dumps(manifest["counts"], ensure_ascii=False))


if __name__ == "__main__": main()
