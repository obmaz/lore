#!/usr/bin/env python3
"""Validate authoring data only; never load it into the game or modify source."""
import argparse
import json
from pathlib import Path

import jsonschema
from materials import ROOT, CATALOG, load_materials

SCHEMA = ROOT / "authoring/story.schema.json"


def validate(document, catalog=None):
    schema = json.loads(SCHEMA.read_text())
    jsonschema.Draft202012Validator.check_schema(schema)
    jsonschema.Draft202012Validator(schema).validate(document)
    if catalog is None:
        catalog = load_materials()[0]
    from characters import load_characters
    profiles = load_characters(catalog=catalog)
    from reference import load_references
    from text_refs import indexes, validate_text, archival, source_ids, reject_fixed_names
    text_data = indexes(profiles,load_references(catalog),catalog)
    units = {unit["file"]: unit for unit in catalog["source_units"]}
    literals = {literal["id"]: literal for unit in units.values() for literal in unit["literals"]}
    for field in ('title','summary'):
        validate_text(document['meta'][field],text_data,literals)
        if document['meta'].get('reference_text'):
            reject_fixed_names(document['meta'][field],text_data)
    scenes = {scene["id"] for unit in units.values() for scene in unit["scenes"]}
    refs = document["source_refs"]
    states = document["state_definitions"]
    errors = []

    def require(ok, message):
        if not ok:
            errors.append(message)

    def check_refs(values):
        for ref in values:
            require(ref in refs, f"unknown source ref: {ref}")

    def provenance(value):
        check_refs(value["source_refs"])
        if value["origin"] != "authored":
            require(bool(value["source_refs"]), "source origin requires evidence")

    def typed(value, kind):
        return {"boolean": lambda: type(value) is bool,
                "integer": lambda: type(value) is int,
                "string": lambda: isinstance(value, str),
                "string_set": lambda: isinstance(value, list) and all(isinstance(v, str) for v in value)
                and len(set(value)) == len(value)}[kind]()

    def state_value(key, op, value):
        if key not in states:
            require(False, f"unknown state: {key}")
            return
        kind = states[key]["type"]
        if op in ("add", "remove", "contains", "not_contains"):
            require(kind == "string_set" and isinstance(value, str), f"set operation type mismatch: {key}")
        elif op in ("increment", "gte", "lte"):
            require(kind == "integer" and type(value) is int, f"numeric operation type mismatch: {key}")
        else:
            require(typed(value, kind), f"value type mismatch: {key}")

    def predicate(value):
        if isinstance(value, bool):
            return
        if "all" in value or "any" in value:
            for part in value.get("all", value.get("any", [])):
                predicate(part)
        elif "not" in value:
            predicate(value["not"])
        else:
            state_value(value["state"], value["op"], value["value"])

    for ref_id, ref in refs.items():
        unit = units.get(ref["file"])
        require(unit is not None, f"unknown source file: {ref_id}")
        if unit:
            require(ref["line_start"] <= ref["line_end"] <= len(unit["original_source"].splitlines()),
                    f"invalid source range: {ref_id}")
        if "scene_id" in ref:
            require(ref["scene_id"] in scenes, f"unknown source scene: {ref_id}")
    for key, state in states.items():
        require(typed(state["initial"], state["type"]), f"initial type mismatch: {key}")
        provenance(state["provenance"])

    nodes = {node["id"]: node for node in document["nodes"]}
    require(len(nodes) == len(document["nodes"]), "duplicate node id")
    require(document["entry_node"] in nodes, "entry node missing")
    used_refs, block_ids, choice_ids = set(), set(), set()

    def check_literal(literal_id, text, source_refs):
        literal = literals.get(literal_id)
        require(literal is not None, f"unknown literal: {literal_id}")
        if literal:
            require(text == literal["text"], f"source quote changed: {literal_id}")
            require(any(ref in refs and refs[ref]["file"] == literal["source"]["file"]
                        and refs[ref]["line_start"] <= literal["source"]["line"] <= refs[ref]["line_end"]
                        for ref in source_refs), f"literal outside cited evidence: {literal_id}")

    for node in nodes.values():
        validate_text(node['title'],text_data,literals)
        if document['meta'].get('reference_text'):
            reject_fixed_names(node['title'],text_data)
        provenance(node["provenance"])
        predicate(node["entry_when"])
        check_refs(node["editorial"]["source_refs"])
        require(bool(node["choices"]) or node["kind"] in ("boundary", "ending"), f"dead end: {node['id']}")
        require(not node["choices"] or node["kind"] not in ("boundary", "ending"), f"terminal has choices: {node['id']}")
        require(node["handoff"] is None or node["kind"] == "boundary", "handoff must be a boundary")
        if node["handoff"]:
            for key in node["handoff"]["carry_states"]:
                require(key in states and states[key]["scope"] == "story", f"invalid carry state: {key}")
        for block in node["blocks"]:
            require(block["speaker"] is None or block["speaker"] in profiles["characters"],
                    f"unknown character speaker: {block['speaker']}")
            require(block["id"] not in block_ids, f"duplicate block id: {block['id']}")
            block_ids.add(block["id"])
            provenance(block["provenance"])
            predicate(block["when"])
            validate_text(block['text'],text_data,literals,require_bindings=document['meta'].get('reference_text',False))
            if document['meta'].get('reference_text') and block['kind']!='source_quote':
                reject_fixed_names(block['text'],text_data)
            for literal_id in source_ids(block['text']):
                if literal_id in literals:
                    check_literal(literal_id,literals[literal_id]['text'],block['provenance']['source_refs'])
            if block["provenance"]["origin"] == "source_exact":
                rich = not isinstance(block['text'],str)
                require(block["kind"] == "source_quote" and bool(block["literal_ids"]) and (rich or len(block['literal_ids'])==1),
                        "exact quote must reference one occurrence; preserve fragments separately")
                if rich:
                    require(source_ids(block['text'])==block['literal_ids'],'source text and occurrence IDs differ')
                    require(archival(block['text'],literals)==''.join(literals[i]['text'] for i in block['literal_ids'] if i in literals),'source quote changed')
                elif len(block["literal_ids"]) == 1:
                    check_literal(block["literal_ids"][0], block["text"], block["provenance"]["source_refs"])
            else:
                require(not block["literal_ids"], "adapted/authored prose must not masquerade as exact literals")
            used_refs.update(block["provenance"]["source_refs"])
        for choice in node["choices"]:
            require(choice["id"] not in choice_ids, f"duplicate choice id: {choice['id']}")
            choice_ids.add(choice["id"])
            require(choice["target"] in nodes, f"unknown target: {choice['target']}")
            provenance(choice["provenance"])
            predicate(choice["when"])
            for field in ('label','consequence'):
                validate_text(choice[field],text_data,literals,require_bindings=document['meta'].get('reference_text',False))
                if document['meta'].get('reference_text') and choice['provenance']['origin']!='source_exact':
                    reject_fixed_names(choice[field],text_data)
            used_refs.update(choice["provenance"]["source_refs"])
            if choice["provenance"]["origin"] == "source_exact":
                require("label_literal_id" in choice, "exact choice label needs literal id")
            if "label_literal_id" in choice:
                require(choice["provenance"]["origin"] == "source_exact", "literal label must be source_exact")
                check_literal(choice["label_literal_id"], archival(choice["label"],literals), choice["provenance"]["source_refs"])
            for effect in choice["effects"]:
                provenance(effect["provenance"])
                state_value(effect["state"], effect["op"], effect["value"])
                require(effect["provenance"]["origin"] != "source_exact",
                        "story effects are abstractions, not exact Pascal operations")

    reachable, pending = set(), [document["entry_node"]]
    while pending:
        key = pending.pop()
        if key in reachable or key not in nodes:
            continue
        reachable.add(key)
        pending.extend(c["target"] for c in nodes[key]["choices"])
    require(reachable == set(nodes), "unreachable nodes in structural graph")
    terminals = {key for key, node in nodes.items() if node["kind"] in ("boundary", "ending")}
    can_finish = set(terminals)
    while True:
        expanded = can_finish | {key for key, node in nodes.items()
                                 if any(c["target"] in can_finish for c in node["choices"])}
        if expanded == can_finish:
            break
        can_finish = expanded
    require(set(nodes) <= can_finish, "some nodes have no structural route to a boundary/ending")
    coverage = document["coverage"]
    check_refs(coverage["required_source_refs"])
    deferred = [item["ref"] for item in coverage["deferred_source_refs"]]
    check_refs(deferred)
    require(not set(deferred) & set(coverage["required_source_refs"]), "required and deferred refs overlap")
    require(set(coverage["required_source_refs"]) <= used_refs, "required source refs not represented in text/choices")
    all_blocks = {b["id"]: b for n in nodes.values() for b in n["blocks"]}
    all_choices = {c["id"]: c for n in nodes.values() for c in n["choices"]}
    scoped_literals = {key for key, literal in literals.items()
                       if any(ref["file"] == literal["source"]["file"]
                              and ref["line_start"] <= literal["source"]["line"] <= ref["line_end"]
                              for ref in refs.values())}
    handled = set()
    for item in coverage["literal_dispositions"]:
        key = item["literal_id"]
        require(key in scoped_literals, f"disposition outside source scope: {key}")
        require(key not in handled, f"duplicate disposition: {key}")
        handled.add(key)
        require(set(item["block_ids"]) <= block_ids, f"unknown disposition block: {key}")
        require(set(item["choice_ids"]) <= choice_ids, f"unknown disposition choice: {key}")
        if item["handling"] in ("verbatim", "adapted", "alternate_path"):
            require(bool(item["block_ids"] or item["choice_ids"]), f"disposition needs a text/choice target: {key}")
        if item["handling"] == "verbatim":
            require(any(key in all_blocks[b]["literal_ids"] for b in item["block_ids"] if b in all_blocks)
                    or any(all_choices[c].get("label_literal_id") == key for c in item["choice_ids"] if c in all_choices),
                    f"verbatim disposition not quoted: {key}")
        if item["handling"] == "adapted":
            require(any(all_blocks[b]["provenance"]["origin"] == "source_adaptation"
                        for b in item["block_ids"] if b in all_blocks)
                    or any(all_choices[c]["provenance"]["origin"] == "source_adaptation"
                           for c in item["choice_ids"] if c in all_choices), f"adaptation target missing: {key}")
        if coverage["status"] == "complete":
            require(item["handling"] != "pending", f"complete coverage has pending literal: {key}")
    if coverage["status"] == "complete":
        require(not deferred, "complete coverage cannot defer source")
        require(scoped_literals <= handled, "complete coverage has unaccounted source literals")
    if document["meta"]["status"] == "approved":
        require(coverage["status"] == "complete" and not document["open_questions"], "approved draft has unresolved work")
    if errors:
        raise ValueError("\n".join(errors))
    return {"nodes": len(nodes), "choices": len(choice_ids), "blocks": len(block_ids),
            "coverage": coverage["status"], "unaccounted_scoped_literals": len(scoped_literals - handled),
            "condition_paths_verified": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path)
    args = parser.parse_args()
    paths = args.paths or sorted(path for path in (ROOT / "authoring/drafts").glob("*.json")
                                if not path.name.endswith(".continuity.json"))
    if not args.paths:
        paths += sorted(path for path in (ROOT/'writing/quests').glob('*.json') if not path.name.endswith('.continuity.json'))
    for path in paths:
        document = json.loads(path.read_text())
        if path.resolve().is_relative_to(ROOT/'writing') and document['meta'].get('reference_text') is not True:
            raise ValueError('new writing drafts must enable reference_text')
        print(f"{path}: {json.dumps(validate(document), ensure_ascii=False)}")


if __name__ == "__main__":
    main()
