#!/usr/bin/env python3
"""Extract read-only story research material, never runtime game rules.

Pascal expressions are retained, not evaluated. Source order is NOT play order.
The syntax tree keeps choices, conditions, loops and early exits separate.
Every literal (including empty strings and non-story resources) is inventoried.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re

from source_branch_inventory import lex as control_lex, program_files

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "repo_source/LORE_1993_src"
OUTPUT = ROOT / "story_material"
PLAN = ROOT / "tool/story_quest_plan.json"
WORD = re.compile(r"[A-Za-z_][A-Za-z_0-9]*|\d+|:=|<=|>=|<>|\.\.|[^\s]", re.ASCII)
DISPLAY = {"print", "cprint", "talk", "message", "hprint", "chprint", "hprintxy",
           "hprintxy4select", "bhprint", "ehprint", "outhprintxy", "outtextxy",
           "auxprint", "text_fading", "writeln", "write"}
TEXT_ARG_START = {"print": 1, "message": 1, "auxprint": 1, "cprint": 2,
                  "chprint": 2, "hprintxy": 2, "hprintxy4select": 2,
                  "bhprint": 2, "ehprint": 2, "outhprintxy": 2, "outtextxy": 2}


@dataclass(frozen=True)
class Token:
    value: str
    start: int
    end: int
    line: int
    kind: str = "code"


def lex(text: str) -> list[Token]:
    tokens = []
    pos, line = 0, 1
    while pos < len(text):
        char = text[pos]
        if char.isspace():
            line += char == "\n"
            pos += 1
            continue
        if char == "{" or text.startswith("(*", pos) or text.startswith("//", pos):
            closing = "}" if char == "{" else "*)" if text.startswith("(*", pos) else "\n"
            end = text.find(closing, pos + (1 if char == "{" else 2))
            if end < 0:
                if closing == "\n":
                    break
                raise ValueError(f"Unterminated comment at line {line}")
            end += len(closing)
            line += text[pos:end].count("\n")
            pos = end
            continue
        start, first_line = pos, line
        if char == "'":
            pos += 1
            while pos < len(text):
                if text[pos] == "'":
                    pos += 1
                    if pos < len(text) and text[pos] == "'":
                        pos += 1
                        continue
                    break
                line += text[pos] == "\n"
                pos += 1
            else:
                raise ValueError(f"Unterminated string at line {first_line}")
            tokens.append(Token(text[start:pos], start, pos, first_line, "string"))
        else:
            match = WORD.match(text, pos)
            if match is None:
                raise ValueError(f"Unknown token at line {line}")
            pos = match.end()
            tokens.append(Token(match.group().lower(), start, pos, first_line))
    return tokens


class Parser:
    """Structural Pascal reader; it deliberately does not interpret expressions."""

    def __init__(self, text: str, filename: str):
        self.text, self.filename = text, filename
        self.tokens = lex(text)
        self.pos = 0
        self.routines = []

    def value(self):
        return self.tokens[self.pos].value if self.pos < len(self.tokens) else "<eof>"

    def fail(self, message):
        line = self.tokens[min(self.pos, len(self.tokens) - 1)].line
        raise ValueError(f"{self.filename}:{line}: {message}")

    def expect(self, value):
        if self.value() != value:
            self.fail(f"Expected {value}, got {self.value()}")
        self.pos += 1

    def code(self, start, end):
        if start == end:
            return ""
        return self.text[self.tokens[start].start:self.tokens[end - 1].end]

    def node(self, kind, start, **fields):
        end = self.pos
        return {"id": f"{self.filename}:{self.tokens[start].line}:{self.tokens[start].start}",
                "kind": kind, "source": {"file": self.filename,
                "line_start": self.tokens[start].line,
                "line_end": self.tokens[max(start, end - 1)].line,
                "offset_start": self.tokens[start].start,
                "offset_end": self.tokens[max(start, end - 1)].end}, **fields}

    def until(self, stop):
        start, depth = self.pos, 0
        while self.pos < len(self.tokens):
            value = self.value()
            if depth == 0 and value in stop:
                return start, self.pos
            depth += value in ("(", "[")
            depth -= value in (")", "]")
            self.pos += 1
        self.fail(f"Missing delimiter {stop}")

    def sequence(self, stop):
        children = []
        while self.value() not in stop:
            if self.value() == "<eof>":
                self.fail(f"Unclosed sequence, expected {stop}")
            if self.value() == ";":
                self.pos += 1
                continue
            before = self.pos
            children.append(self.statement())
            if self.pos <= before:
                self.fail("Parser made no progress")
        return children

    def statement(self):
        start, word = self.pos, self.value()
        if self.pos + 1 < len(self.tokens) and self.tokens[self.pos + 1].value == ":":
            self.pos += 2
            body = self.statement()
            return self.node("label", start, label=word, body=body)
        if word == "begin":
            self.pos += 1
            children = self.sequence({"end"})
            self.expect("end")
            return self.node("sequence", start, children=children)
        if word == "asm":
            self.pos += 1
            self.until({"end"})
            self.expect("end")
            return self.node("assembly", start, code=self.code(start, self.pos))
        if word == "if":
            self.pos += 1
            a, b = self.until({"then"})
            expression = self.code(a, b)
            self.expect("then")
            yes = self.statement()
            no = None
            if self.value() == "else":
                self.pos += 1
                no = self.statement()
            return self.node("if", start, expression=expression, then=yes, **{"else": no})
        if word in {"for", "while", "with"}:
            self.pos += 1
            a, b = self.until({"do"})
            expression = self.code(a, b)
            self.expect("do")
            body = self.statement()
            return self.node(word, start, expression=expression, body=body)
        if word == "repeat":
            self.pos += 1
            children = self.sequence({"until"})
            self.expect("until")
            a, b = self.until({";", "end", "else"})
            return self.node("repeat", start, children=children, until=self.code(a, b))
        if word == "case":
            self.pos += 1
            a, b = self.until({"of"})
            expression = self.code(a, b)
            self.expect("of")
            arms = []
            while self.value() not in {"end", "<eof>"}:
                if self.value() == ";":
                    self.pos += 1
                    continue
                arm_start = self.pos
                if self.value() == "else":
                    self.pos += 1
                    body_start = self.pos
                    children = self.sequence({"end"})
                    arms.append({"label": "else", "body": self.node("sequence", body_start, children=children)})
                    break
                a, b = self.until({":"})
                label = self.code(a, b)
                self.expect(":")
                body = self.statement()
                arms.append({"label": label, "body": body, "line": self.tokens[arm_start].line})
            self.expect("end")
            return self.node("case", start, expression=expression, arms=arms)
        if word in {";", "end", "else", "until"}:
            return self.node("empty", start)
        a, b = self.until({";", "end", "else", "until"})
        if b == a:
            self.fail("Empty simple statement")
        return self.node("statement", start, code=self.code(a, b))

    def routine(self, parent=None):
        start = self.pos
        self.pos += 1
        name = self.value()
        self.pos += 1
        self.until({";"})
        self.expect(";")
        qualified = f"{parent}.{name}" if parent else name
        while self.value() not in {"begin", "asm"}:
            if self.value() in {"forward", "external"}:
                self.until({";"})
                self.expect(";")
                return
            if self.value() in {"procedure", "function"}:
                self.routine(qualified)
            elif self.value() == "<eof>":
                self.fail(f"Missing body for {name}")
            else:
                self.pos += 1
        body = self.statement()
        record = self.node("routine", start, name=qualified, body=body)
        record["id"] = f"{self.filename}::{qualified}"
        self.routines.append(record)
        if self.value() == ";":
            self.pos += 1

    def parse(self):
        implementation = next((i for i, t in enumerate(self.tokens) if t.value == "implementation"), None)
        self.pos = implementation + 1 if implementation is not None else 0
        while self.pos < len(self.tokens):
            if self.value() in {"procedure", "function"}:
                self.routine()
            elif self.value() == "begin":
                start = self.pos
                body = self.statement()
                root = self.node("routine", start, name="__main__", body=body)
                root["id"] = f"{self.filename}::__main__"
                self.routines.append(root)
            else:
                self.pos += 1
        return sorted(self.routines, key=lambda r: r["source"]["offset_start"])


def descendants(node, path=()):
    yield node, path
    kind = node["kind"]
    if kind == "if":
        yield from descendants(node["then"], path + ({"kind": "if", "expression": node["expression"], "outcome": True},))
        if node["else"]:
            yield from descendants(node["else"], path + ({"kind": "if", "expression": node["expression"], "outcome": False},))
    elif kind == "case":
        for arm in node["arms"]:
            yield from descendants(arm["body"], path + ({"kind": "case", "expression": node["expression"], "label": arm["label"]},))
    elif "body" in node:
        yield from descendants(node["body"], path + ({"kind": kind, "expression": node.get("expression")},))
    for child in node.get("children", []):
        yield from descendants(child, path + (({"kind": "repeat", "until": node["until"]},) if kind == "repeat" else ()))


def compact(text):
    return re.sub(r"\s+", "", text).lower()


def text_role(node):
    code = node.get("code", "")
    if re.match(r"\s*m\s*\[", code, re.I):
        return "choice_label_or_prompt"
    calls = re.findall(r"\b([a-z_]\w*)\s*\(", code, re.I)
    if any(call.lower() in DISPLAY for call in calls):
        return "display_text_fragment"
    if re.match(r"\s*s\s*:=", code, re.I):
        return "text_variable_fragment"
    return "other_literal"


def display_event(node, context):
    """Readable symbolic text. No variable evaluation or invented speaker."""
    if node["kind"] != "statement":
        return None
    code = node["code"]
    tokens = lex(code)
    if not tokens or tokens[0].value not in DISPLAY or len(tokens) < 2 or tokens[1].value != "(":
        return None
    name = tokens[0].value
    args, start, depth = [], 2, 0
    for index in range(2, len(tokens)):
        value = tokens[index].value
        if value == ")" and depth == 0:
            args.append(tokens[start:index])
            break
        if value == "," and depth == 0:
            args.append(tokens[start:index])
            start = index + 1
            continue
        depth += value in ("(", "[")
        depth -= value in (")", "]")
    text_args = args[TEXT_ARG_START.get(name, 0):]
    if name in {"auxprint", "outhprintxy"}:
        text_args = text_args[:1]  # Following boolean controls layout, not text.
    parts = []
    for arg in text_args:
        first, depth = 0, 0
        for index in range(len(arg) + 1):
            if index == len(arg) or (arg[index].value == "+" and depth == 0):
                piece = arg[first:index]
                if len(piece) == 1 and piece[0].kind == "string":
                    parts.append({"kind": "literal", "text": piece[0].value[1:-1].replace("''", "'")})
                elif piece:
                    parts.append({"kind": "expression", "source_expression": code[piece[0].start:piece[-1].end]})
                first = index + 1
                continue
            depth += arg[index].value in ("(", "[")
            depth -= arg[index].value in (")", "]")
    return {"statement_id": node["id"], "source": node["source"], "call": name,
        "branch_context": list(context), "speaker": None, "parts": parts,
        "text_template": "".join(part["text"] if part["kind"] == "literal" else "{{" + part["source_expression"] + "}}" for part in parts),
        "fully_literal": all(part["kind"] == "literal" for part in parts), "original_statement": code}


def numeric_labels(label):
    values = []
    for item in label.split(","):
        item = item.strip()
        if re.fullmatch(r"\d+", item):
            values.append(int(item))
        elif re.fullmatch(r"\d+\s*\.\.\s*\d+", item):
            a, b = map(int, item.split(".."))
            values.extend(range(a, b + 1))
    return values


def map_context(path):
    for context in reversed(path):
        if context["kind"] == "case" and compact(context["expression"]) == "party.map":
            return numeric_labels(context["label"])
    return []


def scene_roots(routine):
    map_cases = [(node, path) for node, path in descendants(routine["body"])
                 if node["kind"] == "case" and compact(node["expression"]) == "party.map"]
    if not map_cases:
        return [(routine["body"], (), [])]
    result = []
    for case, path in map_cases:
        for arm in case["arms"]:
            context = path + ({"kind": "case", "expression": case["expression"], "label": arm["label"]},)
            body = arm["body"]
            # Keep the entire map arm together. Splitting it into individual
            # display statements would lose silent setup, earlier exit guards,
            # battle continuations and the no-argument End_Demo call.
            result.append((body, context, numeric_labels(arm["label"])))
    return result


def progress_effects(node, path):
    code = node.get("code", "")
    effects = []
    for match in re.finditer(r"\b(inc|dec)\s*\(\s*(?:party\.)?etc\s*\[\s*(\d+)\s*\](?:\s*,\s*([^)]*))?\s*\)", code, re.I):
        operation, index, amount = match.groups()
        effects.append({"slot": int(index), "operation": operation.lower(), "amount_expression": amount or "1"})
    for match in re.finditer(r"\b(?:party\.)?etc\s*\[\s*(\d+)\s*\]\s*:=\s*(.*)", code, re.I | re.S):
        index, expression = match.groups()
        effects.append({"slot": int(index), "operation": "assign", "value_expression": expression})
    for effect in effects:
        effect.update({"source": node["source"], "statement_id": node["id"], "branch_context": list(path)})
        known_case = next((p for p in reversed(path) if p["kind"] == "case"
            and compact(p["expression"]) in {f"party.etc[{effect['slot']}]", f"etc[{effect['slot']}]"}
            and re.fullmatch(r"\d+", p["label"].strip())), None)
        if known_case:
            effect["case_input_state"] = int(known_case["label"])
            if effect["operation"] in {"inc", "dec"} and effect["amount_expression"].isdigit():
                effect["case_output_state"] = effect["case_input_state"] + int(effect["amount_expression"]) * (1 if effect["operation"] == "inc" else -1)
        if effect["operation"] == "assign" and re.fullmatch(r"\d+", effect["value_expression"].strip()):
            effect["assigned_state"] = int(effect["value_expression"])
    return effects


def extract_file(path):
    raw = path.read_bytes()
    text = raw.decode("johab")  # Fail rather than replace or garble source text.
    parser = Parser(text, path.name)
    routines = parser.parse()
    expected_controls = Counter(word for word, _ in control_lex(raw))
    parsed_controls = Counter(node["kind"] for routine in routines for node, _ in descendants(routine["body"]))
    control_kinds = ("if", "case", "while", "repeat", "for", "with")
    control_counts = {kind: {"source": expected_controls[kind], "extracted": parsed_controls[kind]} for kind in control_kinds}
    if any(value["source"] != value["extracted"] for value in control_counts.values()):
        raise ValueError(f"Unrepresented control-flow sites in {path.name}: {control_counts}")
    statements = []
    for routine in routines:
        for node, context in descendants(routine["body"]):
            if node["kind"] == "statement":
                statements.append((node, routine["id"], context))
    statements.sort(key=lambda entry: entry[0]["source"]["offset_start"])
    literals = []
    for token in parser.tokens:
        if token.kind != "string":
            continue
        owners = [entry for entry in statements if entry[0]["source"]["offset_start"] <= token.start < entry[0]["source"]["offset_end"]]
        owner = min(owners, key=lambda e: e[0]["source"]["offset_end"] - e[0]["source"]["offset_start"]) if owners else None
        literals.append({"id": f"{path.name}:literal:{token.start}", "text": token.value[1:-1].replace("''", "'"),
            "pascal_literal": token.value, "source": {"file": path.name, "line": token.line,
            "offset_start": token.start, "offset_end": token.end},
            "role": text_role(owner[0]) if owner else "declaration_or_control_expression",
            "statement_id": owner[0]["id"] if owner else None,
            "routine_id": owner[1] if owner else None,
            "branch_context": list(owner[2]) if owner else []})
    scenes = []
    for routine in routines:
        for root, parent_context, maps in scene_roots(routine):
            a, b = root["source"]["offset_start"], root["source"]["offset_end"]
            selected = [literal for literal in literals if a <= literal["source"]["offset_start"] < b]
            flat = list(descendants(root, parent_context))
            effects = [effect for node, context in flat for effect in progress_effects(node, context)]
            # Retain silent routines and calls too, not just text/state writes.
            scenes.append({"id": f"scene:{root['id']}", "routine_id": routine["id"],
                "maps": maps, "source": root["source"], "entry_context": list(parent_context),
                "coordinate_tests": list(dict.fromkeys(re.findall(r"\b(?:on|at)\s*\([^)]*\)", text[a:b], re.I))),
                "original_source": text[a:b], "structure": root,
                "text_occurrences": selected, "state_changes": effects,
                "display_events": [event for node, context in flat if (event := display_event(node, context)) is not None],
                "calls": list(dict.fromkeys(re.findall(r"\b([a-z_]\w*)\s*\(", text[a:b], re.I)))})
    covered = {literal["id"] for scene in scenes for literal in scene["text_occurrences"]}
    supplementary = [literal for literal in literals if literal["id"] not in covered]
    if supplementary:
        scenes.append({"id": f"scene:{path.name}:supplementary", "routine_id": None,
            "maps": [], "source": {"file": path.name, "line_start": 1, "line_end": len(text.splitlines())},
            "entry_context": [], "coordinate_tests": [], "original_source": None,
            "structure": None, "text_occurrences": supplementary, "state_changes": [], "display_events": [], "calls": [],
            "note": "선언문·조건식·지도 분기 밖 문자열. 파일 원문과 함께 확인; 대사로 단정하지 않는다."})
    return {"file": path.name, "encoding": "johab", "sha256": hashlib.sha256(raw).hexdigest(),
            "control_site_counts": control_counts,
            "original_source": text, "routines": routines, "literals": literals, "scenes": scenes}


def validate_evidence(plan, units):
    counts = {unit["file"]: len(unit["original_source"].splitlines()) for unit in units}
    def visit(value):
        if isinstance(value, dict):
            if {"file", "line_start", "line_end"} <= value.keys():
                if value["file"] not in counts or not 1 <= value["line_start"] <= value["line_end"] <= counts[value["file"]]:
                    raise ValueError(f"Invalid source evidence: {value}")
            for item in value.values():
                visit(item)
        elif isinstance(value, list):
            for item in value:
                visit(item)
    visit(plan)


def progression(units):
    changes, transfers, interruptions = [], [], []
    for unit in units:
        for routine in unit["routines"]:
            for node, context in descendants(routine["body"]):
                if node["kind"] != "statement":
                    continue
                changes.extend(progress_effects(node, context))
                code = node["code"]
                for match in re.finditer(r"\b(party\.)?map\s*:=\s*(.*)", code, re.I):
                    if not match.group(1) and not any(c["kind"] == "with" and compact(c["expression"]) == "party" for c in context):
                        continue
                    expression = match.group(2).strip()
                    transfers.append({"statement_id": node["id"], "source": node["source"],
                        "from_map_case": map_context(context), "target_expression": expression,
                        "target_map": int(expression) if expression.isdigit() else None,
                        "branch_context": list(context), "code": code})
                if re.match(r"\s*(exit|goto|halt|battlemode|load|end_demo)\b", code, re.I):
                    interruptions.append({"statement_id": node["id"], "source": node["source"],
                        "code": code, "branch_context": list(context)})
    tracks = [{"id": name, "slot": slot, "transitions": [c for c in changes if c["slot"] == slot]}
              for slot, name in ((10, "lordahn"), (13, "lastditch"), (14, "gaia"), (15, "water"))]
    prediction = next(r for u in units for r in u["routines"] if u["file"] == "LOREMENU.PAS" and r["name"] == "returnpredict")
    return {"schema_version": 1, "quest_state_tracks": tracks,
        "all_state_changes": changes, "map_transfers": transfers, "interruptions_and_continuations": interruptions,
        "source_hint_selector": prediction,
        "notes": ["전이는 원문에서 추출한 식과 분기 문맥이다. 조건을 실행해 평가한 결과가 아니다.",
                  "앞의 독립 if에서 exit하는 경우, 뒤의 문장에 도달하지 않을 수 있다. 원문 structure를 같이 읽는다.",
                  "map 전환 목록은 입출구 접근 경로·보행 도달성의 완전한 증명이 아니다.",
                  "ReturnPredict는 상태 기반 안내문 선택기이며 모든 이동을 강제하는 퀘스트 그래프가 아니다."]}


def map_registry():
    code = (ROOT / "lib/game/lore_world_manager.dart").read_text(encoding="utf-8")
    found = re.findall(r"(\d+): const MapInfo\(\s*mapId: \d+,\s*fileName: '([^']+)',\s*title: '([^']+)'", code)
    return [{"id": int(number), "resource": resource, "title": title,
             "title_source": "lib/game/lore_world_manager.dart"} for number, resource, title in found]


def build():
    files = [SOURCE / f"{name}.PAS" for name in program_files()]
    units = [extract_file(path) for path in files]
    scenes = [scene for unit in units for scene in unit["scenes"]]
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    validate_evidence(plan, units)
    routine_index = {}
    for unit in units:
        for routine in unit["routines"]:
            routine_index.setdefault(routine["name"].split(".")[-1], []).append(routine["id"])
    for scene in scenes:
        tokens = lex(scene["original_source"] or "")
        called = {token.value for index, token in enumerate(tokens[:-1])
                  if token.kind == "code" and tokens[index + 1].value == "("}
        if scene["structure"]:
            for node, _ in descendants(scene["structure"]):
                if node["kind"] == "statement" and re.fullmatch(r"\s*[a-z_]\w*\s*", node["code"], re.I):
                    called.add(node["code"].strip().lower())
        scene["calls"] = sorted(called)
        scene["called_routine_candidates"] = {name: routine_index[name] for name in sorted(called) if name in routine_index}
    packages, assigned = [], set()
    for quest in plan["quests"]:
        selected = [scene for scene in scenes if set(scene["maps"]) & set(quest["maps"])
                    or (not scene["maps"] and scene["source"]["file"] in quest.get("files_without_map", []))]
        assigned.update(scene["id"] for scene in selected)
        milestones = []
        for milestone in quest.get("milestones", []):
            event_index, literal_index, scene_ids = {}, {}, set()
            for evidence in milestone["evidence"]:
                for unit in units:
                    if unit["file"] != evidence["file"]:
                        continue
                    for scene in unit["scenes"]:
                        events = [event for event in scene["display_events"] if
                                  event["source"]["line_start"] <= evidence["line_end"] and
                                  event["source"]["line_end"] >= evidence["line_start"]]
                        original = [literal for literal in scene["text_occurrences"] if
                                    evidence["line_start"] <= literal["source"]["line"] <= evidence["line_end"]]
                        if events or original:
                            scene_ids.add(scene["id"])
                        event_index.update({event["statement_id"]: event for event in events})
                        literal_index.update({literal["id"]: literal for literal in original})
            milestones.append({**milestone, "related_script_ids": sorted(scene_ids),
                "original_display_events": list(event_index.values()),
                "original_literal_occurrences": list(literal_index.values())})
        packages.append({**quest, "milestones": milestones, "status": "source_research_not_finished_story",
            "order_policy": "source_order_within_branches; no universal play order",
            "scripts": selected, "writing_workspace": {"opening": "", "connecting_narrative": "", "ending": ""},
            "bridge_slots": [{"from_milestone": left["id"], "to_milestone": right["id"],
                "purpose": "이동·시간 경과·동기를 연결하되 원문 대사와 조건을 바꾸지 않는다.",
                "source_facts": [left["summary"], right["summary"]], "draft": ""}
                for left, right in zip(quest.get("milestones", []), quest.get("milestones", [])[1:])]})
    remaining = [scene for scene in scenes if scene["id"] not in assigned]
    packages.append({"id": "shared_system_and_text", "title": "공통 대사·시설·전투·메뉴·선언 자료",
        "kind": "appendix", "maps": [], "status": "not_a_linear_quest", "scripts": remaining,
        "note": "본문 퀘스트 밖의 모든 문자열을 보존한다. 호출되는 공통 대사와 UI 문구를 구분해 사용할 것."})
    coverage = {"source_files": len(units), "source_literal_occurrences": sum(len(u["literals"]) for u in units),
        "scenes": len(scenes), "quest_packages": len(packages) - 1,
        "literal_roles": dict(Counter(lit["role"] for unit in units for lit in unit["literals"])),
        "control_sites": {kind: sum(unit["control_site_counts"][kind]["source"] for unit in units)
                          for kind in ("if", "case", "while", "repeat", "for", "with")},
        "missing_literal_ids": [], "unassigned_scene_ids": [],
        "scope": "LORE.PAS에서 Uses로 도달하는 보존 소스; 치트·DARK·MYST 제외. 플랫폼 유닛도 부록에 보존.",
        "limitations": ["정적 구문 추출이다. 게임을 실행하거나 모든 가능한 경로를 플레이한 증거는 아니다.",
            "퀘스트 묶음·제목·권장 순서는 편집 분류이며 원본의 퀘스트 ID가 아니다.",
            "문자열 누락 0은 모든 분기의 실제 도달성·발화 순서가 검증됐다는 뜻이 아니다.",
            "동적 이름·변수·문자 코드 연결은 Pascal 식과 원문에 보존하며 임의의 완성 대사로 만들지 않는다.",
            "exit/goto/전투·불러오기/선택 취소가 후속 실행을 바꾼다. source_order를 플레이 순서로 읽지 않는다.",
            "새 연결 서사는 빈 draft에 작성하며 원문 자료와 분리한다."]}
    all_literal_ids = {literal["id"] for unit in units for literal in unit["literals"]}
    exported_ids = {literal["id"] for package in packages for scene in package["scripts"] for literal in scene["text_occurrences"]}
    coverage["missing_literal_ids"] = sorted(all_literal_ids - exported_ids)
    coverage["unassigned_scene_ids"] = sorted({scene["id"] for scene in scenes} - {scene["id"] for package in packages for scene in package["scripts"]})
    if coverage["missing_literal_ids"] or coverage["unassigned_scene_ids"]:
        raise ValueError("Story material lost source literals or scenes")
    # Keep the complete routine tree once in the catalog. Quest packages remain
    # self-contained; catalog scene entries reference nodes/literals by ID.
    catalog_units = [{**unit, "scenes": [{key: value for key, value in scene.items()
                     if key not in {"structure", "text_occurrences"}} | {
                         "structure_node_id": scene["structure"]["id"] if scene["structure"] else None,
                         "text_occurrence_ids": [literal["id"] for literal in scene["text_occurrences"]]}
                     for scene in unit["scenes"]]} for unit in units]
    catalog = {"schema_version": 1, "purpose": "story_writing_research_only", "entrypoint": "LORE.PAS",
        "offset_unit": "unicode_characters_in_original_source",
        "maps": map_registry(), "source_units": catalog_units, "coverage": coverage}
    outputs = {"scripts.json": catalog, "coverage.json": coverage, "progression.json": progression(units),
        "quests.json": {"schema_version": 1, "classification_policy": plan["classification_policy"], "route_edges": plan["route_edges"],
            "quests": [{key: value for key, value in package.items() if key != "scripts"} | {
                "file": f"quests/{package['id']}.json", "script_count": len(package["scripts"])} for package in packages]}}
    outputs.update({f"quests/{package['id']}.json": package for package in packages})
    return outputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify generated files without writing")
    args = parser.parse_args()
    outputs = build()
    for relative, data in outputs.items():
        path = OUTPUT / relative
        content = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != content:
                raise SystemExit(f"Story material drifted: {relative}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
    coverage = outputs["coverage.json"]
    print(f"Story material: {coverage['source_files']} files, {coverage['source_literal_occurrences']} literals, "
          f"{coverage['scenes']} scenes, {coverage['quest_packages']} quest packages; no missing literals.")


if __name__ == "__main__":
    main()
