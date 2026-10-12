# 모바일 리메이크 문서 안내

이 폴더는 이 프로젝트 내부 자료만 설명합니다. 아래 문서가 각 주제의 기준입니다.
README에는 실행 안내를, AGENTS에는 작업 제약을 둡니다. 작업 이력을 현재 설계와 섞지 않습니다.

| 문서 | 역할 |
| --- | --- |
| [개발 기준](porting/direct_port_strategy.md) | 목표·로직 소유권·수치 계약·실행 순서·최종 완료 게이트 |
| [원작 규칙 명세](game_specs.md) | 데이터 구조·장비·마법·전투 수식·시설·필드 규칙 |
| [실행 모델](source/execution_model.md) | 원본 모듈과 입력부터 효과까지의 실행 순서 |
| [절차 추적](source/procedure_traces.md) | 호출 중단·전투·표시·저장 경계의 구체 사례 |
| [상태 수명주기](source/state_lifecycle.md) | 퀘스트 카운터·지도 재구성·시작/불러오기·행동 비용 |
| [계약 장부](audits/contract_ledger.md) | 원본 위치·이식 코드·테스트의 연결 현황 |
| [완료 공백](audits/completion_gaps.md) | 미분류 루틴·미연결 DOS 근거 후보 |
| [도구 안내](../tool/README.md) | 추출·회귀·브라우저 검증 도구 |
| [원문 추출 자료](../story_material/README.md) | 자체 대사·선택·진행 자료 |
| [모바일 UI](mobile_ui.md) | 화면 비율·캐릭터 생성·팝업·전투·그래픽 스킨 |
| [대화 흐름](porting/dialogue_flow.md) | Dart 대화 정의·실행기·임무 연결 경계 |
| [음악 출처](source/music_sources.md) | 음악 대응과 미확정 출처 기록 |

## 검증 명령

명령은 프로젝트 루트에서 실행합니다. Windows에서도 UTF-8을 명시합니다.

```sh
flutter analyze
flutter test
python -X utf8 -m unittest discover -s tool
python -X utf8 tool/audit_lorespec.py repo_source/LORE_1993_src/LORESPEC.PAS --coverage
python -X utf8 tool/audit_messages.py
python -X utf8 tool/source_branch_inventory.py --check
python -X utf8 tool/audit_source_memory.py --check
python -X utf8 tool/build_port_contract_ledger.py --check
python -X utf8 tool/report_map_parity.py --check
python -X utf8 tool/report_port_workload.py --check
python -X utf8 tool/report_completion_gaps.py --check
python -X utf8 tool/source_map25_guardian.py --check
python -X utf8 tool/source_map26_final.py --check
python -X utf8 tool/source_map23_keep3.py --check
```

수치·저장 코드를 바꾸면 VM과 JavaScript의 숫자 호환성 및 릴리스 웹 빌드도 확인합니다.

```sh
dart run tool/verify_source_memory.dart
dart compile js -O2 tool/verify_source_memory.dart -o build/source-memory-verification.js
node build/source-memory-verification.js
python -X utf8 tool/build_web_release.py
```

## 문서 관리

`audits/`의 Markdown·JSON은 생성 도구가 관리하는 근거 자료입니다. 출력만 수동으로
고치지 않고 입력·도구를 검토한 뒤 재생성합니다. 등록 수는 완료율이 아니며,
예전 판정 문구는 실제 코드·근거와 함께 확인합니다. 원본 분석도 전체 경로 동등성의 증명은 아닙니다.

장부 해시는 파일 바이트 기준이므로 Windows Git의 자동 CRLF 변환으로 드리프트가 발생할 수 있습니다.
먼저 해당 파일의 원본 Git 바이트·줄바꿈을 비교합니다. Pascal 소스는 `.gitattributes`의 CRLF
규칙을 유지하며, 단순히 검사를 통과시키기 위해 자료 해시를 다시 기록하지 않습니다.
파일명 정렬의 플랫폼 차이로 JSON 목록 순서도 달라질 수 있으므로 항목 내용과 순서 차이를 구분합니다.

새 설계·소스 설명은 해당 기준 문서에 반영하고 같은 내용을 여러 곳에 복사하지 않습니다.
새 문서는 소문자 `snake_case`로, 같은 보고서의 Markdown·JSON은 같은 이름으로 관리합니다.
과거 커밋 목록은 `../COMMIT_HISTORY.txt`, 삭제된 문서의 이전 내용은 Git 이력에서 확인합니다.
