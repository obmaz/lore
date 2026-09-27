# LORE 스크립트 분기 감사

`python3 tool/audit_script_branches.py > PORT_BRANCH_AUDIT.md`로 재생성한다.
원본 좌표 추출은 `audit_lorespec.py`의 휴리스틱이며 46개 `on/at` 좌표만
잡는다. 조건식, 동적 좌표, 원본의 모든 실행 경로를 증명하지 않는다.
가림 판정은 앞선 무조건·반복 규칙이 뒤 규칙의 전 좌표를 덮는 경우만 확정한다.

전체 598개 / 활성 303개 / 비활성 295개 / 원본 추출 좌표 46개.

## 맵별 현황

| 맵 | 크기 | 활성 | 비활성 | step | talk | portal | enter |
| ---: | :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 100×100 | 2 | 1 | 2 | 0 | 0 | 0 |
| 2 | 100×100 | 0 | 0 | 0 | 0 | 0 | 0 |
| 3 | 100×100 | 0 | 0 | 0 | 0 | 0 | 0 |
| 4 | 100×100 | 6 | 5 | 6 | 0 | 0 | 0 |
| 5 | 50×50 | 1 | 0 | 0 | 0 | 1 | 0 |
| 6 | 100×100 | 58 | 31 | 5 | 52 | 0 | 1 |
| 7 | 75×75 | 29 | 4 | 2 | 26 | 0 | 1 |
| 8 | 75×75 | 0 | 4 | 0 | 0 | 0 | 0 |
| 9 | 50×50 | 34 | 13 | 6 | 27 | 1 | 0 |
| 10 | 50×75 | 17 | 2 | 2 | 14 | 0 | 1 |
| 11 | 50×50 | 12 | 13 | 11 | 0 | 0 | 1 |
| 12 | 50×75 | 6 | 8 | 5 | 0 | 0 | 1 |
| 13 | 100×100 | 2 | 9 | 2 | 0 | 0 | 0 |
| 14 | 50×50 | 9 | 13 | 9 | 0 | 0 | 0 |
| 15 | 50×75 | 13 | 11 | 13 | 0 | 0 | 0 |
| 16 | 40×40 | 4 | 12 | 4 | 0 | 0 | 0 |
| 17 | 100×100 | 15 | 11 | 15 | 0 | 0 | 0 |
| 18 | 50×100 | 13 | 16 | 13 | 0 | 0 | 0 |
| 19 | 50×50 | 20 | 14 | 20 | 0 | 0 | 0 |
| 20 | 50×100 | 14 | 48 | 14 | 0 | 0 | 0 |
| 21 | 50×50 | 12 | 41 | 3 | 0 | 9 | 0 |
| 22 | 50×50 | 6 | 15 | 4 | 0 | 1 | 1 |
| 23 | 50×50 | 3 | 7 | 2 | 0 | 1 | 0 |
| 24 | 50×50 | 7 | 2 | 0 | 6 | 0 | 1 |
| 25 | 50×50 | 8 | 14 | 7 | 0 | 1 | 0 |
| 26 | 50×50 | 2 | 0 | 1 | 0 | 0 | 1 |
| 27 | 30×50 | 10 | 1 | 2 | 8 | 0 | 0 |

## 검토 필요 항목

### 원본 추출 좌표 중 활성 규칙/포털에 없는 곳: 0개

- 없음

### 활성 규칙·포털이 모두 겹치지 않는 비활성 항목: 0개

- 없음

### 포털과 좌표가 겹치고 이동 목적지가 일치하는 비활성 항목: 56개

- 맵 7 `spec-7-L306` step (50, *) — LORESPEC.PAS:306
- 맵 7 `spec-7-L306-1` step (*, 71) — LORESPEC.PAS:306
- 맵 8 `spec-8-L332` step (50, *) — LORESPEC.PAS:332
- 맵 8 `spec-8-L332x` step (*, *) — LORESPEC.PAS:332
- 맵 8 `spec-8-L332-1` step (*, 71) — LORESPEC.PAS:332
- 맵 9 `spec-9-L354-1` step (*, 5) — LORESPEC.PAS:354
- 맵 9 `spec-9-L354-2` step (*, 5) — LORESPEC.PAS:354
- 맵 9 `spec-9-L354-1xx` step (*, 46) — LORESPEC.PAS:354
- 맵 10 `spec-10-L444-1` step (*, 71) — LORESPEC.PAS:444
- 맵 11 `spec-11-L465xxxxxxx` step (*, 46) — LORESPEC.PAS:465
- 맵 12 `spec-12-L560-1` step (*, 71) — LORESPEC.PAS:560
- 맵 13 `spec-13-L669-1` step (*, 96) — LORESPEC.PAS:669
- 맵 14 `spec-14-L814-1` step (*, 46) — LORESPEC.PAS:814
- 맵 15 `spec-15-L879-1` step (*, 71) — LORESPEC.PAS:879
- 맵 16 `spec-16-L966-1` step (*, 36) — LORESPEC.PAS:966
- 맵 19 `spec-19-L1366-1` step (*, 46) — LORESPEC.PAS:1366
- 맵 20 `spec-20-L1475-1` step (*, 96) — LORESPEC.PAS:1475
- 맵 21 `spec-21-L1760-1` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-2` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-3` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-4` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-5` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-6` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-7` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-8` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-9` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-10` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-11` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-12` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-13` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-14` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-15` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-16` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-17` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-18` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-19` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-20` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-21` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-22` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-23` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-24` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-25` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-26` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-27` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-28` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-29` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-30` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-31` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-32` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-33` step (*, 46) — LORESPEC.PAS:1760
- 맵 22 `spec-22-L1816-1` step (*, 46) — LORESPEC.PAS:1816
- 맵 22 `spec-22-L1816-2` step (*, 46) — LORESPEC.PAS:1816
- 맵 22 `spec-22-L1816-3` step (*, 46) — LORESPEC.PAS:1816
- 맵 23 `spec-23-L1880-1` step (*, 46) — LORESPEC.PAS:1880
- 맵 24 `spec-24-L1980-1` step (*, 46) — LORESPEC.PAS:1980
- 맵 25 `spec-25-L1995-1` step (*, 46) — LORESPEC.PAS:1995

### 포털과 겹치는 진입 거절 이동 분기: 17개

- 맵 7 `spec-7-L306-2` step (*, 71) — LORESPEC.PAS:306
- 맵 8 `spec-8-L332-2` step (*, 71) — LORESPEC.PAS:332
- 맵 9 `spec-9-L354-3` step (*, 5) — LORESPEC.PAS:354
- 맵 9 `spec-9-L354-2xx` step (*, 46) — LORESPEC.PAS:354
- 맵 10 `spec-10-L444-2` step (*, 71) — LORESPEC.PAS:444
- 맵 12 `spec-12-L560-2` step (*, 71) — LORESPEC.PAS:560
- 맵 13 `spec-13-L669-2` step (*, 96) — LORESPEC.PAS:669
- 맵 14 `spec-14-L814-2` step (*, 46) — LORESPEC.PAS:814
- 맵 15 `spec-15-L879-2` step (*, 71) — LORESPEC.PAS:879
- 맵 16 `spec-16-L966-2` step (*, 36) — LORESPEC.PAS:966
- 맵 19 `spec-19-L1366-2` step (*, 46) — LORESPEC.PAS:1366
- 맵 20 `spec-20-L1475-2` step (*, 96) — LORESPEC.PAS:1475
- 맵 21 `spec-21-L1760-34` step (*, 46) — LORESPEC.PAS:1760
- 맵 22 `spec-22-L1816-4` step (*, 46) — LORESPEC.PAS:1816
- 맵 23 `spec-23-L1880-2` step (*, 46) — LORESPEC.PAS:1880
- 맵 24 `spec-24-L1980-2` step (*, 46) — LORESPEC.PAS:1980
- 맵 25 `spec-25-L1995-2` step (*, 46) — LORESPEC.PAS:1995

### 포털과 겹치는 차단·플래그 분기: 4개

- 맵 21 `spec-21-L1760-35` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-36` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-37` step (*, 46) — LORESPEC.PAS:1760
- 맵 21 `spec-21-L1760-38` step (*, 46) — LORESPEC.PAS:1760

### 포털과 겹치지만 효과를 분류하지 못한 분기: 0개

- 없음

### 앞선 반복 규칙에 확정적으로 가린 규칙: 0개

- 없음

### 동시에 만족할 수 없는 조건: 0개

- 없음

### 맵 밖 또는 잘못된 좌표: 0개

- 없음

### 중복 ID: 0개

- 없음

### 효과 없는 스크립트: 0개

- 없음

이동 목적지 일치는 부수 효과(전투·플래그·지도 변화)의 동등성을 증명하지 않는다.
포털 거절·차단 분기는 UI 및 전투 실행 경로와 별도 대조해야 한다.

### 같은 ID를 공유하는 조건별 포털 분기

- keep1-exit-guard (4개 조건별 변형)
- portal-21-22-lavagate (5개 조건별 변형)

### 비활성으로 보관한 분기

실행되지 않는 원본 보관 항목이다. 아래 목록은 이식 완료 증거가 아니다.

- 맵 9 `gold-9-10-24` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 9 `gold-9-12-26` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 9 `gold-9-15-25` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 9 `gold-9-16-23` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 9 `gold-9-18-27` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 11 `gold-11-20-30` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 11 `gold-11-18-36` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 11 `gold-11-35-32` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 11 `gold-11-33-36` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 11 `gold-11-35-14` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 11 `gold-11-14-16` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 11 `gold-11-37-12` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 14 `gold-14-6-6` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 14 `gold-14-18-10` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 14 `gold-14-6-44` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 14 `gold-14-31-30` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 14 `gold-14-31-8` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 14 `gold-14-14-28` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 6 `castle-chest-62-82` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 4 `map4-spacejump-40-18` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 4 `draconian-lecture` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 4 `draconian-join` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 6 `spec-6-L190-1-1` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-1-2` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-1-3` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-1-4` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-1-5` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-1-6` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-1-7` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-1-8` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-1-9` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-1-10` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-1-11` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-1-12` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 11 `spec-11-L465-1` LORESPEC.PAS:465 — 장비 지급(choosewhom) 미해석; 조건 미지원: k = 0; 미지원: asyouwish;; 조건 미지원: player[k].class = 5; 미지원: with player[k] do begin; 미지원: weapon := 3;; 미지원: wea_power := 12;; 미지원: if class = 1 then wea_power := wea_power + round(wea_power *
- 맵 11 `spec-11-L465-2` LORESPEC.PAS:465 — 장비 지급(choosewhom) 미해석; 조건 미지원: k = 0; 미지원: asyouwish;; 조건 미지원: player[k].class = 5; 미지원: with player[k] do begin; 미지원: weapon := 3;; 미지원: wea_power := 12;; 미지원: if class = 1 then wea_power := wea_power + round(wea_power *
- 맵 11 `spec-11-L465-3` LORESPEC.PAS:465 — 장비 지급(choosewhom) 미해석; 조건 미지원: k = 0; 미지원: asyouwish;; 조건 미지원: player[k].class = 5; 미지원: with player[k] do begin; 미지원: weapon := 3;; 미지원: wea_power := 12;; 미지원: if class = 1 then wea_power := wea_power + round(wea_power *
- 맵 11 `mummy-room` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 14 `golden-shield-menace` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 14 `menace-center-25-8` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 14 `menace-center-26-8` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 15 `golden-shield-quake` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 15 `golden-armor-quake` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 15 `quake-boss-room` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 17 `map17-hidra` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 18 `map18-huge-dragon` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 17 `map17-shortcut-72` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 19 `spec-19-L1366-1xx` LORESPEC.PAS:1366 — 조건/효과 미기록
- 맵 19 `spec-19-L1366-2xx` LORESPEC.PAS:1366 — 조건/효과 미기록
- 맵 19 `spec-19-L1366-1xxx` LORESPEC.PAS:1366 — 조건 미지원: not odd(party.etc[40]); 미지원: for j := 27 to 37 do; 영역 변형(좌표 변수): for i := 25 to 27 do map[i,j] := 44;; 미지원: party.etc[40] := (random(7)+1) shl 1;
- 맵 19 `spec-19-L1366-2xxx` LORESPEC.PAS:1366 — 조건 미지원: not odd(party.etc[40]); 미지원: for j := 27 to 37 do; 영역 변형(좌표 변수): for i := 25 to 27 do map[i,j] := 44;; 미지원: party.etc[40] := (random(7)+1) shl 1;
- 맵 19 `spec-19-L1366-3` LORESPEC.PAS:1366 — 조건 미지원: not odd(party.etc[40]); 미지원: for j := 27 to 37 do; 영역 변형(좌표 변수): for i := 25 to 27 do map[i,j] := 44;; 미지원: party.etc[40] := (random(7)+1) shl 1;
- 맵 17 `map17-passage-38` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 22 `spec-22-L1816-2x` LORESPEC.PAS:1816 — 조건/효과 미기록
- 맵 22 `spec-22-L1816-3x` LORESPEC.PAS:1816 — 조건/효과 미기록
- 맵 22 `keep2-ambush-25-18` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 23 `spec-23-L1880x` LORESPEC.PAS:1880 — 미지원: for j := 7 to 34 do; 미지원: for i := 12 to 39 do; 조건 미지원: map[i,j] = 0; 미지원: map[i,j] := 39;
- 맵 25 `spec-25-L1995-1xx` LORESPEC.PAS:1995 — 조건/효과 미기록
- 맵 25 `spec-25-L1995-2xx` LORESPEC.PAS:1995 — 조건/효과 미기록
- 맵 25 `spec-25-L1995-1xxx` LORESPEC.PAS:1995 — 조건/효과 미기록
- 맵 25 `spec-25-L1995-2xxx` LORESPEC.PAS:1995 — 조건/효과 미기록
- 맵 25 `keep25-corridor-15-34` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 25 `keep25-corridor-36-34` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 21 `spec-21-L1760-1x` LORESPEC.PAS:1760 — 조건 미지원: not (odd(party.etc[40]) and odd(party.etc[41])); 미지원: enemynumber := random(4)+3;; 미지원: j := map[x,y];; 조건 미지원: j = 0
- 맵 21 `spec-21-L1760-2x` LORESPEC.PAS:1760 — 조건 미지원: not (odd(party.etc[40]) and odd(party.etc[41])); 미지원: enemynumber := random(4)+3;; 미지원: j := map[x,y];; 조건 미지원: j = 0
- 맵 21 `spec-21-L1760-3x` LORESPEC.PAS:1760 — 조건 미지원: not (odd(party.etc[40]) and odd(party.etc[41])); 미지원: enemynumber := random(4)+3;; 미지원: j := map[x,y];; 조건 미지원: j = 0
- 맵 18 `lockup-passage-22-41` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 18 `lockup-guardian-21-41` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 12 `spec-12-L560-1xx` LORESPEC.PAS:560 — 조건 미지원: x = 18
- 맵 12 `spec-12-L560-2xx` LORESPEC.PAS:560 — 조건 미지원: x = 18
- 맵 20 `den7-quiz-y91` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 20 `den7-quiz-y75` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 20 `spec-20-L1475-1xx` LORESPEC.PAS:1475 — 미지원: i := random(8);; 미지원: case i of; 미지원: 0 : Print(7,'문> 이 게임의 배경은 4개의 대륙이다');; 미지원: 1 : Print(7,'문> Ancient Evil은 응징되어야 한다');; 미지원: 2 : Print(7,'문> Lord Ahn만이 유일한 Semi-God이다');; 미지원: 3 : Print(7,'문> 이 세계의 모든 악은 응징되어야 한다');; 미지원: 4 : Print(7,'문> 이 게임의 제작자는 안 영기이다');; 미지원: 5 : Print(7,'문> 게임속의 인물은
- 맵 20 `spec-20-L1475-2xx` LORESPEC.PAS:1475 — 미지원: i := random(8);; 미지원: case i of; 미지원: 0 : Print(7,'문> 이 게임의 배경은 4개의 대륙이다');; 미지원: 1 : Print(7,'문> Ancient Evil은 응징되어야 한다');; 미지원: 2 : Print(7,'문> Lord Ahn만이 유일한 Semi-God이다');; 미지원: 3 : Print(7,'문> 이 세계의 모든 악은 응징되어야 한다');; 미지원: 4 : Print(7,'문> 이 게임의 제작자는 안 영기이다');; 미지원: 5 : Print(7,'문> 게임속의 인물은
- 맵 20 `spec-20-L1475` LORESPEC.PAS:1475 — 조건 미지원: map[x,y] = 0; 미지원: y := 80
- 맵 20 `spec-20-L1475x` LORESPEC.PAS:1475 — 조건 미지원: map[x,y] = 0; 미지원: y := 63
- 맵 20 `den7-torch-y18` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 20 `den7-minotaur-y48` LORESPEC.PAS (파일 추정) — 조건/효과 미기록
- 맵 20 `spec-20-L1475-1xxxx` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-2xxxx` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-3` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-4` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-5` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-6` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-7` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-8` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-9` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-10` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-11` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-12` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-13` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-14` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-15` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-16` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-17` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-18` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-19` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-20` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-21` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-22` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-23` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-24` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-25` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-26` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-27` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-28` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-29` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-30` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-31` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-32` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-33` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-34` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-35` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 20 `spec-20-L1475-36` LORESPEC.PAS:1475 — 미지원: for i := 4 to 6 do; 미지원: if j > 1 then; 미지원: for k := 0 to 1 do; 미지원: if j < 3 then delay(2000);; 미지원: if i > 1 then begin; 미지원: if i < 4 then delay(1500);; 조건 미지원: enemy[7].dead
- 맵 6 `spec-6-L190-1` LORESPEC.PAS:190 — 미지원: for i := 1 to 6 do; 미지원: with player[i] do; 조건 미지원: (name <> '') and (weapon = 0) and (class <> 5); 미지원: weapon := 1;; 미지원: wea_power := 5;; 조건 미지원: wantexit; 미지원: aux := soundon;; 미지원: for i := y - 4 to y - 1 do begin; 미지원: map[x,pred(i)] := 44;; 미지원: map[x,i] := 48;; 미지원: else asyouwish;
- 맵 6 `spec-6-L190-2` LORESPEC.PAS:190 — 미지원: for i := 1 to 6 do; 미지원: with player[i] do; 조건 미지원: (name <> '') and (weapon = 0) and (class <> 5); 미지원: weapon := 1;; 미지원: wea_power := 5;; 조건 미지원: wantexit; 미지원: aux := soundon;; 미지원: for i := y - 4 to y - 1 do begin; 미지원: map[x,pred(i)] := 44;; 미지원: map[x,i] := 48;; 미지원: else asyouwish;
- 맵 6 `spec-6-L190-3` LORESPEC.PAS:190 — 미지원: for i := 1 to 6 do; 미지원: with player[i] do; 조건 미지원: (name <> '') and (weapon = 0) and (class <> 5); 미지원: weapon := 1;; 미지원: wea_power := 5;; 조건 미지원: wantexit; 미지원: aux := soundon;; 미지원: for i := y - 4 to y - 1 do begin; 미지원: map[x,pred(i)] := 44;; 미지원: map[x,i] := 48;; 미지원: else asyouwish;
- 맵 1 `spec-1-L25-seq2` LORESPEC.PAS:25 — 조건 미지원: party.food > 155; 미지원: party.food := 255; 미지원: x := x - x1; y := y - y1;
- 맵 4 `spec-4-L37-1x` LORESPEC.PAS:37 — 미지원: aux := SoundOn; SoundOn := false;
- 맵 4 `spec-4-L37-2x` LORESPEC.PAS:37 — 미지원: aux := SoundOn; SoundOn := false;
- 맵 6 `spec-6-L190-2-1` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-2-2` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-2-3` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-2-4` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-2-5` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-2-6` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-2-7` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-2-8` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-2-9` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-2-10` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-2-11` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-2-12` LORESPEC.PAS:190 — 조건 미지원: player[6].name = 'Mad Joe'; 미지원: player[6].name := '';
- 맵 6 `spec-6-L190-1x` LORESPEC.PAS:190 — 미지원: aux := soundon;; 미지원: for i := y - 4 to y - 1 do begin; 미지원: map[x,pred(i)] := 44;; 미지원: map[x,i] := 48;; 미지원: else asyouwish;
- 맵 6 `spec-6-L190-2x` LORESPEC.PAS:190 — 미지원: aux := soundon;; 미지원: for i := y - 4 to y - 1 do begin; 미지원: map[x,pred(i)] := 44;; 미지원: map[x,i] := 48;; 미지원: else asyouwish;
- 맵 6 `spec-6-L190-3x` LORESPEC.PAS:190 — 미지원: aux := soundon;; 미지원: for i := y - 4 to y - 1 do begin; 미지원: map[x,pred(i)] := 44;; 미지원: map[x,i] := 48;; 미지원: else asyouwish;
- 맵 7 `spec-7-L306` LORESPEC.PAS:306 — 조건 미지원: wantenter('GROUND GATE')
- 맵 7 `spec-7-L306x` LORESPEC.PAS:306 — 조건/효과 미기록
- 맵 7 `spec-7-L306-1` LORESPEC.PAS:306 — 조건 미지원: wantexit
- 맵 7 `spec-7-L306-2` LORESPEC.PAS:306 — 조건 미지원: wantexit
- 맵 8 `spec-8-L332` LORESPEC.PAS:332 — 조건 미지원: wantenter('GROUND GATE')
- 맵 8 `spec-8-L332x` LORESPEC.PAS:332 — 조건/효과 미기록
- 맵 8 `spec-8-L332-1` LORESPEC.PAS:332 — 조건 미지원: wantexit
- 맵 8 `spec-8-L332-2` LORESPEC.PAS:332 — 조건 미지원: wantexit
- 맵 9 `spec-9-L354-1` LORESPEC.PAS:354 — 조건 미지원: wantenter('SWAMP GATE'); 미지원: face := 1;; 미지원: for i := 4 downto 0 do begin; 미지원: if i > 0 then begin
- 맵 9 `spec-9-L354-2` LORESPEC.PAS:354 — 조건 미지원: wantenter('SWAMP GATE'); 미지원: face := 1;; 미지원: for i := 4 downto 0 do begin; 미지원: if i > 0 then begin
- 맵 9 `spec-9-L354-3` LORESPEC.PAS:354 — 조건 미지원: wantenter('SWAMP GATE'); 미지원: face := 1;; 미지원: for i := 4 downto 0 do begin; 미지원: if i > 0 then begin
- 맵 9 `spec-9-L354-1x` LORESPEC.PAS:354 — 미지원: face := 1;; 미지원: for i := 4 downto 0 do begin; 미지원: if i > 0 then begin
- 맵 9 `spec-9-L354-2x` LORESPEC.PAS:354 — 미지원: face := 1;; 미지원: for i := 4 downto 0 do begin; 미지원: if i > 0 then begin
- 맵 9 `spec-9-L354-3x` LORESPEC.PAS:354 — 미지원: face := 1;; 미지원: for i := 4 downto 0 do begin; 미지원: if i > 0 then begin
- 맵 9 `spec-9-L354-1xx` LORESPEC.PAS:354 — 조건 미지원: wantexit
- 맵 9 `spec-9-L354-2xx` LORESPEC.PAS:354 — 조건 미지원: wantexit
- 맵 10 `spec-10-L444-1` LORESPEC.PAS:444 — 조건 미지원: wantexit
- 맵 10 `spec-10-L444-2` LORESPEC.PAS:444 — 조건 미지원: wantexit
- 맵 11 `spec-11-L465xxxxxxx` LORESPEC.PAS:465 — 조건 미지원: wantexit
- 맵 11 `spec-11-L465xxxxxxxx` LORESPEC.PAS:465 — 조건/효과 미기록
- 맵 12 `spec-12-L560-1` LORESPEC.PAS:560 — 조건 미지원: wantexit
- 맵 12 `spec-12-L560-2` LORESPEC.PAS:560 — 조건 미지원: wantexit
- 맵 12 `spec-12-L560-1x` LORESPEC.PAS:560 — 조건 미지원: x = 33
- 맵 12 `spec-12-L560-2x` LORESPEC.PAS:560 — 조건 미지원: x = 33
- 맵 12 `spec-12-L560` LORESPEC.PAS:560 — 미지원: hany := 20;; 미지원: case k of; 미지원: 0 : begin; 미지원: 1 : begin; 미지원: k := ReturnJoinMember;; 미지원: if k = 1 then begin; 미지원: with player[k] do begin; 미지원: name := 'Rigel';; 미지원: class := 7;; 미지원: weapon := 4;; 미지원: shield := 1;; 미지원: armor := 1;; 미지원: wea_power := 10;; 미지원: shi_power := 1;; 미지원: ar
- 맵 12 `spec-12-L560x` LORESPEC.PAS:560 — 미지원: x := x - x1; y := y - y1;
- 맵 13 `spec-13-L669-1` LORESPEC.PAS:669 — 조건 미지원: wantexit
- 맵 13 `spec-13-L669-2` LORESPEC.PAS:669 — 조건 미지원: wantexit
- 맵 13 `spec-13-L669-1x` LORESPEC.PAS:669 — 조건/효과 미기록
- 맵 13 `spec-13-L669-2x` LORESPEC.PAS:669 — 조건/효과 미기록
- 맵 13 `spec-13-L669` LORESPEC.PAS:669 — 미지원: for j := 71 to 81 do; 미지원: if map[i,j] = 52 then map[i,j] := 44;; 미지원: if map[i,j] in [40,51] then map[i,j] := 42;; 미지원: allright := FALSE;; 미지원: x1 := sgn(81-x);; 미지원: if x1 = 0 then allright := TRUE; 미지원: else begin; 미지원: if x1 = 1 then face := 6 else face := 7;; 미지원: x := x + x1;; 미지원: y1 :=
- 맵 13 `spec-13-L669-1xx` LORESPEC.PAS:669 — 적 배치(계산식): joinenemy(i, i+49); 조건 미지원: not enemy[3].dead
- 맵 13 `spec-13-L669-2xx` LORESPEC.PAS:669 — 적 배치(계산식): joinenemy(i, i+49); 조건 미지원: not enemy[3].dead
- 맵 13 `spec-13-L669-3` LORESPEC.PAS:669 — 적 배치(계산식): joinenemy(i, i+49); 조건 미지원: not enemy[3].dead
- 맵 13 `spec-13-L669-4` LORESPEC.PAS:669 — 적 배치(계산식): joinenemy(i, i+49); 조건 미지원: not enemy[3].dead
- 맵 14 `spec-14-L814-1` LORESPEC.PAS:814 — 조건 미지원: wantexit
- 맵 14 `spec-14-L814-2` LORESPEC.PAS:814 — 조건 미지원: wantexit
- 맵 14 `spec-14-L814-1x` LORESPEC.PAS:814 — 조건/효과 미기록
- 맵 14 `spec-14-L814-2x` LORESPEC.PAS:814 — 조건/효과 미기록
- 맵 15 `spec-15-L879-1` LORESPEC.PAS:879 — 조건 미지원: wantexit
- 맵 15 `spec-15-L879-2` LORESPEC.PAS:879 — 조건 미지원: wantexit
- 맵 15 `spec-15-L879-1x` LORESPEC.PAS:879 — 조건/효과 미기록
- 맵 15 `spec-15-L879-2x` LORESPEC.PAS:879 — 조건/효과 미기록
- 맵 15 `spec-15-L879-1xxx` LORESPEC.PAS:879 — 미지원: map[x,48] := 44;; 미지원: map[x,47] := 44;
- 맵 15 `spec-15-L879-2xxx` LORESPEC.PAS:879 — 미지원: map[x,48] := 44;; 미지원: map[x,47] := 44;
- 맵 15 `spec-15-L879-1xx` LORESPEC.PAS:879 — 미지원: map[x,48] := 44;; 미지원: map[x,47] := 44;
- 맵 15 `spec-15-L879-2xx` LORESPEC.PAS:879 — 미지원: map[x,48] := 44;; 미지원: map[x,47] := 44;
- 맵 16 `spec-16-L966-1` LORESPEC.PAS:966 — 조건 미지원: wantexit
- 맵 16 `spec-16-L966-2` LORESPEC.PAS:966 — 조건 미지원: wantexit
- 맵 16 `spec-16-L966-1x` LORESPEC.PAS:966 — 조건/효과 미기록
- 맵 16 `spec-16-L966-2x` LORESPEC.PAS:966 — 조건/효과 미기록
- 맵 16 `spec-16-L966-1xxx` LORESPEC.PAS:966 — 미지원: s := '';; 미지원: case party.etc[37] of; 미지원: 2 : s := '한';; 미지원: 1 : s := '두';; 미지원: 0 : s := '세';; 미지원: enemynumber := 3 - party.etc[37];; 미지원: party.etc[37] := 3; 미지원: j := 0;; 미지원: for i := 1 to enemynumber do if not enemy[i].dead then inc(j; 미지원: party.etc[37] := 3 - j;
- 맵 16 `spec-16-L966-2xxx` LORESPEC.PAS:966 — 미지원: s := '';; 미지원: case party.etc[37] of; 미지원: 2 : s := '한';; 미지원: 1 : s := '두';; 미지원: 0 : s := '세';; 미지원: enemynumber := 3 - party.etc[37];; 미지원: party.etc[37] := 3; 미지원: j := 0;; 미지원: for i := 1 to enemynumber do if not enemy[i].dead then inc(j; 미지원: party.etc[37] := 3 - j;
- 맵 16 `spec-16-L966-3x` LORESPEC.PAS:966 — 미지원: s := '';; 미지원: case party.etc[37] of; 미지원: 2 : s := '한';; 미지원: 1 : s := '두';; 미지원: 0 : s := '세';; 미지원: enemynumber := 3 - party.etc[37];; 미지원: party.etc[37] := 3; 미지원: j := 0;; 미지원: for i := 1 to enemynumber do if not enemy[i].dead then inc(j; 미지원: party.etc[37] := 3 - j;
- 맵 16 `spec-16-L966-4x` LORESPEC.PAS:966 — 미지원: s := '';; 미지원: case party.etc[37] of; 미지원: 2 : s := '한';; 미지원: 1 : s := '두';; 미지원: 0 : s := '세';; 미지원: enemynumber := 3 - party.etc[37];; 미지원: party.etc[37] := 3; 미지원: j := 0;; 미지원: for i := 1 to enemynumber do if not enemy[i].dead then inc(j; 미지원: party.etc[37] := 3 - j;
- 맵 16 `spec-16-L966-1xx` LORESPEC.PAS:966 — 미지원: s := '';; 미지원: case party.etc[37] of; 미지원: 2 : s := '한';; 미지원: 1 : s := '두';; 미지원: 0 : s := '세';; 미지원: enemynumber := 3 - party.etc[37];; 미지원: party.etc[37] := 3; 미지원: j := 0;; 미지원: for i := 1 to enemynumber do if not enemy[i].dead then inc(j; 미지원: party.etc[37] := 3 - j;
- 맵 16 `spec-16-L966-2xx` LORESPEC.PAS:966 — 미지원: s := '';; 미지원: case party.etc[37] of; 미지원: 2 : s := '한';; 미지원: 1 : s := '두';; 미지원: 0 : s := '세';; 미지원: enemynumber := 3 - party.etc[37];; 미지원: party.etc[37] := 3; 미지원: j := 0;; 미지원: for i := 1 to enemynumber do if not enemy[i].dead then inc(j; 미지원: party.etc[37] := 3 - j;
- 맵 16 `spec-16-L966-3` LORESPEC.PAS:966 — 미지원: s := '';; 미지원: case party.etc[37] of; 미지원: 2 : s := '한';; 미지원: 1 : s := '두';; 미지원: 0 : s := '세';; 미지원: enemynumber := 3 - party.etc[37];; 미지원: party.etc[37] := 3; 미지원: j := 0;; 미지원: for i := 1 to enemynumber do if not enemy[i].dead then inc(j; 미지원: party.etc[37] := 3 - j;
- 맵 16 `spec-16-L966-4` LORESPEC.PAS:966 — 미지원: s := '';; 미지원: case party.etc[37] of; 미지원: 2 : s := '한';; 미지원: 1 : s := '두';; 미지원: 0 : s := '세';; 미지원: enemynumber := 3 - party.etc[37];; 미지원: party.etc[37] := 3; 미지원: j := 0;; 미지원: for i := 1 to enemynumber do if not enemy[i].dead then inc(j; 미지원: party.etc[37] := 3 - j;
- 맵 17 `spec-17-L1010-1` LORESPEC.PAS:1010 — 조건 미지원: wantexit
- 맵 17 `spec-17-L1010-2` LORESPEC.PAS:1010 — 조건 미지원: wantexit
- 맵 17 `spec-17-L1010-1x` LORESPEC.PAS:1010 — 조건/효과 미기록
- 맵 17 `spec-17-L1010-2x` LORESPEC.PAS:1010 — 조건/효과 미기록
- 맵 17 `spec-17-L1010x` LORESPEC.PAS:1010 — 조건/효과 미기록
- 맵 17 `spec-17-L1010xx` LORESPEC.PAS:1010 — 조건/효과 미기록
- 맵 17 `spec-17-L1010xxx` LORESPEC.PAS:1010 — 조건/효과 미기록
- 맵 17 `spec-17-L1010xxxx` LORESPEC.PAS:1010 — 미지원: for j := 47 to 57 do; 미지원: for i := 71 to 82 do; 조건 미지원: map[i,j] = 40; 미지원: map[i,j] := 50;
- 맵 18 `spec-18-L1174-1` LORESPEC.PAS:1174 — 조건 미지원: wantexit
- 맵 18 `spec-18-L1174-2` LORESPEC.PAS:1174 — 조건 미지원: wantexit
- 맵 18 `spec-18-L1174-1x` LORESPEC.PAS:1174 — 조건/효과 미기록
- 맵 18 `spec-18-L1174-2x` LORESPEC.PAS:1174 — 조건/효과 미기록
- 맵 18 `spec-18-L1174-1xxx` LORESPEC.PAS:1174 — 미지원: j := player[1].level[3];; 미지원: for i := 2 to 6 do; 조건 미지원: player[i].name <> ''; 조건 미지원: player[i].level[3] > j; 미지원: j := player[i].level[3];; 조건 미지원: j < 5; 조건 미지원: k = 2; 미지원: k := ReturnJoinMember;; 조건 미지원: k = 1; 미지원: with player[k] do begin; 미지원: name := 'Spica';; 미지원: sex := female;; 미지원
- 맵 18 `spec-18-L1174-2xxx` LORESPEC.PAS:1174 — 미지원: j := player[1].level[3];; 미지원: for i := 2 to 6 do; 조건 미지원: player[i].name <> ''; 조건 미지원: player[i].level[3] > j; 미지원: j := player[i].level[3];; 조건 미지원: j < 5; 조건 미지원: k = 2; 미지원: k := ReturnJoinMember;; 조건 미지원: k = 1; 미지원: with player[k] do begin; 미지원: name := 'Spica';; 미지원: sex := female;; 미지원
- 맵 18 `spec-18-L1174-3` LORESPEC.PAS:1174 — 미지원: j := player[1].level[3];; 미지원: for i := 2 to 6 do; 조건 미지원: player[i].name <> ''; 조건 미지원: player[i].level[3] > j; 미지원: j := player[i].level[3];; 조건 미지원: j < 5; 조건 미지원: k = 2; 미지원: k := ReturnJoinMember;; 조건 미지원: k = 1; 미지원: with player[k] do begin; 미지원: name := 'Spica';; 미지원: sex := female;; 미지원
- 맵 18 `spec-18-L1174-4` LORESPEC.PAS:1174 — 미지원: j := player[1].level[3];; 미지원: for i := 2 to 6 do; 조건 미지원: player[i].name <> ''; 조건 미지원: player[i].level[3] > j; 미지원: j := player[i].level[3];; 조건 미지원: j < 5; 조건 미지원: k = 2; 미지원: k := ReturnJoinMember;; 조건 미지원: k = 1; 미지원: with player[k] do begin; 미지원: name := 'Spica';; 미지원: sex := female;; 미지원
- 맵 18 `spec-18-L1174-5` LORESPEC.PAS:1174 — 미지원: j := player[1].level[3];; 미지원: for i := 2 to 6 do; 조건 미지원: player[i].name <> ''; 조건 미지원: player[i].level[3] > j; 미지원: j := player[i].level[3];; 조건 미지원: j < 5; 조건 미지원: k = 2; 미지원: k := ReturnJoinMember;; 조건 미지원: k = 1; 미지원: with player[k] do begin; 미지원: name := 'Spica';; 미지원: sex := female;; 미지원
- 맵 18 `spec-18-L1174-6` LORESPEC.PAS:1174 — 미지원: j := player[1].level[3];; 미지원: for i := 2 to 6 do; 조건 미지원: player[i].name <> ''; 조건 미지원: player[i].level[3] > j; 미지원: j := player[i].level[3];; 조건 미지원: j < 5; 조건 미지원: k = 2; 미지원: k := ReturnJoinMember;; 조건 미지원: k = 1; 미지원: with player[k] do begin; 미지원: name := 'Spica';; 미지원: sex := female;; 미지원
- 맵 18 `spec-18-L1174-7` LORESPEC.PAS:1174 — 미지원: j := player[1].level[3];; 미지원: for i := 2 to 6 do; 조건 미지원: player[i].name <> ''; 조건 미지원: player[i].level[3] > j; 미지원: j := player[i].level[3];; 조건 미지원: j < 5; 조건 미지원: k = 2; 미지원: k := ReturnJoinMember;; 조건 미지원: k = 1; 미지원: with player[k] do begin; 미지원: name := 'Spica';; 미지원: sex := female;; 미지원
- 맵 18 `spec-18-L1174-8` LORESPEC.PAS:1174 — 미지원: j := player[1].level[3];; 미지원: for i := 2 to 6 do; 조건 미지원: player[i].name <> ''; 조건 미지원: player[i].level[3] > j; 미지원: j := player[i].level[3];; 조건 미지원: j < 5; 조건 미지원: k = 2; 미지원: k := ReturnJoinMember;; 조건 미지원: k = 1; 미지원: with player[k] do begin; 미지원: name := 'Spica';; 미지원: sex := female;; 미지원
- 맵 18 `spec-18-L1174-9` LORESPEC.PAS:1174 — 미지원: j := player[1].level[3];; 미지원: for i := 2 to 6 do; 조건 미지원: player[i].name <> ''; 조건 미지원: player[i].level[3] > j; 미지원: j := player[i].level[3];; 조건 미지원: j < 5; 조건 미지원: k = 2; 미지원: k := ReturnJoinMember;; 조건 미지원: k = 1; 미지원: with player[k] do begin; 미지원: name := 'Spica';; 미지원: sex := female;; 미지원
- 맵 19 `spec-19-L1366-1` LORESPEC.PAS:1366 — 조건 미지원: wantexit
- 맵 19 `spec-19-L1366-2` LORESPEC.PAS:1366 — 조건 미지원: wantexit
- 맵 19 `spec-19-L1366-1x` LORESPEC.PAS:1366 — 조건/효과 미기록
- 맵 19 `spec-19-L1366-2x` LORESPEC.PAS:1366 — 조건/효과 미기록
- 맵 19 `spec-19-L1366` LORESPEC.PAS:1366 — 미지원: enemynumber := random(3) + 3;; 적 지정(미상): with enemy[i] do begin; 미지원: E_number := 25;; 미지원: hp := 210;; 미지원: level := 7;
- 맵 19 `spec-19-L1366-1xxxx` LORESPEC.PAS:1366 — 미지원: map[x,y-1] := 49;; 미지원: j := party.etc[40] shr 1;; 조건 미지원: j <> (x-10) div 4; 미지원: hp := 210;
- 맵 19 `spec-19-L1366-2xxxx` LORESPEC.PAS:1366 — 미지원: map[x,y-1] := 49;; 미지원: j := party.etc[40] shr 1;; 조건 미지원: j <> (x-10) div 4; 미지원: hp := 210;
- 맵 19 `spec-19-L1366-3x` LORESPEC.PAS:1366 — 미지원: map[x,y-1] := 49;; 미지원: j := party.etc[40] shr 1;; 조건 미지원: j <> (x-10) div 4; 미지원: hp := 210;
- 맵 19 `spec-19-L1366-4` LORESPEC.PAS:1366 — 미지원: map[x,y-1] := 49;; 미지원: j := party.etc[40] shr 1;; 조건 미지원: j <> (x-10) div 4; 미지원: hp := 210;
- 맵 20 `spec-20-L1475-1` LORESPEC.PAS:1475 — 조건 미지원: wantexit
- 맵 20 `spec-20-L1475-2` LORESPEC.PAS:1475 — 조건 미지원: wantexit
- 맵 20 `spec-20-L1475-1x` LORESPEC.PAS:1475 — 조건/효과 미기록
- 맵 20 `spec-20-L1475-2x` LORESPEC.PAS:1475 — 조건/효과 미기록
- 맵 21 `spec-21-L1760-1` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-2` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-3` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-4` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-5` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-6` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-7` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-8` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-9` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-10` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-11` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-12` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-13` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-14` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-15` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-16` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-17` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-18` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-19` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-20` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-21` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-22` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-23` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-24` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-25` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-26` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-27` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-28` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-29` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-30` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-31` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-32` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-33` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-34` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-35` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-36` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-37` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 21 `spec-21-L1760-38` LORESPEC.PAS:1760 — 조건 미지원: wantexit; 미지원: j := 1;; 미지원: inc(j);; 조건 미지원: j = 1; 미지원: enemynumber := j+4;; 조건 미지원: enemy[1].dead; 조건 미지원: enemy[2].dead; 조건 미지원: enemy[1].dead and enemy[2].dead
- 맵 22 `spec-22-L1816-1` LORESPEC.PAS:1816 — 조건 미지원: wantexit; 미지원: j := random(5) + 42;; 조건 미지원: j = 42; 미지원: j := 35;; 적 배치(계산식): joinenemy(i, j); 조건 미지원: enemy[7].dead
- 맵 22 `spec-22-L1816-2` LORESPEC.PAS:1816 — 조건 미지원: wantexit; 미지원: j := random(5) + 42;; 조건 미지원: j = 42; 미지원: j := 35;; 적 배치(계산식): joinenemy(i, j); 조건 미지원: enemy[7].dead
- 맵 22 `spec-22-L1816-3` LORESPEC.PAS:1816 — 조건 미지원: wantexit; 미지원: j := random(5) + 42;; 조건 미지원: j = 42; 미지원: j := 35;; 적 배치(계산식): joinenemy(i, j); 조건 미지원: enemy[7].dead
- 맵 22 `spec-22-L1816-4` LORESPEC.PAS:1816 — 조건 미지원: wantexit; 미지원: j := random(5) + 42;; 조건 미지원: j = 42; 미지원: j := 35;; 적 배치(계산식): joinenemy(i, j); 조건 미지원: enemy[7].dead
- 맵 22 `spec-22-L1816-1-1` LORESPEC.PAS:1816 — 조건/효과 미기록
- 맵 22 `spec-22-L1816-1-2` LORESPEC.PAS:1816 — 조건/효과 미기록
- 맵 22 `spec-22-L1816-1-3` LORESPEC.PAS:1816 — 조건/효과 미기록
- 맵 22 `spec-22-L1816-1-4` LORESPEC.PAS:1816 — 조건/효과 미기록
- 맵 22 `spec-22-L1816-2-1` LORESPEC.PAS:1816 — 조건/효과 미기록
- 맵 22 `spec-22-L1816-2-2` LORESPEC.PAS:1816 — 조건/효과 미기록
- 맵 22 `spec-22-L1816-2-3` LORESPEC.PAS:1816 — 조건/효과 미기록
- 맵 22 `spec-22-L1816-2-4` LORESPEC.PAS:1816 — 조건/효과 미기록
- 맵 23 `spec-23-L1880` LORESPEC.PAS:1880 — 조건/효과 미기록
- 맵 23 `spec-23-L1880-1` LORESPEC.PAS:1880 — 조건 미지원: wantexit
- 맵 23 `spec-23-L1880-2` LORESPEC.PAS:1880 — 조건 미지원: wantexit
- 맵 23 `spec-23-L1880-1x` LORESPEC.PAS:1880 — 미지원: else turn_mind(i,i);; 미지원: aux := FALSE;; 미지원: if party.etc[6] = 255 then exit;; 미지원: if party.etc[6] > 0 then begin; 미지원: else aux := TRUE;; 미지원: for j := 25 to 27 do; 영역 변형(좌표 변수): for i := 24 to 27 do map[i,j] := 46;
- 맵 23 `spec-23-L1880-2x` LORESPEC.PAS:1880 — 미지원: else turn_mind(i,i);; 미지원: aux := FALSE;; 미지원: if party.etc[6] = 255 then exit;; 미지원: if party.etc[6] > 0 then begin; 미지원: else aux := TRUE;; 미지원: for j := 25 to 27 do; 영역 변형(좌표 변수): for i := 24 to 27 do map[i,j] := 46;
- 맵 23 `spec-23-L1880-3` LORESPEC.PAS:1880 — 미지원: else turn_mind(i,i);; 미지원: aux := FALSE;; 미지원: if party.etc[6] = 255 then exit;; 미지원: if party.etc[6] > 0 then begin; 미지원: else aux := TRUE;; 미지원: for j := 25 to 27 do; 영역 변형(좌표 변수): for i := 24 to 27 do map[i,j] := 46;
- 맵 24 `spec-24-L1980-1` LORESPEC.PAS:1980 — 조건 미지원: wantexit
- 맵 24 `spec-24-L1980-2` LORESPEC.PAS:1980 — 조건 미지원: wantexit
- 맵 25 `spec-25-L1995-1` LORESPEC.PAS:1995 — 조건 미지원: wantexit
- 맵 25 `spec-25-L1995-2` LORESPEC.PAS:1995 — 조건 미지원: wantexit
- 맵 25 `spec-25-L1995-1x` LORESPEC.PAS:1995 — 미지원: if (i = 0) and (j > 1) then; 미지원: for i := 1 to 6 do; 조건 미지원: player[i].name <> ''; 미지원: player[i].class := 10;
- 맵 25 `spec-25-L1995-2x` LORESPEC.PAS:1995 — 미지원: if (i = 0) and (j > 1) then; 미지원: for i := 1 to 6 do; 조건 미지원: player[i].name <> ''; 미지원: player[i].class := 10;
- 맵 25 `spec-25-L1995-3` LORESPEC.PAS:1995 — 미지원: if (i = 0) and (j > 1) then; 미지원: for i := 1 to 6 do; 조건 미지원: player[i].name <> ''; 미지원: player[i].class := 10;
- 맵 25 `spec-25-L1995-4` LORESPEC.PAS:1995 — 미지원: if (i = 0) and (j > 1) then; 미지원: for i := 1 to 6 do; 조건 미지원: player[i].name <> ''; 미지원: player[i].class := 10;
- 맵 25 `spec-25-L1995-5` LORESPEC.PAS:1995 — 미지원: if (i = 0) and (j > 1) then; 미지원: for i := 1 to 6 do; 조건 미지원: player[i].name <> ''; 미지원: player[i].class := 10;
- 맵 25 `spec-25-L1995-6` LORESPEC.PAS:1995 — 미지원: if (i = 0) and (j > 1) then; 미지원: for i := 1 to 6 do; 조건 미지원: player[i].name <> ''; 미지원: player[i].class := 10;
- 맵 27 `spec-27-L2202-seq` LORESPEC.PAS:2202 — 조건 미지원: wantexit; 조건 미지원: y < 25; 미지원: inc(y) else dec(y);

## 활성 분기 시나리오 목록

참 조건은 `require` 그대로이며, 거짓 탐침은 해당 조건을 뒤집는 대표 입력이다.
거짓 탐침의 실제 후속 규칙은 실행 엔진의 우선순위 및 다른 조건에 따라 달라진다.

### 맵 1

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `spec-1-L25-seq`<br>LORESPEC.PAS:25 | step (*, *) | {"tileAtPlayerZero":true,"flagNot":"etc32_bit8"} | flagNot etc32_bit8 → 추가; tileAtPlayerZero True → 타일을 0 이외로 | food, flag:etc32_bit8, stepBack |
| `spec-1-L25-seq3`<br>LORESPEC.PAS:25 | step (*, *) | {"tileAtPlayerZero":true,"flag":"etc32_bit8"} | flag etc32_bit8 → 제거; tileAtPlayerZero True → 타일을 0 이외로 | stepBack |

### 맵 4

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `ancient-evil-first`<br>LORESPEC.PAS (파일 추정) | step (20, 39) | {"flagNot":"ancientEvilMet"} | flagNot ancientEvilMet → 추가 | flag:ancientEvilMet |
| `ancient-evil-later`<br>LORESPEC.PAS (파일 추정) | step (20, 39) | {"flag":"ancientEvilMet"} | flag ancientEvilMet → 제거 | teleport |
| `spec-4-L37`<br>LORESPEC.PAS:37 | step (40, 18) | 조건 없음 | 조건 없음 | teleport |
| `spec-4-L37-1`<br>LORESPEC.PAS:37 | step (26, 16) | {"notAllFlags":["draconianMet","etc5"]} | notAllFlags → draconianMet 추가 | 대사/연출 |
| `spec-4-L37-2`<br>LORESPEC.PAS:37 | step (26, 16) | {"allFlags":["etc5"],"notAllFlags":["draconianMet"]} | allFlags → etc5 제거; notAllFlags → draconianMet 추가 | join:draconian, flag:draconianMet, block |
| `spec-4-L37-3`<br>LORESPEC.PAS:37 | step (26, 16) | {"allFlags":["draconianMet"]} | allFlags → draconianMet 제거 | block |

### 맵 5

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `portal-5-23-frostdragon`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"flagNot":"frostDragonDefeated"} | flagNot frostDragonDefeated → 추가 | battle(적 7, 승리 플래그, 적 선공, 도주 분기), block |

### 맵 6

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `madjoe-join`<br>LORETALK.PAS (파일 추정) | talk (40, 15) | {"flagNot":"madJoeJoined"} | flagNot madJoeJoined → 추가 | flag:madJoeJoined, join:mad_joe |
| `spec-6-L190`<br>LORESPEC.PAS:190 | step (62, 82) | {"tileAtPlayerZero":true} | tileAtPlayerZero True → 타일을 0 이외로 | gold, setTile |
| `prison-battle-first`<br>LORESPEC.PAS (파일 추정) | step (51..52, 12) | {"flag":"madJoeJoined","flagNot":"prisonBattleStarted","tileAtPlayerZero":true} | flag madJoeJoined → 제거; flagNot prisonBattleStarted → 추가; tileAtPlayerZero True → 타일을 0 이외로 | flag:prisonBattleStarted, battle(적 2, 적 선공), setTile, flag:prisonBattleDone |
| `prison-battle-return`<br>LORESPEC.PAS (파일 추정) | step (51..52, 12) | {"allFlags":["madJoeJoined","prisonBattleStarted"],"flagNot":"prisonBattleDone","tileAtPlayerZero":true} | flagNot prisonBattleDone → 추가; tileAtPlayerZero True → 타일을 0 이외로; allFlags → madJoeJoined 제거 | battle(적 7, 적 선공), setTile, flag:prisonBattleDone |
| `castle-exit-skeleton`<br>LORESPEC.PAS (파일 추정) | step (*, 95) | {"flagNot":"skeletonJoined"} | flagNot skeletonJoined → 추가 | join:skeleton, flag:skeletonJoined |
| `talk-6-9-64`<br>LORETALK.PAS (파일 추정) | talk (9, 64) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-72-73`<br>LORETALK.PAS (파일 추정) | talk (72, 73) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-58-74`<br>LORETALK.PAS (파일 추정) | talk (58, 74) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-63-27`<br>LORETALK.PAS (파일 추정) | talk (63, 27) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-90-82`<br>LORETALK.PAS (파일 추정) | talk (90, 82) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-94-68`<br>LORETALK.PAS (파일 추정) | talk (94, 68) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-19-53`<br>LORETALK.PAS (파일 추정) | talk (19, 53) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-13-27`<br>LORETALK.PAS (파일 추정) | talk (13, 27) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-18-27`<br>LORETALK.PAS (파일 추정) | talk (18, 27) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-21-33`<br>LORETALK.PAS (파일 추정) | talk (21, 33) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-10-30`<br>LORETALK.PAS (파일 추정) | talk (10, 30) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-13-32`<br>LORETALK.PAS (파일 추정) | talk (13, 32) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-15-35`<br>LORETALK.PAS (파일 추정) | talk (15, 35) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-18-33`<br>LORETALK.PAS (파일 추정) | talk (18, 33) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-21-36`<br>LORETALK.PAS (파일 추정) | talk (21, 36) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-18-38`<br>LORETALK.PAS (파일 추정) | talk (18, 38) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-72-78`<br>LORETALK.PAS (파일 추정) | talk (72, 78) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-24-50`<br>LORETALK.PAS (파일 추정) | talk (24, 50) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-24-54`<br>LORETALK.PAS (파일 추정) | talk (24, 54) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-13-55`<br>LORETALK.PAS (파일 추정) | talk (13, 55) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-50-11`<br>LORETALK.PAS (파일 추정) | talk (50, 11) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-53-11`<br>LORETALK.PAS (파일 추정) | talk (53, 11) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-41-10`<br>LORETALK.PAS (파일 추정) | talk (41, 10) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-63-10`<br>LORETALK.PAS (파일 추정) | talk (63, 10) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-60-15`<br>LORETALK.PAS (파일 추정) | talk (60, 15) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-51-14`<br>LORETALK.PAS (파일 추정) | talk (51, 14) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-83-27`<br>LORETALK.PAS (파일 추정) | talk (83, 27) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-6-51-72`<br>LORETALK.PAS (파일 추정) | talk (51, 72) | {"flagNot":"menaceInfoGiven"} | flagNot menaceInfoGiven → 추가 | flag:menaceInfoGiven |
| `talk-6-51-72-b`<br>LORETALK.PAS (파일 추정) | talk (51, 72) | {"flag":"menaceInfoGiven"} | flag menaceInfoGiven → 제거 | 대사/연출 |
| `talk-6-63-76`<br>LORETALK.PAS (파일 추정) | talk (63, 76) | {"flagNot":"jrAntaresSecretFound"} | flagNot jrAntaresSecretFound → 추가 | setTileArea, setTile, flag:jrAntaresSecretFound |
| `talk-6-42-78`<br>LORETALK.PAS (파일 추정) | talk (42, 78) | {"flagNot":"weaponRoomVisited"} | flagNot weaponRoomVisited → 추가 | 대사/연출 |
| `talk-6-42-78-b`<br>LORETALK.PAS (파일 추정) | talk (42, 78) | {"flag":"weaponRoomVisited"} | flag weaponRoomVisited → 제거 | 대사/연출 |
| `talk-6-42-80`<br>LORETALK.PAS (파일 추정) | talk (42, 80) | {"flagNot":"weaponRoomVisited"} | flagNot weaponRoomVisited → 추가 | 대사/연출 |
| `talk-6-42-80-b`<br>LORETALK.PAS (파일 추정) | talk (42, 80) | {"flag":"weaponRoomVisited"} | flag weaponRoomVisited → 제거 | 대사/연출 |
| `talk-6-50-51-a`<br>LORETALK.PAS (파일 추정) | talk (50, 51) | {"flag":"loreChallengeAccepted"} | flag loreChallengeAccepted → 제거 | 대사/연출 |
| `talk-6-50-51-b`<br>LORETALK.PAS (파일 추정) | talk (50, 51) | {"quest":{"name":"lordahn","lt":3},"flagNot":"loreChallengeAccepted"} | flagNot loreChallengeAccepted → 추가; lordahn 단계 → 조건 밖 값 | 대사/연출 |
| `talk-6-50-51-c`<br>LORETALK.PAS (파일 추정) | talk (50, 51) | {"quest":{"name":"lordahn","gte":3},"flagNot":"loreChallengeAccepted"} | flagNot loreChallengeAccepted → 추가; lordahn 단계 → 조건 밖 값 | setTile, flag:loreChallengeAccepted |
| `talk-6-52-51-a`<br>LORETALK.PAS (파일 추정) | talk (52, 51) | {"flag":"loreChallengeAccepted"} | flag loreChallengeAccepted → 제거 | 대사/연출 |
| `talk-6-52-51-b`<br>LORETALK.PAS (파일 추정) | talk (52, 51) | {"quest":{"name":"lordahn","lt":3},"flagNot":"loreChallengeAccepted"} | flagNot loreChallengeAccepted → 추가; lordahn 단계 → 조건 밖 값 | 대사/연출 |
| `talk-6-52-51-c`<br>LORETALK.PAS (파일 추정) | talk (52, 51) | {"quest":{"name":"lordahn","gte":3},"flagNot":"loreChallengeAccepted"} | flagNot loreChallengeAccepted → 추가; lordahn 단계 → 조건 밖 값 | setTile, flag:loreChallengeAccepted |
| `talk-6-51-87`<br>LORETALK.PAS (파일 추정) | talk (51, 87) | {"flagNot":"loreChallengeBlessed"} | flagNot loreChallengeBlessed → 추가 | setTileArea, flag:loreChallengeBlessed |
| `talk-6-51-87-b`<br>LORETALK.PAS (파일 추정) | talk (51, 87) | {"flag":"loreChallengeBlessed"} | flag loreChallengeBlessed → 제거 | 대사/연출 |
| `talk-6-gate-a`<br>LORETALK.PAS (파일 추정) | talk (48..54, 31..37) | {"quest":{"name":"lordahn","eq":0}} | lordahn 단계 → 조건 밖 값 | 대사/연출 |
| `talk-6-gate-b`<br>LORETALK.PAS (파일 추정) | talk (48..54, 31..37) | {"quest":{"name":"lordahn","gte":1}} | lordahn 단계 → 조건 밖 값 | 대사/연출 |
| `talk-6-51-28-q0`<br>LORETALK.PAS (파일 추정) | talk (51, 28) | {"quest":{"name":"lordahn","eq":0}} | lordahn 단계 → 조건 밖 값 | questStep:lordahn |
| `talk-6-51-28-q1`<br>LORETALK.PAS (파일 추정) | talk (51, 28) | {"quest":{"name":"lordahn","eq":1}} | lordahn 단계 → 조건 밖 값 | questStep:lordahn |
| `talk-6-51-28-q2`<br>LORETALK.PAS (파일 추정) | talk (51, 28) | {"quest":{"name":"lordahn","eq":2}} | lordahn 단계 → 조건 밖 값 | questStep:lordahn |
| `talk-6-51-28-q3`<br>LORETALK.PAS (파일 추정) | talk (51, 28) | {"quest":{"name":"lordahn","eq":3}} | lordahn 단계 → 조건 밖 값 | 대사/연출 |
| `talk-6-51-28-q4`<br>LORETALK.PAS (파일 추정) | talk (51, 28) | {"quest":{"name":"lordahn","eq":4}} | lordahn 단계 → 조건 밖 값 | exp, questStep:lordahn |
| `talk-6-51-28-q5`<br>LORETALK.PAS (파일 추정) | talk (51, 28) | {"quest":{"name":"lordahn","eq":5}} | lordahn 단계 → 조건 밖 값 | questStep:lordahn |
| `talk-6-51-28-q6`<br>LORETALK.PAS (파일 추정) | talk (51, 28) | {"quest":{"name":"lordahn","eq":6}} | lordahn 단계 → 조건 밖 값 | 대사/연출 |
| `lore-weapon-room`<br>LORESPEC.PAS (파일 추정) | step (41, 79) | {"flagNot":"weaponRoomVisited"} | flagNot weaponRoomVisited → 추가 | flag:weaponRoomVisited, setTile, nudge, equip |
| `enter-6-castle-gate`<br>LOREENT.PAS (파일 추정) | enter (*, *) | 조건 없음 | 조건 없음 | setTile, setTileArea |

### 맵 7

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `lastditch-passwall-left`<br>LORESPEC.PAS (파일 추정) | step (30, 8..11) | {"tileAtPlayerZero":true} | tileAtPlayerZero True → 타일을 0 이외로 | setTileArea |
| `lastditch-passwall-right`<br>LORESPEC.PAS (파일 추정) | step (32, 8..11) | {"tileAtPlayerZero":true} | tileAtPlayerZero True → 타일을 0 이외로 | setTileArea |
| `talk-7-51-55`<br>LORETALK.PAS (파일 추정) | talk (51, 55) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-7-8-44`<br>LORETALK.PAS (파일 추정) | talk (8, 44) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-7-68-35`<br>LORETALK.PAS (파일 추정) | talk (68, 35) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-7-43-9`<br>LORETALK.PAS (파일 추정) | talk (43, 9) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-7-65-10`<br>LORETALK.PAS (파일 추정) | talk (65, 10) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-7-14-68`<br>LORETALK.PAS (파일 추정) | talk (14, 68) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-7-57-42`<br>LORETALK.PAS (파일 추정) | talk (57, 42) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-7-44-34`<br>LORETALK.PAS (파일 추정) | talk (44, 34) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-7-32-56`<br>LORETALK.PAS (파일 추정) | talk (32, 56) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-7-36-19-a`<br>LORETALK.PAS (파일 추정) | talk (36, 19) | {"quest":{"name":"lastditch","eq":0}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `talk-7-36-19-b`<br>LORETALK.PAS (파일 추정) | talk (36, 19) | {"quest":{"name":"lastditch","gte":1}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `talk-7-36-21-a`<br>LORETALK.PAS (파일 추정) | talk (36, 21) | {"quest":{"name":"lastditch","eq":0}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `talk-7-36-21-b`<br>LORETALK.PAS (파일 추정) | talk (36, 21) | {"quest":{"name":"lastditch","gte":1}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `talk-7-41-18-a`<br>LORETALK.PAS (파일 추정) | talk (41, 18) | {"quest":{"name":"lastditch","eq":0}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `talk-7-41-18-b`<br>LORETALK.PAS (파일 추정) | talk (41, 18) | {"quest":{"name":"lastditch","gte":1}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `talk-7-41-20-a`<br>LORETALK.PAS (파일 추정) | talk (41, 20) | {"quest":{"name":"lastditch","eq":0}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `talk-7-41-20-b`<br>LORETALK.PAS (파일 추정) | talk (41, 20) | {"quest":{"name":"lastditch","gte":1}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `talk-7-41-22-a`<br>LORETALK.PAS (파일 추정) | talk (41, 22) | {"quest":{"name":"lastditch","eq":0}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `talk-7-41-22-b`<br>LORETALK.PAS (파일 추정) | talk (41, 22) | {"quest":{"name":"lastditch","gte":1}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `talk-7-40-41-a`<br>LORETALK.PAS (파일 추정) | talk (40, 41) | {"quest":{"name":"lastditch","eq":0}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `talk-7-40-41-b`<br>LORETALK.PAS (파일 추정) | talk (40, 41) | {"quest":{"name":"lastditch","gte":1}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `polaris-join`<br>LORETALK.PAS (파일 추정) | talk (37, 41) | {"quest":{"name":"lastditch","lt":2}} | lastditch 단계 → 조건 밖 값 | flag:polarisJoined, join:polaris, setTile |
| `talk-7-38-17-q0`<br>LORETALK.PAS (파일 추정) | talk (38, 17) | {"quest":{"name":"lastditch","eq":0}} | lastditch 단계 → 조건 밖 값 | questStep:lastditch |
| `talk-7-38-17-q1`<br>LORETALK.PAS (파일 추정) | talk (38, 17) | {"quest":{"name":"lastditch","eq":1}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `talk-7-38-17-q2`<br>LORETALK.PAS (파일 추정) | talk (38, 17) | {"quest":{"name":"lastditch","eq":2}} | lastditch 단계 → 조건 밖 값 | exp, questStep:lastditch |
| `talk-7-38-17-q3`<br>LORETALK.PAS (파일 추정) | talk (38, 17) | {"quest":{"name":"lastditch","eq":3}} | lastditch 단계 → 조건 밖 값 | 대사/연출 |
| `enter-7-polaris-tile`<br>LOREENT.PAS (파일 추정) | enter (*, *) | {"partyMember":"Polaris"} | partyMember Polaris → 현재 파티에서 제외 | setTile |

### 맵 9

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `portal-9-13-swamp-gate`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"flagNot":"etc35_bit6"} | flagNot etc35_bit6 → 추가 | flag:etc35_bit6 |
| `spec-9-L354`<br>LORESPEC.PAS:354 | step (10, 24) | {"notAllFlags":["etc35_bit1"]} | notAllFlags → etc35_bit1 추가 | gold, flag:etc35_bit1 |
| `spec-9-L354x`<br>LORESPEC.PAS:354 | step (12, 26) | {"notAllFlags":["etc35_bit2"]} | notAllFlags → etc35_bit2 추가 | gold, flag:etc35_bit2 |
| `spec-9-L354xx`<br>LORESPEC.PAS:354 | step (15, 25) | {"notAllFlags":["etc35_bit3"]} | notAllFlags → etc35_bit3 추가 | gold, flag:etc35_bit3 |
| `spec-9-L354xxx`<br>LORESPEC.PAS:354 | step (16, 23) | {"notAllFlags":["etc35_bit4"]} | notAllFlags → etc35_bit4 추가 | gold, flag:etc35_bit4 |
| `spec-9-L354xxxx`<br>LORESPEC.PAS:354 | step (18, 27) | {"notAllFlags":["etc35_bit5"]} | notAllFlags → etc35_bit5 추가 | gold, flag:etc35_bit5 |
| `talk-9-24-38`<br>LORETALK.PAS (파일 추정) | talk (24, 38) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-9-23-12`<br>LORETALK.PAS (파일 추정) | talk (23, 12) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-9-28-18`<br>LORETALK.PAS (파일 추정) | talk (28, 18) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-9-30-31`<br>LORETALK.PAS (파일 추정) | talk (30, 31) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-9-34-38`<br>LORETALK.PAS (파일 추정) | talk (34, 38) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-9-38-14`<br>LORETALK.PAS (파일 추정) | talk (38, 14) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-9-15-42`<br>LORETALK.PAS (파일 추정) | talk (15, 42) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-9-26-7`<br>LORETALK.PAS (파일 추정) | talk (26, 7) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-9-34-24-a`<br>LORETALK.PAS (파일 추정) | talk (34, 24) | {"quest":{"name":"gaia","eq":0}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-34-24-b`<br>LORETALK.PAS (파일 추정) | talk (34, 24) | {"quest":{"name":"gaia","gte":1}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-37-24-a`<br>LORETALK.PAS (파일 추정) | talk (37, 24) | {"quest":{"name":"gaia","eq":0}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-37-24-b`<br>LORETALK.PAS (파일 추정) | talk (37, 24) | {"quest":{"name":"gaia","gte":1}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-41-24-a`<br>LORETALK.PAS (파일 추정) | talk (41, 24) | {"quest":{"name":"gaia","eq":0}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-41-24-b`<br>LORETALK.PAS (파일 추정) | talk (41, 24) | {"quest":{"name":"gaia","gte":1}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-35-27-a`<br>LORETALK.PAS (파일 추정) | talk (35, 27) | {"quest":{"name":"gaia","eq":0}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-35-27-b`<br>LORETALK.PAS (파일 추정) | talk (35, 27) | {"quest":{"name":"gaia","gte":1}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-38-27-a`<br>LORETALK.PAS (파일 추정) | talk (38, 27) | {"quest":{"name":"gaia","eq":0}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-38-27-b`<br>LORETALK.PAS (파일 추정) | talk (38, 27) | {"quest":{"name":"gaia","gte":1}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-41-27-a`<br>LORETALK.PAS (파일 추정) | talk (41, 27) | {"quest":{"name":"gaia","eq":0}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-41-27-b`<br>LORETALK.PAS (파일 추정) | talk (41, 27) | {"quest":{"name":"gaia","gte":1}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-42-25-q0`<br>LORETALK.PAS (파일 추정) | talk (42, 25) | {"quest":{"name":"gaia","eq":0}} | gaia 단계 → 조건 밖 값 | questStep:gaia |
| `talk-9-42-25-q1`<br>LORETALK.PAS (파일 추정) | talk (42, 25) | {"quest":{"name":"gaia","eq":1}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-42-25-q2`<br>LORETALK.PAS (파일 추정) | talk (42, 25) | {"quest":{"name":"gaia","eq":2}} | gaia 단계 → 조건 밖 값 | exp, questStep:gaia |
| `talk-9-42-25-q3`<br>LORETALK.PAS (파일 추정) | talk (42, 25) | {"quest":{"name":"gaia","eq":3}} | gaia 단계 → 조건 밖 값 | questStep:gaia |
| `talk-9-42-25-q4`<br>LORETALK.PAS (파일 추정) | talk (42, 25) | {"quest":{"name":"gaia","eq":4}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `talk-9-42-25-q5`<br>LORETALK.PAS (파일 추정) | talk (42, 25) | {"quest":{"name":"gaia","eq":5}} | gaia 단계 → 조건 밖 값 | exp, questStep:gaia |
| `talk-9-42-25-q6`<br>LORETALK.PAS (파일 추정) | talk (42, 25) | {"quest":{"name":"gaia","eq":6}} | gaia 단계 → 조건 밖 값 | 대사/연출 |
| `spec-9-L354xxxxx`<br>LORESPEC.PAS:354 | step (*, 10) | {"quest":[{"name":"water","lt":5}]} | water 단계 → 조건 밖 값 | nudge |

### 맵 10

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `talk-10-11-16`<br>LORETALK.PAS (파일 추정) | talk (11, 16) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-10-14-18`<br>LORETALK.PAS (파일 추정) | talk (14, 18) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-10-24-22`<br>LORETALK.PAS (파일 추정) | talk (24, 22) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-10-27-22`<br>LORETALK.PAS (파일 추정) | talk (27, 22) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-10-24-69`<br>LORETALK.PAS (파일 추정) | talk (24, 69) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-10-37-16`<br>LORETALK.PAS (파일 추정) | talk (37, 16) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-10-40-18`<br>LORETALK.PAS (파일 추정) | talk (40, 18) | 조건 없음 | 조건 없음 | 대사/연출 |
| `lorehunter-join`<br>LORETALK.PAS (파일 추정) | talk (40, 56) | {"flagNot":"loreHunterJoined"} | flagNot loreHunterJoined → 추가 | flag:loreHunterJoined, join:lore_hunter, setTile |
| `talk-10-25-18-q0`<br>LORETALK.PAS (파일 추정) | talk (25, 18) | {"quest":{"name":"water","eq":0}} | water 단계 → 조건 밖 값 | questStep:water |
| `talk-10-25-18-q1`<br>LORETALK.PAS (파일 추정) | talk (25, 18) | {"quest":{"name":"water","eq":1}} | water 단계 → 조건 밖 값 | 대사/연출 |
| `talk-10-25-18-q2`<br>LORETALK.PAS (파일 추정) | talk (25, 18) | {"quest":{"name":"water","eq":2}} | water 단계 → 조건 밖 값 | exp, questStep:water |
| `talk-10-25-18-q3`<br>LORETALK.PAS (파일 추정) | talk (25, 18) | {"quest":{"name":"water","eq":3}} | water 단계 → 조건 밖 값 | 대사/연출 |
| `talk-10-25-18-q4`<br>LORETALK.PAS (파일 추정) | talk (25, 18) | {"quest":{"name":"water","eq":4}} | water 단계 → 조건 밖 값 | exp, questStep:water |
| `talk-10-25-18-q5`<br>LORETALK.PAS (파일 추정) | talk (25, 18) | {"quest":{"name":"water","eq":5}} | water 단계 → 조건 밖 값 | 대사/연출 |
| `enter-10-hunter-tile`<br>LOREENT.PAS (파일 추정) | enter (*, *) | {"flag":"loreHunterJoined"} | flag loreHunterJoined → 제거 | setTile |
| `spec-10-L444`<br>LORESPEC.PAS:444 | step (*, 46) | 조건 없음 | 조건 없음 | teleport |
| `spec-10-L444x`<br>LORESPEC.PAS:444 | step (*, 49) | 조건 없음 | 조건 없음 | teleport |

### 맵 11

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `spec-11-L465`<br>LORESPEC.PAS:465 | step (20, 30) | {"notAllFlags":["etc33_bit1"]} | notAllFlags → etc33_bit1 추가 | gold, flag:etc33_bit1 |
| `spec-11-L465x`<br>LORESPEC.PAS:465 | step (18, 36) | {"notAllFlags":["etc33_bit2"]} | notAllFlags → etc33_bit2 추가 | gold, flag:etc33_bit2 |
| `spec-11-L465xx`<br>LORESPEC.PAS:465 | step (35, 32) | {"notAllFlags":["etc33_bit3"]} | notAllFlags → etc33_bit3 추가 | gold, flag:etc33_bit3 |
| `spec-11-L465xxx`<br>LORESPEC.PAS:465 | step (33, 36) | {"notAllFlags":["etc33_bit4"]} | notAllFlags → etc33_bit4 추가 | gold, flag:etc33_bit4 |
| `spec-11-L465xxxx`<br>LORESPEC.PAS:465 | step (35, 14) | {"notAllFlags":["etc33_bit5"]} | notAllFlags → etc33_bit5 추가 | gold, flag:etc33_bit5 |
| `spec-11-L465xxxxx`<br>LORESPEC.PAS:465 | step (14, 16) | {"notAllFlags":["etc33_bit6"]} | notAllFlags → etc33_bit6 추가 | gold, flag:etc33_bit6 |
| `spec-11-L465xxxxxx`<br>LORESPEC.PAS:465 | step (37, 12) | {"notAllFlags":["etc33_bit7"]} | notAllFlags → etc33_bit7 추가 | gold, flag:etc33_bit7 |
| `oedipus-spear`<br>LORESPEC.PAS (파일 추정) | step (*, 44) | {"flagNot":"oedipusSpearTaken"} | flagNot oedipusSpearTaken → 추가 | equip, flag:oedipusSpearTaken |
| `spec-11-L465-1x`<br>LORESPEC.PAS:465 | step (*, 24) | {"notAllFlags":["etc6"],"quest":[{"name":"lastditch","eq":1}]} | notAllFlags → etc6 추가; lastditch 단계 → 조건 밖 값 | battle(적 3, 적 선공, 격퇴 슬롯 3), questStep:lastditch |
| `spec-11-L465-2x`<br>LORESPEC.PAS:465 | step (*, 24) | {"allFlags":["etc6"],"quest":[{"name":"lastditch","eq":1}]} | allFlags → etc6 제거; lastditch 단계 → 조건 밖 값 | battle(적 3, 적 선공) |
| `spec-11-L465-3x`<br>LORESPEC.PAS:465 | step (*, 24) | {"allFlags":["etc6"],"quest":[{"name":"lastditch","eq":1}]} | allFlags → etc6 제거; lastditch 단계 → 조건 밖 값 | battle(적 3, 적 선공), block |
| `enter-11-pyramid`<br>LOREENT.PAS (파일 추정) | enter (*, *) | {"quest":{"name":"lastditch","gte":2}} | lastditch 단계 → 조건 밖 값 | setTile |

### 맵 12

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `rigel-join`<br>LORESPEC.PAS (파일 추정) | step (12, 48) | {"flagNot":"etc31_bit2"} | flagNot etc31_bit2 → 추가 | flag:rigelJoined, join:rigel, flag:etc31_bit2, food, rigelBlessing |
| `golden-seal-12-18-10`<br>LORESPEC.PAS (파일 추정) | step (18, 10) | {"flagNot":"goldenSealFound","quest":{"name":"gaia","lt":2}} | flagNot goldenSealFound → 추가; gaia 단계 → 조건 밖 값 | setTile, questStep:gaia, flag:goldenSealFound |
| `puzzle-door-right`<br>LORESPEC.PAS (파일 추정) | step (33, 50) | {"moveDyNot":1} | moveDyNot 1 → 진입 방향을 금지 값으로 | setTile |
| `puzzle-door-wrong`<br>LORESPEC.PAS (파일 추정) | step (1..99, 50) | {"moveDyNot":1} | moveDyNot 1 → 진입 방향을 금지 값으로 | teleport |
| `t_den2-trap-y10`<br>LORESPEC.PAS (파일 추정) | step (*, 10) | {"flagNot":"goldenSealFound","quest":{"name":"gaia","lt":2}} | flagNot goldenSealFound → 추가; gaia 단계 → 조건 밖 값 | setTileArea |
| `enter-12-evilseal`<br>LOREENT.PAS (파일 추정) | enter (*, *) | {"quest":{"name":"gaia","gte":2}} | gaia 단계 → 조건 밖 값 | setTile |

### 맵 13

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `den4-pyramid-chapters`<br>LORESPEC.PAS (파일 추정) | step (76..86, 71..81) | {"tileAtPlayerValue":52} | tileAtPlayerValue 52 → 타일을 다른 값으로 | setTileArea, setTile, teleport |
| `den4-gorgon`<br>LORESPEC.PAS (파일 추정) | step (80..82, 68) | {"flagNot":"etc38_bit5","tileAtPlayerValue":52} | flagNot etc38_bit5 → 추가; tileAtPlayerValue 52 → 타일을 다른 값으로 | battle(적 3, 승리 플래그, 적 선공, 도주 분기), nudge |

### 맵 14

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `spec-14-L814`<br>LORESPEC.PAS:814 | step (6, 6) | {"notAllFlags":["etc32_bit1"]} | notAllFlags → etc32_bit1 추가 | gold, flag:etc32_bit1 |
| `spec-14-L814x`<br>LORESPEC.PAS:814 | step (18, 10) | {"notAllFlags":["etc32_bit2"]} | notAllFlags → etc32_bit2 추가 | gold, flag:etc32_bit2 |
| `spec-14-L814xx`<br>LORESPEC.PAS:814 | step (6, 44) | {"notAllFlags":["etc32_bit3"]} | notAllFlags → etc32_bit3 추가 | gold, flag:etc32_bit3 |
| `spec-14-L814xxx`<br>LORESPEC.PAS:814 | step (31, 30) | {"notAllFlags":["etc32_bit4"]} | notAllFlags → etc32_bit4 추가 | gold, flag:etc32_bit4 |
| `spec-14-L814xxxx`<br>LORESPEC.PAS:814 | step (31, 8) | {"notAllFlags":["etc32_bit5"]} | notAllFlags → etc32_bit5 추가 | gold, flag:etc32_bit5 |
| `spec-14-L814xxxxx`<br>LORESPEC.PAS:814 | step (14, 28) | {"notAllFlags":["etc32_bit6"]} | notAllFlags → etc32_bit6 추가 | gold, flag:etc32_bit6 |
| `spec-14-L814xxxxxx`<br>LORESPEC.PAS:814 | step (16, 20) | {"notAllFlags":["goldenShieldMenaceTaken"]} | notAllFlags → goldenShieldMenaceTaken 추가 | equip, flag:goldenShieldMenaceTaken |
| `spec-14-L814-1-1`<br>LORESPEC.PAS:814 | step (25, 8) | {"quest":[{"name":"lordahn","eq":3}]} | lordahn 단계 → 조건 밖 값 | questStep:lordahn |
| `spec-14-L814-2-1`<br>LORESPEC.PAS:814 | step (26, 8) | {"quest":[{"name":"lordahn","eq":3}]} | lordahn 단계 → 조건 밖 값 | questStep:lordahn |

### 맵 15

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `spec-15-L879`<br>LORESPEC.PAS:879 | step (14, 7) | {"notAllFlags":["goldenShieldQuakeTaken"]} | notAllFlags → goldenShieldQuakeTaken 추가 | equip, flag:goldenShieldQuakeTaken |
| `spec-15-L879x`<br>LORESPEC.PAS:879 | step (45, 19) | {"notAllFlags":["goldenArmorQuakeTaken"]} | notAllFlags → goldenArmorQuakeTaken 추가 | equip, flag:goldenArmorQuakeTaken |
| `spec-15-L879-1xxxx`<br>LORESPEC.PAS:879 | step (*, 27) | {"notAllFlags":["etc6"],"quest":[{"name":"gaia","eq":4}]} | notAllFlags → etc6 추가; gaia 단계 → 조건 밖 값 | battle(적 3, 적 선공, 격퇴 슬롯 3), questStep:gaia |
| `spec-15-L879-2xxxx`<br>LORESPEC.PAS:879 | step (*, 27) | {"allFlags":["etc6"],"quest":[{"name":"gaia","eq":4}]} | allFlags → etc6 제거; gaia 단계 → 조건 밖 값 | battle(적 3, 적 선공) |
| `spec-15-L879-3`<br>LORESPEC.PAS:879 | step (*, 27) | {"allFlags":["etc6"],"quest":[{"name":"gaia","eq":4}]} | allFlags → etc6 제거; gaia 단계 → 조건 밖 값 | battle(적 3, 적 선공), block |
| `quake-gold-a-10`<br>LORESPEC.PAS (파일 추정) | step (10, 48) | {"flagNot":"quakeGoldA"} | flagNot quakeGoldA → 추가 | gold, setTile, flag:quakeGoldA |
| `quake-gold-a-11`<br>LORESPEC.PAS (파일 추정) | step (11, 48) | {"flagNot":"quakeGoldA"} | flagNot quakeGoldA → 추가 | gold, setTile, flag:quakeGoldA |
| `quake-gold-a-40`<br>LORESPEC.PAS (파일 추정) | step (40, 48) | {"flagNot":"quakeGoldA"} | flagNot quakeGoldA → 추가 | gold, setTile, flag:quakeGoldA |
| `quake-gold-a-41`<br>LORESPEC.PAS (파일 추정) | step (41, 48) | {"flagNot":"quakeGoldA"} | flagNot quakeGoldA → 추가 | gold, setTile, flag:quakeGoldA |
| `quake-gold-b-10`<br>LORESPEC.PAS (파일 추정) | step (10, 48) | {"flag":"quakeGoldA","flagNot":"quakeGoldB"} | flag quakeGoldA → 제거; flagNot quakeGoldB → 추가 | gold, setTile, flag:quakeGoldB |
| `quake-gold-b-11`<br>LORESPEC.PAS (파일 추정) | step (11, 48) | {"flag":"quakeGoldA","flagNot":"quakeGoldB"} | flag quakeGoldA → 제거; flagNot quakeGoldB → 추가 | gold, setTile, flag:quakeGoldB |
| `quake-gold-b-40`<br>LORESPEC.PAS (파일 추정) | step (40, 48) | {"flag":"quakeGoldA","flagNot":"quakeGoldB"} | flag quakeGoldA → 제거; flagNot quakeGoldB → 추가 | gold, setTile, flag:quakeGoldB |
| `quake-gold-b-41`<br>LORESPEC.PAS (파일 추정) | step (41, 48) | {"flag":"quakeGoldA","flagNot":"quakeGoldB"} | flag quakeGoldA → 제거; flagNot quakeGoldB → 추가 | gold, setTile, flag:quakeGoldB |

### 맵 16

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `wivern-3-remaining`<br>LORESPEC.PAS (파일 추정) | step (*, 10) | {"tileAtPlayerZero":true,"quest":{"name":"wivern","eq":0}} | tileAtPlayerZero True → 타일을 0 이외로; wivern 단계 → 조건 밖 값 | battle(적 3, 적 선공), questStep:wivern |
| `wivern-2-remaining`<br>LORESPEC.PAS (파일 추정) | step (*, 10) | {"tileAtPlayerZero":true,"quest":{"name":"wivern","eq":1}} | tileAtPlayerZero True → 타일을 0 이외로; wivern 단계 → 조건 밖 값 | battle(적 2, 적 선공), questStep:wivern |
| `wivern-1-remaining`<br>LORESPEC.PAS (파일 추정) | step (*, 10) | {"tileAtPlayerZero":true,"quest":{"name":"wivern","eq":2}} | tileAtPlayerZero True → 타일을 0 이외로; wivern 단계 → 조건 밖 값 | battle(적 1, 적 선공), questStep:wivern |
| `wivern-cleared`<br>LORESPEC.PAS (파일 추정) | step (*, 10) | {"tileAtPlayerZero":true,"quest":{"name":"wivern","gte":3}} | tileAtPlayerZero True → 타일을 0 이외로; wivern 단계 → 조건 밖 값 | 대사/연출 |

### 맵 17

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `redantares-teach`<br>LORESPEC.PAS (파일 추정) | step (75, 52) | {"flagNot":"specialMagicLearned"} | flagNot specialMagicLearned → 추가 | setTileArea, flag:specialMagicLearned |
| `redantares-join`<br>LORESPEC.PAS (파일 추정) | step (75, 52) | {"flag":"specialMagicLearned","flagNot":"etc38_bit2","mindRead":true} | flag specialMagicLearned → 제거; flagNot etc38_bit2 → 추가; mindRead True → 독심술 끄기 | flag:redAntaresJoined, join:red_antares, flag:etc38_bit2 |
| `redantares-wait-for-mindread`<br>LORESPEC.PAS (파일 추정) | step (75, 52) | {"flag":"specialMagicLearned","flagNot":"etc38_bit2","mindReadInactive":true} | flag specialMagicLearned → 제거; flagNot etc38_bit2 → 추가; mindReadInactive True → 독심술 켜기 | 대사/연출 |
| `spec-17-L1010-1xx`<br>LORESPEC.PAS:1010 | step (22, *) | {"notAllFlags":["bossHidraDefeated","etc1","etc6"],"quest":[{"name":"water","lt":2}]} | notAllFlags → bossHidraDefeated 추가; water 단계 → 조건 밖 값 | torch, flag:etc1, battle(적 3, 도주 분기), nudge, questStep:water, flag:bossHidraDefeated, teleport |
| `spec-17-L1010-2xx`<br>LORESPEC.PAS:1010 | step (22, *) | {"allFlags":["etc1"],"notAllFlags":["bossHidraDefeated","etc6"],"quest":[{"name":"water","lt":2}]} | allFlags → etc1 제거; notAllFlags → bossHidraDefeated 추가; water 단계 → 조건 밖 값 | battle(적 3, 도주 분기), nudge, questStep:water, flag:bossHidraDefeated, teleport |
| `spec-17-L1010-3`<br>LORESPEC.PAS:1010 | step (22, *) | {"allFlags":["etc6"],"notAllFlags":["bossHidraDefeated","etc1"],"quest":[{"name":"water","lt":2}]} | allFlags → etc6 제거; notAllFlags → bossHidraDefeated 추가; water 단계 → 조건 밖 값 | torch, flag:etc1, battle(적 3), nudge |
| `spec-17-L1010-4`<br>LORESPEC.PAS:1010 | step (22, *) | {"allFlags":["etc1","etc6"],"notAllFlags":["bossHidraDefeated"],"quest":[{"name":"water","lt":2}]} | allFlags → etc1 제거; notAllFlags → bossHidraDefeated 추가; water 단계 → 조건 밖 값 | battle(적 3), nudge |
| `spec-17-L1010-5`<br>LORESPEC.PAS:1010 | step (22, *) | {"allFlags":["etc6"],"notAllFlags":["bossHidraDefeated","etc1"],"quest":[{"name":"water","lt":2}]} | allFlags → etc6 제거; notAllFlags → bossHidraDefeated 추가; water 단계 → 조건 밖 값 | torch, flag:etc1, battle(적 3), block |
| `spec-17-L1010-6`<br>LORESPEC.PAS:1010 | step (22, *) | {"allFlags":["etc1","etc6"],"notAllFlags":["bossHidraDefeated"],"quest":[{"name":"water","lt":2}]} | allFlags → etc1 제거; notAllFlags → bossHidraDefeated 추가; water 단계 → 조건 밖 값 | battle(적 3), block |
| `map17-row80-shortcut-safe`<br>LORESPEC.PAS (파일 추정) | step (72, 80) | 조건 없음 | 조건 없음 | setTileArea, teleport |
| `map17-passage-44-shortcut`<br>LORESPEC.PAS (파일 추정) | step (72, 44) | 조건 없음 | 조건 없음 | setTileArea, nudge |
| `map17-passage-44`<br>LORESPEC.PAS (파일 추정) | step (*, 44) | 조건 없음 | 조건 없음 | setTileArea |
| `spec-17-L1010xxxxx`<br>LORESPEC.PAS:1010 | step (72, *) | 조건 없음 | 조건 없음 | setTileArea, nudge |
| `spec-17-L1010xxxxxx`<br>LORESPEC.PAS:1010 | step (*, 38) | 조건 없음 | 조건 없음 | setTileArea, teleport |
| `spec-17-L1010`<br>LORESPEC.PAS:1010 | step (*, 80) | 조건 없음 | 조건 없음 | teleport |

### 맵 18

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `spica-first-meeting`<br>LORESPEC.PAS (파일 추정) | step (37, 31) | {"flagNot":"etc39_bit1"} | flagNot etc39_bit1 → 추가 | flag:etc39_bit1 |
| `spica-join`<br>LORESPEC.PAS (파일 추정) | step (37, 31) | {"flag":"etc39_bit1","flagNot":"etc39_bit2","mindRead":true,"minEspLevel":5} | flag etc39_bit1 → 제거; flagNot etc39_bit2 → 추가; mindRead True → 독심술 끄기; minEspLevel 5 → 초능력 레벨 낮추기 | flag:spicaJoined, join:spica, flag:etc39_bit2 |
| `spica-cannot-read`<br>LORESPEC.PAS (파일 추정) | step (37, 31) | {"flag":"etc39_bit1","flagNot":"etc39_bit2","mindRead":true,"maxEspLevelBelow":5} | flag etc39_bit1 → 제거; flagNot etc39_bit2 → 추가; mindRead True → 독심술 끄기; maxEspLevelBelow 5 → 초능력 레벨 높이기 | 대사/연출 |
| `spica-mind-read-inactive`<br>LORESPEC.PAS (파일 추정) | step (37, 31) | {"flag":"etc39_bit1","flagNot":"etc39_bit2","mindReadInactive":true} | flag etc39_bit1 → 제거; flagNot etc39_bit2 → 추가; mindReadInactive True → 독심술 켜기 | 대사/연출 |
| `spec-18-L1174-1xxxx`<br>LORESPEC.PAS:1174 | step (31, *) | {"notAllFlags":["bossHugeDragonDefeated","etc1","etc6"],"quest":[{"name":"water","lt":4}]} | notAllFlags → bossHugeDragonDefeated 추가; water 단계 → 조건 밖 값 | torch, flag:etc1, nudge, battle(적 2, 적 선공, 도주 분기), teleport, questStep:water, flag:bossHugeDragonDefeated |
| `spec-18-L1174-2xxxx`<br>LORESPEC.PAS:1174 | step (31, *) | {"allFlags":["etc1"],"notAllFlags":["bossHugeDragonDefeated","etc6"],"quest":[{"name":"water","lt":4}]} | allFlags → etc1 제거; notAllFlags → bossHugeDragonDefeated 추가; water 단계 → 조건 밖 값 | nudge, battle(적 2, 적 선공, 도주 분기), teleport, questStep:water, flag:bossHugeDragonDefeated |
| `spec-18-L1174-3x`<br>LORESPEC.PAS:1174 | step (31, *) | {"allFlags":["etc6"],"notAllFlags":["bossHugeDragonDefeated","etc1"],"quest":[{"name":"water","lt":4}]} | allFlags → etc6 제거; notAllFlags → bossHugeDragonDefeated 추가; water 단계 → 조건 밖 값 | torch, flag:etc1, nudge, battle(적 2, 적 선공), teleport |
| `spec-18-L1174-4x`<br>LORESPEC.PAS:1174 | step (31, *) | {"allFlags":["etc1","etc6"],"notAllFlags":["bossHugeDragonDefeated"],"quest":[{"name":"water","lt":4}]} | allFlags → etc1 제거; notAllFlags → bossHugeDragonDefeated 추가; water 단계 → 조건 밖 값 | nudge, battle(적 2, 적 선공), teleport |
| `spec-18-L1174-5x`<br>LORESPEC.PAS:1174 | step (31, *) | {"allFlags":["etc6"],"notAllFlags":["bossHugeDragonDefeated","etc1"],"quest":[{"name":"water","lt":4}]} | allFlags → etc6 제거; notAllFlags → bossHugeDragonDefeated 추가; water 단계 → 조건 밖 값 | torch, flag:etc1, nudge, battle(적 2, 적 선공), block |
| `spec-18-L1174-6x`<br>LORESPEC.PAS:1174 | step (31, *) | {"allFlags":["etc1","etc6"],"notAllFlags":["bossHugeDragonDefeated"],"quest":[{"name":"water","lt":4}]} | allFlags → etc1 제거; notAllFlags → bossHugeDragonDefeated 추가; water 단계 → 조건 밖 값 | nudge, battle(적 2, 적 선공), block |
| `spec-18-L1174`<br>LORESPEC.PAS:1174 | step (22, 41) | {"tileAtPlayerValue":52} | tileAtPlayerValue 52 → 타일을 다른 값으로 | setTile |
| `spec-18-L1174-1xx`<br>LORESPEC.PAS:1174 | step (21, 41) | {"tileAtPlayerValue":52,"notAllFlags":["etc1","lockupGuardianDefeated"]} | tileAtPlayerValue 52 → 타일을 다른 값으로; notAllFlags → etc1 추가 | torch, flag:etc1, battle(적 1, 적 선공), flag:lockupGuardianDefeated |
| `spec-18-L1174-2xx`<br>LORESPEC.PAS:1174 | step (21, 41) | {"tileAtPlayerValue":52,"allFlags":["etc1"],"notAllFlags":["lockupGuardianDefeated"]} | tileAtPlayerValue 52 → 타일을 다른 값으로; allFlags → etc1 제거; notAllFlags → lockupGuardianDefeated 추가 | battle(적 1, 적 선공), flag:lockupGuardianDefeated |

### 맵 19

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `evil-seal-lever-a-blocked`<br>LORESPEC.PAS (파일 추정) | step (11, 40) | {"flag":"swampWalkActive","tileAtPlayerZero":true} | flag swampWalkActive → 제거; tileAtPlayerZero True → 타일을 0 이외로 | 대사/연출 |
| `evil-seal-lever-a`<br>LORESPEC.PAS (파일 추정) | step (11, 40) | {"flagNot":"swampWalkActive","tileAtPlayerZero":true} | flagNot swampWalkActive → 추가; tileAtPlayerZero True → 타일을 0 이외로 | setTile, flag:evilSealLeverA |
| `evil-seal-lever-b-blocked`<br>LORESPEC.PAS (파일 추정) | step (41, 39) | {"flag":"swampWalkActive","tileAtPlayerZero":true} | flag swampWalkActive → 제거; tileAtPlayerZero True → 타일을 0 이외로 | 대사/연출 |
| `evil-seal-lever-b`<br>LORESPEC.PAS (파일 추정) | step (41, 39) | {"flagNot":"swampWalkActive","notAllFlags":["evilSealRoomCleared"],"tileAtPlayerZero":true} | flagNot swampWalkActive → 추가; tileAtPlayerZero True → 타일을 0 이외로; notAllFlags → evilSealRoomCleared 추가 | setTile, setTileArea, randomFlag, flag:evilSealLeverB |
| `evil-seal-lever-b-cleared`<br>LORESPEC.PAS (파일 추정) | step (41, 39) | {"flag":"evilSealRoomCleared","flagNot":"swampWalkActive","tileAtPlayerZero":true} | flag evilSealRoomCleared → 제거; flagNot swampWalkActive → 추가; tileAtPlayerZero True → 타일을 0 이외로 | setTile |
| `evil-seal-room-1`<br>LORESPEC.PAS (파일 추정) | step (14, 6) | {"flag":"evilSealRoom1","flagNot":"evilSealRoomCleared"} | flag evilSealRoom1 → 제거; flagNot evilSealRoomCleared → 추가 | setTileArea, battle(적 7, 적 선공, 도주 분기), nudge, flag:evilSealRoomCleared, flag:lavaGateKeyLeft, flag:sealPuzzleA |
| `evil-seal-room-2`<br>LORESPEC.PAS (파일 추정) | step (18, 6) | {"flag":"evilSealRoom2","flagNot":"evilSealRoomCleared"} | flag evilSealRoom2 → 제거; flagNot evilSealRoomCleared → 추가 | setTileArea, battle(적 7, 적 선공, 도주 분기), nudge, flag:evilSealRoomCleared, flag:lavaGateKeyLeft, flag:sealPuzzleA |
| `evil-seal-room-3`<br>LORESPEC.PAS (파일 추정) | step (22, 6) | {"flag":"evilSealRoom3","flagNot":"evilSealRoomCleared"} | flag evilSealRoom3 → 제거; flagNot evilSealRoomCleared → 추가 | setTileArea, battle(적 7, 적 선공, 도주 분기), nudge, flag:evilSealRoomCleared, flag:lavaGateKeyLeft, flag:sealPuzzleA |
| `evil-seal-room-4`<br>LORESPEC.PAS (파일 추정) | step (26, 6) | {"flag":"evilSealRoom4","flagNot":"evilSealRoomCleared"} | flag evilSealRoom4 → 제거; flagNot evilSealRoomCleared → 추가 | setTileArea, battle(적 7, 적 선공, 도주 분기), nudge, flag:evilSealRoomCleared, flag:lavaGateKeyLeft, flag:sealPuzzleA |
| `evil-seal-room-5`<br>LORESPEC.PAS (파일 추정) | step (30, 6) | {"flag":"evilSealRoom5","flagNot":"evilSealRoomCleared"} | flag evilSealRoom5 → 제거; flagNot evilSealRoomCleared → 추가 | setTileArea, battle(적 7, 적 선공, 도주 분기), nudge, flag:evilSealRoomCleared, flag:lavaGateKeyLeft, flag:sealPuzzleA |
| `evil-seal-room-6`<br>LORESPEC.PAS (파일 추정) | step (34, 6) | {"flag":"evilSealRoom6","flagNot":"evilSealRoomCleared"} | flag evilSealRoom6 → 제거; flagNot evilSealRoomCleared → 추가 | setTileArea, battle(적 7, 적 선공, 도주 분기), nudge, flag:evilSealRoomCleared, flag:lavaGateKeyLeft, flag:sealPuzzleA |
| `evil-seal-room-7`<br>LORESPEC.PAS (파일 추정) | step (38, 6) | {"flag":"evilSealRoom7","flagNot":"evilSealRoomCleared"} | flag evilSealRoom7 → 제거; flagNot evilSealRoomCleared → 추가 | setTileArea, battle(적 7, 적 선공, 도주 분기), nudge, flag:evilSealRoomCleared, flag:lavaGateKeyLeft, flag:sealPuzzleA |
| `evil-seal-room-wrong-1`<br>LORESPEC.PAS (파일 추정) | step (14, 6) | {"notAllFlags":["evilSealRoom1","evilSealRoomCleared"]} | notAllFlags → evilSealRoom1 추가 | setTileArea, setTileAtPlayer |
| `evil-seal-room-wrong-2`<br>LORESPEC.PAS (파일 추정) | step (18, 6) | {"notAllFlags":["evilSealRoom2","evilSealRoomCleared"]} | notAllFlags → evilSealRoom2 추가 | setTileArea, setTileAtPlayer |
| `evil-seal-room-wrong-3`<br>LORESPEC.PAS (파일 추정) | step (22, 6) | {"notAllFlags":["evilSealRoom3","evilSealRoomCleared"]} | notAllFlags → evilSealRoom3 추가 | setTileArea, setTileAtPlayer |
| `evil-seal-room-wrong-4`<br>LORESPEC.PAS (파일 추정) | step (26, 6) | {"notAllFlags":["evilSealRoom4","evilSealRoomCleared"]} | notAllFlags → evilSealRoom4 추가 | setTileArea, setTileAtPlayer |
| `evil-seal-room-wrong-5`<br>LORESPEC.PAS (파일 추정) | step (30, 6) | {"notAllFlags":["evilSealRoom5","evilSealRoomCleared"]} | notAllFlags → evilSealRoom5 추가 | setTileArea, setTileAtPlayer |
| `evil-seal-room-wrong-6`<br>LORESPEC.PAS (파일 추정) | step (34, 6) | {"notAllFlags":["evilSealRoom6","evilSealRoomCleared"]} | notAllFlags → evilSealRoom6 추가 | setTileArea, setTileAtPlayer |
| `evil-seal-room-wrong-7`<br>LORESPEC.PAS (파일 추정) | step (38, 6) | {"notAllFlags":["evilSealRoom7","evilSealRoomCleared"]} | notAllFlags → evilSealRoom7 추가 | setTileArea, setTileAtPlayer |
| `evil-seal-guardians`<br>LORESPEC.PAS (파일 추정) | step (*, 8..12) | {"flagNot":"evilSealRoomCleared"} | flagNot evilSealRoomCleared → 추가 | battle(적 0, 도주 분기), setTileAtPlayer |

### 맵 20

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `spec-20-L1475xx`<br>LORESPEC.PAS:1475 | step (*, 91) | 조건 없음 | 조건 없음 | setTileArea, setTile |
| `spec-20-L1475xxx`<br>LORESPEC.PAS:1475 | step (*, 75) | 조건 없음 | 조건 없음 | setTileArea, setTile |
| `den7-quiz-y54`<br>LORESPEC.PAS (파일 추정) | step (*, 54) | 조건 없음 | 조건 없음 | setTileArea, teleport |
| `den7-passage-y88`<br>LORESPEC.PAS (파일 추정) | step (*, 88) | {"tileAtPlayerZero":true} | tileAtPlayerZero True → 타일을 0 이외로 | teleport |
| `den7-exit-y88`<br>LORESPEC.PAS (파일 추정) | step (*, 88) | 조건 없음 | 조건 없음 | teleport |
| `den7-passage-y71`<br>LORESPEC.PAS (파일 추정) | step (*, 71) | {"tileAtPlayerZero":true} | tileAtPlayerZero True → 타일을 0 이외로 | teleport |
| `den7-exit-y71`<br>LORESPEC.PAS (파일 추정) | step (*, 71) | 조건 없음 | 조건 없음 | teleport |
| `spec-20-L1475xxxx`<br>LORESPEC.PAS:1475 | step (*, 18) | 조건 없음 | 조건 없음 | torch, flag:etc1 |
| `spec-20-L1475-1xxx`<br>LORESPEC.PAS:1475 | step (*, 48) | {"notAllFlags":["den7MinotaurCleared","etc1"]} | notAllFlags → den7MinotaurCleared 추가 | torch, flag:etc1, battle(적 1, 적 선공), flag:den7MinotaurCleared |
| `spec-20-L1475-2xxx`<br>LORESPEC.PAS:1475 | step (*, 48) | {"allFlags":["etc1"],"notAllFlags":["den7MinotaurCleared"]} | allFlags → etc1 제거; notAllFlags → den7MinotaurCleared 추가 | battle(적 1, 적 선공), flag:den7MinotaurCleared |
| `den7-dragons-y13`<br>LORESPEC.PAS (파일 추정) | step (*, 13) | {"flagNot":"den7DragonsCleared"} | flagNot den7DragonsCleared → 추가 | torch, battle(적 3, 적 선공, 도주 분기), nudge, flag:den7DragonsCleared |
| `den7-mudmen-y13`<br>LORESPEC.PAS (파일 추정) | step (*, 13) | {"flag":"den7DragonsCleared","flagNot":"den7MudmenCleared"} | flag den7DragonsCleared → 제거; flagNot den7MudmenCleared → 추가 | torch, battle(적 7, 적 선공, 도주 분기), nudge, flag:den7MudmenCleared |
| `den7-master-y13`<br>LORESPEC.PAS (파일 추정) | step (*, 13) | {"flag":"den7MudmenCleared","flagNot":"den7MazeCleared"} | flag den7MudmenCleared → 제거; flagNot den7MazeCleared → 추가 | torch, battle(적 7, 적 선공, 도주 분기, 격퇴 슬롯 7), nudge, flag:den7MazeCleared, flag:lavaGateKeyRight, teleport |
| `den7-return-y13`<br>LORESPEC.PAS (파일 추정) | step (*, 13) | {"flag":"den7MazeCleared"} | flag den7MazeCleared → 제거 | torch, teleport |

### 맵 21

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `keep1-exit-guard`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"notAllFlags":["keep1LeftGuardianDefeated","keep1RightGuardianDefeated"],"flagNot":"swampKeepBossDefeated"} | flagNot swampKeepBossDefeated → 추가; notAllFlags → keep1LeftGuardianDefeated 추가 | battle(적 7, 승리 플래그, 적 선공, 도주 중 지정 슬롯 격퇴, 적별 격퇴 플래그) |
| `keep1-exit-guard`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"flag":"keep1LeftGuardianDefeated","flagNot":"keep1RightGuardianDefeated"} | flag keep1LeftGuardianDefeated → 제거; flagNot keep1RightGuardianDefeated → 추가 | battle(적 6, 승리 플래그, 적 선공, 도주 중 지정 슬롯 격퇴, 적별 격퇴 플래그) |
| `keep1-exit-guard`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"flag":"keep1RightGuardianDefeated","flagNot":"keep1LeftGuardianDefeated"} | flag keep1RightGuardianDefeated → 제거; flagNot keep1LeftGuardianDefeated → 추가 | battle(적 6, 승리 플래그, 적 선공, 도주 중 지정 슬롯 격퇴, 적별 격퇴 플래그) |
| `keep1-exit-guard`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"allFlags":["keep1LeftGuardianDefeated","keep1RightGuardianDefeated"],"flagNot":"swampKeepBossDefeated"} | flagNot swampKeepBossDefeated → 추가; allFlags → keep1LeftGuardianDefeated 제거 | flag:swampKeepBossDefeated, block |
| `keep1-seal-gate-a`<br>LORESPEC.PAS (파일 추정) | step (25, 20) | {"flagNot":"sealPuzzleA"} | flagNot sealPuzzleA → 추가 | nudge |
| `keep1-seal-gate-b`<br>LORESPEC.PAS (파일 추정) | step (25, 20) | {"flagNot":"sealPuzzleB"} | flagNot sealPuzzleB → 추가 | nudge |
| `portal-21-22-lavagate`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"notAllFlags":["lavaGateKeyLeft","lavaGateKeyRight"]} | notAllFlags → lavaGateKeyLeft 추가 | block |
| `portal-21-22-lavagate`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"allFlags":["lavaGateKeyLeft","lavaGateKeyRight"],"notAllFlags":["lavaGateLeftGuardianDefeated","lavaGateRightGuardianDefeated"]} | allFlags → lavaGateKeyLeft 제거; notAllFlags → lavaGateLeftGuardianDefeated 추가 | battle(적 2, 승리 플래그, 적 선공, 적별 격퇴 플래그) |
| `portal-21-22-lavagate`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"allFlags":["lavaGateKeyLeft","lavaGateKeyRight","lavaGateLeftGuardianDefeated"],"flagNot":"lavaGateRightGuardianDefeated"} | flagNot lavaGateRightGuardianDefeated → 추가; allFlags → lavaGateKeyLeft 제거 | battle(적 1, 승리 플래그, 적 선공, 적별 격퇴 플래그) |
| `portal-21-22-lavagate`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"allFlags":["lavaGateKeyLeft","lavaGateKeyRight","lavaGateRightGuardianDefeated"],"flagNot":"lavaGateLeftGuardianDefeated"} | flagNot lavaGateLeftGuardianDefeated → 추가; allFlags → lavaGateKeyLeft 제거 | battle(적 1, 승리 플래그, 적 선공, 적별 격퇴 플래그) |
| `portal-21-22-lavagate`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"allFlags":["lavaGateKeyLeft","lavaGateKeyRight","lavaGateLeftGuardianDefeated","lavaGateRightGuardianDefeated"]} | allFlags → lavaGateKeyLeft 제거 | flag:lavaGateGuardiansCleared |
| `keep1-special-ambush`<br>LORESPEC.PAS (파일 추정) | step (*, 1..45) | 조건 없음 | 조건 없음 | battle(적 0, 적 선공), setTileAtPlayer |

### 맵 22

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `keep2-exit-guard`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"flagNot":"etc43_bit3"} | flagNot etc43_bit3 → 추가 | battle(적 7, 적 선공, 격퇴 슬롯 7), flag:etc43_bit3 |
| `spec-22-L1816-1x`<br>LORESPEC.PAS:1816 | step (25, 18) | {"notAllFlags":["etc6","keep2AmbushCleared"]} | notAllFlags → etc6 추가 | battle(적 5, 적 선공), flag:keep2AmbushCleared |
| `keep2-guards-y25`<br>LORESPEC.PAS (파일 추정) | step (24..26, 25) | {"flagNot":"keep2GuardsCleared"} | flagNot keep2GuardsCleared → 추가 | battle(적 5), flag:keep2GuardsCleared |
| `keep2-ambush-zone-a`<br>LORESPEC.PAS (파일 추정) | step (*, 1..45) | {"flagNot":"keep2AmbushCleared"} | flagNot keep2AmbushCleared → 추가 | battle(적 5, 적 선공, 도주 분기), setTileAtPlayer |
| `keep2-ambush-zone-b`<br>LORESPEC.PAS (파일 추정) | step (*, 47..99) | {"flagNot":"keep2AmbushCleared"} | flagNot keep2AmbushCleared → 추가 | battle(적 5, 적 선공, 도주 분기), setTileAtPlayer |
| `enter-22-ancient-evil`<br>LOREENT.PAS (파일 추정) | enter (*, *) | {"flagNot":"ancientEvilSpeechGiven","enteredFromMap":21} | flagNot ancientEvilSpeechGiven → 추가; enteredFromMap 21 → 다른 맵에서 진입 | flag:ancientEvilSpeechGiven |

### 맵 23

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `portal-23-25-dungeon`<br>LOREENT.PAS (파일 추정) | portal (*, *) | {"flagNot":"dungeonOfEvilCleared"} | flagNot dungeonOfEvilCleared → 추가 | battle(적 7, 적 선공, 도주 분기, 격퇴 슬롯 3), block, flag:dungeonOfEvilCleared |
| `keep3-necromancer-y26`<br>LORESPEC.PAS (파일 추정) | step (*, 26) | {"tileAtPlayerValue":52} | tileAtPlayerValue 52 → 타일을 다른 값으로 | battle(적 6, 적 선공, 도주 분기), battle(적 1, 적 선공, 도주 분기), nudge, setTile, setTileArea |
| `keep3-trap-25-27`<br>LORESPEC.PAS (파일 추정) | step (25, 27) | {"tileAtPlayerValue":52} | tileAtPlayerValue 52 → 타일을 다른 값으로 | setTile, setTileArea, flag:keep3TrapCleared |

### 맵 24

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `talk-24-17-15`<br>LORETALK.PAS (파일 추정) | talk (17, 15) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-24-18-10`<br>LORETALK.PAS (파일 추정) | talk (18, 10) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-24-20-13`<br>LORETALK.PAS (파일 추정) | talk (20, 13) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-24-27-8`<br>LORETALK.PAS (파일 추정) | talk (27, 8) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-24-31-13`<br>LORETALK.PAS (파일 추정) | talk (31, 13) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-24-33-10`<br>LORETALK.PAS (파일 추정) | talk (33, 10) | 조건 없음 | 조건 없음 | setTile, flag:programmerMet |
| `enter-24-shelter`<br>LOREENT.PAS (파일 추정) | enter (*, *) | {"flag":"programmerMet"} | flag programmerMet → 제거 | setTile |

### 맵 25

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `keep3-key-a-second`<br>LORESPEC.PAS (파일 추정) | step (5, 34) | {"flag":"keep3KeyB","flagNot":"keep3KeyA"} | flag keep3KeyB → 제거; flagNot keep3KeyA → 추가 | setTile, flag:keep3KeyA, flag:sealPuzzleB |
| `keep3-key-a-first`<br>LORESPEC.PAS (파일 추정) | step (5, 34) | {"flagNot":"keep3KeyA"} | flagNot keep3KeyA → 추가 | flag:keep3KeyA |
| `keep3-key-b-second`<br>LORESPEC.PAS (파일 추정) | step (46, 34) | {"flag":"keep3KeyA","flagNot":"keep3KeyB"} | flag keep3KeyA → 제거; flagNot keep3KeyB → 추가 | setTile, flag:keep3KeyB, flag:sealPuzzleB |
| `keep3-key-b-first`<br>LORESPEC.PAS (파일 추정) | step (46, 34) | {"flagNot":"keep3KeyB"} | flagNot keep3KeyB → 추가 | flag:keep3KeyB |
| `spec-25-L1995`<br>LORESPEC.PAS:1995 | step (15, 34) | {"tileAtPlayerZero":true} | tileAtPlayerZero True → 타일을 0 이외로 | setTile, setTileArea |
| `spec-25-L1995x`<br>LORESPEC.PAS:1995 | step (36, 34) | {"tileAtPlayerZero":true} | tileAtPlayerZero True → 타일을 0 이외로 | setTile, setTileArea |
| `keep3-metal-guardian-y43`<br>LORESPEC.PAS (파일 추정) | step (*, 43) | {"tileAtPlayerZero":true} | tileAtPlayerZero True → 타일을 0 이외로 | torch, battle(적 5, 적 선공, 도주 분기), nudge, setTileArea, partyClass |
| `portal-25-26-chamber`<br>LOREENT.PAS (파일 추정) | portal (*, *) | 조건 없음 | 조건 없음 | torch, battle(적 6, 도주 분기), teleport, block |

### 맵 26

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `enter-26-chamber`<br>LOREENT.PAS (파일 추정) | enter (*, *) | 조건 없음 | 조건 없음 | setTileArea |
| `spec-26-L2104-seq`<br>LORESPEC.PAS:2104 | step (*, *) | {"tileAtPlayerZero":true,"flagNot":"bossNecromancerDefeated"} | flagNot bossNecromancerDefeated → 추가; tileAtPlayerZero True → 타일을 0 이외로 | nudge, battle(적 7, 적 선공, 도주 분기, 격퇴 슬롯 7), flag:bossNecromancerDefeated |

### 맵 27

| 규칙 / 원본 | 트리거 좌표 | 참 조건 | 거짓 탐침 | 타일·전투·상태 효과 |
| :--- | :--- | :--- | :--- | :--- |
| `talk-27-15-6`<br>LORETALK.PAS (파일 추정) | talk (15, 6) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-27-10-14`<br>LORETALK.PAS (파일 추정) | talk (10, 14) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-27-10-18`<br>LORETALK.PAS (파일 추정) | talk (10, 18) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-27-10-30`<br>LORETALK.PAS (파일 추정) | talk (10, 30) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-27-21-32`<br>LORETALK.PAS (파일 추정) | talk (21, 32) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-27-21-22`<br>LORETALK.PAS (파일 추정) | talk (21, 22) | 조건 없음 | 조건 없음 | 대사/연출 |
| `talk-27-21-12`<br>LORETALK.PAS (파일 추정) | talk (21, 12) | 조건 없음 | 조건 없음 | setTileAtTarget |
| `talk-27-any`<br>LORETALK.PAS (파일 추정) | talk (*, *) | 조건 없음 | 조건 없음 | setTileAtTarget |
| `map27-special-upper`<br>LORESPEC.PAS (파일 추정) | step (*, 1..24) | {"tileAtPlayerZero":true} | tileAtPlayerZero True → 타일을 0 이외로 | nudge |
| `map27-special-lower`<br>LORESPEC.PAS (파일 추정) | step (*, 25..1000000000) | {"tileAtPlayerZero":true} | tileAtPlayerZero True → 타일을 0 이외로 | nudge |
