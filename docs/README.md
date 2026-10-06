# 프로젝트 문서

실행 계획은 [직접 이식 전략](porting/direct_port_strategy.md) 하나다.
나머지는 원본 분석, 검증 근거 또는 과거 검증 기록이다.

| 위치 | 내용 |
| --- | --- |
| [game_specs.md](game_specs.md) | 게임 동작과 알려진 이식 차이 |
| `porting/` | 현재 직접 이식 전략 |
| `source/` | 원본 실행 모델·절차 추적·상태 수명주기·규칙 구조 |
| `audits/` | 감사 보고서·계약 장부·근거 JSON |
| `reviews/` | 다른 이식 프로젝트의 구조 검토 |
| `verification/` | 날짜별 검증 기록 |

감사 자료의 최신 여부는 저장소 루트에서 아래 명령으로 확인한다.

```sh
python -X utf8 tool/source_branch_inventory.py --check
python -X utf8 tool/audit_source_memory.py --check
python -X utf8 tool/build_port_contract_ledger.py --check
python -X utf8 tool/report_map_parity.py --check
python -X utf8 tool/report_port_workload.py --check
```

새 문서의 파일명은 소문자 `snake_case`로 작성한다. 날짜별 기록은
`YYYY-MM-DD.md`를 사용하고, 같은 장부의 Markdown·JSON은 동일한 이름을 쓴다.
README·AGENTS와 원본 게임 자료의 파일명은 각각 도구 규칙과 원본 이름을 따른다.
