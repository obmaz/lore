import 'dart:math';
import 'item.dart';

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
  demigod(10, '반신');

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
  })  : weaPower = weaPower ??
            (playerClass == PlayerClass.monk
                ? 12
                : (playerClass == PlayerClass.knight ? 3 : 2)),
        ac = ac ?? (playerClass == PlayerClass.knight ? 1 : 0),
        hp = hp ?? (endurance * battleLevel),
        sp = sp ?? (mentality * magicLevel),
        esp = esp ?? (concentration * espLevel);

  int get maxHp => endurance * battleLevel;
  int get maxSp => mentality * magicLevel;
  int get maxEsp => concentration * espLevel;

  bool get isDead => dead > 0;
  bool get isUnconscious => unconscious > 0 && !isDead;
  bool get isPoisoned => poison > 0 && !isDead;
  bool get isAlive => !isDead;
  bool get canAct => !isDead && !isUnconscious;

  String get condition {
    if (dead > 0) return 'dead';
    if (unconscious > 0) return 'unconscious';
    if (poison > 0) return 'poisoned';
    return 'good';
  }

  /// 무기 장착
  void equipWeapon(Item item) {
    if (item.type != ItemType.weapon) return;
    if (playerClass == PlayerClass.monk) return; // 전투승은 무기 장착 불가

    weapon = item.id;
    int p = item.power;
    if (playerClass == PlayerClass.knight) {
      p += (p * 0.5).round(); // 기사 무기 위력 +50% 보너스
    }
    weaPower = p;
  }

  /// 방패 장착
  void equipShield(Item item) {
    if (item.type != ItemType.shield) return;
    shield = item.id;
    shiPower = item.power;
    _updateAc();
  }

  /// 갑옷 장착
  void equipArmor(Item item) {
    if (item.type != ItemType.armor) return;
    armor = item.id;
    armPower = item.power;
    _updateAc();
  }

  void _updateAc() {
    int total = shiPower + armPower;
    if (playerClass == PlayerClass.knight) total += 1;
    ac = min(10, total);
  }

  /// 1993년 원작 LORECRET.PAS 프리셋 캐릭터 생성
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
}
