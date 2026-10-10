import 'dart:math';

import '../logic/lore_random.dart';
import '../logic/lore_source_memory.dart';

import 'item.dart';
import 'monster.dart';

enum Gender { male, female }

enum PlayerClass {
  knight(1, '기사'),
  mage(2, '마법사'),
  esper(3, '에스퍼'),
  warrior(4, '전사'),
  monk(5, '전투승'),
  ninja(6, '닌자'),
  hunter(7, '사냥꾼'),
  vagrant(8, '떠돌이'),
  ghost(9, '혼령'),
  demigod(10, '반신'),

  /// 원작 `join`으로 영입된 동료 (파스칼 `class := 0`).
  /// 직업별 성장 판정이 적용되지 않는다.
  none(0, '동료');

  final int id;
  final String koreanName;
  const PlayerClass(this.id, this.koreanName);

  static PlayerClass fromId(int id) {
    return PlayerClass.values.firstWhere(
      (c) => c.id == id,
      orElse: () => PlayerClass.warrior,
    );
  }
}

/// 1993년 원작 LORESUB.PAS의 'lore' 레코드에 대응하는 파티원 클래스
class PartyMember {
  String name;
  Gender sex;
  PlayerClass playerClass;

  int strength;
  int mentality;
  int concentration;
  int endurance;
  int resistance;
  int agility;
  int accArms;
  int accMagic;
  int accEsp;
  int luck;

  int poison;
  int unconscious;
  int dead;

  int hp;
  int sp;
  int esp;

  int battleLevel;
  int magicLevel;
  int espLevel;

  int experience;
  int ac;

  int weapon;
  int shield;
  int armor;
  int weaPower;
  int shiPower;
  int armPower;

  PartyMember({
    required this.name,
    this.sex = Gender.male,
    required this.playerClass,
    required this.strength,
    required this.mentality,
    required this.concentration,
    required this.endurance,
    required this.resistance,
    required this.agility,
    required this.accArms,
    required this.accMagic,
    required this.accEsp,
    required this.luck,
    this.battleLevel = 1,
    this.magicLevel = 1,
    this.espLevel = 1,
    this.experience = 0,
    int? hp,
    int? sp,
    int? esp,
    this.poison = 0,
    this.unconscious = 0,
    this.dead = 0,
    this.weapon = 0,
    this.shield = 0,
    this.armor = 0,
    int? weaPower,
    this.shiPower = 0,
    this.armPower = 0,
    int? ac,
  }) : weaPower =
           weaPower ??
           (playerClass == PlayerClass.monk
               ? 12
               : (playerClass == PlayerClass.knight ? 3 : 2)),
       ac = ac ?? (playerClass == PlayerClass.knight ? 1 : 0),
       hp = hp ?? (endurance * battleLevel),
       sp = sp ?? (mentality * magicLevel),
       esp = esp ?? (concentration * espLevel);

  /// Fresh, unwritten Pascal record, before Display_Condition is called.
  factory PartyMember.zero() => PartyMember(
    name: '',
    sex: Gender.male,
    playerClass: PlayerClass.none,
    strength: 0,
    mentality: 0,
    concentration: 0,
    endurance: 0,
    resistance: 0,
    agility: 0,
    accArms: 0,
    accMagic: 0,
    accEsp: 0,
    luck: 0,
    hp: 0,
    sp: 0,
    esp: 0,
    battleLevel: 0,
    magicLevel: 0,
    espLevel: 0,
    weaPower: 0,
    ac: 0,
  );

  /// An unused `player[k]` slot past the joined members: the zero record of
  /// `Create` after its first `SimpleDisCond`, whose `ReturnCondition` turns
  /// `hp = 0` into `unconscious := 1` and then `dead := 1` (LORESUB:709-710).
  /// (`player[k].name := ''` keeps the record as it was instead.)
  factory PartyMember.blank() => PartyMember(
    name: '',
    playerClass: PlayerClass.none,
    strength: 0,
    mentality: 0,
    concentration: 0,
    endurance: 0,
    resistance: 0,
    agility: 0,
    accArms: 0,
    accMagic: 0,
    accEsp: 0,
    luck: 0,
    hp: 0,
    sp: 0,
    esp: 0,
    unconscious: 1,
    dead: 1,
  );

  /// LORESUB `SimpleDisCond`: `ReturnCondition(j)` for the slots 1..6, named
  /// or not (only the drawing is skipped for empty names).
  static void simpleDisCond(Iterable<PartyMember> party) {
    for (final member in party.take(6)) {
      member.returnCondition();
    }
  }

  int get maxHp => endurance * battleLevel;
  int get maxSp => mentality * magicLevel;
  int get maxEsp => concentration * espLevel;

  bool get isDead => dead > 0;
  bool get isUnconscious => unconscious > 0 && !isDead;
  bool get isPoisoned => poison > 0 && !isDead;
  bool get isAlive => !isDead;
  bool get canAct => !isDead && !isUnconscious;

  /// LORESUB.PAS `exist`: 전투에서 실제로 행동할 수 있는 파티 슬롯.
  bool get isBattleActive =>
      name.isNotEmpty && unconscious == 0 && dead == 0 && hp > 0;

  /// LORESUB.PAS `ReturnCondition`: the text and its side effects. A member
  /// with `hp <= 0` and no `unconscious` becomes unconscious (1), and one
  /// whose `unconscious` exceeds `endurance * level[1]` dies (`dead := 1`).
  /// `DisplayCondition`/`SimpleDisCond` run this for every redraw of the slot.
  String returnCondition() {
    if (hp <= 0 && unconscious == 0) unconscious = 1;
    if (unconscious > LorePascal.integer(endurance * battleLevel) &&
        dead == 0) {
      dead = 1;
    }
    return condition;
  }

  String get condition {
    if (dead > 0) return 'dead';
    if (unconscious > 0) return 'unconscious';
    if (poison > 0) return 'poisoned';
    return 'good';
  }

  static const List<String> weaponNames = [
    '맨손',
    '단도',
    '곤봉',
    '미늘창',
    '장검',
    '철퇴',
    '기병창',
    '도끼창',
    '삼지창',
    '화염검',
  ];
  static const List<String> shieldNames = [
    '없음',
    '가죽 방패',
    '청동 방패',
    '강철 방패',
    '기사 방패',
    '마법 방패',
  ];
  static const List<String> armorNames = [
    '평복',
    '가죽 갑옷',
    '사슬 갑옷',
    '판금 갑옷',
    '기사 갑옷',
    '용비늘 갑옷',
  ];

  String get weaponName =>
      weapon >= 0 && weapon < weaponNames.length ? weaponNames[weapon] : '맨손';
  String get shieldName =>
      shield >= 0 && shield < shieldNames.length ? shieldNames[shield] : '없음';
  String get armorName =>
      armor >= 0 && armor < armorNames.length ? armorNames[armor] : '평복';

  /// 원작 LORESUB.PAS 기준 무기 장착
  void equipWeaponRaw(int id, int power) {
    if (playerClass == PlayerClass.monk) return;
    weapon = id;
    int p = LorePascal.byte(power);
    if (playerClass == PlayerClass.knight) {
      p = LorePascal.byte(p + (p * 0.5).round());
    }
    weaPower = p;
  }

  void equipShieldRaw(int id, int power) {
    shield = id;
    shiPower = power;
    _updateAc();
  }

  void equipArmorRaw(int id, int power) {
    armor = id;
    armPower = power;
    _updateAc();
  }

  /// 무기 장착 (Item 기반)
  void equipWeapon(Item item) {
    if (item.type != ItemType.weapon) return;
    equipWeaponRaw(item.id, item.power);
  }

  /// 방패 장착
  void equipShield(Item item) {
    if (item.type != ItemType.shield) return;
    equipShieldRaw(item.id, item.power);
  }

  /// 갑옷 장착
  void equipArmor(Item item) {
    if (item.type != ItemType.armor) return;
    equipArmorRaw(item.id, item.power);
  }

  void _updateAc() {
    int total = LorePascal.byte(shiPower + armPower);
    if (playerClass == PlayerClass.knight) total = LorePascal.byte(total + 1);
    ac = min(10, total);
  }

  static const List<int> expTable = [
    0, // Lv 1
    1500, // Lv 2
    6000, // Lv 3
    20000, // Lv 4
    50000, // Lv 5
    150000, // Lv 6
    250000, // Lv 7
    500000, // Lv 8
    800000, // Lv 9
    1050000, // Lv 10
    1320000, // Lv 11
    1620000, // Lv 12
    1950000, // Lv 13
    2310000, // Lv 14
    2700000, // Lv 15
    3120000, // Lv 16
    3570000, // Lv 17
    4050000, // Lv 18
    4560000, // Lv 19
    5100000, // Lv 20
  ];

  static const List<int> trainingCostTable = [
    0, // Lv 1
    3, // Lv 2
    5, // Lv 3
    8, // Lv 4
    15, // Lv 5
    25, // Lv 6
    40, // Lv 7
    70, // Lv 8
    120, // Lv 9
    200, // Lv 10
    350, // Lv 11
    600, // Lv 12
    1000, // Lv 13
    1700, // Lv 14
    3000, // Lv 15
    5000, // Lv 16
    8300, // Lv 17
    14000, // Lv 18
    24000, // Lv 19
    40000, // Lv 20
  ];

  /// 경험치에 따라 달성 가능한 최대 레벨 계산 (원작 LORESUB.PAS:1355)
  static int getCalculatedLevel(int exp) {
    for (int i = 20; i >= 1; i--) {
      if (exp >= expTable[i - 1]) return i;
    }
    return 1;
  }

  /// 특정 레벨로 승급하기 위한 훈련 비용 (원작 LORESUB.PAS:1375)
  static int getTrainingCost(int targetLevel) {
    if (targetLevel < 1 || targetLevel > 20) return 0;
    return trainingCostTable[targetLevel - 1];
  }

  /// 1993년 원작 LORESUB.PAS:1332 Train_Center 승급 처리.
  ///
  /// 원작은 경험치로 계산된 레벨(`j`)로 **한 번에 점프**시키고,
  /// 능력치 성장 판정(`luck > random(30)`)은 **점프 1회당 단 1회**만 수행한다.
  /// 따라서 Lv.1 → Lv.15로 한 번에 승급해도 스탯은 1번만 오른다.
  ///
  /// 또한 원작은 훈련소에서 HP/SP/ESP를 회복시켜 주지 않는다.
  /// (회복은 병원 `LORESUB.PAS:1517 Hospital`에서만 가능)
  List<String> trainLevelUp(int targetLevel, {Random? random}) {
    if (targetLevel <= battleLevel || targetLevel > 20) return [];
    final growthMessages = <String>[];
    final rng = random ?? LoreRandom.fromClock();

    battleLevel = targetLevel;
    growthMessages.add('$name의 레벨이 $battleLevel(으)로 승급되었습니다!');

    // 직업별 주사위 스탯 성장 (luck > random(30))
    switch (playerClass) {
      case PlayerClass.knight: // 1: Fighter
        if (luck > rng.nextInt(30)) {
          if (strength < 20) {
            strength++;
            growthMessages.add('완력이 1 상승했습니다. ($strength)');
          } else if (endurance < 20) {
            endurance++;
            growthMessages.add('체질이 1 상승했습니다. ($endurance)');
          } else if (accArms < 20) {
            accArms++;
            growthMessages.add('무기명중률이 1 상승했습니다. ($accArms)');
          } else {
            agility = LorePascal.byte(agility + 1);
            growthMessages.add('민첩성이 1 상승했습니다. ($agility)');
          }
        }
        break;

      case PlayerClass.mage: // 2: Mage
      case PlayerClass.ghost: // 9: Antares
        magicLevel = battleLevel;
        espLevel = (battleLevel / 2).round();
        if (luck > rng.nextInt(30)) {
          if (mentality < 20) {
            mentality++;
            growthMessages.add('지력이 1 상승했습니다. ($mentality)');
          } else if (concentration < 20) {
            concentration++;
            growthMessages.add('집중력이 1 상승했습니다. ($concentration)');
          } else if (accMagic < 20) {
            accMagic++;
            growthMessages.add('마법명중률이 1 상승했습니다. ($accMagic)');
          }
        }
        break;

      case PlayerClass.esper: // 3: Esper
        espLevel = battleLevel;
        magicLevel = (battleLevel / 2).round();
        if (luck > rng.nextInt(30)) {
          if (concentration < 20) {
            concentration++;
            growthMessages.add('집중력이 1 상승했습니다. ($concentration)');
          } else if (accEsp < 20) {
            accEsp++;
            growthMessages.add('초능력명중률이 1 상승했습니다. ($accEsp)');
          } else if (mentality < 20) {
            mentality++;
            growthMessages.add('지력이 1 상승했습니다. ($mentality)');
          }
        }
        break;

      case PlayerClass.warrior: // 4: Priest
        magicLevel = battleLevel < 16 ? battleLevel : 15;
        if (luck > rng.nextInt(30)) {
          if (strength < 20) {
            strength++;
            growthMessages.add('완력이 1 상승했습니다. ($strength)');
          } else if (mentality < 20) {
            mentality++;
            growthMessages.add('지력이 1 상승했습니다. ($mentality)');
          } else if (accArms < 20) {
            accArms++;
            growthMessages.add('무기명중률이 1 상승했습니다. ($accArms)');
          } else if (accMagic < 20) {
            accMagic++;
            growthMessages.add('마법명중률이 1 상승했습니다. ($accMagic)');
          }
        }
        break;

      case PlayerClass.monk: // 5: Monk (무기를 착용하지 않는 대신 맨손 위력 자동 폭증!)
        weaPower = battleLevel * 2 + 10;
        growthMessages.add('전투승의 맨손 위력이 $weaPower(으)로 대폭 상승했습니다!');
        if (luck > rng.nextInt(30)) {
          if (strength < 20) {
            strength++;
            growthMessages.add('완력이 1 상승했습니다. ($strength)');
          } else if (accArms < 20) {
            accArms++;
            growthMessages.add('무기명중률이 1 상승했습니다. ($accArms)');
          } else if (endurance < 20) {
            endurance++;
            growthMessages.add('체질이 1 상승했습니다. ($endurance)');
          }
        }
        break;

      case PlayerClass.ninja: // 6: Ninja
        magicLevel = (battleLevel / 2).round();
        espLevel = magicLevel;
        if (luck > rng.nextInt(30)) {
          if (resistance < 18) {
            resistance++;
            growthMessages.add('저항력이 1 상승했습니다. ($resistance)');
          } else if (resistance < 20) {
            if (luck < rng.nextInt(21)) {
              resistance++;
              growthMessages.add('저항력이 1 상승했습니다. ($resistance)');
            }
          } else {
            agility = LorePascal.byte(agility + 1);
            growthMessages.add('민첩성이 1 상승했습니다. ($agility)');
          }
        }
        break;

      case PlayerClass.hunter: // 7: Hunter
      case PlayerClass.vagrant: // 8: Thief
        if (luck > rng.nextInt(30)) {
          if (endurance < 20) {
            endurance++;
            growthMessages.add('체질이 1 상승했습니다. ($endurance)');
          } else if (strength < 20) {
            strength++;
            growthMessages.add('완력이 1 상승했습니다. ($strength)');
          } else {
            agility = LorePascal.byte(agility + 1);
            growthMessages.add('민첩성이 1 상승했습니다. ($agility)');
          }
        }
        break;

      case PlayerClass.none: // 0: join으로 영입된 동료 (직업 성장 없음)
        break;

      case PlayerClass.demigod: // 10: Hero (올스탯 성장)
        magicLevel = battleLevel;
        espLevel = battleLevel;
        if (strength < 20) strength++;
        if (mentality < 20) mentality++;
        if (concentration < 20) concentration++;
        if (endurance < 20) endurance++;
        if (agility < 20) agility++;
        if (accArms < 20) accArms++;
        if (accMagic < 20) accMagic++;
        if (accEsp < 20) accEsp++;
        growthMessages.add('영웅의 모든 스탯이 고루 성장했습니다!');
        break;
    }

    return growthMessages;
  }

  /// 레벨업 처리 (군사 훈련소 간이 승급)
  void levelUp() {
    trainLevelUp(battleLevel + 1);
  }

  /// 1993년 원작 LORESUB.PAS:1042 `join(num, partynum)` 이식.
  ///
  /// 몬스터 템플릿(FOEDATA 75종)의 능력치로 동료 파티원을 생성한다.
  /// - `class := 0` (직업 없음) → [PlayerClass.none]
  /// - `resistance div 2`, `concentration/esp/accEsp = 0`, `luck = 10`
  /// - `level[1] = 몬스터 레벨`, `level[2] = castlevel * 3` (최소 1), `level[3] = 1`
  /// - 장비 ID는 무기 10 / 방패 6 / 갑옷 6(원작의 가상 슬롯), `wea_power = level*2+10`
  static PartyMember fromMonsterTemplate(
    Monster monster, {
    String? name,
    int previousExperience = 0,
  }) {
    final level = LorePascal.byte(monster.level);
    final castLevel = LorePascal.byte(monster.castLevel * 3);
    final magicLevel = castLevel == 0 ? 1 : castLevel;
    return PartyMember(
      name: name ?? monster.name,
      playerClass: PlayerClass.none,
      strength: monster.strength,
      mentality: monster.mentality,
      concentration: 0,
      endurance: monster.endurance,
      resistance: monster.resistance ~/ 2,
      agility: monster.agility,
      accArms: monster.accArms,
      accMagic: monster.accMagic,
      accEsp: 0,
      luck: 10,
      battleLevel: level,
      magicLevel: magicLevel,
      espLevel: 1,
      experience: level >= 1 && level <= 19
          ? expTable[level - 1]
          : level >= 20 && level <= 30
          ? 510000
          : previousExperience,
      weapon: 10,
      shield: 6,
      armor: 6,
      weaPower: LorePascal.byte(level * 2 + 10),
      shiPower: 0,
      armPower: monster.ac,
      ac: monster.ac,
      hp: LorePascal.integer(monster.endurance * level),
      sp: LorePascal.integer(monster.mentality * magicLevel),
      esp: 0,
    );
  }

  /// 1993년 원작 LORECRET.PAS 프리셋 캐릭터 생성
  /// 원작 `LORECRET.PAS:704` `Fourth` 끝의 공통 초기화.
  ///
  /// ```pascal
  /// poison := 0; unconscious := 0; dead := 0; level[1..3] := 1;
  /// ac := 0; if class = 1 then ac := 1;
  /// experience := 0; weapon := 0; shield := 0; armor := 0;
  /// wea_power := 2; if class = 1 then wea_power := 3;
  /// if class = 5 then wea_power := 12;
  /// ```
  void applyCreationInit() {
    poison = 0;
    unconscious = 0;
    dead = 0;
    battleLevel = 1;
    magicLevel = 1;
    espLevel = 1;
    ac = playerClass == PlayerClass.knight ? 1 : 0;
    experience = 0;
    weapon = 0;
    shield = 0;
    armor = 0;
    weaPower = switch (playerClass) {
      PlayerClass.knight => 3,
      PlayerClass.monk => 12,
      _ => 2,
    };
    shiPower = 0;
    armPower = 0;
    hp = endurance;
    sp = mentality;
    esp = concentration;
    // 원작 `accuracy[2]/[3]` 재배치 (무기/마법/초능력 명중률).
    final acc = accArms;
    switch (playerClass) {
      case PlayerClass.knight:
      case PlayerClass.monk:
      case PlayerClass.hunter:
      case PlayerClass.vagrant:
        accMagic = 5;
        accEsp = 5;
        break;
      case PlayerClass.mage:
        accArms = 5;
        accMagic = acc;
        accEsp = 5;
        break;
      case PlayerClass.esper:
        accArms = 5;
        accMagic = 5;
        accEsp = acc;
        break;
      case PlayerClass.warrior:
        accMagic = acc;
        accEsp = 8;
        break;
      case PlayerClass.ninja:
        accMagic = 5;
        accEsp = acc;
        break;
      default:
        accMagic = 5;
        accEsp = 5;
        break;
    }
  }

  static PartyMember createPreset(int presetIndex, {String? customName}) {
    switch (presetIndex) {
      case 1: // Hercules
        return PartyMember(
          name: customName ?? 'Hercules',
          playerClass: PlayerClass.knight,
          strength: 17,
          mentality: 5,
          concentration: 5,
          endurance: 17,
          resistance: 11,
          agility: 15,
          accArms: 15,
          accMagic: 5,
          accEsp: 5,
          luck: 10,
        );
      case 2: // Titan
        return PartyMember(
          name: customName ?? 'Titan',
          playerClass: PlayerClass.knight,
          strength: 14,
          mentality: 5,
          concentration: 7,
          endurance: 14,
          resistance: 14,
          agility: 16,
          accArms: 17,
          accMagic: 5,
          accEsp: 5,
          luck: 7,
        );
      case 3: // Merlin
        return PartyMember(
          name: customName ?? 'Merlin',
          playerClass: PlayerClass.mage,
          strength: 11,
          mentality: 19,
          concentration: 14,
          endurance: 5,
          resistance: 5,
          agility: 7,
          accArms: 5,
          accMagic: 18,
          accEsp: 5,
          luck: 15,
        );
      case 4: // Betelgeuse
        return PartyMember(
          name: customName ?? 'Betelgeuse',
          playerClass: PlayerClass.mage,
          strength: 14,
          mentality: 17,
          concentration: 5,
          endurance: 7,
          resistance: 7,
          agility: 11,
          accArms: 5,
          accMagic: 15,
          accEsp: 5,
          luck: 14,
        );
      case 5: // Genius Kie
        return PartyMember(
          name: customName ?? 'Genius Kie',
          playerClass: PlayerClass.warrior,
          strength: 14,
          mentality: 11,
          concentration: 7,
          endurance: 11,
          resistance: 11,
          agility: 11,
          accArms: 20,
          accMagic: 11,
          accEsp: 8,
          luck: 9,
        );
      case 6: // Bellatrix
        return PartyMember(
          name: customName ?? 'Bellatrix',
          playerClass: PlayerClass.warrior,
          strength: 14,
          mentality: 11,
          concentration: 5,
          endurance: 11,
          resistance: 14,
          agility: 14,
          accArms: 15,
          accMagic: 11,
          accEsp: 8,
          luck: 11,
        );
      case 7: // Regulus
        return PartyMember(
          name: customName ?? 'Regulus',
          playerClass: PlayerClass.monk,
          strength: 19,
          mentality: 5,
          concentration: 5,
          endurance: 17,
          resistance: 7,
          agility: 15,
          accArms: 13,
          accMagic: 5,
          accEsp: 5,
          luck: 11,
        );
      default:
        return PartyMember(
          name: customName ?? 'Hero',
          playerClass: PlayerClass.knight,
          strength: 15,
          mentality: 10,
          concentration: 10,
          endurance: 15,
          resistance: 10,
          agility: 15,
          accArms: 15,
          accMagic: 5,
          accEsp: 5,
          luck: 10,
        );
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'sex': sex.index,
    'classId': playerClass.id,
    'strength': strength,
    'mentality': mentality,
    'concentration': concentration,
    'endurance': endurance,
    'resistance': resistance,
    'agility': agility,
    'accArms': accArms,
    'accMagic': accMagic,
    'accEsp': accEsp,
    'luck': luck,
    'hp': hp,
    'sp': sp,
    'esp': esp,
    'battleLevel': battleLevel,
    'magicLevel': magicLevel,
    'espLevel': espLevel,
    'experience': experience,
    'weapon': weapon,
    'shield': shield,
    'armor': armor,
    'weaPower': weaPower,
    'shiPower': shiPower,
    'armPower': armPower,
    'ac': ac,
    'poison': poison,
    'unconscious': unconscious,
    'dead': dead,
  };

  factory PartyMember.fromJson(Map<String, dynamic> json) {
    final member = PartyMember(
      name: json['name'] as String? ?? 'Hero',
      sex: (json['sex'] as int? ?? 0) == 1 ? Gender.female : Gender.male,
      playerClass: PlayerClass.fromId(json['classId'] as int? ?? 1),
      strength: json['strength'] as int? ?? 10,
      mentality: json['mentality'] as int? ?? 10,
      concentration: json['concentration'] as int? ?? 10,
      endurance: json['endurance'] as int? ?? 10,
      resistance: json['resistance'] as int? ?? 10,
      agility: json['agility'] as int? ?? 10,
      accArms: json['accArms'] as int? ?? 10,
      accMagic: json['accMagic'] as int? ?? 5,
      accEsp: json['accEsp'] as int? ?? 5,
      luck: json['luck'] as int? ?? 10,
      hp: json['hp'] as int?,
      sp: json['sp'] as int?,
      esp: json['esp'] as int?,
      battleLevel: json['battleLevel'] as int? ?? 1,
      magicLevel: json['magicLevel'] as int? ?? 1,
      espLevel: json['espLevel'] as int? ?? 1,
      experience: json['experience'] as int? ?? 0,
      weapon: json['weapon'] as int? ?? 0,
      shield: json['shield'] as int? ?? 0,
      armor: json['armor'] as int? ?? 0,
      weaPower: json['weaPower'] as int? ?? 0,
      shiPower: json['shiPower'] as int? ?? 0,
      armPower: json['armPower'] as int? ?? 0,
      ac: json['ac'] as int? ?? 0,
      poison: json['poison'] as int? ?? 0,
      unconscious: json['unconscious'] as int? ?? 0,
      dead: json['dead'] as int? ?? 0,
    );
    return member;
  }
}
