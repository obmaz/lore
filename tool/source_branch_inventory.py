"""Inventory syntactic Pascal control-flow sites in the shipped LORE program.

This is a denominator for source control-flow edges, not proof of behavioral
equivalence. It excludes unreachable standalone utilities and external units.
"""

import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "repo_source/LORE_1993_src"
INVENTORY = ROOT / "PORT_SOURCE_BRANCH_INVENTORY.json"
REPORT = ROOT / "PORT_SOURCE_BRANCH_INVENTORY.md"
KINDS = ("if", "case", "while", "repeat", "for")
TRANSFERS = ("goto", "exit")
PLATFORM_UNITS = {"ADLIB.PAS", "UHANX.PAS", "VOICE.PAS"}
TOKEN = re.compile(r"[A-Za-z_][A-Za-z_0-9]*|\d+|:=|<=|>=|<>|\.\.|[^\s]", re.ASCII)


def lex(data: bytes):
    """Return (lowercase token, line) pairs with strings/comments removed."""
    source = data.decode("latin1")
    result = []
    index = 0
    line = 1
    while index < len(source):
        c = source[index]
        if c == "'":
            index += 1
            while index < len(source):
                if source[index] == "'":
                    index += 1
                    if index < len(source) and source[index] == "'":
                        index += 1
                        continue
                    break
                if source[index] == "\n":
                    line += 1
                index += 1
            else:
                raise ValueError(f"Unterminated string at line {line}")
            continue
        if c == "{" or source.startswith("(*", index):
            opening = "{" if c == "{" else "(*"
            closing = "}" if c == "{" else "*)"
            start = index
            index = source.find(closing, index + len(opening))
            if index == -1:
                raise ValueError(f"Unterminated comment at line {line}")
            line += source[start:index].count("\n")
            index += len(closing)
            continue
        if source.startswith("//", index):
            index = source.find("\n", index)
            if index == -1:
                break
            continue
        if c.isspace():
            if c == "\n":
                line += 1
            index += 1
            continue
        match = TOKEN.match(source, index)
        assert match is not None
        result.append((match.group().lower(), line))
        index = match.end()
    return result


def program_files():
    """Follow local Uses dependencies from LORE.PAS, including unit bodies."""
    pending = ["LORE"]
    found = set()
    while pending:
        name = pending.pop()
        if name in found:
            continue
        path = SOURCE / f"{name}.PAS"
        if not path.exists():
            continue  # DOS / third-party units are outside the source tree.
        found.add(name)
        tokens = lex(path.read_bytes())
        for index, (word, _) in enumerate(tokens):
            if word != "uses":
                continue
            for dependency, _ in tokens[index + 1 :]:
                if dependency == ";":
                    break
                if (SOURCE / f"{dependency.upper()}.PAS").exists():
                    pending.append(dependency.upper())
    return sorted(found)


def case_alternatives(tokens, start):
    """Count top-level case labels; the unmatched path is added separately."""
    at = start + 1
    while at < len(tokens) and tokens[at][0] != "of":
        at += 1
    if at == len(tokens):
        raise ValueError(f"case without of on line {tokens[start][1]}")
    stack = ["case"]
    labels = 0
    at += 1
    while at < len(tokens):
        word = tokens[at][0]
        if word == "case":
            stack.append("case")
        elif word == "begin":
            stack.append("begin")
        elif word == "end":
            if not stack:
                raise ValueError(f"Unexpected end on line {tokens[at][1]}")
            stack.pop()
            if not stack:
                return labels
        elif len(stack) == 1 and word == ":":
            labels += 1
        at += 1
    raise ValueError(f"Unterminated case on line {tokens[start][1]}")


def inventory():
    files = program_files()
    sites = []
    for name in files:
        filename = f"{name}.PAS"
        tokens = lex((SOURCE / filename).read_bytes())
        same_line = Counter()
        for index, (word, line) in enumerate(tokens):
            if word not in KINDS + TRANSFERS:
                continue
            same_line[(line, word)] += 1
            item = {
                "id": f"{filename}:{line}:{word}:{same_line[(line, word)]}",
                "file": filename,
                "line": line,
                "kind": word,
            }
            if word == "case":
                labels = case_alternatives(tokens, index)
                if labels == 0:
                    raise ValueError(f"case has no labels at {filename}:{line}")
                item["outcomes"] = labels + 1
                item["case_labels"] = labels
            elif word in KINDS:
                item["outcomes"] = 2
            sites.append(item)
    return {
        "entry": "LORE.PAS",
        "source_files": [f"{name}.PAS" for name in files],
        "source_sha256": {
            f"{name}.PAS": hashlib.sha256((SOURCE / f"{name}.PAS").read_bytes()).hexdigest()
            for name in files
        },
        "excluded_standalone_programs": [
            path.name for path in sorted(SOURCE.glob("LORE*.PAS"))
            if path.stem not in files
        ],
        "sites": sites,
    }


def report(data):
    rows = []
    for filename in data["source_files"]:
        subset = [s for s in data["sites"] if s["file"] == filename]
        counts = Counter(s["kind"] for s in subset)
        cases = sum(s["case_labels"] for s in subset if s["kind"] == "case")
        edges = sum(s["outcomes"] for s in subset if "outcomes" in s)
        rows.append((filename, counts, cases, edges))
    totals = Counter(s["kind"] for s in data["sites"])
    labels = sum(s["case_labels"] for s in data["sites"] if s["kind"] == "case")
    edges = sum(s["outcomes"] for s in data["sites"] if "outcomes" in s)
    lines = [
        "# LORE 원본 정적 분기 분모",
        "",
        "`python3 tool/source_branch_inventory.py --check`로 소스와 목록의 드리프트를 확인한다.",
        "JSON 목록에는 각 원본 파일의 SHA-256도 기록한다.",
        "메인 `LORE.PAS`에서 `Uses`를 따라 도달하는 저장소 내 Pascal 파일을 센다.",
        "외부 DOS·그래픽·음성 유닛은 소스가 없으므로 범위 밖이다. 별도 치트 프로그램은 제외한다.",
        "문자열·주석은 제외한다. `case`의 각 라벨 묶음과 기본/미일치 경로를 각각 한 결과로 센다.",
        "`if`·`while`·`repeat`·`for`는 각각 참/거짓 또는 실행/종료 두 결과로 센다.",
        "",
        "| 파일 | if | case | case 라벨 | while | repeat | for | 분기 지점 | 결과 경로 | goto | exit |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for filename, counts, cases, count_edges in rows:
        sites = sum(counts[k] for k in KINDS)
        values = [filename, *(str(counts[k]) for k in ("if", "case")), str(cases),
                  *(str(counts[k]) for k in ("while", "repeat", "for")),
                  str(sites), str(count_edges), str(counts["goto"]), str(counts["exit"])]
        lines.append("| " + " | ".join(values) + " |")
    sites = sum(totals[k] for k in KINDS)
    values = ["합계", *(str(totals[k]) for k in ("if", "case")), str(labels),
              *(str(totals[k]) for k in ("while", "repeat", "for")),
              str(sites), str(edges), str(totals["goto"]), str(totals["exit"])]
    lines.append("| " + " | ".join(values) + " |")
    core = [s for s in data["sites"] if s["file"] not in PLATFORM_UNITS]
    platform = [s for s in data["sites"] if s["file"] in PLATFORM_UNITS]
    core_sites = sum(s["kind"] in KINDS for s in core)
    core_edges = sum(s.get("outcomes", 0) for s in core)
    platform_sites = sum(s["kind"] in KINDS for s in platform)
    platform_edges = sum(s.get("outcomes", 0) for s in platform)
    lines.extend([
        "",
        f"게임 프로그램·유닛 11개: **{core_sites}개 분기 지점 / {core_edges}개 결과 경로**. "
        f"DOS 화면·음악·음성 유닛 3개: {platform_sites}개 / {platform_edges}개. "
        f"전체 도달 소스 14개: {sites}개 / {edges}개.",
        "플랫폼 유닛(`ADLIB`, `UHANX`, `VOICE`)은 현대 엔진의 오디오·화면 구현으로",
        "대체할 범위다. 게임 로직 대장에는 나머지 11개 파일의 분기 지점을 우선 연결한다.",
        "",
        "`goto`와 `exit`는 별도 제어 이동 지점이며 결과 경로 합계에는 더하지 않는다.",
        "이 숫자는 **원본 구문상의 분기 분모**다. 단락 평가, 조건식의 조합, 호출 가능성,",
        "난수·선택 값의 경계, 효과 순서, 지도·데이터 파일의 항목, 저장 상태, 각 경로의",
        "도달 가능성은 아직 검증하지 않았다. 따라서 이 수치를 이식 완료율이나 남은",
        "작업 건수로 해석하지 않는다. 다음 단계에서 `PORT_SOURCE_BRANCH_INVENTORY.json`의",
        "각 지점을 자료 매핑·공통 규칙·고유 사건 등으로 묶고, 묶음별 원본 조건·효과와",
        "이식 코드·검증 증거를 연결한다. 의미가 다른 경로와 묶음에서 빠진 항목은 별도 검토한다.",
        "",
        "제외한 독립 프로그램: " + ", ".join(data["excluded_standalone_programs"]) + ".",
        "",
    ])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = inventory()
    serialized = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    markdown = report(data)
    if args.check:
        if INVENTORY.read_text() != serialized or REPORT.read_text() != markdown:
            raise SystemExit("LORE branch inventory is stale; regenerate it")
    else:
        INVENTORY.write_text(serialized)
        REPORT.write_text(markdown)
    print(markdown)


if __name__ == "__main__":
    main()
