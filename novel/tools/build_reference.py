#!/usr/bin/env python3
"""Deterministically build authoring JSON from the independent snapshot and analysis.

Only generated JSON is written. A baseline hash check protects direct manual edits.
First migration preserves the v1 registry inside analysis.json; later builds use it.
"""
import copy
import hashlib
import json
import re
from materials import ROOT, load_materials, read
from disclosure import RELATION_ANALYSIS, compile_disclosure

ANALYSIS = ROOT / "reference/analysis.json"
BASELINE = ROOT / "reference/generated_manifest.json"
REGISTRY = ROOT / "characters/registry.json"


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def metadata(kind="none", note="원작 근거의 요약/값. 등장인물의 지식과 별개이다."):
    return {"addition": kind not in ("none", "unknown"), "kind": kind, "note": note,
            "knowledge_policy": "author_reference_not_character_knowledge"}


def evidence(file, start, end=None):
    return {"file": file, "line_start": start, "line_end": end or start}


def claim(field, value, citations=(), origin="source_adaptation", kind=None):
    if value is None:
        origin, kind = "unknown", "unknown"
    kind = kind or {"inferred": "interpretation", "authored": "new_setting"}.get(origin, "none")
    if kind == "unknown":
        note = "원작에서 확인되지 않아 미상으로 남긴다. 수치로 추정하지 않는다."
    elif kind == "transliteration":
        note = "집필용 한국어 음역을 새로 정했다. 원작 명칭은 original/canonical_name에 보존한다."
    elif kind == "interpretation":
        note = "대사/행동을 바탕으로 한 집필 해석. 원작의 확정 성격이나 설정이 아니며 검토 후 수정한다."
    elif kind == "new_setting":
        note = "집필자가 제안한 원작에 없는 설정. 확정하지 않은 후보이다."
    else:
        note = "원작 근거의 요약/값. 등장인물의 지식과 별개이다."
    return {"field": field, "value": value, "origin": origin,
            "status": "unknown" if origin == "unknown" else "proposed" if kind in ("new_setting", "interpretation") else "confirmed",
            "evidence": list(citations), "metadata": metadata(kind, note)}


def ranges(rows):
    return [evidence(f, a, b) for f, a, b in rows]


def migrate_claim(value):
    result = copy.deepcopy(value)
    if result["origin"] == "source_adaptation" and result["status"] == "proposed":
        result["origin"] = "inferred"
    kind = {"authored": "new_setting", "inferred": "interpretation"}.get(result["origin"], "none")
    result["metadata"] = metadata(kind, "기존 집필 제안/원작 요약의 출처 구분을 보존한다.")
    return result


def build(analysis, catalog, templates):
    names = read(ROOT / "reference/names.json")
    from reference import schema_validator
    schema_validator(ROOT/'reference/names.schema.json').validate(names)
    units = {u["file"]: u for u in catalog["source_units"]}
    all_literals = [literal for u in catalog["source_units"] for literal in u["literals"]]
    phonetics = dict(analysis["phonetics"])
    phonetics.update({r["name"]: k for r, k in zip(templates["records"], analysis["enemy_phonetics"])})
    if len(analysis["enemy_phonetics"]) != len(templates["records"]):
        raise ValueError("enemy phonetics count differs")
    profiles = copy.deepcopy(analysis["preserved_profiles"]["characters"])
    specs = dict(analysis["enrichment"])
    for spec in analysis["new_characters"]:
        key = spec["id"]
        citations = ranges(spec["ranges"])
        name_literals = [l for l in all_literals if spec["name"] is not None and l["text"] == spec["name"] and any(
            e["file"] == l["source"]["file"] and e["line_start"] <= l["source"]["line"] <= e["line_end"] for e in citations)]
        binary = [{"file": "FOEDATA.DAT", "record_index": i} for i in spec.get("templates", [])
                  if templates["records"][i-1]["name"] == spec["name"]]
        profiles[key] = {
            "revision": 1, "kind": spec["kind"],
            "canonical_name": {"value": spec["name"], "origin": "source_exact" if name_literals or binary else "source_adaptation",
                               "literal_ids": [l["id"] for l in name_literals], "evidence": citations + binary},
            "display_name": spec.get("display_name") or phonetics[spec["name"]] + (" (사칭자)" if key == "false_necromancer" else ""),
            "aliases": [], "source_facts": [],
            "writing": {"status": "outline", "traits": [], "speech": [], "goals": [],
                        "boundaries": [], "notes": "원작의 전편 참조 카드. 실제 합류/생사/지식은 선택 경로에서 관리한다."},
            "relationships": []}
        specs[key] = dict(spec, extra_ranges=spec["ranges"])
    for key, profile in profiles.items():
        spec = specs.get(key, {})
        if key in analysis["preserved_profiles"]["characters"]:
            profile["revision"] += 1
        name = profile["canonical_name"]
        if spec.get("name_ranges"):
            name["evidence"] = ranges(spec["name_ranges"])
        if name["value"] is None:
            name["origin"] = "unknown"
        name["metadata"] = metadata("unknown" if name["origin"] == "unknown" else "none")
        profile["korean_name"] = claim("korean_name", phonetics.get(name["value"]), origin="authored", kind="transliteration")
        profile["display_name_metadata"] = metadata("interpretation", "편집용 역할/구별 표기. 원작의 고유 이름 또는 새 인물 설정으로 쓰지 않는다.")
        if key in names['characters']:
            profile['writing_name'] = copy.deepcopy(names['characters'][key])
            profile['display_name'] = profile['writing_name']['value']
            profile['display_name_metadata'] = copy.deepcopy(profile['writing_name']['metadata'])
            if key == 'protagonist':
                profile['writing']['notes'] = '집필 이름은 임시 지정이다. 성별·직업·최종 성향은 미정이다.'
        citations = list(name["evidence"])
        for fact in profile["source_facts"]:
            citations.extend(fact["evidence"])
        citations += ranges(spec.get("extra_ranges", []))
        for source_claim in spec.get("source_claims", []):
            citations += ranges(source_claim["ranges"])
        citations = list({json.dumps(e, sort_keys=True): e for e in citations}.values())
        for field in ("source_facts", "relationships"):
            profile[field] = [migrate_claim(c) for c in profile[field]]
        for field in ("traits", "speech", "goals"):
            profile["writing"][field] = [migrate_claim(c) for c in profile["writing"][field]]
        if spec.get("source_role"):
            profile["source_facts"].append(claim("story_role", spec["source_role"], citations))
        for source_claim in spec.get("source_claims", []):
            profile["source_facts"].append(claim(source_claim["field"],source_claim["value"],ranges(source_claim["ranges"])))
        biography = {field: claim(field, None) for field in ("age", "gender", "species", "occupation", "appearance", "alignment")}
        for fact in profile["source_facts"]:
            target = {"class": "occupation", "gender": "gender"}.get(fact["field"])
            if target:
                biography[target] = dict(copy.deepcopy(fact), field=target)
        for field in ("gender", "species", "occupation", "appearance"):
            if field in spec:
                biography[field] = claim(field, spec[field], citations)
        biography.update(copy.deepcopy(spec.get("biography_overrides", {})))
        profile["biography"] = biography
        for field, value in (("traits", spec.get("trait")), ("speech", spec.get("speech"))):
            if value:
                profile["writing"][field].append(claim("temperament" if field == "traits" else "voice", value, citations, "inferred"))
            elif not profile["writing"][field]:
                profile["writing"][field].append(claim("temperament" if field == "traits" else "voice", None))
        if spec.get("goal"):
            profile["writing"]["goals"].append(claim("motivation",spec["goal"],citations,"inferred"))
        for field, additions in spec.get("writing_additions", {}).items():
            if field not in ("traits", "speech", "goals"):
                raise ValueError("writing_additions must use claim arrays")
            profile["writing"][field].extend(copy.deepcopy(additions))
        if spec.get("relationships_additions"):
            raise ValueError("move relationships_additions to characters/relationships.analysis.json with explicit disclosure policy")
        profile["writing"]["boundaries"] += ["나이는 원작에서 확인되지 않았다. 레벨이나 사망 수치를 나이로 사용하지 않는다.",
            "카드의 대사 근거에는 주변 인물/서술자의 말도 포함된다. 자기 대사로 바꾸거나 경로 지식에 자동 추가하지 않는다."]
        profile["resource_refs"] = {"equipment": spec.get("equipment", []),
                                    "abilities": [f"magic_{i}" for i in spec.get("abilities", [])],
                                    "enemy_templates": [f"enemy_{i:02d}" for i in spec.get("templates", [])]}
        if any(profile["resource_refs"].values()):
            profile["source_facts"].append(claim("reference_usage", "장비는 해당 영입/전투 시점의 자료, 마법은 설명/전수된 기법, 적 데이터는 기반 템플릿의 참조다. 현재 소지/습득/수치 확정을 뜻하지 않는다.", citations))
        profile["source_excerpts"] = [{"literal_id": l["id"], "text": l["text"]} for l in all_literals
            if l["text"] and l["role"] == "display_text_fragment" and any("line_start" in e and e["file"] == l["source"]["file"] and
            e["line_start"] <= l["source"]["line"] <= e["line_end"] for e in citations)]
    checkpoints = compile_disclosure(profiles,read(RELATION_ANALYSIS),claim,ranges,metadata)
    registry = {"version": 3, "revision": analysis["preserved_profiles"]["revision"]+1, "characters": profiles,
                "disclosure_checkpoints":checkpoints}
    references = {category: {"version": 1, "revision": analysis["revision"], "category": category, "items": {}}
                  for category in ("equipment", "abilities", "bestiary")}

    def item(category, key, name, ko, kind, citations, claims, exact=True):
        references[category]["items"][key] = {"revision": analysis["revision"], "category": kind,
            "original_name": claim("original_name", name, citations, "source_exact" if exact else "source_adaptation"),
            "korean_name": claim("korean_name", ko, citations, "source_exact" if exact else "source_adaptation") if name == ko
                           else claim("korean_name", ko, origin="authored", kind="transliteration"),
            "claims": claims, "character_ids": [k for k, p in profiles.items() if key in p["resource_refs"][
                "enemy_templates" if category == "bestiary" else category]]}
        if key in names[category]:
            references[category]['items'][key]['writing_name'] = copy.deepcopy(names[category][key])

    for record in templates["records"]:
        e = [{"file": "FOEDATA.DAT", "record_index": record["id"]}]
        item("bestiary", f"enemy_{record['id']:02d}", record["name"], phonetics[record["name"]], "enemy_template", e,
             [claim("original_combat_parameters", record["fields"], e, "source_exact"),
              claim("mechanical_scope", "기본 적 템플릿. 전투 스크립트의 이름/수치 변경이나 동료 변환을 적용하기 전 값이며 개인의 나이/성격이 아니다.", templates["layout_evidence"])])
    sub = units["LORESUB.PAS"]["original_source"].splitlines()
    powers = [None,5,7,9,10,15,20,30,40,50]
    prices = [None,500,1500,3000,5000,10000,30000,60000,80000,100000]
    for line, text in enumerate(sub, 1):
        match = re.search(r"(\d+)\s*:\s*ReturnWeapon\s*:=\s*'([^']+)'", text)
        if match:
            number, name = int(match[1]), match[2]
            e = [evidence("LORESUB.PAS",line)]
            cs = [claim("game_index",number,e,"source_exact")]
            if number:
                cs += [claim("shop_price_gold",prices[number],[evidence("LORESUB.PAS",1208,1231)]),
                       claim("base_weapon_power",powers[number],[evidence("LORESUB.PAS",1246,1260)]),
                       claim("class_rules","무기상 구매 시 전투승은 사용 대상에서 제외. 기사는 기본 위력에 반올림한 50%를 가산.",[evidence("LORESUB.PAS",1241,1260)])]
            else:
                cs.append(claim("base_weapon_power",None))
            cs.append(claim("elemental_effect",None))
            item("equipment",f"weapon_{number}",name,name,"weapon",e,cs)
        match = re.search(r"([1-5])\s*:\s*ReturnDefense\s*:=\s*'([^']+)'", text)
        if match:
            number, material = int(match[1]), match[2]
            for slot, label, prices_ in (("shield","방패",[1000,5000,25000,80000,100000]),
                                         ("armor","갑옷",[5000,25000,80000,100000,200000])):
                e = [evidence("LORESUB.PAS",line), evidence("LORESUB.PAS",1273,1318)]
                cs = [claim("game_index",number,e),claim("shop_price_gold",prices_[number-1],e),
                      claim("base_defense_power",number+(slot=="armor"),e)]
                if number == 5:
                    source_ranges = [evidence("LORESPEC.PAS",858,877),evidence("LORESPEC.PAS",905,924)] if slot=="shield" else [evidence("LORESPEC.PAS",925,943)]
                    cs.append(claim("script_display_name",f"황금의 {label}",source_ranges,"source_exact"))
                    cs.append(claim("treasure_scope","발견 시 장착자를 선택하며 해당 장비 ID/기본 방어력을 설정한다. 상점의 금제 장비와 다른 마법 효과를 임의로 추가하지 않는다.",source_ranges))
                item("equipment",f"{slot}_{number}",f"{material} {label}",f"{material} {label}",slot,e,cs,exact=False)
        match = re.search(r"(\d+)\s*:\s*ReturnMagic\s*:=\s*'([^']+)'", text)
        if not match:
            continue
        number, name = int(match[1]), match[2]
        e = [evidence("LORESUB.PAS",line)]
        cs = [claim("game_index",number,e,"source_exact")]
        if number <= 12:
            category = "direct_attack"
            cs += [claim("effect","직접 공격 피해. 이름별 자연현상/차원 서사는 별도 확정하지 않음.",[evidence("LOREBATT.PAS",172,234)]),
                   claim("conditions","단일 대상 처리에서 SP=round(마법 레벨 × 주문 번호² / 2) 소모. 명중 실패, 적 저항, 방어로 피해가 막힐 수 있음. 전체 대상은 별도 반복 처리.",[evidence("LOREBATT.PAS",195,244)])]
        elif number <= 18:
            category = "indirect_attack"
            cs += [claim("effect",analysis["indirect_effects"][number-13],[evidence("LORESPEC.PAS",1091,1103)]),
                   claim("conditions","레드 안타레스의 전수 진행과 사용자의 능력이 필요. 전투의 SP 소비/명중/적 저항 검사를 따르며 자동 성공이 아님.",[evidence("LORESPEC.PAS",1086,1104),evidence("LOREBATT.PAS",246,360)])]
        elif number <= 32:
            category = "healing"
            cs += [claim("effect",name,[evidence("LORESUB.PAS",748,761)]),
                   claim("conditions","회복 메뉴에서 사용자의 마법 레벨로 선택 가능한 단계가 제한된다. 대상 수, SP, 독/의식불능/사망 상태별 처리와 부활 비용 검사를 확인한다. 무제한 부활을 뜻하지 않음.",[evidence("LOREMENU.PAS",43,230)])]
        elif number <= 40:
            category = "phenomena"
            spec = analysis["phenomena"][number-33]
            e2 = [evidence("LOREMENU.PAS",*spec["range"])]
            cs += [claim("effect",spec["effect"],e2),claim("sp_cost",spec["cost"],e2),
                   claim("conditions","필드 메뉴의 단계별 선택 제한과 SP 부족 검사를 따른다. 이동/지형 마법에는 위치/경계/지형 제한 및 배척이 있음.",[evidence("LOREMENU.PAS",232,498)])]
        else:
            category = "extrasense"
            cs += [claim("effect",analysis["extrasense_effects"][number-41],[evidence("LORESPEC.PAS",1285,1293)]),
                   claim("conditions","ESP와 초자연력 레벨/상태/위치 검사에 따름. 필드와 전투 처리도 구분한다. 독심으로 모든 동료를 자동 영입하지 않음.",[evidence("LOREMENU.PAS",700,867),evidence("LORESPEC.PAS",1208,1268)] if number !=45 else [evidence("LOREBATT.PAS",360,526)])]
        item("abilities",f"magic_{number}",name,name,category,e,cs)
    targets = {'characters':profiles,**{c:d['items'] for c,d in references.items()}}
    for category in targets:
        if not set(names[category]) <= set(targets[category]):
            raise ValueError(f'unknown naming override: {category}')
    return {"characters/registry.json": registry, **{f"reference/{k}.json": v for k,v in references.items()}}


def main():
    analysis = read(ANALYSIS)
    if BASELINE.exists():
        for relative, expected in read(BASELINE)["artifacts"].items():
            path = ROOT / relative
            if not path.is_file() or digest(path.read_bytes()) != expected:
                raise ValueError(f"manual edits detected; refusing overwrite: {relative}")
    if "preserved_profiles" not in analysis:
        original = read(REGISTRY)
        if original["version"] != 1:
            raise ValueError("first migration requires the preserved v1 registry")
        analysis["preserved_profiles"] = original
    outputs = build(analysis, load_materials()[0], read(ROOT / "materials/enemy_templates.json"))
    if BASELINE.exists():
        for relative, document in outputs.items():
            previous = read(ROOT / relative)
            if relative == "characters/registry.json":
                for key, profile in document["characters"].items():
                    old = previous["characters"].get(key)
                    if old:
                        profile["revision"] = old["revision"]
                        if profile != old:
                            profile["revision"] += 1
            else:
                for key, item_ in document["items"].items():
                    old = previous["items"].get(key)
                    if old:
                        item_["revision"] = old["revision"]
                        if item_ != old:
                            item_["revision"] += 1
            document["revision"] = previous["revision"]
            if document != previous:
                document["revision"] += 1
    # Validate every output before any write (no partial invalid rebuild).
    from reference import validate_catalog
    for relative, document in outputs.items():
        if relative.startswith("reference/"):
            validate_catalog(document)
    from characters import validate_registry
    validate_registry(outputs["characters/registry.json"], references={k:outputs[f"reference/{k}.json"]
                      for k in ("equipment","abilities","bestiary")})
    ANALYSIS.write_bytes(encoded(analysis))
    for relative, document in outputs.items():
        (ROOT / relative).write_bytes(encoded(document))
    BASELINE.write_bytes(encoded({"version":1,"artifacts":{p:digest(encoded(d)) for p,d in outputs.items()}}))
    print(json.dumps({"characters":len(outputs["characters/registry.json"]["characters"]),
                      **{k:len(outputs[f"reference/{k}.json"]["items"]) for k in ("equipment","abilities","bestiary")}}))


if __name__ == "__main__":
    main()
