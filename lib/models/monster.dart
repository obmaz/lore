/// 1993년 원작의 enemydata1(도감 템플릿) 및 enemydata2(전투 인스턴스)에 대응하는 Monster 모델
class Monster {
  final int eNumber;
  final String name;
  final int strength;
  final int mentality;
  final int endurance;
  final int resistance;
  final int agility;
  final int accArms;
  final int accMagic;
  final int ac;
  final int special;
  final int castLevel;
  final int specialCastLevel;
  final int level;

  int hp;
  final int maxHp;
  bool isPoisoned;
  bool isUnconscious;
  bool isDead;

  Monster({
    required this.eNumber,
    required this.name,
    required this.strength,
    required this.mentality,
    required this.endurance,
    required this.resistance,
    required this.agility,
    required this.accArms,
    required this.accMagic,
    required this.ac,
    required this.special,
    required this.castLevel,
    required this.specialCastLevel,
    required this.level,
    int? hp,
    this.isPoisoned = false,
    this.isUnconscious = false,
    this.isDead = false,
  })  : maxHp = endurance * (level > 0 ? level : 1),
        hp = hp ?? (endurance * (level > 0 ? level : 1));

  Monster copyWith({
    int? hp,
    bool? isPoisoned,
    bool? isUnconscious,
    bool? isDead,
  }) {
    return Monster(
      eNumber: eNumber,
      name: name,
      strength: strength,
      mentality: mentality,
      endurance: endurance,
      resistance: resistance,
      agility: agility,
      accArms: accArms,
      accMagic: accMagic,
      ac: ac,
      special: special,
      castLevel: castLevel,
      specialCastLevel: specialCastLevel,
      level: level,
      hp: hp ?? this.hp,
      isPoisoned: isPoisoned ?? this.isPoisoned,
      isUnconscious: isUnconscious ?? this.isUnconscious,
      isDead: isDead ?? this.isDead,
    );
  }

  /// 원작 FOEDATA.DAT 기반 대표 몬스터 생성 팩토리
  factory Monster.create(int id) {
    if (id < 1 || id > monsterTemplates.length) {
      id = 1;
    }
    final t = monsterTemplates[id - 1];
    return Monster(
      eNumber: t.eNumber,
      name: t.name,
      strength: t.strength,
      mentality: t.mentality,
      endurance: t.endurance,
      resistance: t.resistance,
      agility: t.agility,
      accArms: t.accArms,
      accMagic: t.accMagic,
      ac: t.ac,
      special: t.special,
      castLevel: t.castLevel,
      specialCastLevel: t.specialCastLevel,
      level: t.level,
    );
  }

  // 1993년 원작 FOEDATA.DAT 바이너리에서 파싱된 몬스터 템플릿
  static final List<Monster> monsterTemplates = [
    Monster(eNumber: 1, name: 'Orc', strength: 8, mentality: 0, endurance: 8, resistance: 0, agility: 8, accArms: 8, accMagic: 0, ac: 1, special: 0, castLevel: 0, specialCastLevel: 0, level: 1),
    Monster(eNumber: 2, name: 'Troll', strength: 9, mentality: 0, endurance: 6, resistance: 0, agility: 9, accArms: 9, accMagic: 0, ac: 1, special: 0, castLevel: 0, specialCastLevel: 0, level: 1),
    Monster(eNumber: 3, name: 'Serpent', strength: 7, mentality: 3, endurance: 7, resistance: 0, agility: 11, accArms: 11, accMagic: 6, ac: 1, special: 1, castLevel: 1, specialCastLevel: 0, level: 1),
    Monster(eNumber: 4, name: 'Earth Worm', strength: 3, mentality: 5, endurance: 5, resistance: 0, agility: 6, accArms: 11, accMagic: 7, ac: 1, special: 0, castLevel: 1, specialCastLevel: 0, level: 1),
    Monster(eNumber: 5, name: 'Dwarf', strength: 10, mentality: 0, endurance: 10, resistance: 0, agility: 10, accArms: 10, accMagic: 0, ac: 2, special: 0, castLevel: 0, specialCastLevel: 0, level: 2),
    Monster(eNumber: 6, name: 'Giant', strength: 15, mentality: 0, endurance: 13, resistance: 0, agility: 8, accArms: 8, accMagic: 0, ac: 2, special: 0, castLevel: 0, specialCastLevel: 0, level: 2),
    Monster(eNumber: 7, name: 'Phantom', strength: 0, mentality: 12, endurance: 12, resistance: 0, agility: 0, accArms: 0, accMagic: 13, ac: 0, special: 0, castLevel: 2, specialCastLevel: 0, level: 2),
    Monster(eNumber: 8, name: 'Wolf', strength: 7, mentality: 0, endurance: 11, resistance: 0, agility: 15, accArms: 15, accMagic: 0, ac: 1, special: 0, castLevel: 0, specialCastLevel: 0, level: 2),
    Monster(eNumber: 9, name: 'Imp', strength: 8, mentality: 8, endurance: 10, resistance: 20, agility: 18, accArms: 18, accMagic: 10, ac: 2, special: 0, castLevel: 2, specialCastLevel: 0, level: 3),
    Monster(eNumber: 10, name: 'Goblin', strength: 11, mentality: 0, endurance: 13, resistance: 0, agility: 13, accArms: 13, accMagic: 0, ac: 3, special: 0, castLevel: 0, specialCastLevel: 0, level: 3),
    Monster(eNumber: 11, name: 'Python', strength: 9, mentality: 5, endurance: 10, resistance: 0, agility: 13, accArms: 13, accMagic: 6, ac: 1, special: 1, castLevel: 1, specialCastLevel: 0, level: 3),
    Monster(eNumber: 12, name: 'Insects', strength: 6, mentality: 4, endurance: 8, resistance: 0, agility: 14, accArms: 14, accMagic: 15, ac: 2, special: 1, castLevel: 1, specialCastLevel: 0, level: 3),
    Monster(eNumber: 13, name: 'Giant Spider', strength: 10, mentality: 0, endurance: 9, resistance: 0, agility: 20, accArms: 13, accMagic: 0, ac: 2, special: 1, castLevel: 0, specialCastLevel: 0, level: 4),
    Monster(eNumber: 14, name: 'Gremlin', strength: 10, mentality: 0, endurance: 10, resistance: 0, agility: 20, accArms: 20, accMagic: 0, ac: 2, special: 0, castLevel: 0, specialCastLevel: 0, level: 4),
    Monster(eNumber: 15, name: 'Buzz Bug', strength: 13, mentality: 0, endurance: 11, resistance: 0, agility: 15, accArms: 15, accMagic: 0, ac: 1, special: 1, castLevel: 0, specialCastLevel: 0, level: 4),
    Monster(eNumber: 16, name: 'Skeleton', strength: 13, mentality: 0, endurance: 14, resistance: 10, agility: 10, accArms: 13, accMagic: 0, ac: 3, special: 0, castLevel: 0, specialCastLevel: 0, level: 5),
    Monster(eNumber: 17, name: 'Zombie', strength: 15, mentality: 0, endurance: 16, resistance: 10, agility: 5, accArms: 11, accMagic: 0, ac: 2, special: 0, castLevel: 0, specialCastLevel: 0, level: 5),
    Monster(eNumber: 25, name: 'Fire Dragon', strength: 18, mentality: 16, endurance: 20, resistance: 30, agility: 14, accArms: 16, accMagic: 18, ac: 5, special: 1, castLevel: 4, specialCastLevel: 1, level: 10),
    Monster(eNumber: 50, name: 'Necromancer', strength: 16, mentality: 20, endurance: 22, resistance: 50, agility: 18, accArms: 18, accMagic: 20, ac: 7, special: 1, castLevel: 5, specialCastLevel: 2, level: 16),
  ];
}
