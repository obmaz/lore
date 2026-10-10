"""Character references, source-backed identity and explicit writing proposals."""
import copy
import json
import jsonschema

from materials import ROOT, load_materials, read, validate_evidence

CHARACTERS = ROOT / "characters/registry.json"
SCHEMA = ROOT / "characters/character.schema.json"


def validate_registry(document, catalog=None):
    jsonschema.Draft202012Validator(read(SCHEMA)).validate(document)
    if catalog is None:
        catalog = load_materials()[0]
    literals = {l["id"]: l for unit in catalog["source_units"] for l in unit["literals"]}
    profiles = document["characters"]
    for key, profile in profiles.items():
        name = profile["canonical_name"]
        validate_evidence(name["evidence"], catalog)
        if name["origin"] != "authored" and not name["evidence"]:
            raise ValueError(f"source name needs evidence: {key}")
        if name["origin"] == "source_exact":
            if not name["literal_ids"] or any(i not in literals or literals[i]["text"] != name["value"] for i in name["literal_ids"]):
                raise ValueError(f"source character name changed: {key}")
            for literal_id in name["literal_ids"]:
                location = literals[literal_id]["source"]
                if not any(e["file"] == location["file"] and e["line_start"] <= location["line"] <= e["line_end"] for e in name["evidence"]):
                    raise ValueError(f"name outside cited evidence: {key}")
        elif name["literal_ids"]:
            raise ValueError(f"non-exact name cannot claim exact literals: {key}")
        claims = profile["source_facts"] + profile["writing"]["traits"] + profile["writing"]["speech"] + profile["writing"]["goals"]
        for fact in profile["source_facts"]:
            if fact["origin"] != "source_adaptation" or fact["status"] != "confirmed":
                raise ValueError(f"source facts cannot contain writing proposals: {key}")
        for claim in claims + profile["relationships"]:
            validate_evidence(claim["evidence"], catalog)
            if claim["origin"] == "source_adaptation" and not claim["evidence"]:
                raise ValueError(f"source character claim needs evidence: {key}")
        for relationship in profile["relationships"]:
            if relationship["target"] not in profiles:
                raise ValueError(f"unknown relationship target: {key}")
        if profile["writing"]["status"] == "approved" and any(c["status"] == "proposed" for c in claims + profile["relationships"]):
            raise ValueError(f"approved profile has unresolved proposals: {key}")
    return document


def load_characters(catalog=None):
    return validate_registry(read(CHARACTERS), catalog)


if __name__ == "__main__":
    profiles = load_characters()
    print(json.dumps({"characters": len(profiles["characters"]), "revision": profiles["revision"]}))
