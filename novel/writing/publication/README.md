# 출판용 소제목 트리와 흐름도

장·소단락·분기·합류·조건부 반응을 원래 집필 JSON에서 연결한 편집 자료입니다.
작가용 전편 스포일러이며, 새 이야기 원본이나 출판 승인된 원고가 아닙니다.

- [오프라인 흐름도](../previews/publication-flow.html): 장별 목차와 외부 서비스 없는 SVG.
- [Markdown](generated/flow.md): 전체 장 연결, 소제목 트리, 장별 Mermaid 그래프, 종이책 순서 예시.
  GitHub에서 Mermaid를 그림으로 볼 수 있고 텍스트 트리는 일반 편집기에서도 읽을 수 있습니다.
- [구조 JSON](generated/flow.graph.json): 노드·선·장별 그래프·소속 트리와 원본 제목/본문/조건 참조.
- [선형 편집 순서 JSON](generated/linear-editions.json): 선택한 예시 경로의 실제 문단 순서와 본문 참조.
- [검사 결과](generated/coverage.json): 15장·88소단락·6결정·14선택지·96개 경로와 도식의 일치.

## 무엇을 고치는가

`flow.plan.json`은 표시용 결정/반응 소제목과 선형 출판 경로 예시를 정의합니다.
공용 양식은 `../templates/publication-flow.template.json`, 형식은 `../publication.schema.json`입니다.
원래 장 제목은 `../storyboard/chapters.json`, 소단락은 `chapter-subsections.json`,
실제 선택·조건·효과는 `../branches/series.json`에서 수정합니다. 여기에서 별도로
제목·본문·분기를 복사해 집필하거나 두 개의 이야기 원본을 유지하지 않습니다.

생성 JSON의 노드 ID는 안정된 소단락·결정·선택 ID에서 만듭니다. `label_ref`, `content_ref`,
`guard_ref`, `effects_ref`는 파일과 JSON Pointer로 원래 항목을 가리킵니다.
`label_rich_text`는 생성 시점의 참조 포함 제목 스냅샷이며 편집 입력이 아닙니다.
표시명 변경 후 사전과 도식을 재생성하면 같은 ID로 새 이름이 반영됩니다.

## 트리와 그래프를 구별하기

트리는 장 아래 어떤 소단락·결정·선택이 속하는지 보여 줍니다. 소속 트리를 실제 읽기 순서로
해석하지 않습니다. 그래프는 공통 주요 내용 → 결정 → 선택 뒤 이야기 → 합류 → 필수 결과 →
다음 본줄기를 보여 줍니다. 같은 소단락에 두 결정이 있으면 첫 합류 뒤 다음 결정을 거칩니다.

9장의 두 봉인은 두 순서의 문맥 복제 노드로 그립니다. 공유 노드를 양방향으로 이어 거짓
반복 경로를 만들지 않으며, 어느 순서에서도 두 블록을 모두 수행한 뒤 합류합니다.
문맥 노드의 `unit_id`는 같은 원본을 참조하므로 별도 원고를 복제하지 않습니다.

보라색 점선은 조건부 반응입니다. 별도 후속 연결 그림은 상태 키 공유와 실제 경로에서
선택·반응이 함께 발생한 경우만 표시합니다. 유일한 원인이나 모든 상황의 반응을 증명하는
것은 아닙니다. 원래 조건·동행·장비와 실행 도구가 최종 기준입니다.
25개 미구현 후보는 후보로만 표시하고 실제 분기 선으로 지어내지 않습니다.

## 종이책·전자책 편집에 사용하기

종이책은 배타 선택지를 모두 한 이야기처럼 이어 붙이지 않습니다. `linear_editions`에
수동 선택 ID를 지정하면 실제 재생 경로에서 소단락·선택 문단·조건부 반응·필수 결과의
순서를 뽑습니다. 자동 선택도 실제 문단 참조로 남고 미선택 이야기는 끼워 넣지 않습니다.

현재 `paper-draft`는 편집 예시이지 정사나 최종 출판 경로가 아닙니다. 모든 항목은
`page: null`, `prose_status: outline`, `publication_approved: false`입니다. 이후 본문을
완성하고 편집 경로를 확정한 뒤 실제 조판에서 페이지를 정해야 합니다.
대화 원문 전체와 장편 본문이 이 도식/예시 JSON 안에 완성되어 있다는 뜻은 아닙니다.
선택형 전자책에는 그래프 ID·조건·합류를 재사용하되 경로 공개와 원문 반영표를 먼저 검증합니다.

## 생성과 검사

`novel/`에서 실행합니다. 게임·서버·Mermaid 런타임·외부 네트워크가 필요 없습니다.

```sh
python -X utf8 tools/publication_flow.py validate
python -X utf8 tools/publication_flow.py export
python -X utf8 tools/publication_flow.py export --check
python -X utf8 tools/writing.py export
python -X utf8 tools/writing.py export --check
```

`writing.py`의 검증/생성에도 포함됩니다. 생성물과 매니페스트는 수동 편집하지 않습니다.
수동 출력 변경이 있으면 덮어쓰기를 거부하므로 변경을 보존하고 올바른 편집 입력으로 옮깁니다.
검사는 원래 96개 실행 경로를 도식에 대조하지만 산문의 의미·독자의 실제 읽음·출판 완성을
승인하지 않습니다. 작가용 자료는 기존 독자 웹에 통째로 게시하지 않습니다.
