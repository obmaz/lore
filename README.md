# 또 다른 지식의 성전 (LORE 1993)

1993년 DOS 게임 **또 다른 지식의 성전**을 Flutter로 이식한 프로젝트입니다. 원본 Pascal 소스와 실행 데이터는 `repo_source/LORE_1993_src/`, `repo_source/LORE_1993_runtime/`에 있습니다. 게임 동작의 대조 내용과 알려진 편차는 [게임 명세서](DOCS_GAME_SPECS.md)에 기록했습니다.

완전 이식의 검증 기준과 게임 엔진으로 확장하기 위한 경계는 [엔진 구조](ENGINE_ARCHITECTURE.md)에 정리했습니다.
단계별 작업과 최종 완료 판정은 [완전 이식 마스터 플랜](PORT_MASTER_PLAN.md)을 따릅니다.
원본 범위와 남은 검증 항목은 [원본 계약 기준선](PORT_CONTRACT_LEDGER.md)에서 확인할 수 있습니다.

## 실행

Flutter SDK가 설치된 환경에서:

```sh
flutter pub get
flutter run -d chrome
```

데스크톱·모바일 등 다른 Flutter 기기도 `flutter devices`로 확인한 뒤 `flutter run -d <기기>`로 실행할 수 있습니다.

## 검증

```sh
flutter analyze
flutter test
flutter build web --release
python3 tool/audit_lorespec.py repo_source/LORE_1993_src/LORESPEC.PAS --coverage
python3 tool/audit_messages.py
```

원본에서 추출한 지도·폰트·대사·전투 데이터를 `assets/`에 포함했습니다. 추출 및 병합 도구는 `tool/`에 있으며, 게임 실행과 테스트에는 별도의 DOS 런타임이 필요하지 않습니다.
