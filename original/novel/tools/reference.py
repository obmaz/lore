"""Validate author references and addition labels without reading game files."""
import json
import jsonschema
from referencing import Registry, Resource
from materials import ROOT, load_materials, read, validate_evidence

COMMON = ROOT / "reference/metadata.schema.json"
CATEGORIES = ("equipment", "abilities", "bestiary")


def schema_validator(path):
    common = read(COMMON)
    registry = Registry().with_resource(common["$id"], Resource.from_contents(common))
    return jsonschema.Draft202012Validator(read(path), registry=registry)


def validate_claim(claim, catalog=None):
    origin, meta = claim["origin"], claim["metadata"]
    validate_evidence(claim["evidence"], catalog)
    if origin.startswith("source_"):
        if not claim["evidence"] or meta["addition"] or meta["kind"] != "none":
            raise ValueError("source claim needs evidence and cannot be an addition")
    elif origin == "unknown":
        if claim["value"] is not None or claim.get("status", "unknown") != "unknown" or meta["kind"] != "unknown" or meta["addition"]:
            raise ValueError("unknown must remain null and unknown")
    else:
        kind = "interpretation" if origin == "inferred" else "new_setting"
        if not meta["addition"] or meta["kind"] not in (kind, "transliteration") or not meta["note"].strip():
            raise ValueError("added content needs explicit addition metadata")
        if meta["kind"] != "transliteration" and claim.get("status", "proposed") != "proposed":
            raise ValueError("interpretation/new setting must remain proposed")
        if meta["kind"] == "transliteration" and claim.get("field") != "korean_name":
            raise ValueError("transliteration is only for Korean name labels")
        if origin == "inferred" and (not claim["evidence"] or meta["kind"] != "interpretation"):
            raise ValueError("interpretation needs evidence")


def validate_catalog(document, catalog=None):
    schema_validator(ROOT / "reference/catalog.schema.json").validate(document)
    if catalog is None:
        catalog = load_materials()[0]
    for item in document["items"].values():
        for claim in [item["original_name"], item["korean_name"], *item["claims"]]:
            validate_claim(claim, catalog)
            if claim["field"] == "original_combat_parameters":
                records = read(ROOT / "materials/enemy_templates.json")["records"]
                binary = [e for e in claim["evidence"] if "record_index" in e]
                if len(binary) != 1 or claim["value"] != records[binary[0]["record_index"]-1]["fields"]:
                    raise ValueError("original enemy parameters changed")
        original = item["original_name"]
        if original["origin"] == "source_exact":
            value = original["value"]
            for evidence in original["evidence"]:
                if "record_index" in evidence:
                    records = read(ROOT / "materials/enemy_templates.json")["records"]
                    if records[evidence["record_index"]-1]["name"] != value:
                        raise ValueError("enemy template name changed")
                else:
                    unit = next(u for u in catalog["source_units"] if u["file"] == evidence["file"])
                    text = "\n".join(unit["original_source"].splitlines()[evidence["line_start"]-1:evidence["line_end"]])
                    if value not in text:
                        raise ValueError("original reference name absent from evidence")
    return document


def load_references(catalog=None):
    return {category: validate_catalog(read(ROOT / f"reference/{category}.json"), catalog)
            for category in CATEGORIES}


if __name__ == "__main__":
    print(json.dumps({key: len(value["items"]) for key, value in load_references().items()}))
