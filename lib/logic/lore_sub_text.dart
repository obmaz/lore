/// 1993년 원작 `LORESUB.PAS` 의 문구/표현을 그대로 옮긴 모듈.
///
/// 원작에서 UI(선택창/상태표/상점/전투 로그)에 쓰이던 문자열과 함수를
/// 포트에서도 동일하게 쓰기 위해 모아 둔다.
library;

/// 원작 `LORESUB.PAS:440` 이후 GameOver / 세이브·로드 선택창.
class LoreSubText {
  const LoreSubText._();

  /// 원작 `PressAnyKey` 대기 안내 (`LORESUB.PAS:209`).
  static const String pressAnyKey = '아무키나 누르십시오 ...';

  /// 원작 `LORESUB.PAS:452` - 전멸(party.etc[6] = 255) 시.
  static const String allDead = '일행은 모험중에 모두 목숨을 잃었다.';

  /// 원작 `LORESUB.PAS:456` - 불러올 게임 선택.
  static const String selectLoadGame = '불러 내고 싶은 게임을 선택하십시오.';
  static const List<String> loadSlots = [
    '없습니다',
    '본 게임 데이타',
    '게임 데이타 1 (부)',
    '게임 데이타 2 (부)',
    '게임 데이타 3 (부)',
  ];

  /// 원작 `LORESUB.PAS:465` - 불러오는 중.
  static const String loadingGame = '저장했던 게임을 다시 불러옵니다';

  /// 원작 `LORESUB.PAS:474` - 종료 확인.
  static const String quitConfirm = '정말로 끝내겠습니까 ?';
  static const String quitNo = '       << 아니오 >>';
  static const String quitYes = '       <<   예   >>';

  /// 원작 `LORESUB.PAS:480` - 전투 패배(party.etc[6] = 1) 시.
  static const String battleLost = '일행은 모두 전투에서 패했다 !!';
  static const String battleLostAsk = '    어떻게 하시겠습니까 ?';
  static const String resumeGame = '   이전의 게임을 재개한다';
  static const String endGame = '       게임을 끝낸다';

  /// 원작 `LORESUB.PAS:621` - 대상 선택 안내.
  static const String chooseOne = '한명을 고르시오 ---';

  /// 원작 `LORESUB.PAS:1350` - 훈련소.
  static const String trainWho = '누가 훈련을 받겠습니까 ?';

  /// 원작 `LORESUB.PAS:1507` - 승급에 필요한 경험치 안내(앞부분).
  static const String trainExpPrefix = ' 당신이 다음 레벨이 되려면 경험치가 ';

  /// 원작 `LORESUB.PAS:1183` - 상점 가격 표기.
  ///
  /// 원작은 선택지 문자열을 `ReturnWeapon(i) + ' : ' + '금 500'` 처럼 만든다.
  static const List<String> priceLabels = [
    '금 500',
    '금 1500',
    '금 3000',
    '금 5000',
    '금 10000',
    '금 30000',
    '금 60000',
    '금 80000',
    '금 100000',
    '금 1000',
    '금 25000',
    '금 200000',
  ];

  static String priceLabel(int gold) => '금 $gold';

  /// 원작 `LORESUB.PAS:1218` - 상점 수량 표기(`' 개'`).
  static const String countSuffix = ' 개';

  /// 원작 상태표 머리글 (`LORESUB.PAS:1520` 부근).
  static const String statusHeader = '이름 체력 마력 초능력 방어 레벨 상태';

  // ---------------------------------------------------------------------
  // 원작 `LORESUB.PAS:640` ReturnClass / :665 ReturnWeapon / :685 ReturnDefense
  // ---------------------------------------------------------------------
  /// 직업 번호 → 이름 (원작 `LORESUB.PAS:640` ReturnClass).
  static const Map<int, String> classNames = {
    1: '기사',
    2: '마법사',
    3: '에스퍼',
    4: '전사',
    5: '전투승',
    6: '닌자',
    7: '사냥꾼',
    8: '떠돌이',
    9: '혼령',
    10: '반신반인',
  };

  static const String classNameDefault = '불확실함';

  /// 무기 번호 → 이름 (원작 `LORESUB.PAS:665` ReturnWeapon).
  static const Map<int, String> weaponNames = {
    0: '맨손',
    1: '단도',
    2: '곤봉',
    3: '미늘창',
    4: '장검',
    5: '철퇴',
    6: '기병창',
    7: '도끼창',
    8: '삼지창',
    9: '화염검',
  };

  static const String weaponNameDefault = '불확실한 무기';

  /// 방패/갑옷 번호 → 이름 (원작 `LORESUB.PAS:685` ReturnDefense).
  static const Map<int, String> defenseNames = {
    0: '없음',
    1: '가죽',
    2: '청동',
    3: '강철',
    4: '은제',
    5: '금제',
  };

  static const String defenseNameDefault = '불확실한';

  static String classLabel(int id) => classNames[id] ?? classNameDefault;
  static String weaponLabel(int id) => weaponNames[id] ?? weaponNameDefault;

  /// `ReturnWeapon`의 `Josa`: 0, 2..4, 6..9 는 '으', 그 외는 ''.
  static String weaponJosa(int id) =>
      (id == 0 || (id >= 2 && id <= 4) || (id >= 6 && id <= 9)) ? '으' : '';
  static String defenseLabel(int id) => defenseNames[id] ?? defenseNameDefault;

  // ---------------------------------------------------------------------
  // 원작 `LORESUB.PAS:786` ReturnMessage
  // ---------------------------------------------------------------------
  /// 전투 로그 문장 생성(원작 `ReturnMessage(who, how, what, whom)`).
  ///
  /// - `how` 1: 무기 공격, 2/3: 마법 공격, 4: 특수 공격,
  ///   5: 아군 대상 마법, 6: 적 대상 마법, 7: 도망, 그 외: 주저
  static String returnMessage({
    required String actor,
    required int how,
    int? what,
    String? target,
  }) {
    final name = actor;
    switch (how) {
      case 1:
        return '$name는 ${weaponLabel(what ?? 0)}${weaponJosa(what ?? 0)}로 $target를 공격했다';
      case 2:
      case 3:
        return "$name는 '${magicName((what ?? 0) + (how == 3 ? 6 : 0))}'${magicJosa((what ?? 0) + (how == 3 ? 6 : 0))}로 $target에게 공격했다";
      case 4:
        return '$name는 $target에게 ${magicName((what ?? 0) + 12)}${magicJosa((what ?? 0) + 12)}로 특수 공격을 했다';
      case 5:
        return "$name는 $target에게 '${magicName((what ?? 0) + 18)}'${magicMokjuk((what ?? 0) + 18)} 사용했다";
      case 6:
        return '$name는 $target에게 ${magicName((what ?? 0) + 40)}${magicMokjuk((what ?? 0) + 40)} 사용했다';
      case 7:
        return '일행은 도망을 시도했다';
      default:
        return '$name는 잠시 주저했다';
    }
  }

  /// 원작 `LORESUB.PAS:725` ReturnMagic - 마법 번호 → 이름.
  static const Map<int, String> magicNames = {
    1: '마법 화살',
    2: '마법 화구',
    3: '마법 단창',
    4: '독 바늘',
    5: '맥동 광선',
    6: '직격 뇌전',
    7: '공기 폭풍',
    8: '열선 파동',
    9: '초음파',
    10: '초냉기',
    11: '인공 지진',
    12: '차원 이탈',
    13: '독',
    14: '기술 무력화',
    15: '방어 무력화',
    16: '능력 저하',
    17: '마법 불능',
    18: '탈 초인화',
    19: '한명 치료',
    20: '한명 독 제거',
    21: '한명 치료와 독제거',
    22: '한명 의식 돌림',
    23: '한명 부활',
    24: '한명 치료와 독제거와 의식돌림',
    25: '한명 복합 치료',
    26: '모두 치료',
    27: '모두 독 제거',
    28: '모두 치료와 독제거',
    29: '모두 의식 돌림',
    30: '모두 치료와 독제거와 의식돌림',
    31: '모두 부활',
    32: '모두 복합 치료',
    33: '마법의 햇불',
    34: '공중 부상',
    35: '물위를 걸음',
    36: '늪위를 걸음',
    37: '기화 이동',
    38: '지형 변화',
    39: '공간 이동',
    40: '식량 제조',
    41: '투시',
    42: '예언',
    43: '독심',
    44: '천리안',
    45: '염력',
  };

  static const String magicNamesDefault = '';

  static const String magicNameDefault = '';

  static String magicName(int id) => magicNames[id] ?? magicNameDefault;

  static const Set<int> _josaE = {
    2,
    9,
    10,
    14,
    15,
    16,
    18,
    19,
    20,
    21,
    25,
    26,
    27,
    28,
    32,
    38,
    40,
    41,
  };

  /// LORESUB `ReturnMagic`: `if magic in [2,9,10,...] then Josa := ''` else `'으'`.
  static String magicJosa(int id) => _josaE.contains(id) ? '' : '으';

  /// LORESUB `ReturnMagic`: `if magic in [2,9,10,...] then Mokjuk := '를'` else `'을'`.
  static String magicMokjuk(int id) => _josaE.contains(id) ? '를' : '을';
}
