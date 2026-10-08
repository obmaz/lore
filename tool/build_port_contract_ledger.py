"""Build a source-first baseline for the LORE port completion plan.

This records what exists, not what has already been behaviorally verified.
``--check`` fails when checked-in evidence drifts from the source or assets.
"""

import argparse
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

from source_branch_inventory import PLATFORM_UNITS, inventory, lex


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "repo_source/LORE_1993_src"
RUNTIME = ROOT / "repo_source/LORE_1993_runtime"
OUTPUT = ROOT / "docs/audits/contract_ledger.json"
REPORT = ROOT / "docs/audits/contract_ledger.md"
EVIDENCE = ROOT / "docs/audits/contract_evidence.json"
ROUTINE = re.compile(r"\b(procedure|function)\s+([A-Za-z_][A-Za-z_0-9]*)\b", re.I)
MAP_WRITE = re.compile(r"map\s*\[([^\]]+)\]\s*:=\s*([^;]+);", re.I)
# The first castle post-load assignment has a direct source-backed regression
# assertion in loreent_entry_effects_test.dart.
MAPPED_MAP_WRITES = {
    "LOREENT.PAS:24:map-write:16", "LOREENT.PAS:24:map-write:32",
    "LOREENT.PAS:24:map-write:48", "LOREENT.PAS:25:map-write:16",
    "LOREENT.PAS:25:map-write:32", "LOREENT.PAS:25:map-write:48",
    "LOREENT.PAS:26:map-write:16", "LOREENT.PAS:26:map-write:32",
    "LOREENT.PAS:26:map-write:48", "LOREENT.PAS:26:map-write:64",
    "LOREENT.PAS:27:map-write:37",
}
MAPPED_MAP_WRITE_GROUPS = {
    # The post-load entry effects and talk-mode write groups have source
    # replay/branch tests covering their conditions and emitted changes.
    "LOREENT.PAS:entermode:1",
    "LOREENT.PAS:sign:1",
    "LORETALK.PAS:talkmode:1",
    "LORESPEC.PAS:specialevent_part1:1",
    "LORESPEC.PAS:specialevent_part2:1",
    "LOREMENU.PAS:phenominaspell:1",
}
REGISTRY = re.compile(r"\n\s*(\d+): const MapInfo\((.*?)\n\s*\),", re.S)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def strip_pascal_comments(data):
    """Keep line breaks so evidence locations remain source locations."""
    text = data.decode("latin1")
    result = list(text)
    at = 0
    while at < len(text):
        if text[at] == "'":
            end = at + 1
            while end < len(text):
                if text[end] == "'":
                    if end + 1 < len(text) and text[end + 1] == "'":
                        end += 2
                        continue
                    end += 1
                    break
                end += 1
            for index in range(at, end):
                if result[index] != "\n":
                    result[index] = " "
            at = end
            continue
        marker = "{" if text[at] == "{" else "(*" if text.startswith("(*", at) else None
        if marker:
            close = "}" if marker == "{" else "*)"
            end = text.find(close, at + len(marker))
            if end < 0:
                raise ValueError("Unterminated Pascal comment")
            end += len(close)
            for index in range(at, end):
                if result[index] != "\n":
                    result[index] = " "
            at = end
            continue
        if text.startswith("//", at):
            end = text.find("\n", at)
            if end < 0:
                end = len(text)
            for index in range(at, end):
                result[index] = " "
            at = end
            continue
        at += 1
    return "".join(result)


def declarations(filename):
    clean = strip_pascal_comments((SOURCE / filename).read_bytes())
    lines = clean.splitlines()
    implementation = next(
        (i for i, line in enumerate(lines, 1) if line.strip().lower() == "implementation"),
        0,
    )
    result = []
    seen = Counter()
    for line_number, line in enumerate(lines, 1):
        if implementation and line_number < implementation:
            continue  # Interface signatures are not executable bodies.
        for match in ROUTINE.finditer(line):
            # Pascal routine headers start a line; an inline callback type does not.
            if line[: match.start()].strip():
                continue
            name = match.group(2)
            seen[name.lower()] += 1
            result.append({
                "id": f"{filename}:{name.lower()}:{seen[name.lower()]}",
                "name": name,
                "kind": match.group(1).lower(),
                "line": line_number,
                "external": "external" in line[match.end():].lower(),
                "indent": len(line) - len(line.lstrip()),
            })
    # A nested routine ends before its enclosing routine body resumes. In
    # LORESPEC, `sgn` is nested inside `specialevent_part1`; otherwise every
    # following map branch is incorrectly owned by `sgn`.
    for index, routine in enumerate(result[1:], 1):
        parent = result[index - 1]
        parent_body_started = any(
            re.search(r"\bbegin\b", lines[line_number - 1], re.I)
            for line_number in range(parent["line"] + 1, routine["line"])
        )
        if routine["indent"] <= parent["indent"] or parent_body_started:
            continue
        depth = 0
        entered = False
        for line_number in range(routine["line"] + 1, len(lines) + 1):
            for token in re.finditer(r"\b(begin|end)\b", lines[line_number - 1], re.I):
                if token.group(1).lower() == "begin":
                    depth += 1
                    entered = True
                elif entered:
                    depth -= 1
                    if depth == 0:
                        routine["end_line"] = line_number
                        break
            if "end_line" in routine:
                break
        if "end_line" not in routine:
            raise ValueError(f"Nested routine has no matching end: {routine['id']}")
    for routine in result:
        routine.pop("indent")
    if filename == "LORE.PAS":
        main_line = next(i for i, line in enumerate(lines, 1) if line.strip().lower() == "begin")
        result.append({
            "id": "LORE.PAS:<main>", "name": "<main>", "kind": "program",
            "line": main_line, "external": False,
        })
    declarations_in_tokens = sum(
        word in {"procedure", "function"} and line >= implementation
        for word, line in lex((SOURCE / filename).read_bytes())
    )
    source_declarations = len(result) - (filename == "LORE.PAS")
    if declarations_in_tokens != source_declarations:
        raise ValueError(f"Routine declaration extraction incomplete in {filename}")
    return clean, result


def owner(routines, line):
    current = None
    for routine in routines:
        if routine["line"] > line:
            break
        if routine.get("end_line", line) < line:
            continue
        current = routine["id"]
    return current or "<program-or-unit-init>"


def source_contracts(inv):
    routines_by_file = {}
    writes = []
    for filename in inv["source_files"]:
        clean, routines = declarations(filename)
        routines_by_file[filename] = routines
        for line_number, line in enumerate(clean.splitlines(), 1):
            for match in MAP_WRITE.finditer(line):
                write_id = f"{filename}:{line_number}:map-write:{match.start()}"
                writes.append({
                    "id": write_id,
                    "file": filename,
                    "line": line_number,
                    "routine": owner(routines, line_number),
                    "index": match.group(1).strip(),
                    "value": match.group(2).strip(),
                    "status": "mapped" if (
                        write_id in MAPPED_MAP_WRITES or
                        owner(routines, line_number) in MAPPED_MAP_WRITE_GROUPS
                    ) else "unmapped",
                })
    ordinal = Counter()
    sites = []
    for item in inv["sites"]:
        filename = item["file"]
        routine = owner(routines_by_file[filename], item["line"])
        key = (routine, item["kind"])
        ordinal[key] += 1
        sites.append({
            "id": f"{routine}:{item['kind']}:{ordinal[key]}",
            "inventory_id": item["id"],
            "file": filename,
            "line": item["line"],
            "routine": routine,
            "kind": item["kind"],
            "outcomes": item.get("outcomes"),
            "classification": "platform" if filename in PLATFORM_UNITS else "unclassified",
            "behavioral_evidence": [],
        })
    return routines_by_file, sites, writes


def link_contract_evidence(sites):
    """Apply only reviewed, source-located behavioral evidence."""
    rows = json.loads(EVIDENCE.read_text(encoding="utf-8"))["contracts"]
    # Reviewed source-backed bundles whose tests cover a procedure boundary but
    # do not yet have one hand-written row for every syntactic branch. Keep
    # these explicitly partial; the ledger must not imply full procedure proof.
    supplemental = [
        {
            "file": "LORECRET.PAS",
            "routines": {"LORECRET.PAS:erase:1", "LORECRET.PAS:fourth:1",
                         "LORECRET.PAS:third:1", "LORECRET.PAS:second:1",
                         "LORECRET.PAS:name:1", "LORECRET.PAS:whatclass:1",
                         "LORECRET.PAS:which:1", "LORECRET.PAS:profile:1",
                         "LORECRET.PAS:createcharacter:1", "LORECRET.PAS:display:1",
                         "LORECRET.PAS:last:1"},
            "implementation": "lib/data/lore_creation.dart",
            "test": "test/creation_test.dart",
            "note": "Partial source bundle for LORECRET character creation and display procedures. The test cites LORECRET.PAS and checks the shared source-backed data/creation boundary; it does not claim every CRT frame, key loop, or DOS rendering branch.",
        },
        {
            "file": "LOREENT.PAS",
            "routines": {"LOREENT.PAS:entermode:1", "LOREENT.PAS:sign:1"},
            "implementation": "lib/logic/lore_ent_procedures.dart",
            "test": "test/source_entrance_replay_test.dart",
            "note": "Partial source bundle for LOREENT entrance/sign dispatch. The source entrance replay checks extracted destinations, cancellation ordering, and ground at-coordinate boundaries; guarded battles, CRT presentation and every native retry remain separate evidence.",
        },
        {
            "file": "LORESUB.PAS",
            "routines": {"LORESUB.PAS:simplediscond:1", "LORESUB.PAS:display_condition:1",
                         "LORESUB.PAS:displaycondition:1", "LORESUB.PAS:displayhp:1",
                         "LORESUB.PAS:displaysp:1", "LORESUB.PAS:displayesp:1"},
            "implementation": "lib/models/party_member.dart",
            "test": "test/return_condition_test.dart",
            "note": "Partial source bundle for LORESUB ReturnCondition/SimpleDisCond and status display normalization. Boundary tests cover HP, unconscious/dead thresholds and raw Pascal storage; DOS text layout and every display branch remain separate.",
        },
        {
            "file": "LORESUB.PAS",
            "routines": None,
            "implementation": "lib/models/party_member.dart",
            "test": "tool/tests/test_remaining_source_contracts.py",
            "note": "Partial source ownership bundle for remaining LORESUB shared utility, menu, save/load, and input branches. The static contract test retains source and port ownership; individual DOS prompts, key loops, storage effects, and every utility outcome remain separate evidence.",
        },
        {
            "file": "LORE.PAS",
            "routines": {"LORE.PAS:<main>"},
            "implementation": "lib/logic/lore_main_procedures.dart",
            "test": "tool/tests/test_remaining_source_contracts.py",
            "note": "Partial source ownership bundle for the LORE.PAS program entry and startup loop. The static contract test keeps the source and port owner present; startup sequencing, DOS prompts, and every loop outcome remain separate evidence.",
        },
        {
            "file": "LOREHELP.PAS",
            "routines": {"LOREHELP.PAS:box:1", "LOREHELP.PAS:messagebox:1",
                         "LOREHELP.PAS:text_fading:1", "LOREHELP.PAS:title_menu:1",
                         "LOREHELP.PAS:scroll_sub:1"},
            "implementation": "lib/screens/main_game_screen.dart",
            "test": "tool/tests/test_remaining_source_contracts.py",
            "note": "Partial source ownership bundle for LOREHELP help, title, box, and fading procedures. The static contract test retains source and port ownership; DOS text timing, keyboard loops, and every help branch remain separate evidence.",
        },
        {
            "file": "LORESPEC.PAS",
            "routines": {"LORESPEC.PAS:specialevent_part1:1",
                         "LORESPEC.PAS:specialevent_part2:1",
                         "LORESPEC.PAS:sgn:1", "LORESPEC.PAS:specialevent:1"},
            "implementation": "lib/logic/lore_spec_procedures.dart",
            "test": "tool/tests/test_remaining_source_contracts.py",
            "note": "Partial source ownership bundle for remaining LORESPEC special-event branches. Existing route and map contracts plus the static ownership test retain source boundaries; unplayed map events, CRT prompts, combat continuations, and all effects remain separate evidence.",
        },
        {
            "file": "LOREMAIN.PAS",
            "routines": {"LOREMAIN.PAS:main:1", "LOREMAIN.PAS:enter_water:1",
                         "LOREMAIN.PAS:enter_swamp:1", "LOREMAIN.PAS:enter_lava:1"},
            "implementation": "lib/logic/lore_main_procedures.dart",
            "test": "tool/tests/test_remaining_source_contracts.py",
            "note": "Partial source ownership bundle for the remaining LOREMAIN main-loop branches. Terrain, entrance, route, and map contracts cover selected boundaries; full movement timing, random encounter ordering, and every main-loop outcome remain separate evidence.",
        },
        {
            "file": "LORETALK.PAS",
            "routines": {"LORETALK.PAS:talkmode:1"},
            "implementation": "lib/logic/lore_talk_procedures.dart",
            "test": "tool/tests/test_remaining_source_contracts.py",
            "note": "Partial source ownership bundle for the remaining LORETALK talk-mode loop. Source talk replay covers selected dialogue boundaries; all text branches, input timing, and NPC outcomes remain separate evidence.",
        },
    ]
    linked_ids = {row["id"] for row in rows}
    for bundle in supplemental:
        for site in sites:
            if (site["id"] in linked_ids or site["file"] != bundle["file"] or
                    (bundle["routines"] is not None and
                     site["routine"] not in bundle["routines"]) or
                    site["classification"] == "platform"):
                continue
            rows.append({
                "id": site["id"], "line": site["line"], "kind": site["kind"],
                "classification": "common-rule" if bundle["file"] == "LORESUB.PAS" else "content-rule",
                "implementation": bundle["implementation"], "test": bundle["test"],
                "supporting_evidence": [], "note": bundle["note"],
                "verification": "partial",
            })
            linked_ids.add(site["id"])
    by_id = {site["id"]: site for site in sites}
    seen = set()
    for row in rows:
        site_id = row["id"]
        if site_id in seen or site_id not in by_id:
            raise ValueError(f"Duplicate or unknown linked contract: {site_id}")
        seen.add(site_id)
        site = by_id[site_id]
        if (site["line"], site["kind"], site["classification"]) != (
            row["line"], row["kind"], "unclassified",
        ):
            raise ValueError(f"Linked contract source moved: {site_id}")
        if row["classification"] not in {"common-rule", "content-rule"}:
            raise ValueError(f"Unsupported contract class: {site_id}")
        if row["verification"] not in {"partial", "verified"}:
            raise ValueError(f"Unsupported verification status: {site_id}")
        if not row["note"].strip():
            raise ValueError(f"Linked contract has no reviewed scope: {site_id}")
        implementation = ROOT / row["implementation"]
        test = ROOT / row["test"]
        if not implementation.is_file() or not test.is_file():
            raise ValueError(f"Linked contract evidence is missing: {site_id}")
        if site["file"] not in test.read_text(encoding="utf-8"):
            raise ValueError(f"Test does not cite original source: {site_id}")
        supporting = row.get("supporting_evidence", [])
        if not isinstance(supporting, list) or any(
            not isinstance(path, str) or not (ROOT / path).is_file()
            for path in supporting
        ):
            raise ValueError(f"Supporting contract evidence is missing: {site_id}")
        site["classification"] = row["classification"]
        site["verification_status"] = row["verification"]
        site["port_handler"] = row["implementation"]
        site["behavioral_evidence"] = list(dict.fromkeys([row["test"], *supporting]))
        site["reviewed_scope"] = row["note"]
    return rows


def runtime_assets():
    copies = {".MAP": "maps", ".FNT": "fonts", ".DAT": "data"}
    audio = {
        "MUSIC1.BGM": "music1_title.mp3",
        "MUSIC2.BGM": "music2_town.mp3",
        "MUSIC3.BGM": "music3_ground.mp3",
        "MUSIC4.BGM": "music4_den.mp3",
        "MUSIC5.BGM": "music5_keep.mp3",
        "HIT.VOC": "hit.wav",
        "SCREAM1.VOC": "scream1.wav",
        "SCREAM2.VOC": "scream2.wav",
    }
    rows = []
    for path in sorted(p for p in RUNTIME.iterdir() if p.is_file()):
        suffix = path.suffix.upper()
        target = (
            ROOT / "assets" / copies[suffix] / path.name if suffix in copies
            else ROOT / "assets/audio" / audio[path.name] if path.name in audio
            else None
        )
        if suffix in copies:
            status = "exact-copy" if target.exists() and digest(path) == digest(target) else "missing-or-changed-copy"
        elif path.name in audio:
            status = "converted-audio-present" if target.exists() else "missing-audio-conversion"
        elif suffix == ".EXE":
            status = "engine-replaced"
        elif suffix in {".TXT", ".DOC"}:
            status = "documentation-only"
        else:
            status = "unmapped-runtime-file"
        rows.append({
            "source": path.relative_to(ROOT).as_posix(),
            "kind": suffix.lstrip(".").lower() or "other",
            "sha256": digest(path),
            "port_copy": target.relative_to(ROOT).as_posix() if target and target.exists() else None,
            "copy_equal": digest(path) == digest(target) if suffix in copies and target.exists() else None,
            "status": status,
        })
    return rows


def source_catalog(inv):
    reachable = set(inv["source_files"])
    rows = []
    for path in sorted(p for p in SOURCE.iterdir() if p.is_file()):
        if path.name in reachable:
            role = "reachable-program-or-unit"
        elif path.name == "EGAVGA.OBJ":
            role = "linked-dos-object"
        elif path.suffix.upper() == ".PAS":
            header = strip_pascal_comments(path.read_bytes()).lstrip().lower()
            role = (
                "independent-utility" if header.startswith("program ")
                else "unit-outside-main-Uses-graph" if header.startswith("unit ")
                else "pascal-source-fragment"
            )
        else:
            role = "source-support-file"
        rows.append({"file": path.name, "sha256": digest(path), "role": role})
    return rows


def map_registry():
    text = (ROOT / "lib/game/lore_world_manager.dart").read_text(encoding="utf-8")
    body = text.split("static final Map<int, MapInfo> mapRegistry = {", 1)[1].split("};", 1)[0]
    rows = []
    for map_id, entry in REGISTRY.findall(body):
        filename = re.search(r"fileName: '([^']+)'", entry).group(1)
        category = re.search(r"category: MapCategory\.(\w+)", entry).group(1)
        rows.append({"map_id": int(map_id), "file": f"{filename}.MAP", "category": category})
    return rows


def evidence_catalog():
    rows = []
    tests = sorted((ROOT / "test").glob("*_test.dart"))
    bodies = {test: test.read_text(encoding="utf-8") for test in tests}
    for test in tests:
        cited = sorted(set(re.findall(r"(?:repo_source/LORE_1993_src/)?(LORE[A-Z0-9_]*\.PAS)", bodies[test])))
        rows.append({
            "path": test.relative_to(ROOT).as_posix(), "kind": "test",
            "sha256": digest(test), "cited_source_files": cited,
            "scope": "candidate-evidence; behavioral contract linkage pending",
        })
    for fixture in sorted((ROOT / "test/fixtures").glob("*.json")):
        users = [test.relative_to(ROOT).as_posix() for test, body in bodies.items() if fixture.name in body]
        rows.append({
            "path": fixture.relative_to(ROOT).as_posix(), "kind": "fixture",
            "sha256": digest(fixture),
            "test_users": users,
            "scope": "candidate-evidence; source behavior not inferred from filename",
        })
    return rows


def port_rule_sources():
    files = sorted((ROOT / "assets/data").glob("*.json"))
    files += [ROOT / path for path in (
        "lib/data/lore_script.dart",
        "lib/game/lore_game.dart",
        "lib/game/lore_world_manager.dart",
        "lib/game/lore_dialogue_manager.dart",
        "lib/game/lore_dungeon_event_manager.dart",
        "lib/logic/lore_tile_protocol.dart",
        "lib/logic/lore_movement_logic.dart",
        "lib/logic/lore_field_session.dart",
        "lib/logic/lore_source_memory.dart",
        "lib/logic/lore_random.dart",
        "lib/logic/lore_talk_procedures.dart",
        "lib/logic/lore_talk_mode.dart",
        "lib/logic/lore_sign.dart",
        "lib/logic/lore_water_lord.dart",
        "tool/export_dos_random_stream.py",
        "tool/verify_source_random.dart",
        "lib/game/lore_map_manager.dart",
        "lib/logic/lore_spec_procedures.dart",
        "lib/logic/lore_portal_session.dart",
        "lib/logic/lore_talk_dispatcher.dart",
        "lib/logic/lore_special_event_dispatcher.dart",
        "lib/logic/script_world_reducer.dart",
        "lib/logic/script_battle_session.dart",
        "lib/logic/script_party_reducer.dart",
        "lib/logic/lore_lava_logic.dart",
        "lib/logic/lore_swamp_logic.dart",
        "lib/screens/main_game_screen.dart",
        "lib/logic/lore_game_option.dart",
        "lib/logic/lore_cast_spell.dart",
        "lib/logic/lore_view_procedures.dart",
        "lib/logic/lore_extrasense.dart",
        "lib/logic/lore_town_shops.dart",
        "lib/widgets/lore_window.dart",
        "lib/widgets/lore_select_view.dart",
        "lib/widgets/lore_source_text.dart",
        "lib/game/bgi_font_decoder.dart",
        "lib/game/sprite_sheet.dart",
        "lib/theme/retro_theme.dart",
        "lib/widgets/message_log_view.dart",
        "lib/widgets/dialogue_history_view.dart",
        "lib/widgets/party_status_view.dart",
        "lib/widgets/game_screen_layout.dart",
        "lib/services/audio_manager.dart",
        "tool/capture_dos_reference.py",
        "lib/widgets/script_scene_dialog.dart",
        "lib/logic/lore_source_speech.dart",
        "tool/export_source_speech.py",
        "docs/audits/contract_evidence.json",
    )]
    rows = []
    for path in files:
        item = {"path": path.relative_to(ROOT).as_posix(), "sha256": digest(path)}
        if path.suffix == ".json":
            data = json.loads(path.read_text(encoding="utf-8"))
            item["top_level_counts"] = {
                key: len(value) for key, value in data.items()
                if isinstance(value, (list, dict))
            }
        rows.append(item)
    return rows


def build():
    inv = inventory()
    checked = json.loads((ROOT / "docs/audits/source_branch_inventory.json").read_text(encoding="utf-8"))
    if inv != checked:
        raise ValueError("Source branch inventory has drifted; regenerate it first")
    routines, sites, writes = source_contracts(inv)
    linked = link_contract_evidence(sites)
    assets = runtime_assets()
    source_files = source_catalog(inv)
    maps = map_registry()
    if len(maps) != 27 or len({row["map_id"] for row in maps}) != 27:
        raise ValueError("Expected 27 unique registered map IDs")
    for row in maps:
        if not (RUNTIME / row["file"]).exists():
            raise ValueError(f"Missing original map: {row['file']}")
    evidence = evidence_catalog()
    if any(not row["test_users"] for row in evidence if row["kind"] == "fixture"):
        raise ValueError("An evidence fixture has no test user")
    ids = [site["id"] for site in sites]
    if len(ids) != len(set(ids)):
        raise ValueError("Duplicate contract IDs")
    special_tokens = Counter(
        word for filename in inv["source_files"]
        for word, _ in lex((SOURCE / filename).read_bytes())
        if word in {"asm", "with"}
    )
    return {
        "schema_version": 1,
        "source_files": inv["source_files"],
        "source_sha256": inv["source_sha256"],
        "source_catalog": source_files,
        "routines": routines,
        "control_sites": sites,
        "linked_contracts": linked,
        "map_writes": writes,
        "runtime_assets": assets,
        "map_registry": maps,
        "existing_evidence": evidence,
        "port_rule_sources": port_rule_sources(),
        "baseline_gaps": {
            "duplicate_contract_ids": 0,
            "missing_registered_maps": 0,
            "orphan_fixtures": 0,
            "unmapped_behavior_sites": sum(s["classification"] == "unclassified" for s in sites),
            "unverified_behavior_sites": sum(
                s["classification"] != "platform" and
                s.get("verification_status") != "verified" for s in sites
            ),
            "partially_verified_behavior_sites": sum(
                s.get("verification_status") == "partial" for s in sites
            ),
            "unmapped_map_writes": len(writes),
            "pascal_constructs_awaiting_semantic_review": dict(sorted(special_tokens.items())),
        },
        "limitations": [
            "Routine ownership is nearest declaration, not a full Pascal AST.",
            "Map-write expressions are inventoried, not yet evaluated for all states.",
            "Fixtures are candidate evidence until linked to a source contract and result.",
            "JSON, Dart fallback, and runtime behavior equivalence is not implied by registration.",
            "Audio counterparts are filename mappings; audible equivalence is not yet verified.",
        ],
    }


def report(data):
    sites = data["control_sites"]
    assets = data["runtime_assets"]
    counts = Counter(site["kind"] for site in sites)
    exact = sum(asset["status"] == "exact-copy" for asset in assets)
    converted = sum(asset["status"] == "converted-audio-present" for asset in assets)
    unmapped = [asset["source"] for asset in assets if asset["status"] == "unmapped-runtime-file"]
    fixture_count = sum(row["kind"] == "fixture" for row in data["existing_evidence"])
    test_count = sum(row["kind"] == "test" for row in data["existing_evidence"])
    game_sites = [site for site in sites if site["classification"] == "unclassified"]
    linked = data["linked_contracts"]
    game_branches = sum(site["outcomes"] is not None for site in game_sites)
    lines = [
        "# LORE 원본 계약 기준선",
        "",
        "`python3 tool/build_port_contract_ledger.py --check`로 원본·이식 자산·기존 근거의 드리프트를 확인한다.",
        "이 장부는 등록·증거 연결 현황이며 이식 완료율이 아니다. 부분 근거와 검증 완료를 구분한다.",
        "",
        "| 등록 항목 | 수 | 현재 판정 |",
        "| --- | ---: | --- |",
        f"| 원본 의존 Pascal 파일 | {len(data['source_files'])} | 해시 고정 |",
        f"| 원본 폴더 전체 파일 | {len(data['source_catalog'])} | 독립 도구·연결 객체도 분류 |",
        f"| 루틴 선언·프로그램 본문 | {sum(map(len, data['routines'].values()))} | 외부 선언 1건 포함, 소유 루틴 추정 |",
        f"| 제어 지점 | {len(sites)} | 게임 분기별 근거 연결 현황은 아래에 분리 |",
        f"| 그중 if/case/while/repeat/for | {sum(counts[k] for k in ('if','case','while','repeat','for'))} | 구문 인벤토리 |",
        f"| 그중 goto/exit | {counts['goto'] + counts['exit']} | 이동 대상·호출 효과 검토 대기 |",
        f"| 지도 쓰기 문장 | {len(data['map_writes'])} | 연결 {sum(w['status'] != 'unmapped' for w in data['map_writes'])}, 미연결 {sum(w['status'] == 'unmapped' for w in data['map_writes'])} |",
        f"| 원본 런타임 파일 | {len(assets)} | 바이트 복사 {exact}, 오디오 대응 파일 {converted}, 미매핑 {len(unmapped)} |",
        f"| 등록된 지도 ID / 고유 MAP 파일 | {len(data['map_registry'])} / {len({m['file'] for m in data['map_registry']})} | 원본 파일 존재 확인 |",
        f"| 이식 규칙·데이터 출처 | {len(data['port_rule_sources'])} | JSON/기존 처리 경로 등록 |",
        f"| 기존 테스트 / JSON 근거 파일 | {test_count} / {fixture_count} | 후보로 등록, 의미 검증 별도 |",
        f"| 미분류 게임 제어 지점 | {data['baseline_gaps']['unmapped_behavior_sites']} | 분기 {game_branches}, goto/exit {len(game_sites) - game_branches} |",
        f"| 원본 행동 근거 연결 지점 | {len(linked)} | `docs/audits/contract_evidence.json`의 원본 줄·이식 코드·테스트에 연결 |",
        f"| 부분 근거 / 검증 완료 | {data['baseline_gaps']['partially_verified_behavior_sites']} / {len(linked) - data['baseline_gaps']['partially_verified_behavior_sites']} | 부분 근거는 완료로 계산하지 않음 |",
        f"| 미검증 게임 제어 지점 | {data['baseline_gaps']['unverified_behavior_sites']} | 최종 게이트에서 0 필요 |",
        f"| 의미 분석 대기 Pascal 구문 | asm {data['baseline_gaps']['pascal_constructs_awaiting_semantic_review'].get('asm', 0)}, with {data['baseline_gaps']['pascal_constructs_awaiting_semantic_review'].get('with', 0)} | 원본 조건·효과 검토 대상 |",
        "",
        "## 현재의 빈칸",
        "",
        "- 검증 목록에 없는 게임 분기와 모든 지도 쓰기는 아직 실행 규칙·이식 코드·행동 테스트에 연결하지 않았다.",
        "- 기존 테스트/fixture는 보존하며 근거 후보로 등록했다. 파일 이름만으로 검증 완료로 승격하지 않는다.",
        "- Pascal 전체 문법 트리가 아니므로 루틴 소유와 동적 표현식은 후속 의미 검토가 필요하다.",
        "- 직접 프로시저와 미이전 처리기의 우선순위·도달성은 이식 전략의 단계 2에서 연결한다.",
        "- 오디오는 대응 파일의 존재만 확인했다. 소리·재생 시점의 동등성은 이식 전략의 단계 4 대상이다.",
        f"- 원본 런타임 미매핑 파일: {', '.join(unmapped) if unmapped else '없음'}.",
        "",
        "다음 작업은 장부 항목을 공통 규칙·콘텐츠 규칙·플랫폼 대체에 연결하고,",
        "효과 순서와 독립 실행 결과를 검증하는 것이다. `docs/porting/direct_port_strategy.md`의 실행 순서와 최종 완료 게이트를 따른다.",
        "",
    ]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = build()
    serialized = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    markdown = report(data)
    if args.check:
        if OUTPUT.read_text(encoding="utf-8") != serialized or REPORT.read_text(encoding="utf-8") != markdown:
            raise SystemExit("Port contract ledger drifted; run tool/build_port_contract_ledger.py")
        print("Port contract ledger is current")
    else:
        OUTPUT.write_text(serialized, encoding="utf-8")
        REPORT.write_text(markdown, encoding="utf-8")
        print(f"Registered {len(data['control_sites'])} control sites and {len(data['runtime_assets'])} runtime files")


if __name__ == "__main__":
    main()
