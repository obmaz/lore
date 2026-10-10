# LORE 인터랙티브 소설 집필 자료

이 폴더만 복사해서 사용할 수 있는 집필 패키지다. 대사·선택지·분기·진행 자료와
검증 도구를 모두 포함한다. Python과 `requirements.txt`의 패키지만 필요하다.
원래 게임 저장소, Pascal 파일, Flutter 소스, 게임 자산을 읽지 않는다.

```text
novel/
├── materials/        원문·선택지·조건·진행 자료의 고정 JSON 스냅샷
├── characters/       인물별 이름·원작 정보·성향·말투·관계
├── authoring/        집필 스키마와 퀘스트별 원고
├── continuity/      공유 설정과 연속성 스키마
├── tools/           원문·인물·집필·경로 검증 도구
└── tests/           독립 실행과 분기·연속성 검사
```

## 먼저 읽을 자료

- [materials/quests.json](materials/quests.json): 18개 집필 단위와 공통 부록의 목록·연결.
- [materials/quests/lore_menace.json](materials/quests/lore_menace.json): 첫 의뢰의 실제 원문·조건.
- [characters/registry.json](characters/registry.json): 인물 카드 24개.
- [characters/README.md](characters/README.md): 인물 이름·성향·관계를 작성하는 방법.
- [authoring/README.md](authoring/README.md): 선택·본문·조건·원문 대응 규칙.
- [continuity/README.md](continuity/README.md): 이전 장면과의 일관성·설정 변경 추적.

원문 묶음은 14개 파일의 문자열 발생 2,483개를 보존한다. 같은 대사의 반복과
빈 문자열·UI·코드용 문자열도 포함하며 모두 등장인물의 대사라는 뜻은 아니다.
`materials/scripts.json`에는 원문 텍스트, 출력 문구, 변수 자리, 분기 구조와 안정된
발생 ID가 있다. 퀘스트 자료에는 실제 대사와 사건 근거가 함께 들어 있다.

`LORETALK.PAS` 같은 이름과 줄 번호는 JSON 안에 보관된 원문을 가리키는 출처 표식이다.
그 이름의 외부 파일을 열지 않는다. 원문 코드도 JSON 안의 보존 자료이고 실행하지 않는다.
현재 프롤로그 집필 원고는 구조 초안이며 미작성 대사와 접근 조건을 표시해 두었다.

## 독립 실행

복사한 `novel/` 폴더에서 다음을 실행한다. 게임 빌드는 필요 없다.

```bash
python3 -m pip install -r requirements.txt
python3 tools/materials.py
python3 tools/characters.py
python3 tools/validate_story_authoring.py
python3 tools/story_continuity.py --route enter_courtyard visit_prison accept_joe visit_lord
PYTHONPATH=tools python3 -m unittest discover -s tests
```

경로 자료에는 그 장면에 실제 등장하는 인물 카드도 포함한다. Joe를 영입하지 않은
성주 접견에서는 Joe 카드가 등장 인물로 전달되지 않는다. 인물의 `writing` 제안은
승인 상태를 유지하여 원작의 확정 설정과 섞이지 않도록 한다.

## 원문 자료와 원고의 수정

`materials/manifest.json`은 모든 원문 자료 파일의 SHA-256과 발생 개수를 기록한다.
검증은 먼저 스냅샷 무결성을 확인한다. 인물과 집필 원고는 자유롭게 편집하되,
원문 스냅샷은 매 집필마다 다시 생성하지 않는다. 인물 수정 시 그 인물과 인물 목록의
`revision`을 올리면 의존 장면이 재검토 대상으로 표시된다.

원작에서 다시 수입할 필요가 있을 때만 원래 저장소의 `tool/package_novel_material.py`를
수동 사용한다. 수입 도구는 집필 패키지의 실행 의존성이 아니다. 새 스냅샷의 내용과
해시가 달라지면 기존 원고의 승인 상태를 다시 검토해야 한다.
