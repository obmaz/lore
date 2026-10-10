#!/usr/bin/env python3
"""Manual import of original FOEDATA records into the standalone novel snapshot."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    data = (ROOT / "repo_source/LORE_1993_runtime/FOEDATA.DAT").read_bytes()
    if len(data) != 75 * 29:
        raise ValueError("original enemy record layout changed")
    fields = ["strength", "mentality", "endurance", "resistance", "agility", "accuracy_arms",
              "accuracy_magic", "armor_class", "special", "cast_level", "special_cast_level", "level"]
    records = []
    for number in range(1, 76):
        record = data[(number - 1) * 29:number * 29]
        if record[0] > 16:
            raise ValueError("invalid original enemy name length")
        records.append({"id": number, "name": record[1:record[0] + 1].decode("ascii"),
                        "fields": dict(zip(fields, record[17:])), "original_record_hex": record.hex()})
    path = ROOT / "novel/materials/enemy_templates.json"
    value = {"version": 1, "original_file": "FOEDATA.DAT", "sha256": hashlib.sha256(data).hexdigest(),
             "record_size": 29, "records": records,
             "layout_evidence": [{"file": "LORESUB.PAS", "line_start": 50, "line_end": 64}],
             "notes": ["75 source templates, not ages, individual biographies or current battle states.",
                       "Story encounters can override names and statistics; those overrides stay in the Pascal snapshot."]}
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    manifest_path = ROOT / "novel/materials/manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["artifacts"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest["binary_sources"] = {"FOEDATA.DAT": {"sha256": value["sha256"], "records": 75, "record_size": 29}}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Imported 75 original enemy records into novel JSON.")


if __name__ == "__main__": main()
