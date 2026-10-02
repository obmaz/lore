/// 1993년 원작 LORE (Borland Pascal 6.0) 마을 시설 및 야외 휴식 규칙을
/// UI 위젯과 완전히 분리한 순수 Dart 로직 계층.
///
/// 대응 원작 루틴:
/// - `LORESUB.PAS:1155  Grocery`        (식료품점)
/// - `LORESUB.PAS:1183  Weapon_Shop`    (무기/방패/갑옷 상점)
/// - `LORESUB.PAS:1332  Train_Center`   (군사 훈련소)
/// - `LORESUB.PAS:1517  Hospital`       (병원/신전)
/// - `LOREMENU.PAS:869  Rest`           (야외 캠프 휴식)
///
/// 모든 수치와 대사는 원본 소스를 Johab(CP1361) 디코딩하여 그대로 옮긴 것이다.
/// (도구: `tool/decode_johab.py`)
library;

import 'dart:math';

import '../models/item.dart';
import '../models/party_member.dart';
import 'lore_field_logic.dart';

/// 병원(신전)에서 받을 수 있는 4종 치료 - 원작 `Hospital`의 `select` 메뉴 순서.
enum Treatment {
  /// 상처를 치료 (HP 완전 회복)
  wounds,

  /// 독을 제거
  poison,

  /// 의식의 회복
  consciousness,

  /// 부활
  revive,
}

/// 야외 캠프 휴식(LOREMENU.PAS:869 Rest) 1회 실행 결과.
class RestOutcome {
  /// 휴식 후 남은 식량 (원작 `party.food`).
  final int food;

  /// 휴식 후 마법의 횃불 잔여 스텝 (원작 `party.etc[1]`, 매 휴식마다 1 감소).
  final int torchSteps;

  /// 원작 `Print` 순서를 그대로 보존한 메시지 목록.
  final List<String> logs;

  const RestOutcome({
    required this.food,
    required this.torchSteps,
    required this.logs,
  });

  /// 실제로 체력/의식이 회복된 파티원 수 (테스트 편의용).
  int get healedCount =>
      logs.where((l) => l.contains('회복되었다') || l.contains('치료되었다')).length;
}

/// 군사 훈련소에서 특정 파티원을 승급시킬 때의 견적서 - 원작 `Train_Center` 판정부.
class TrainOffer {
  /// 누적 경험치로 계산된 "도달 가능 레벨" (원작 변수 `j`).
  final int targetLevel;

  /// `targetLevel` 도달에 필요한 누적 경험치 (`ExpData`).
  final int requiredExp;

  /// 훈련 비용 (원작 `long`). Lv.20 도달 시 원작은 금화를 받지 않으므로 0이다.
  final int cost;

  /// 실제로 훈련(승급)이 가능한지 여부.
  final bool canTrain;

  /// 훈련 불가 시 다음 레벨까지 남은 경험치 (원작의 "경험치가 N 이상 이어야 합니다").
  final int expShortage;

  const TrainOffer({
    required this.targetLevel,
    required this.requiredExp,
    required this.cost,
    required this.canTrain,
    required this.expShortage,
  });

  /// 원작이 출력하던 "당신은 금 N개가 더 필요합니다." 문구용 부족 금화.
  int goldShortage(int gold) => canTrain && cost > gold ? cost - gold : 0;
}

/// 원작 마을 시설/휴식의 순수 계산 및 상태 변경 규칙 모음.
class TownLogic {
  TownLogic._();

  // ==========================================================================
  // 공통: 원작 대사 (Johab 디코딩 원문 그대로)
  // ==========================================================================

  static const String groceryIntro = '여기는 식료품점 입니다.';
  static const String groceryPrompt = '몇개를 원하십니까 ?';

  /// 원작 `m[1] := '필요 없습니다'` (구두점 없음).
  static const String groceryDecline = '필요 없습니다';
  static const String shopIntro = '여기는 무기상점입니다.';
  static const String shopSubIntro = '우리들은 무기, 방패, 갑옷을 팔고있습니다.';
  static const String shopCategoryPrompt = '어떤 종류를 원하십니까 ?';
  static const String shopWeaponPrompt = '어떤 무기를 원하십니까 ?';
  static const String shopShieldPrompt = '어떤 방패를 원하십니까 ?';
  static const String shopArmorPrompt = '어떤 갑옷을 원하십니까 ?';
  static const String shopMonkRefuse = '전투승은 이 무기가 필요없습니다.';
  static const String trainIntro = '여기는 군사 훈련소 입니다.';
  static const String trainSubIntro =
      '만약 당신이 충분한 전투 경험을 쌓았다면, 당신은 더욱 능숙하게 무기를 다룰것입니다.';
  static const String trainMaxLevel = '당신은 최고 레벨에 도달했습니다.';
  static const String trainNoNeedToTeach = '더 이상 저희들은 가르칠 필요가 없습니다.';
  static const String trainNotEnoughExp = '당신은 아직 전투 경험이 부족합니다.';
  static const String hospitalIntro = '여기는 병원입니다.';
  static const String hospitalWhoPrompt = '누가 치료를 받겠습니까 ?';
  static const String hospitalWhatPrompt = '어떤 치료입니까 ?';

  /// 원작 `notenoughmoney` / `thankyou` / `asyouwish` (LORESUB.PAS:1027~1037).
  /// 문구는 [LoreFieldLogic]을 단일 소스로 사용한다.
  static const String notEnoughMoney = LoreFieldLogic.notEnoughMoney;
  static const String thankYou = LoreFieldLogic.thankYou;
  static const String asYouWish = LoreFieldLogic.asYouWish;

  /// 성별에 따른 원작 대명사 (`his`/`her`).
  static String possessive(Gender sex) => sex == Gender.male ? '그의' : '그녀의';

  // ==========================================================================
  // 1. 식료품점 (LORESUB.PAS:1155 Grocery)
  //    원작: i=1..5 → (i*10)인분 : 금 (i*100)개, 최대 255인분
  // ==========================================================================

  static const int maxFood = 255;

  /// 10인분~50인분까지 5종류.
  static const List<int> foodPackageAmounts = [10, 20, 30, 40, 50];

  /// 식량 `amount`인분의 가격 - 원작은 10인분당 100금화 고정이다.
  static int foodPackagePrice(int amount) => amount * 10;

  /// 구입 가능 여부 (금화 부족 / 이미 최대치).
  static bool canBuyFood(int gold, int currentFood, int amount) =>
      gold >= foodPackagePrice(amount) && currentFood < maxFood;

  /// 식량 구입을 실제로 적용한 뒤 (남은 금화, 새 식량)을 돌려준다.
  /// 원작과 동일하게 255인분을 넘는 분량은 버려진다(clamp).
  static (int gold, int food) buyFood(int gold, int currentFood, int amount) {
    final cost = foodPackagePrice(amount);
    return (gold - cost, min(maxFood, currentFood + amount));
  }

  // ==========================================================================
  // 2. 무기/방패/갑옷 상점 (LORESUB.PAS:1183 Weapon_Shop)
  //    - 무기: 1..9, 가격 500 ~ 100000 (Item.weapons 그대로)
  //    - 방패: 위력 = 등급 k      (가죽 1,000 → 금제 100,000)
  //    - 갑옷: 위력 = 등급 k + 1  (가죽 5,000 → 금제 200,000)
  //    - 기사(class 1)는 무기 위력 1.5배, AC +1
  // ==========================================================================

  /// 상점에서 파는 무기 (맨손 0번 제외 1..9).
  static List<Item> get shopWeapons => Item.weapons.skip(1).toList();

  /// 상점에서 파는 방패 (없음 0번 제외 1..5).
  static List<Item> get shopShields => Item.shields.skip(1).toList();

  /// 상점에서 파는 갑옷 (없음 0번 제외 1..5).
  static List<Item> get shopArmors => Item.armors.skip(1).toList();

  /// 원작 기준 장착 처리. 전투승(Monk)은 무기를 살 수 없다.
  /// 반환값: 원작대로 처리되었으면 true.
  static bool equipPurchased(PartyMember member, Item item) {
    switch (item.type) {
      case ItemType.weapon:
        if (member.playerClass == PlayerClass.monk) return false;
        member.equipWeapon(item);
        return true;
      case ItemType.shield:
        member.equipShield(item);
        return true;
      case ItemType.armor:
        member.equipArmor(item);
        return true;
    }
  }

  // ==========================================================================
  // 3. 군사 훈련소 (LORESUB.PAS:1332 Train_Center)
  // ==========================================================================

  /// 원작 `ExpData` 테이블 (Lv.2 ~ Lv.20 필요 누적 경험치).
  ///
  /// 주의: 원작 소스의 문자열 상수에는 오타가 두 개 있다.
  ///  - Lv.15: `'270000'`  (실제 값 2,700,000)
  ///  - Lv.20: `'510000'`  (실제 값 5,100,000)
  /// 본 이식판은 실제 게임 진행과 일치하도록 복원된 값을 사용한다
  /// (`PartyMember.expTable`).
  static int expRequiredForLevel(int level) {
    if (level <= 1) return 0;
    if (level > 20) level = 20;
    return PartyMember.expTable[level - 1];
  }

  /// 원작 Train_Center의 판정부를 그대로 재현한 견적서 생성.
  static TrainOffer evaluateTraining(PartyMember member) {
    final target = PartyMember.getCalculatedLevel(member.experience);
    final canTrain = target > member.battleLevel && member.battleLevel < 20;
    final nextLevel = min(20, member.battleLevel + 1);
    return TrainOffer(
      targetLevel: target,
      requiredExp: expRequiredForLevel(target),
      // 원작은 Lv.20 도달 시 금화를 받지 않고 즉시 20으로 만들어 준다.
      cost: target >= 20 ? 0 : PartyMember.getTrainingCost(target),
      canTrain: canTrain,
      expShortage: max(0, expRequiredForLevel(nextLevel) - member.experience),
    );
  }

  /// 승급 처리 후 원작 `Print` 메시지 목록을 돌려준다.
  /// (금화 차감은 호출측에서 `offer.cost`로 수행한다.)
  static List<String> applyTraining(PartyMember member, TrainOffer offer) {
    if (!offer.canTrain) return const [];
    if (offer.targetLevel >= 20) {
      member.trainLevelUp(20);
      return [trainMaxLevel, trainNoNeedToTeach];
    }
    final logs = <String>[
      ...member.trainLevelUp(offer.targetLevel),
      '${member.name}의 레벨은 ${offer.targetLevel} 입니다.',
    ];
    return logs;
  }

  // ==========================================================================
  // 4. 병원/신전 (LORESUB.PAS:1517 Hospital)
  // ==========================================================================

  /// 상처 치료 비용: `(endurance*level[1] - hp) * level[1] div 2 + 1`
  static int treatmentCost(PartyMember p, Treatment t) {
    switch (t) {
      case Treatment.wounds:
        return ((p.maxHp - p.hp) * p.battleLevel) ~/ 2 + 1;
      case Treatment.poison:
        return p.battleLevel * 10;
      case Treatment.consciousness:
        return p.unconscious * 2;
      case Treatment.revive:
        return p.dead * 100 + 400;
    }
  }

  /// 원작 `Hospital`의 조건 분기 그대로.
  static bool canTreat(PartyMember p, Treatment t) {
    switch (t) {
      case Treatment.wounds:
        return p.dead == 0 &&
            p.unconscious == 0 &&
            p.poison == 0 &&
            p.hp < p.maxHp;
      case Treatment.poison:
        return p.dead == 0 && p.unconscious == 0 && p.poison > 0;
      case Treatment.consciousness:
        return p.dead == 0 && p.unconscious > 0;
      case Treatment.revive:
        return p.dead > 0;
    }
  }

  /// 치료 불가 시 원작이 출력하던 안내 문구.
  static String unavailableReason(PartyMember p, Treatment t) {
    switch (t) {
      case Treatment.wounds:
        if (p.dead > 0) return '${p.name}는 이미 죽은 상태입니다';
        if (p.unconscious > 0) return '${p.name}는 이미 의식불명입니다';
        if (p.poison > 0) return '${p.name}는 독이 퍼진 상태입니다';
        return '${p.name}는 치료할 필요가 없습니다';
      case Treatment.poison:
        if (p.dead > 0) return '${p.name}는 이미 죽은 상태입니다';
        if (p.unconscious > 0) return '${p.name}는 이미 의식불명입니다';
        return '${p.name}는 독에 걸리지 않았습니다';
      case Treatment.consciousness:
        if (p.dead > 0) return '${p.name}는 이미 죽은 상태입니다';
        return '${p.name}는 의식불명이 아닙니다';
      case Treatment.revive:
        return '${p.name}는 죽지 않았습니다';
    }
  }

  /// 치료 성공 시 원작이 출력하던 문구.
  static String appliedMessage(PartyMember p, Treatment t) {
    switch (t) {
      case Treatment.wounds:
        return '${p.name}는 ${possessive(p.sex)} 모든 건강이 회복되었다';
      case Treatment.poison:
        return '${p.name}는 독이 제거 되었습니다';
      case Treatment.consciousness:
        return '${p.name}는 의식을 차렸습니다';
      case Treatment.revive:
        return '${p.name}는 다시 살아났습니다';
    }
  }

  /// 치료 효과를 실제 적용한다 (원작 효과 그대로).
  static void applyTreatment(PartyMember p, Treatment t) {
    switch (t) {
      case Treatment.wounds:
        p.hp = p.maxHp;
        break;
      case Treatment.poison:
        p.poison = 0;
        break;
      case Treatment.consciousness:
        p.unconscious = 0;
        p.hp = 1;
        break;
      case Treatment.revive:
        p.dead = 0;
        // 원작: unconscious 값이 최대 HP보다 크면 최대 HP로 제한할 뿐,
        //       HP나 의식불명 상태를 완전히 지워주지는 않는다.
        if (p.unconscious > p.maxHp) p.unconscious = p.maxHp;
        break;
    }
  }

  // ==========================================================================
  // 5. 야외 캠프 휴식 (LOREMENU.PAS:869 Rest)
  // ==========================================================================

  /// 원작 Rest 프로시저를 1:1로 재현한다.
  ///
  /// 1) 파티원 1~6번 순서로:
  ///    - 식량이 0이면 "일행은 식량이 바닥났다"만 출력
  ///    - 사망자는 제외
  ///    - 의식불명(독 아님): `unconscious -= (레벨1+레벨2+레벨3)`,
  ///      깨어나면 식량 1 소모 & `hp<=0`이면 1로 보정
  ///    - 의식불명 + 중독: 독 때문에 의식 회복 실패
  ///    - 중독: 독 때문에 건강 회복 실패
  ///    - 정상: `hp += (레벨1+레벨2+레벨3)*2` (최대치 제한),
  ///      이미 만복이었다면 식량 1개를 되돌려받아 순 소모 0
  /// 2) `party.etc[1]`(마법의 횃불) 1 감소, `etc[2..4]`(물위걸음/늪위걸음/공중부상) 초기화
  /// 3) 살아있는 파티원 전원의 `sp = mentality*level[2]`, `esp = concentration*level[3]` 완전 회복
  static RestOutcome rest(
    List<PartyMember> party,
    int food, {
    int torchSteps = 0,
  }) {
    final logs = <String>[];
    var currentFood = food;

    for (final p in party) {
      if (p.name.isEmpty) continue;

      if (currentFood <= 0) {
        logs.add('일행은 식량이 바닥났다');
        continue;
      }
      if (p.dead > 0) {
        logs.add('${p.name}는 죽었다');
        continue;
      }
      if (p.unconscious > 0 && p.poison == 0) {
        p.unconscious -= p.battleLevel + p.magicLevel + p.espLevel;
        if (p.unconscious <= 0) {
          p.unconscious = 0;
          if (p.hp <= 0) p.hp = 1;
          currentFood--;
          logs.add('${p.name}는 의식이 회복되었다');
        } else {
          logs.add('${p.name}는 여전히 의식 불명이다');
        }
      } else if (p.unconscious > 0 && p.poison > 0) {
        logs.add('독때문에, ${p.name} ${possessive(p.sex)} 의식은 회복되지 않았다');
      } else if (p.poison > 0) {
        logs.add('독때문에, ${p.name} ${possessive(p.sex)} 건강은 회복되지 않았다');
      } else {
        final heal = (p.battleLevel + p.magicLevel + p.espLevel) * 2;
        // 원작: 이미 만복이면 식량을 1개 돌려받은 뒤 다시 1개 소모한다(순 소모 0).
        if (p.hp >= p.maxHp && currentFood < maxFood) currentFood++;
        p.hp += heal;
        if (p.hp >= p.maxHp) {
          p.hp = p.maxHp;
          logs.add('${p.name}는 모든 건강이 회복되었다');
        } else {
          logs.add('${p.name}는 치료되었다');
        }
        currentFood--;
      }
    }

    // 현상계 지속 마법 해제 (원작 party.etc[1..4]).
    var torch = torchSteps;
    if (torch > 0) torch--;

    // 마력/초능력 완전 회복 (원작은 사망자 포함 이름이 있는 파티원 전원에게 적용).
    for (final p in party) {
      if (p.name.isEmpty) continue;
      p.sp = p.maxSp;
      p.esp = p.maxEsp;
    }

    return RestOutcome(food: currentFood, torchSteps: torch, logs: logs);
  }
}
