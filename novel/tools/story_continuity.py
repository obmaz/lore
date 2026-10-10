#!/usr/bin/env python3
"""Read-only continuity validation and context packets for an explicit story path."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

import jsonschema
from referencing import Registry, Resource

from validate_story_authoring import ROOT, SCHEMA, validate as validate_story
from materials import load_materials, validate_evidence
from characters import CHARACTERS, load_characters, validate_registry
from reference import load_references

CONTINUITY_SCHEMA = ROOT / "continuity/continuity.schema.json"
CANON = ROOT / "continuity/canon.json"
DEFAULT = ROOT / "authoring/drafts/prologue.json"


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(",", ":")).encode()).hexdigest()


def input_hashes(story, continuity, canon, profiles=None):
    if profiles is None:
        profiles = load_characters()
    return {"story": fingerprint(story), "canon": fingerprint(canon),
            "continuity": fingerprint({k: v for k, v in continuity.items() if k != "review"}),
            "characters": fingerprint(profiles), "materials": fingerprint(load_materials()[1]),
            "references": fingerprint(load_references())}


def check(value, message):
    if not value:
        raise ValueError(message)


def matches(condition, state):
    if isinstance(condition, bool):
        return condition
    if "all" in condition:
        return all(matches(c, state) for c in condition["all"])
    if "any" in condition:
        return any(matches(c, state) for c in condition["any"])
    if "not" in condition:
        return not matches(condition["not"], state)
    key, op, value = condition["state"], condition["op"], condition["value"]
    check(key in state, f"unknown condition state: {key}")
    current = state[key]
    if op == "eq": return current == value
    if op == "ne": return current != value
    if op == "gte": return current >= value
    if op == "lte": return current <= value
    if op == "contains": return value in current
    if op == "not_contains": return value not in current
    raise ValueError(f"unknown predicate: {op}")


def apply(effects, state):
    for effect in effects:
        key, op, value = effect["state"], effect["op"], effect["value"]
        if op == "set": state[key] = copy.deepcopy(value)
        elif op == "increment": state[key] += value
        elif op == "add" and value not in state[key]: state[key].append(value)
        elif op == "remove" and value in state[key]: state[key].remove(value)


def validate(story, continuity, canon, profiles=None):
    validate_story(story)
    if profiles is None:
        profiles = load_characters()
    else:
        validate_registry(profiles)
    schema = read(CONTINUITY_SCHEMA)
    registry = Registry().with_resources([
        (CONTINUITY_SCHEMA.as_uri(), Resource.from_contents(schema)),
        (SCHEMA.as_uri(), Resource.from_contents(read(SCHEMA)))])
    jsonschema.Draft202012Validator({"$ref": CONTINUITY_SCHEMA.as_uri()}, registry=registry).validate(continuity)
    jsonschema.Draft202012Validator({"$ref": CONTINUITY_SCHEMA.as_uri() + "#/$defs/canon"}, registry=registry).validate(canon)
    check(continuity["story_id"] == story["meta"]["id"], "continuity belongs to another story")
    check(continuity["story_revision"] == story["meta"]["revision"], "story revision changed: review continuity")
    characters = profiles["characters"]
    facts = {fact["id"]: fact for fact in canon["facts"]}
    check(len(facts) == len(canon["facts"]), "duplicate canon fact")
    for fact in facts.values():
        check(set(fact["initial_knowers"]) <= set(characters), "unknown initial knower")
        check(fact["attributed_to"] is None or fact["attributed_to"] in characters, "unknown attributed character")
        if fact["kind"] in ("testimony", "belief"):
            check(fact["attributed_to"] is not None, "testimony/belief must name its owner")
        if fact["status"] == "confirmed":
            check(bool(fact["evidence"]), "confirmed fact needs evidence")
        validate_evidence(fact["evidence"])
    nodes = {node["id"]: node for node in story["nodes"]}
    choices = {choice["id"]: choice for node in nodes.values() for choice in node["choices"]}
    check(set(continuity["contracts"]) == set(nodes), "every node needs a continuity contract")
    stale = []
    if continuity["canon_revision"] != canon["revision"]:
        stale.append("canon revision changed: review continuity manifest")
    if continuity["character_registry_revision"] != profiles["revision"]:
        stale.append("character registry changed: review continuity manifest")
    for key, contract in continuity["contracts"].items():
        check(set(contract["allowed_state_changes"]) <= set(story["state_definitions"]), "unknown allowed state")
        for condition in (contract["before"], contract["after"]):
            matches(condition, {name: definition["initial"] for name, definition in story["state_definitions"].items()})
        for member in contract["cast"]:
            check(member["character_id"] in characters, "unknown cast character")
            matches(member["when"], {name: definition["initial"] for name, definition in story["state_definitions"].items()})
        blocks = {b["id"] for b in nodes[key]["blocks"] if b["kind"] != "author_note"}
        check(set(contract["must_include_block_ids"]) <= blocks, "required block missing or only an author note")
        check(set(contract["must_not_assert"]) <= set(facts), "unknown forbidden fact")
        for dep in contract["dependencies"]:
            check(dep["fact_id"] in facts, "unknown fact dependency")
            if dep["revision"] != facts[dep["fact_id"]]["revision"]:
                stale.append(f"{key}: fact {dep['fact_id']} changed")
        profile_deps = {dep["character_id"]: dep for dep in contract["character_dependencies"]}
        check({member["character_id"] for member in contract["cast"]} <= set(profile_deps), "cast needs character dependencies")
        for dep in profile_deps.values():
            check(dep["character_id"] in characters, "unknown character dependency")
            if dep["revision"] != characters[dep["character_id"]]["revision"]:
                stale.append(f"{key}: character {dep['character_id']} changed")
        for item in contract["knowledge_required"]:
            check(item["character_id"] in characters and item["fact_id"] in facts, "unknown required knowledge")
        for choice in nodes[key]["choices"]:
            check({e["state"] for e in choice["effects"]} <= set(contract["allowed_state_changes"]),
                  f"undeclared state mutation: {key}/{choice['id']}")
    events = {event["id"]: event for event in continuity["event_templates"]}
    check(len(events) == len(continuity["event_templates"]), "duplicate event template")
    for event in events.values():
        check(event["trigger_choice"] in choices, "unknown event trigger")
        check(set(event["participants"]) <= set(characters), "unknown event participant")
        check(set(event["requires_events"]) <= set(events) and event["id"] not in event["requires_events"], "unknown or self-dependent event")
        check(set(event["source_refs"]) <= set(story["source_refs"]), "unknown event evidence")
        if event["origin"] == "source_adaptation": check(bool(event["source_refs"]), "adapted event needs evidence")
        for gain in event["knowledge_gained"]:
            check(gain["character_id"] in event["participants"] and gain["fact_id"] in facts, "unknown knowledge recipient/fact")
            check(gain["informant_id"] is None or gain["informant_id"] in event["participants"], "informant not present")
            if gain["method"] == "heard": check(gain["informant_id"] is not None, "heard knowledge needs informant")
    for thread in continuity["threads"]:
        check(thread["resolution_event"] is None or thread["resolution_event"] in events, "unknown thread resolution")
        check(thread["status"] != "resolved" or thread["resolution_event"] is not None, "resolved thread needs an event")
    review = continuity["review"]
    if review["status"] == "approved":
        check(not stale and not review["issues"] and story["meta"]["status"] == "approved"
              and review["approved_story_revision"] == story["meta"]["revision"]
              and review["approved_canon_revision"] == canon["revision"], "approval is stale or incomplete")
        check(all(e["approval"] == "approved" for e in events.values()), "approved continuity contains proposed events")
        check(review["approved_input_hashes"] == input_hashes(story, continuity, canon, profiles), "approved input content changed")
    return stale


def context(story, continuity, canon, route, profiles=None):
    if profiles is None:
        profiles = load_characters()
    stale = validate(story, continuity, canon, profiles)
    nodes = {node["id"]: node for node in story["nodes"]}
    facts = {fact["id"]: fact for fact in canon["facts"]}
    state = {key: copy.deepcopy(value["initial"]) for key, value in story["state_definitions"].items()}
    known = {character: {fact["id"] for fact in facts.values() if character in fact["initial_knowers"]}
             for character in profiles["characters"]}
    ledger, history, key = [], [], story["entry_node"]
    for choice_id in route:
        node, contract = nodes[key], continuity["contracts"][key]
        check(matches(node["entry_when"], state) and matches(contract["before"], state), f"blocked node: {key}")
        check(all(k["fact_id"] in known[k["character_id"]] for k in contract["knowledge_required"]), f"character lacks knowledge: {key}")
        visible = [b for b in node["blocks"] if b["kind"] != "author_note" and matches(b["when"], state)]
        cast = {m["character_id"] for m in contract["cast"] if matches(m["when"], state)}
        check({b["speaker"] for b in visible if b["speaker"]} <= cast, f"speaker absent from cast: {key}")
        check(set(contract["must_include_block_ids"]) <= {b["id"] for b in visible}, f"required block hidden: {key}")
        choice = next((c for c in node["choices"] if c["id"] == choice_id), None)
        check(choice is not None and matches(choice["when"], state), f"choice unavailable at {key}: {choice_id}")
        before = copy.deepcopy(state)
        apply(choice["effects"], state)
        check(matches(contract["after"], state), f"postcondition failed: {key}")
        history.append({"node_id": key, "choice_id": choice_id, "visible_block_ids": [b["id"] for b in visible], "before": before, "after": copy.deepcopy(state)})
        for event in continuity["event_templates"]:
            if event["trigger_choice"] != choice_id: continue
            check(set(event["requires_events"]) <= {e["id"] for e in ledger}, f"event happened before its prerequisite: {event['id']}")
            check(event["id"] not in {e["id"] for e in ledger}, f"event repeated without explicit repeat model: {event['id']}")
            ledger.append(copy.deepcopy(event))
            for gain in event["knowledge_gained"]: known[gain["character_id"]].add(gain["fact_id"])
        key = choice["target"]
    node, contract = nodes[key], continuity["contracts"][key]
    check(matches(node["entry_when"], state) and matches(contract["before"], state), f"blocked destination: {key}")
    check(all(k["fact_id"] in known[k["character_id"]] for k in contract["knowledge_required"]), f"character lacks knowledge: {key}")
    visible = [b for b in node["blocks"] if b["kind"] != "author_note" and matches(b["when"], state)]
    cast = {m["character_id"] for m in contract["cast"] if matches(m["when"], state)}
    check({b["speaker"] for b in visible if b["speaker"]} <= cast, f"speaker absent from cast: {key}")
    check(set(contract["must_include_block_ids"]) <= {b["id"] for b in visible}, f"required block hidden: {key}")
    choices = [c["id"] for c in node["choices"] if matches(c["when"], state)]
    check(bool(choices) or node["kind"] in ("boundary", "ending"), f"all choices hidden: {key}")
    approved = continuity["review"]["status"] == "approved" and not stale
    dependencies = {d["fact_id"] for d in contract["dependencies"]} | set(contract["must_not_assert"])
    dependencies |= {f for values in known.values() for f in values}
    handoff = None
    if node["handoff"]:
        handoff = {**node["handoff"],
                   "state": {k: copy.deepcopy(state[k]) for k in node["handoff"]["carry_states"]},
                   "knowledge": {k: sorted(v) for k, v in known.items()},
                   "events": copy.deepcopy(ledger), "provisional": not approved}
    references = load_references()
    resources = {category: {} for category in references}
    for member in cast:
        for category, ids in profiles["characters"][member]["resource_refs"].items():
            category = "bestiary" if category == "enemy_templates" else category
            resources[category].update({i: references[category]["items"][i] for i in ids})
    return {"mode": "approved_path" if approved else "draft_preview", "node_id": key,
            "input_fingerprints": input_hashes(story, continuity, canon, profiles),
            "needs_review": stale, "editorial_issues": continuity["review"]["issues"],
            "state": state, "history": history, "handoff_packet": handoff,
            "committed_events": ledger if approved else [], "proposed_events": [] if approved else ledger,
            "knowledge": {k: sorted(v) for k, v in known.items()}, "knowledge_is_provisional": not approved,
            "relevant_facts": [facts[f] for f in sorted(dependencies)], "contract": contract,
            "character_profiles": {member: profiles["characters"][member] for member in sorted(cast)},
            "writing_references": resources,
            "reference_policy": "author_reference_not_character_knowledge_or_current_inventory",
            "open_threads": [t for t in continuity["threads"] if t["resolution_event"] not in {e["id"] for e in ledger}],
            "visible_blocks": visible, "available_choices": choices,
            "validation_limits": ["explicit route only", "prose meaning and character motivation require editorial review"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--story", type=Path, default=DEFAULT)
    parser.add_argument("--route", nargs="*", default=[])
    args = parser.parse_args()
    continuity_path = args.story.with_name(args.story.stem + ".continuity.json")
    print(json.dumps(context(read(args.story), read(continuity_path), read(CANON), args.route), ensure_ascii=False, indent=2))


if __name__ == "__main__": main()
