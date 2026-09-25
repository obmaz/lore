/// 1993년 원작 LORESUB.PAS (727-775행) 기반 45종 전체 마법 체계
enum SpellCategory {
  singleAttack,   // 1..6: 단일 적 공격 마법
  allAttack,      // 7..12: 모든 적 공격 마법
  specialDebuff,  // 13..18: 적 특수 디버프 마법
  singleCure,     // 19..25: 아군 1명 치유/해독/부활
  allCure,        // 26..32: 아군 전체 치유/해독/부활
  field,          // 33..40: 현상계 마법 (필드용)
  esp,            // 41..45: 초능력 / ESP
}

class Spell {
  final int id;
  final String name;
  final SpellCategory category;
  final String description;
  final int baseSp;

  const Spell({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.baseSp,
  });

  /// 시전자의 마법 레벨에 따른 소모 SP 계산 (원작 LOREBATT.PAS 공식)
  int calculateSpCost(int magicLevel) {
    if (magicLevel <= 0) magicLevel = 1;

    switch (category) {
      case SpellCategory.singleAttack:
        // round(level[2] * j * j / 2) (최소 1)
        final j = id; // 1..6
        final cost = (magicLevel * j * j) ~/ 2;
        return cost <= 0 ? 1 : cost;

      case SpellCategory.allAttack:
        // 전체 공격 마법: 단일 마법과 유사하나 위력과 범위가 큼
        final j = id - 6; // 1..6
        final cost = (magicLevel * j * j);
        return cost <= 0 ? 2 : cost;

      case SpellCategory.specialDebuff:
        switch (id) {
          case 13: return 10; // 독
          case 14: return 30; // 기술 무력화
          case 15: return 15; // 방어 무력화
          case 16: return 20; // 능력 저하
          case 17: return 15; // 마법 불능
          case 18: return 20; // 탈 초인화
          default: return 15;
        }

      case SpellCategory.singleCure:
        switch (id) {
          case 19: return 2 * magicLevel; // 한명 치료
          case 20: return 15;             // 한명 독 제거
          case 21: return 2 * magicLevel + 15; // 한명 치료와 독제거
          case 22: return 10;             // 한명 의식 돌림
          case 23: return 30;             // 한명 부활
          case 24: return 2 * magicLevel + 25; // 한명 치료+독제거+의식돌림
          case 25: return 2 * magicLevel + 55; // 한명 복합 치료
          default: return 10;
        }

      case SpellCategory.allCure:
        switch (id) {
          case 26: return 6 * magicLevel; // 모두 치료
          case 27: return 45;             // 모두 독 제거
          case 28: return 6 * magicLevel + 45; // 모두 치료와 독제거
          case 29: return 30;             // 모두 의식 돌림
          case 30: return 6 * magicLevel + 75; // 모두 치료+독제거+의식돌림
          case 31: return 90;             // 모두 부활
          case 32: return 6 * magicLevel + 150; // 모두 복합 치료
          default: return 30;
        }

      case SpellCategory.field:
        return baseSp;

      case SpellCategory.esp:
        switch (id) {
          case 41: return 10; // 투시 (ESP)
          case 42: return 15; // 예언 (ESP)
          case 43: return 15; // 독심 (ESP)
          case 44: return 20; // 천리안 (ESP)
          case 45: return 20; // 염력 (ESP)
          default: return 15;
        }
    }
  }

  /// 마법 레벨에 따라 사용 가능한지 여부 (원작 LOREBATT.PAS 레벨 기준)
  bool isAvailableForLevel(int magicLevel, int espLevel) {
    if (category == SpellCategory.esp) {
      return espLevel >= (id - 40);
    }
    switch (category) {
      case SpellCategory.singleAttack:
        // 0..1: 1개, 2..3: 2개, 4..7: 3개, 8..11: 4개, 12..15: 5개, else 6개
        final req = [0, 0, 2, 4, 8, 12, 16][id];
        return magicLevel >= req;
      case SpellCategory.allAttack:
        // 0..1: 1, 2: 2, 3..5: 3, 6..9: 4, 10..13: 5, 14..17: 6, else 7
        final req = [0, 0, 2, 3, 6, 10, 14][id - 6];
        return magicLevel >= req;
      case SpellCategory.specialDebuff:
        // 0..4: 1, 5..9: 2, 10..11: 3, 12..13: 4, 14..15: 5, 16..17: 6, else 7
        final req = [0, 0, 5, 10, 12, 14, 16][id - 12];
        return magicLevel >= req;
      case SpellCategory.singleCure:
        final req = (id - 18) * 2 - 2;
        return magicLevel >= req;
      case SpellCategory.allCure:
        final req = (id - 25) * 2 + 4;
        return magicLevel >= req;
      default:
        return true;
    }
  }

  // ==========================================
  // 원작 45종 전체 마법 레지스트리 (1..45)
  // ==========================================
  static const List<Spell> allSpells = [
    // 1..6: 단일 공격
    Spell(id: 1, name: '마법 화살', category: SpellCategory.singleAttack, description: '적 1명에게 마력의 화살을 쏘아 타격합니다.', baseSp: 1),
    Spell(id: 2, name: '마법 화구', category: SpellCategory.singleAttack, description: '적 1명에게 불타는 마법 화구를 날립니다.', baseSp: 4),
    Spell(id: 3, name: '마법 단창', category: SpellCategory.singleAttack, description: '적 1명에게 날카로운 마법 단창을 투척합니다.', baseSp: 9),
    Spell(id: 4, name: '독 바늘', category: SpellCategory.singleAttack, description: '적 1명에게 치명적인 독 바늘을 발사합니다.', baseSp: 16),
    Spell(id: 5, name: '맥동 광선', category: SpellCategory.singleAttack, description: '적 1명에게 응축된 맥동 광선을 방출합니다.', baseSp: 25),
    Spell(id: 6, name: '직격 뇌전', category: SpellCategory.singleAttack, description: '적 1명에게 하늘에서 떨어지는 번개를 내리꽂습니다.', baseSp: 36),

    // 7..12: 모든 적 공격
    Spell(id: 7, name: '공기 폭풍', category: SpellCategory.allAttack, description: '모든 적에게 거센 돌풍을 일으켜 타격합니다.', baseSp: 2),
    Spell(id: 8, name: '열선 파동', category: SpellCategory.allAttack, description: '모든 적에게 고온의 열선 파동을 방사합니다.', baseSp: 8),
    Spell(id: 9, name: '초음파', category: SpellCategory.allAttack, description: '모든 적의 청각과 신경을 파괴하는 초음파를 방출합니다.', baseSp: 18),
    Spell(id: 10, name: '초냉기', category: SpellCategory.allAttack, description: '전장을 영하의 혹한으로 뒤덮어 적 전체를 얼립니다.', baseSp: 32),
    Spell(id: 11, name: '인공 지진', category: SpellCategory.allAttack, description: '대지를 뒤흔드는 지진을 일으켜 적 전체를 분쇄합니다.', baseSp: 50),
    Spell(id: 12, name: '차원 이탈', category: SpellCategory.allAttack, description: '차원의 틈을 열어 모든 적에게 괴멸적인 타격을 가합니다.', baseSp: 72),

    // 13..18: 특수 디버프
    Spell(id: 13, name: '독', category: SpellCategory.specialDebuff, description: '적에게 맹독을 주입하여 지속적인 고통을 줍니다.', baseSp: 10),
    Spell(id: 14, name: '기술 무력화', category: SpellCategory.specialDebuff, description: '적의 특수 공격 능력을 영구히 봉인합니다.', baseSp: 30),
    Spell(id: 15, name: '방어 무력화', category: SpellCategory.specialDebuff, description: '적의 장갑과 저항력을 파괴하여 방어력을 낮춥니다.', baseSp: 15),
    Spell(id: 16, name: '능력 저하', category: SpellCategory.specialDebuff, description: '적의 레벨과 전반적인 신체 능력을 약화시킵니다.', baseSp: 20),
    Spell(id: 17, name: '마법 불능', category: SpellCategory.specialDebuff, description: '적의 마법 시전 능력을 억제하여 마법 레벨을 낮춥니다.', baseSp: 15),
    Spell(id: 18, name: '탈 초인화', category: SpellCategory.specialDebuff, description: '적의 초자연적/초능력 특수 능력을 박탈합니다.', baseSp: 20),

    // 19..25: 아군 1명 치유
    Spell(id: 19, name: '한명 치료', category: SpellCategory.singleCure, description: '아군 1명의 생명력(HP)을 회복시킵니다.', baseSp: 2),
    Spell(id: 20, name: '한명 독 제거', category: SpellCategory.singleCure, description: '아군 1명에게 걸린 독을 말끔히 해독합니다.', baseSp: 15),
    Spell(id: 21, name: '한명 치료와 독제거', category: SpellCategory.singleCure, description: '아군 1명의 체력을 회복시키고 독을 치료합니다.', baseSp: 17),
    Spell(id: 22, name: '한명 의식 돌림', category: SpellCategory.singleCure, description: '기절(의식불명) 상태인 아군 1명의 의식을 깨웁니다.', baseSp: 10),
    Spell(id: 23, name: '한명 부활', category: SpellCategory.singleCure, description: '숨을 거둔 아군 1명에게 다시 생명을 불어넣습니다.', baseSp: 30),
    Spell(id: 24, name: '한명 치료+해독+의식돌림', category: SpellCategory.singleCure, description: '기절, 독, 부상을 한 번에 치료합니다.', baseSp: 27),
    Spell(id: 25, name: '한명 복합 치료', category: SpellCategory.singleCure, description: '사망, 기절, 중독, 부상을 모두 완벽히 치유합니다.', baseSp: 57),

    // 26..32: 아군 전체 치유
    Spell(id: 26, name: '모두 치료', category: SpellCategory.allCure, description: '일행 전원의 생명력을 동시에 회복시킵니다.', baseSp: 6),
    Spell(id: 27, name: '모두 독 제거', category: SpellCategory.allCure, description: '일행 전원의 몸에 퍼진 독을 한 번에 해독합니다.', baseSp: 45),
    Spell(id: 28, name: '모두 치료와 독제거', category: SpellCategory.allCure, description: '일행 전원의 체력을 회복하고 독을 정화합니다.', baseSp: 51),
    Spell(id: 29, name: '모두 의식 돌림', category: SpellCategory.allCure, description: '기절한 모든 일행의 의식을 되찾게 합니다.', baseSp: 30),
    Spell(id: 30, name: '모두 치료+해독+의식돌림', category: SpellCategory.allCure, description: '일행 전체의 기절, 독, 상처를 일괄 치료합니다.', baseSp: 81),
    Spell(id: 31, name: '모두 부활', category: SpellCategory.allCure, description: '쓰러져 사망한 모든 일행을 동시에 부활시킵니다.', baseSp: 90),
    Spell(id: 32, name: '모두 복합 치료', category: SpellCategory.allCure, description: '일행 전원의 사망, 기절, 독, 상처를 완전히 소생시킵니다.', baseSp: 156),

    // 33..40: 현상계 마법 (필드용)
    Spell(id: 33, name: '마법의 햇불', category: SpellCategory.field, description: '어두운 던전을 밝히는 마법 불빛을 밝힙니다.', baseSp: 5),
    Spell(id: 34, name: '공중 부상', category: SpellCategory.field, description: '일행의 몸을 띄워 함정을 무시합니다.', baseSp: 10),
    Spell(id: 35, name: '물위를 걸음', category: SpellCategory.field, description: '깊은 물 위를 자유롭게 걸을 수 있게 합니다.', baseSp: 15),
    Spell(id: 36, name: '늪위를 걸음', category: SpellCategory.field, description: '독 늪지대를 피해 없이 안전하게 통과합니다.', baseSp: 15),
    Spell(id: 37, name: '기화 이동', category: SpellCategory.field, description: '벽을 뚫고 통과할 수 있는 기화 상태가 됩니다.', baseSp: 25),
    Spell(id: 38, name: '지형 변화', category: SpellCategory.field, description: '험난한 주변 지형을 평탄하게 바꿉니다.', baseSp: 30),
    Spell(id: 39, name: '공간 이동', category: SpellCategory.field, description: '원하는 마을이나 거점으로 즉시 공간도약합니다.', baseSp: 40),
    Spell(id: 40, name: '식량 제조', category: SpellCategory.field, description: '마력으로 일행의 비상 식량을 소환합니다.', baseSp: 10),

    // 41..45: 초능력 / ESP
    Spell(id: 41, name: '투시', category: SpellCategory.esp, description: '숨겨진 보물상자나 비밀 통로를 투시합니다.', baseSp: 10),
    Spell(id: 42, name: '예언', category: SpellCategory.esp, description: '성전의 기록과 다음 행선지의 미래를 예언받습니다.', baseSp: 15),
    Spell(id: 43, name: '독심', category: SpellCategory.esp, description: '전투 중 적의 마음을 읽어 일행의 편으로 끌어들입니다.', baseSp: 15),
    Spell(id: 44, name: '천리안', category: SpellCategory.esp, description: '멀리 떨어진 맵의 지형과 구조를 감지합니다.', baseSp: 20),
    Spell(id: 45, name: '염력', category: SpellCategory.esp, description: '강력한 정신력으로 물리적 물체나 원자를 조작하여 적을 분쇄합니다.', baseSp: 20),
  ];

  static Spell getById(int id) {
    if (id < 1 || id > 45) return allSpells[0];
    return allSpells[id - 1];
  }
}
