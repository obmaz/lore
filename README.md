# LORE

이 저장소는 원본 이식판과 모바일 리메이크를 하나의 `main` 브랜치에서
동시에 관리합니다.

## 프로젝트 구조

- [`original/`](original/): `main` 브랜치의 원본 이식판
- [`remake/`](remake/): `new_ui` 브랜치의 모바일 현대화판
- [`novel/`](novel/): 게임 코드와 분리된 독립 집필 자료·검증 도구

각 폴더는 독립적인 Flutter 프로젝트입니다. 해당 폴더로 이동한 뒤 기존
Flutter 명령을 실행하세요.

```bash
cd remake
flutter pub get
flutter run -d chrome
```

GitHub Pages 배포 대상은 현재 모바일 리메이크인 `remake/docs`입니다.
원본을 수정할 때는 `original/`, 리메이크를 수정할 때는 `remake/`에서 작업하고,
소설 자료는 `novel/`에서 별도로 작업합니다. 세 루트는 서로의 코드·자료를
읽거나 실행하지 않습니다.
