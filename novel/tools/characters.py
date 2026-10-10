"""Character references, source-backed identity and explicit writing proposals."""
import argparse
import json

from materials import ROOT, load_materials, read, validate_evidence
from reference import schema_validator, validate_claim, load_references
from disclosure import validate_disclosure, project_character, public_ids

CHARACTERS = ROOT / "characters/registry.json"
SCHEMA = ROOT / "characters/character.schema.json"


def validate_registry(document, catalog=None, references=None):
    schema_validator(SCHEMA).validate(document)
    if catalog is None:
        catalog = load_materials()[0]
    literals = {l["id"]: l for unit in catalog["source_units"] for l in unit["literals"]}
    profiles = document["characters"]
    validate_disclosure(document,catalog)
    if references is None:
        references = load_references(catalog)
    for key, profile in profiles.items():
        name = profile["canonical_name"]
        validate_evidence(name["evidence"], catalog)
        validate_claim(name, catalog)
        validate_claim(profile["korean_name"], catalog)
        if name["origin"].startswith("source_") and not name["evidence"]:
            raise ValueError(f"source name needs evidence: {key}")
        if name["origin"] == "source_exact":
            binary = [e for e in name["evidence"] if "record_index" in e]
            records = read(ROOT / "materials/enemy_templates.json")["records"] if binary else []
            exact_binary = any(records[e["record_index"]-1]["name"] == name["value"] for e in binary)
            if (not name["literal_ids"] and not exact_binary) or any(i not in literals or literals[i]["text"] != name["value"] for i in name["literal_ids"]):
                raise ValueError(f"source character name changed: {key}")
            for literal_id in name["literal_ids"]:
                location = literals[literal_id]["source"]
                if not any("line_start" in e and e["file"] == location["file"] and e["line_start"] <= location["line"] <= e["line_end"] for e in name["evidence"]):
                    raise ValueError(f"name outside cited evidence: {key}")
        elif name["literal_ids"]:
            raise ValueError(f"non-exact name cannot claim exact literals: {key}")
        claims = profile["source_facts"] + list(profile["biography"].values()) + profile["writing"]["traits"] + profile["writing"]["speech"] + profile["writing"]["goals"]
        for fact in profile["source_facts"]:
            if fact["origin"] not in ("source_exact", "source_adaptation") or fact["status"] != "confirmed":
                raise ValueError(f"source facts cannot contain writing proposals: {key}")
        for claim in claims + profile["relationships"]:
            validate_claim(claim, catalog)
        for category, ids in profile["resource_refs"].items():
            category = "bestiary" if category == "enemy_templates" else category
            if any(i not in references[category]["items"] for i in ids):
                raise ValueError(f"unknown character resource: {key}")
        for excerpt in profile["source_excerpts"]:
            if excerpt["literal_id"] not in literals or literals[excerpt["literal_id"]]["text"] != excerpt["text"]:
                raise ValueError(f"source excerpt changed: {key}")
        for relationship in profile["relationships"]:
            if relationship["target"] not in profiles:
                raise ValueError(f"unknown relationship target: {key}")
        if profile["writing"]["status"] == "approved" and any(c["status"] == "proposed" for c in claims + profile["relationships"]):
            raise ValueError(f"approved profile has unresolved proposals: {key}")
    for category, reference_document in references.items():
        slot = "enemy_templates" if category == "bestiary" else category
        for key, item in reference_document["items"].items():
            expected = {k for k, p in profiles.items() if key in p["resource_refs"][slot]}
            if set(item["character_ids"]) != expected:
                raise ValueError(f"reference/character links differ: {key}")
    return document


def load_characters(catalog=None):
    return validate_registry(read(CHARACTERS), catalog)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Author-only master validation or spoiler-filtered cards")
    parser.add_argument("--view", choices=("summary","writer"),default="summary")
    parser.add_argument("--character")
    parser.add_argument("--events",nargs="*",default=[])
    args = parser.parse_args()
    profiles = load_characters()
    if args.view=="writer":
        if args.character is None:
            parser.error("writer view requires --character; do not export an undisclosed future roster")
        ids = public_ids(profiles,args.events)
        keys = [args.character]
        print(json.dumps({ids[k]:project_character(profiles,k,args.events) for k in keys},ensure_ascii=False,indent=2))
    else:
        print(json.dumps({"characters": len(profiles["characters"]), "revision": profiles["revision"]}))
