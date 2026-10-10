"""Read the self-contained research snapshot; never access the original game."""
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


if __name__ == "__main__":
    _, manifest = load_materials()
    print(json.dumps(manifest["counts"], ensure_ascii=False))
