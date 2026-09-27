#!/usr/bin/env python3
"""Report source-backed execution coverage for all 27 original LORE maps.

This is an inventory, not a completion percentage. `--check` rejects stale
reports after source, script, or replay fixture changes.
"""

import argparse
import json
from collections import Counter
from pathlib import Path

from audit_lorespec import scan
from audit_loretalk import source_coordinates

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'PORT_MAP_PARITY.md'


def collect():
    maps = json.loads((ROOT / 'assets/data/maps.json').read_text())['maps']
    scripts = json.loads((ROOT / 'assets/data/scripts.json').read_text())['scripts']
    portals = json.loads((ROOT / 'assets/data/portals.json').read_text())['portals']
    spec_events, _ = scan(str(ROOT / 'repo_source/LORE_1993_src/LORESPEC.PAS'))
    talk_events = source_coordinates()
    source_scenarios = json.loads(
        (ROOT / 'test/fixtures/source_parity.json').read_text(),
    )['scenarios']
    entrances = json.loads(
        (ROOT / 'test/fixtures/source_entrance_replay.json').read_text(),
    )['cases']
    exits = json.loads(
        (ROOT / 'test/fixtures/source_exit_replay.json').read_text(),
    )['cases']
    gold_cases = json.loads(
        (ROOT / 'test/fixtures/source_gold_replay.json').read_text(),
    )['cases']
    map12_cases = json.loads(
        (ROOT / 'test/fixtures/map12_state_parity.json').read_text(),
    )['cases']
    spec_count = Counter(entry[0] for entry in spec_events)
    talk_count = Counter(entry[0] for entry in talk_events)
    active_count = Counter(s['map'] for s in scripts if not s.get('disabled'))
    portal_count = Counter(p['map'] for p in portals)
    scenario_count = Counter(s['input']['map'] for s in source_scenarios)
    entrance_count = Counter(case['map'] for case in entrances)
    exit_count = Counter(case['map'] for case in exits)
    state_replay_count = Counter(case['map'] for case in [*gold_cases, *map12_cases])
    replay_count = {}
    for path in (ROOT / 'test/fixtures').glob('map*_route_parity.json'):
        data = json.loads(path.read_text())
        replay_count[data['map']] = len(data['cases'])
    return [{
        'map': item['mapId'],
        'name': item['fileName'],
        'spec': spec_count[item['mapId']],
        'talk': talk_count[item['mapId']],
        'active': active_count[item['mapId']],
        'portals': portal_count[item['mapId']],
        'scenarios': scenario_count[item['mapId']],
        'entrances': entrance_count[item['mapId']],
        'exits': exit_count[item['mapId']],
        'stateReplays': state_replay_count[item['mapId']],
        'replays': replay_count.get(item['mapId'], 0),
    } for item in maps]


def render(rows):
    if len(rows) != 27 or {row['map'] for row in rows} != set(range(1, 28)):
        raise ValueError('the original 27 maps are not all registered')
    lines = [
        '# 27개 맵 원본 실행 비교 현황',
        '',
        '`python3 tool/report_map_parity.py --check`로 최신 상태를 확인한다.',
        '좌표와 활성 스크립트 수는 목록 검사다. 원본 진입·출구 재생은 목적지만 확인한다.',
        '원본 실행 시나리오와 상태·경로 재생도',
        '전체 분기를 증명하지 않는다. 따라서 모든 맵의 완료 판정은 아직 보류한다.',
        '',
        '| 맵 | 파일 | 원본 특수 좌표 | 원본 대화 좌표 | 활성 스크립트 | 포털 | 원본 진입 재생 | 원본 출구 재생 | 원본 근거 시나리오 | 자동 상태 재생 | 자동 경로 재생 | 판정 |',
        '| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |',
    ]
    for row in rows:
        evidence = '부분 실행 비교' if row['entrances'] or row['exits'] or row['scenarios'] or row['stateReplays'] or row['replays'] else '실행 비교 없음'
        lines.append(
            f"| {row['map']} | {row['name']} | {row['spec']} | {row['talk']} | "
            f"{row['active']} | {row['portals']} | {row['entrances']} | {row['exits']} | {row['scenarios']} | {row['stateReplays']} | "
            f"{row['replays']} | {evidence} |"
        )
    lines += [
        '',
        f"합계: 원본 특수 좌표 {sum(r['spec'] for r in rows)}, "
        f"대화 좌표 {sum(r['talk'] for r in rows)}, "
        f"원본 진입 재생 {sum(r['entrances'] for r in rows)}, "
        f"원본 출구 재생 {sum(r['exits'] for r in rows)}, "
        f"원본 근거 시나리오 {sum(r['scenarios'] for r in rows)}, "
        f"자동 상태 재생 {sum(r['stateReplays'] for r in rows)}, "
        f"자동 경로 재생 {sum(r['replays'] for r in rows)}.",
        '',
        '다음 단계: 실행 비교가 없는 맵의 상태·선택·전투 분기를 추가하고, 각',
        '원본 분기와 대응 테스트를 연결한다. 좌표 수를 완료율로 환산하지 않는다.',
        '',
    ]
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    report = render(collect())
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != report:
            raise SystemExit('PORT_MAP_PARITY.md is stale')
    else:
        OUTPUT.write_text(report)


if __name__ == '__main__':
    main()
