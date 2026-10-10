"""Report review gaps from the source contract ledger, without claiming parity.

Regenerate after linking evidence; --check detects drift in the report.
Native fixture references are candidates, never automatic verification.
"""
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

from build_port_contract_ledger import ROOT, build

OUTPUT = ROOT / "docs/audits/completion_gaps.json"
REPORT = OUTPUT.with_suffix(".md")


def summarize(ledger):
    game = [s for s in ledger["control_sites"] if s["classification"] != "platform"]
    unclassified = [s for s in game if s["classification"] == "unclassified"]
    partial = [s for s in game if s.get("verification_status") == "partial"]
    grouped = defaultdict(lambda: Counter())
    for site in game:
        status = "unclassified" if site["classification"] == "unclassified" else site.get("verification_status", "unverified")
        grouped[site["routine"]][status] += 1
    routines = [dict(routine=name, **dict(counts)) for name, counts in grouped.items()]
    routines.sort(key=lambda row: (-row.get("unclassified", 0), row["routine"]))
    contracts = ledger["linked_contracts"]
    tests = {p.relative_to(ROOT).as_posix(): p.read_text(encoding="utf-8")
             for p in sorted((ROOT / "test").rglob("*test.dart"))}
    fixtures = []
    for path in sorted((ROOT / "test/fixtures").glob("dos_*.json")):
        relative = path.relative_to(ROOT).as_posix()
        explicit = [row["id"] for row in contracts
                    if relative in [row["test"], *row.get("supporting_evidence", [])]]
        mentioned = [row["id"] for row in contracts if path.name in row["note"]]
        users = [name for name, content in tests.items() if path.name in content]
        fixtures.append(dict(path=relative, explicit_contracts=explicit,
                             note_mentions=mentioned, test_candidates=users))
    return {
        "scope": "Review inventory, not missing implementations or completion percentage. Platform adapters still need functional validation.",
        "summary": {"game_control_sites": len(game), "unclassified": len(unclassified),
                    "partial": len(partial),
                    "verified": sum(s.get("verification_status") == "verified" for s in game),
                    "unmapped_map_writes": sum(w["status"] == "unmapped" for w in ledger["map_writes"])},
        "routines": routines,
        "unclassified_sites": unclassified,
        "unmapped_map_writes": [w for w in ledger["map_writes"] if w["status"] == "unmapped"],
        "native_fixture_candidates": fixtures,
    }


def report(data):
    s = data["summary"]
    lines = ["# 이식 완료 검증의 빈칸", "",
             "`python3 tool/report_completion_gaps.py --check`로 최신 여부를 확인한다.",
             "실행 계획은 `docs/porting/direct_port_strategy.md` 하나이며, 이 문서는 장부에서 생성한 검토 색인이다.",
             "미분류·부분 근거는 미구현 개수나 완료율이 아니다. 플랫폼 분기의 제외도 어댑터 검증 완료를 뜻하지 않는다.", "",
             f"게임 제어 지점 {s['game_control_sites']}개: 미분류 {s['unclassified']}개, 부분 근거 {s['partial']}개, 검증 완료 {s['verified']}개.",
             f"지도 쓰기 {s['unmapped_map_writes']}개는 개별 계약 연결이 없다. 테스트가 없는 것으로 해석하지 않는다.", "",
             "## 미분류가 남은 루틴", "",
             "| 원본 루틴 | 미분류 | 부분 근거 | 검증 완료 |", "| --- | ---: | ---: | ---: |"]
    for r in data["routines"]:
        if r.get("unclassified", 0):
            lines.append(f"| `{r['routine']}` | {r['unclassified']} | {r.get('partial', 0)} | {r.get('verified', 0)} |")
    lines += ["", "## 테스트에서 참조하지만 계약 연결이 없는 DOS 근거 후보", "",
              "파일명·테스트 참조만으로 원본 분기를 검증했다고 판정하지 않는다. 각 fixture의 source/scope와 실제 테스트 비교를 검토해야 한다.",
              "명시 연결과 계약 note의 파일명 언급을 모두 검색하며, 간접 helper 참조는 이 표에서 누락될 수 있다.", "",
              "| 근거 파일 | 테스트 후보 |", "| --- | --- |"]
    for f in data["native_fixture_candidates"]:
        if f["test_candidates"] and not f["explicit_contracts"] and not f["note_mentions"]:
            lines.append(f"| `{f['path']}` | " + " · ".join(f"`{t}`" for t in f["test_candidates"]) + " |")
    lines += ["", "## 상세 위치", "",
              "동명의 JSON에 미분류 지점의 원본 파일·행·루틴·계약 ID, 지도 쓰기의 좌표식·값,",
              "DOS fixture별 명시 연결·note 언급·테스트 후보를 모두 기록한다.", "",
              "최근 최종전/엔딩 근거는 기존 partial 계약의 supporting_evidence로 연결했다.",
              "최종전의 8개 닫힌 턴과 실제 엔딩 도달은 새 게임부터의 연속 재생, 모든 패배/도주 분기,",
              "전체 BGI/DAC·busy Thunder 난수 동등성을 증명하지 않는다.", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = summarize(build())
    serialized = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    markdown = report(data)
    if args.check:
        if not OUTPUT.exists() or not REPORT.exists() or OUTPUT.read_text(encoding="utf-8") != serialized or REPORT.read_text(encoding="utf-8") != markdown:
            raise SystemExit("Completion gap report drifted; run tool/report_completion_gaps.py")
        print("Completion gap report is current")
    else:
        OUTPUT.write_text(serialized, encoding="utf-8")
        REPORT.write_text(markdown, encoding="utf-8")
        print(json.dumps(data["summary"]))


if __name__ == "__main__":
    main()
