"""Fail-closed projections: author-only truth stays outside ordinary writing packets."""
import copy
from materials import ROOT, read
from reference import validate_claim

RELATION_ANALYSIS = ROOT / "characters/relationships.analysis.json"


def compile_disclosure(profiles, analysis, claim, ranges, metadata):
    """Compile reviewed analysis; policies and hints are editorial additions, not canon."""
    policy_meta = metadata("interpretation", "새로 추가한 집필 공개 정책. 원작의 사건 ID나 새 스토리 사실이 아니다.")
    checkpoints = {}
    for key, record in analysis["checkpoints"].items():
        checkpoints[key] = claim("editing_checkpoint", {"quest_id":record["quest"], "milestone_id":record["milestone"]},
                                 ranges(record["ranges"]), origin="inferred")
        checkpoints[key]["metadata"]["note"] = "원문 위치에 대응시킨 집필 공개 체크포인트. ID와 공개 경계는 편집자가 추가한 해석이다."
    for key, profile in profiles.items():
        config = analysis["profiles"].get(key, {})
        profile["disclosure"] = {"master_visibility":"author_only", "default":"sealed",
            "public_id":config.get("public_id",key),
            "public_display_name":config.get("public_name",profile["korean_name"]["value"] or profile["display_name"]),
            "after_events":config.get("after",[]), "fact_after":config.get("fact_after",{}),
            "policy_metadata":copy.deepcopy(policy_meta)}
        profile["relationships"] = []
    for row in analysis["relationships"]:
        if row["from"] not in profiles or row["to"] not in profiles:
            raise ValueError(f"unknown relationship target: {row['id']}")
        truth = row["truth"]
        origin = row.get("origin",truth if truth in ("inferred","authored") else "source_adaptation")
        proof = ranges(row["ranges"])
        base = claim("relationship",row["description"],proof,origin)
        relation = {k:v for k,v in base.items() if k not in ("field","value")}
        relation.update(id=row["id"], target=row["to"], description=row["description"],
                        relation_type=row["type"], truth_type=truth, claimant=row.get("claimant"),
                        branch_condition=row.get("condition","경로 참조 정보이며 현재 동료/소지품/지식을 자동 확정하지 않는다."),
                        disclosure={"spoiler":row["spoiler"],"after_events":row["after"],
                            "policy_metadata":copy.deepcopy(policy_meta), "foreshadowing":[
                                {"after_events":h["after"],"claim":claim("foreshadowing",h["text"],ranges(h["ranges"]),"inferred")}
                                for h in row.get("hints",[])]})
        profiles[row["from"]]["relationships"].append(relation)
        if "reverse_type" in row:
            reverse = copy.deepcopy(relation)
            reverse.update(id=row["id"]+":reverse",target=row["from"],relation_type=row["reverse_type"])
            profiles[row["to"]]["relationships"].append(reverse)
    return checkpoints


def validate_disclosure(document, catalog):
    checkpoints = document["disclosure_checkpoints"]
    quests = {q["id"]:q for q in read(ROOT/"materials/quests.json")["quests"]}
    for checkpoint in checkpoints.values():
        validate_claim(checkpoint,catalog)
        value = checkpoint["value"]
        if not isinstance(value,dict) or set(value)!={"quest_id","milestone_id"} or value["quest_id"] not in quests:
            raise ValueError("invalid disclosure checkpoint quest")
        milestone = value["milestone_id"]
        if milestone is not None and milestone not in {m["id"] for m in quests[value["quest_id"]].get("milestones",[])}:
            raise ValueError("invalid disclosure checkpoint milestone")
    profiles = document["characters"]
    public_ids = [p["disclosure"]["public_id"] for p in profiles.values()]
    if len(set(public_ids)) != len(public_ids) or any(not i for i in public_ids):
        raise ValueError("duplicate/empty public character ID")
    if any(p["disclosure"]["public_id"] in profiles and p["disclosure"]["public_id"] != key for key,p in profiles.items()):
        raise ValueError("public character ID collides with private character ID")

    def gates(values):
        if not set(values) <= set(checkpoints):
            raise ValueError("unknown disclosure checkpoint")

    def policy(meta):
        if not meta["addition"] or meta["kind"] != "interpretation" or not meta["note"]:
            raise ValueError("disclosure policy must be marked editorial")

    ids = set()
    for p in profiles.values():
        d = p["disclosure"]
        gates(d["after_events"])
        policy(d["policy_metadata"])
        fields = {f["field"] for f in p["source_facts"]}
        for field, after in d["fact_after"].items():
            if field not in fields:
                raise ValueError(f"disclosure rule for unknown source field: {field}")
            gates(after)
        for r in p["relationships"]:
            if r["id"] in ids:
                raise ValueError("duplicate relationship ID")
            ids.add(r["id"])
            if r["claimant"] is not None and r["claimant"] not in profiles:
                raise ValueError("unknown relationship claimant")
            if r["truth_type"]=="testimony" and r["claimant"] is None:
                raise ValueError("relationship testimony needs claimant")
            if r["truth_type"] in ("inferred","authored") and r["origin"]!=r["truth_type"]:
                raise ValueError("inferred relationship cannot be source fact")
            release = r["disclosure"]
            gates(release["after_events"])
            policy(release["policy_metadata"])
            for hint in release["foreshadowing"]:
                gates(hint["after_events"])
                validate_claim(hint["claim"],catalog)
                if not hint["claim"]["metadata"]["addition"] or hint["claim"]["status"]!="proposed":
                    raise ValueError("foreshadowing must be a marked writing proposal")


def validate_reveals(document, reveals):
    if not set(reveals) <= set(document["disclosure_checkpoints"]):
        raise ValueError("unknown disclosure checkpoint")


def unlocked(after, reveals):
    # Empty is NOT public; future/unreviewed information remains sealed.
    return bool(after) and bool(set(after) & set(reveals))


def public_ids(document, reveals):
    validate_reveals(document,reveals)
    return {key:key if unlocked(p["disclosure"]["after_events"],reveals) else p["disclosure"]["public_id"]
            for key,p in document["characters"].items()}


def project_character(document, key, reveals=()):
    validate_reveals(document,reveals)
    p = document["characters"][key]
    d = p["disclosure"]
    open_ = unlocked(d["after_events"],reveals)
    ids = public_ids(document,reveals)
    identity_public = open_ or (p["korean_name"]["value"] is not None and d["public_display_name"]==p["korean_name"]["value"])
    result = {"revision":p["revision"], "view":"disclosed_writing_card", "display_name":p["display_name"] if open_ else d["public_display_name"],
              "original_name":p["canonical_name"]["value"] if identity_public else None,
              "korean_name":p["korean_name"]["value"] if identity_public else None,
              "identity_metadata":copy.deepcopy(d["policy_metadata"]),
              "biography":copy.deepcopy(p["biography"]) if open_ else {},
              "source_facts":[copy.deepcopy(f) for f in p["source_facts"] if unlocked(d["fact_after"].get(f["field"],[]),reveals)],
              "writing":{field:copy.deepcopy(p["writing"][field]) if open_ else [] for field in ("traits","speech","goals")},
              "resource_refs":copy.deepcopy(p["resource_refs"]) if open_ else {"equipment":[],"abilities":[],"enemy_templates":[]},
              "relationships":[], "foreshadowing":[],
              "source_excerpts":[], "master_visibility":"author_only", "hidden_information_policy":"do_not_assert_or_guess"}
    # Never forward whole notes, aliases, raw excerpts or the secret disclosure rules.
    for relation in p["relationships"]:
        release = relation["disclosure"]
        if unlocked(release["after_events"],reveals):
            r = {k:copy.deepcopy(v) for k,v in relation.items() if k != "disclosure"}
            r["target"] = ids[r["target"]]
            if r["claimant"] is not None:
                r["claimant"] = ids[r["claimant"]]
            result["relationships"].append(r)
        else:
            # No target, relation ID/type, secret answer, or reveal deadline in a hint.
            result["foreshadowing"].extend(copy.deepcopy(h["claim"]) for h in release["foreshadowing"]
                                          if unlocked(h["after_events"],reveals))
    return result


def remap_ids(value, mapping):
    if isinstance(value,dict):
        return {mapping.get(k,k):remap_ids(v,mapping) for k,v in value.items()}
    if isinstance(value,list):
        return [remap_ids(v,mapping) for v in value]
    if isinstance(value,str):
        for original, public in mapping.items():
            if original != public:
                value = value.replace(original,public)
        return value
    return value
