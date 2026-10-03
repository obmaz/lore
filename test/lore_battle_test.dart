import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_batt_text.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/spell.dart';

/// Scripted `random`: records every bound and answers from [values] (then 0).
class _Script implements Random {
  _Script([List<int> values = const []]) : _values = List.of(values);
  final List<int> _values;
  final List<int> bounds = [];

  @override
  int nextInt(int max) {
    bounds.add(max);
    return _values.isEmpty ? 0 : _values.removeAt(0);
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// LOREBATT.PAS procedures: random-call order, texts and the ordering quirks.
void main() {
  PartyMember hero() => PartyMember.createPreset(1)
    ..accArms = 20
    ..accMagic = 20
    ..strength = 20
    ..weaPower = 20
    ..battleLevel = 20;

  LoreBattle make(
    List<PartyMember> party,
    List<Monster> enemy,
    _Script random, [
    List<String>? out,
  ]) => LoreBattle(
    party: party,
    enemy: enemy,
    random: random,
    print: (color, text) => out?.add(text),
  );

  test(
    'AttackOne draws accuracy, damage variance, resistance, defence in order',
    () {
      final r = _Script([0, 0, 99, 0]);
      final orc = Monster.create(1)
        ..resistance = 0
        ..ac = 0
        ..hp = 500;
      final lines = <String>[];
      final b = make([hero()], [orc], r, lines);
      b.battle[1] = [0, 1, 1, 1];
      b.person = 1;
      b.attackOne();
      expect(r.bounds, [20, 50, 100, 10]);
      expect(lines.first, contains('공격했다'));
      expect(lines.last, startsWith('적은 '));
    },
  );

  test(
    'AttackOne on an unconscious foe executes it with random(4) and exp text',
    () {
      final r = _Script([2]);
      final orc = Monster.create(1)..isUnconscious = true;
      final h = hero();
      final lines = <String>[];
      final b = make([h], [orc], r, lines);
      b.battle[1] = [0, 1, 1, 1];
      b.person = 1;
      b.attackOne();
      expect(r.bounds, [4]);
      expect(lines, [lines.first, LoreBattText.killBlood]);
      expect(orc.isDead, isTrue);
      // PlusExperience: unconscious foe → everybody gains silently.
      expect(h.experience, 1 * 1 * 1 ~/ 8 == 0 ? 1 : 0);
    },
  );

  test('PlusExperience: E_number^3 div 8 (min 1) with message only for a conscious foe', () {
    final dragon = Monster.create(54);
    final h = hero();
    final lines = <String>[];
    final b = make([h], [dragon], _Script(), lines);
    b.plusExperience(1, 1);
    expect(h.experience, 54 * 54 * 54 ~/ 8);
    expect(
      lines.single,
      '${h.name}는 ${54 * 54 * 54 ~/ 8}${LoreBattText.expGainedMsg}',
    );
    dragon.isUnconscious = true;
    lines.clear();
    final before = h.experience;
    b.plusExperience(1, 1);
    expect(lines, isEmpty);
    expect(h.experience, before + 54 * 54 * 54 ~/ 8);
  });

  test('CastAll moves battle[person,3] past a dead foe, so each live foe is cast on once', () {
    final enemies = [
      Monster.create(1)..isDead = true,
      Monster.create(2),
      Monster.create(3),
    ];
    final mage = PartyMember.createPreset(3)
      ..magicLevel = 20
      ..sp = 5000
      ..accMagic = 0;
    final lines = <String>[];
    final b = make([mage], enemies, _Script(), lines);
    b.battle[1] = [0, 3, 1, 0];
    b.person = 1;
    b.castAll();
    final named = lines.where((l) => l.contains('공격했다')).toList();
    expect(named.length, 2);
    expect(named[0], contains(enemies[1].name));
    expect(named[1], contains(enemies[2].name));
  });

  test('EnemyAttack with special = 0 draws random(acc1*1000) then random(acc2*1000)', () {
    final r = _Script([1, 0]);
    final orc = Monster.create(1)..special = 0;
    final b = make([hero()], [orc], r);
    b.person = 1;
    b.enemyAttack();
    expect(r.bounds.take(2), [orc.accArms * 1000, max(1, orc.accMagic * 1000)]);
  });

  test('EnemyAttack with special > 0 draws random(50) first and needs more than 3 live foes', () {
    final r = _Script([0]);
    final snake = Monster.create(1)..special = 1;
    final b = make([hero()], [snake], r);
    b.person = 1;
    b.enemyAttack();
    expect(r.bounds.first, 50);
    // One foe only (j <= 3): special attack is skipped, the normal draws follow.
    expect(r.bounds.sublist(1).take(2), [
      snake.accArms * 1000,
      max(1, snake.accMagic * 1000),
    ]);
  });

  test('EndBattle judges a simultaneous wipe-out as a defeat first', () {
    final h = hero()..hp = 0;
    final orc = Monster.create(1)..isDead = true;
    final b = make([h], [orc], _Script());
    expect(b.endBattle(), 1);
    h.hp = 10;
    expect(b.endBattle(), 0);
    orc.isDead = false;
    expect(b.endBattle(), isNull);
  });

  test('enemy phase: poison ticks before acting; a summon waits for the next phase', () {
    final summoner = Monster.create(62)
      ..castLevel = 0
      ..special = 0;
    final victim = Monster.create(1)
      ..hp = 1
      ..isPoisoned = true;
    final b = make([hero()], [summoner, victim], _Script());
    b.enemyPhase();
    expect(victim.hp, 0);
    expect(victim.isUnconscious, isTrue);
  });

  test('autoSelect follows the class table (mage level -> round(i/2), esper ESP 5 on the last live foe)', () {
    final mage = PartyMember.createPreset(3)..magicLevel = 6;
    final foes = [
      Monster.create(1),
      Monster.create(2),
      Monster.create(3)..isDead = true,
    ];
    final b = make([mage], foes, _Script());
    mage.playerClass = PlayerClass.mage;
    b.autoSelect(1);
    expect(b.battle[1], [0, 2, 2, 1]); // level 6 -> i = 3 -> round(1.5) = 2
    mage.playerClass = PlayerClass.esper;
    b.autoSelect(1);
    expect(b.battle[1], [0, 6, 5, 2]);
    mage.playerClass = PlayerClass.knight;
    mage.weapon = 4;
    b.autoSelect(1);
    expect(b.battle[1], [0, 1, 4, 1]);
  });

  test('RunAway uses random(50) > agility', () {
    final r = _Script([30]);
    final h = hero()..agility = 10;
    final lines = <String>[];
    final b = make([h], [Monster.create(1)], r, lines);
    b.person = 1;
    expect(b.runAway(), isFalse);
    expect(lines.single, LoreBattText.runFailed);
    r.bounds.clear();
    final r2 = _Script([10]);
    final b2 = make([h], [Monster.create(1)], r2, lines);
    b2.person = 1;
    expect(b2.runAway(), isTrue);
    expect(lines.last, LoreBattText.runSuccess);
  });

  test('CastSpecial 4 stores resistance - 10 in a byte (5 becomes 251)', () {
    final r = _Script([100, 0]);
    final orc = Monster.create(1)..resistance = 5;
    final b = make([hero()..sp = 100], [orc], r);
    b.battle[1] = [0, 6, 4, 1];
    b.person = 1;
    b.castSpecial();
    expect(orc.resistance, 251);
    orc.resistance = 0;
    b.castSpecial();
    expect(orc.resistance, 0);
  });

  test('all-cure spells follow CureSpell: slot 1 from level 6, then level div 2 - 3 slots', () {
    final cure = Spell.allSpells
        .where((s) => s.category == SpellCategory.allCure)
        .toList();
    int available(int level) =>
        cure.where((s) => s.isAvailableForLevel(level, 0)).length;
    expect(
      [
        for (final level in [5, 6, 7, 8, 9, 10, 12, 20]) available(level),
      ],
      [0, 1, 1, 1, 1, 2, 3, 7],
    );
  });

  test('PlusGold sums template level^3 * max(ac,1)', () {
    final foes = [Monster.create(1), Monster.create(54)];
    final lines = <String>[];
    final b = make([hero()], foes, _Script(), lines);
    final t1 = Monster.monsterTemplates[0];
    final t2 = Monster.monsterTemplates[53];
    final want =
        t1.level * t1.level * t1.level * (t1.ac == 0 ? 1 : t1.ac) +
        t2.level * t2.level * t2.level * (t2.ac == 0 ? 1 : t2.ac);
    expect(b.plusGold(), want);
    expect(lines.single, LoreBattText.goldFound('$want'));
  });

  test('the enemy phase ends with SimpleDisCond (LOREBATT:1171)', () {
    final hurt = hero()..hp = 0;
    final battle = make([hurt], [Monster.create(1)..isDead = true], _Script());
    expect(hurt.unconscious, 0);
    battle.enemyPhase();
    expect((hurt.unconscious, hurt.dead), (1, 0));
    // Unused slots count as already dead, so they are not picked or counted.
    expect(battle.p(6).dead, 1);
  });
}
