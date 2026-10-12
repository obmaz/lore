# 원문·진행 자료 추출

이 폴더는 이 프로젝트의 Pascal 소스에서 읽기 전용 연구 자료를 추출하는 출력 위치입니다.
현재 체크아웃에는 안내 문서만 있습니다. 아래 명령을 실행하면 JSON을 생성합니다.
게임 실행에는 이 출력이 필요하지 않으며 다른 프로젝트의 자료와 연결하지 않습니다.

명령은 이 프로젝트 루트에서 실행합니다.

```sh
python -X utf8 tool/export_story_material.py
python -X utf8 tool/export_story_material.py --check
```

| 생성 경로 | 내용 |
| --- | --- |
| `scripts.json` | 보존 문구·발생 ID·출력 사건·조건·분기 구조 |
| `coverage.json` | 원문 발생의 보존 범위와 누락 검사 |
| `progression.json` | 퀘스트 카운터·상태 변경의 정적 분석 |
| `quests.json` | 퀘스트 자료 묶음과 경로 연결 목록 |
| `quests/*.json` | 해당 묶음의 실제 원문·조건·선택·사건 근거 |

분류·원문 근거는 [tool/story_quest_plan.json](../tool/story_quest_plan.json)에서 관리합니다.
원문은 자체 `repo_source/LORE_1993_src/`에서 읽으며 추출 과정에서 실행하지 않습니다.
순서·좌표·강제/선택/병렬 연결은 정적 분석입니다. 모든 이동과 플레이 경로를 검증했다는 뜻은 아닙니다.
EVIL GOD와 MUDDY의 두 봉인은 순서가 자유여도 다음 관문에서 모두 요구됩니다.
반복·빈 문자열·UI·기술 문자열을 원문에서 제거하지 않습니다.

생성 JSON은 재생성 시 덮어씁니다. 편집용 초안은 이 폴더의 별도 파일에 두고
게임 코드·자산·원문·fixture와 섞지 않습니다. 도구 검증은 [tool/README.md](../tool/README.md)를 따릅니다.
