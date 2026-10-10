"""Summarize source-backed, executable parity scenarios by map.

This counts recorded scenarios and checkpoints, not all original branches.
Run the Flutter test to determine whether the recorded expectations pass.
"""

import json
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "test/fixtures/source_parity.json"


def report() -> str:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    by_map = defaultdict(list)
    for scenario in data["scenarios"]:
        by_map[scenario["input"]["map"]].append(scenario)

    lines = [
        "# 원본 근거 실행 시나리오",
        "",
        "명세 건수만 집계한다. 통과 여부는 `flutter test test/source_parity_test.dart`로 확인한다.",
        "원본 전체 분기 대비 완료율을 뜻하지 않는다.",
        "",
        "| 맵 | 시나리오 | 효과 검사 지점 | 미발동 검사 |",
        "| ---: | ---: | ---: | ---: |",
    ]
    for map_id, scenarios in sorted(by_map.items()):
        checkpoints = sum(len(s["trace"]) for s in scenarios)
        no_trigger = sum(s["selected"] is None for s in scenarios)
        lines.append(f"| {map_id} | {len(scenarios)} | {checkpoints} | {no_trigger} |")
    lines.append(
        f"| 합계 | {len(data['scenarios'])} | "
        f"{sum(len(s['trace']) for s in data['scenarios'])} | "
        f"{sum(s['selected'] is None for s in data['scenarios'])} |"
    )
    lines.extend(
        [
            "",
            f"원본 근거 구간: {len(data['sources'])}개.",
            "",
            "각 시나리오의 예상 효과는 사람이 Pascal 원본을 읽고 기록한다. "
            "테스트는 원본 해당 줄의 근거 문자열과 이식 엔진의 실행 결과를 검사한다.",
        ]
    )
    return "\n".join(lines)


if __name__ == "__main__":
    print(report())
