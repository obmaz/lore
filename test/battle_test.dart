import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/item.dart';
import 'package:lore/logic/battle_engine.dart';
import 'package:lore/logic/lore_join.dart';

/// 고정된 난수 시퀀스를 반환하는 Mock Random 클래스
class DeterministicRandom implements Random {
  final List<int> _values;
  int _index = 0;

  DeterministicRandom(this._values);

  @override
  int nextInt(int max) {
    if (_values.isEmpty) return 0;
    final val = _values[_index % _values.length];
    _index++;
    return val % max;
  }

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(100) / 100.0;
}

Monster _supportCaster(int castLevel) => Monster(
  eNumber: 1,
  name: '지원 마법사',
  strength: 0,
  mentality: 20,
  endurance: 20,
  resistance: 0,
  agility: 0,
  accArms: 0,
  accMagic: 20,
  ac: 0,
  special: 0,
  castLevel: castLevel,
  specialCastLevel: 0,
  level: 5,
  hp: 50,
);

void main() {
  group('LORE 1993 전투 공식 및 엔진 검증 (BattleEngine Tests)', () {
    test('1. 경험치 및 골드 보상 공식 검증', () {
      final engine = BattleEngine();

      // Orc (eNumber: 1, Level: 1, AC: 1)
      final orc = Monster.create(1);
      expect(
        engine.calculateExperience(orc),
        equals(1),
      ); // 1^3 / 8 = 0 -> min 1

      // Imp (eNumber: 9, Level: 3, AC: 2)
      final imp = Monster.create(9);
      // 9^3 / 8 = 729 / 8 = 91
      expect(engine.calculateExperience(imp), equals(91));

      // Salamander (eNumber: 16, Level: 4, AC: 3)
      final salamander = Monster.create(16);
      // 16^3 / 8 = 4096 / 8 = 512
      expect(engine.calculateExperience(salamander), equals(512));

      // 골드 보상: sum(level^3 * ac)
      // orc: 1^3 * 1 = 1
      // imp: 3^3 * 2 = 54
      // salamander: 4^3 * 3 = 192
      // 총합 = 1 + 54 + 192 = 247
      final gold = engine.calculateGold([orc, imp, salamander]);
      expect(gold, equals(247));
    });

    test('Major Mummy 전투 금화는 덮어쓴 능력치 대신 원본 도감 값을 쓴다', () {
      final engine = BattleEngine();
      // LORESPEC.PAS:533-546: Sprite 둘을 Sphinx로 바꾸고 E_number=20,
      // Mummy는 AC를 1로 바꾼다. PlusGold는 enemydata[20/26]을 조회한다.
      final enemies = [
        Monster.create(35).withOverrides(name: 'Sphinx', level: 4, eNumber: 20),
        Monster.create(35).withOverrides(name: 'Sphinx', level: 4, eNumber: 20),
        Monster.create(26).withOverrides(name: 'Major Mummy', ac: 1),
      ];
      expect(enemies.last.ac, 1);
      // Kelpie(#20): 5^3 * 2 = 250, Mummy(#26): 7^3 * 3 = 1029.
      expect(engine.calculateGold(enemies), 1529);
    });

    test('의식불명 적의 처형 경험치는 행동 가능한 일행 전원에게 지급한다', () {
      final engine = BattleEngine(random: DeterministicRandom([0, 0, 99, 0]));
      final hero = PartyMember.createPreset(1)..weaPower = 100;
      final ally = PartyMember.createPreset(3);
      final empty = PartyMember.createPreset(4)..name = '';
      final unconscious = PartyMember.createPreset(5)..unconscious = 1;
      final dead = PartyMember.createPreset(6)..dead = 1;
      final noHp = PartyMember.createPreset(7)..hp = 0;
      final party = [hero, ally, empty, unconscious, dead, noHp];
      final before = [for (final member in party) member.experience];
      final target = Monster.create(9)
        ..hp = 0
        ..isUnconscious = true;

      final result = engine.executePlayerWeaponAttack(
        hero,
        target,
        party: party,
      );
      expect(result.outcome, AttackOutcome.killed);
      expect(result.expGained, 91);
      expect(hero.experience, before[0] + 91);
      expect(ally.experience, before[1] + 91);
      for (var i = 2; i < party.length; i++) {
        expect(party[i].experience, before[i]);
      }

      // 멀쩡한 적을 처음 쓰러뜨린 경험치는 공격자에게만 간다.
      final fresh = Monster.create(1);
      final knockdown = engine.executePlayerWeaponAttack(
        hero,
        fresh,
        party: party,
      );
      expect(knockdown.outcome, AttackOutcome.unconscious);
      expect(hero.experience, before[0] + 92);
      expect(ally.experience, before[1] + 91);
    });

    test('단일 마법은 의식불명 적을 SP 없이 처형하고 일행 경험치를 지급한다', () {
      final engine = BattleEngine();
      final mage = PartyMember.createPreset(3)..sp = 0;
      final ally = PartyMember.createPreset(1);
      final party = [mage, ally];
      final beforeMage = mage.experience;
      final beforeAlly = ally.experience;
      final target = Monster.create(9)
        ..hp = 0
        ..isUnconscious = true;

      final result = engine.executePlayerSingleMagicAttack(
        mage,
        target,
        1,
        party: party,
      );
      expect(result.outcome, AttackOutcome.killed);
      expect(mage.sp, 0);
      expect(mage.experience, beforeMage + 91);
      expect(ally.experience, beforeAlly + 91);

      mage.sp = 100;
      final second = Monster.create(9)
        ..hp = 0
        ..isUnconscious = true;
      final all = engine.executePlayerAllMagicAttack(
        mage,
        [second],
        7,
        party: party,
      );
      expect(all.single.outcome, AttackOutcome.killed);
      expect(mage.experience, beforeMage + 182);
      expect(ally.experience, beforeAlly + 182);
    });

    test('염력 1~6단계는 첫 기절과 처형에 각각 원본 경험치 분기를 적용한다', () {
      final engine = BattleEngine(random: DeterministicRandom([0]));
      final caster = PartyMember.createPreset(3)
        ..espLevel = 1
        ..esp = 40;
      final ally = PartyMember.createPreset(1);
      final party = [caster, ally];
      final beforeCaster = caster.experience;
      final beforeAlly = ally.experience;
      final orc = Monster.create(1);

      final knockout = engine.executePlayerESP(
        caster,
        orc,
        45,
        party,
        enemies: [orc],
      );
      expect(knockout.outcome, AttackOutcome.unconscious);
      expect(knockout.expGained, 1);
      expect(orc.isUnconscious, isTrue);
      expect(caster.experience, beforeCaster + 1);
      expect(ally.experience, beforeAlly);

      final execution = engine.executePlayerESP(
        caster,
        orc,
        45,
        party,
        enemies: [orc],
      );
      expect(execution.outcome, AttackOutcome.killed);
      expect(execution.expGained, 1);
      expect(orc.isDead, isTrue);
      expect(caster.experience, beforeCaster + 2);
      expect(ally.experience, beforeAlly + 1);
      expect(caster.esp, 0);
    });

    test('염력 7~10단계는 적 전체를 공격하고 원본의 선택 대상 경험치 계산을 따른다', () {
      final engine = BattleEngine(random: DeterministicRandom([6]));
      final caster = PartyMember.createPreset(3)
        ..espLevel = 7
        ..esp = 40;
      final ally = PartyMember.createPreset(1);
      final party = [caster, ally];
      final selected = Monster.create(1);
      final sleeping = Monster.create(9)
        ..hp = 0
        ..isUnconscious = true;
      final sturdy = Monster.create(2)..hp = 100;
      final enemies = [selected, sleeping, sturdy];
      final beforeCaster = caster.experience;
      final beforeAlly = ally.experience;

      final result = engine.executePlayerESP(
        caster,
        selected,
        45,
        party,
        enemies: enemies,
      );
      expect(result.outcome, AttackOutcome.killed);
      expect(result.damage, 105); // k=7, 적마다 35
      expect(selected.isUnconscious, isTrue);
      expect(sleeping.isDead, isTrue);
      expect(sturdy.hp, 65);
      // 원본은 처형 시 sleeping(#9)이 아닌 선택한 selected(#1)로
      // PlusExperience를 호출한다. 첫 기절 +1, 처형 일행에게 +1.
      expect(result.expGained, 2);
      expect(caster.experience, beforeCaster + 2);
      expect(ally.experience, beforeAlly + 1);
      expect(caster.esp, 20);
    });

    test('염력 11~12단계 공포는 저항·인내력 손실·죽음의 세 분기를 따른다', () {
      final caster = PartyMember.createPreset(3)
        ..espLevel = 11
        ..esp = 60
        ..accEsp = 5;
      final party = [caster];
      final resistant = Monster.create(1)..resistance = 20;
      final resisted = BattleEngine(random: DeterministicRandom([10, 0]))
          .executePlayerESP(caster, resistant, 45, party, enemies: [resistant]);
      expect(resisted.outcome, AttackOutcome.resisted);
      expect(resistant.resistance, 15);
      expect(resistant.endurance, 8);

      final missedTarget = Monster.create(1);
      final missed = BattleEngine(random: DeterministicRandom([10, 39, 59]))
          .executePlayerESP(
            caster,
            missedTarget,
            45,
            party,
            enemies: [missedTarget],
          );
      expect(missed.outcome, AttackOutcome.miss);
      expect(missedTarget.endurance, 3);
      expect(missedTarget.maxHp, 3);
      expect(missedTarget.hp, 8); // 원본은 현재 HP를 변경하지 않는다.
      expect(missedTarget.isDead, isFalse);

      final killedTarget = Monster.create(1);
      final killed = BattleEngine(random: DeterministicRandom([10, 39, 0]))
          .executePlayerESP(
            caster,
            killedTarget,
            45,
            party,
            enemies: [killedTarget],
          );
      expect(killed.outcome, AttackOutcome.killed);
      expect(killedTarget.isDead, isTrue);
      expect(killedTarget.hp, 8); // 원본은 dead 플래그만 설정한다.
      expect(caster.esp, 0);
    });

    test('독심술은 고레벨 저항을 먼저 판정하고 62번 적을 레벨 17로 취급한다', () {
      final caster = PartyMember.createPreset(3)
        ..espLevel = 16
        ..esp = 45
        ..accEsp = 60;
      final party = [caster];
      final blockedTarget = Monster.create(62);
      expect(blockedTarget.level, 19);
      final blocked = BattleEngine(random: DeterministicRandom([0]))
          .executePlayerESP(
            caster,
            blockedTarget,
            43,
            party,
            enemies: [blockedTarget],
          );
      expect(blocked.outcome, AttackOutcome.failed);
      expect(blockedTarget.isDead, isFalse);

      final passedTarget = Monster.create(62);
      final passed = BattleEngine(random: DeterministicRandom([1, 0]))
          .executePlayerESP(
            caster,
            passedTarget,
            43,
            party,
            enemies: [passedTarget],
          );
      expect(passed.outcome, AttackOutcome.joined);

      caster.espLevel = 17;
      final equalLevelTarget = Monster.create(62);
      final equalLevel = BattleEngine(random: DeterministicRandom([0]))
          .executePlayerESP(
            caster,
            equalLevelTarget,
            43,
            party,
            enemies: [equalLevelTarget],
          );
      expect(equalLevel.outcome, AttackOutcome.joined);
      expect(caster.esp, 0);
    });

    test('독심술 성공 후 6번 슬롯에는 전투 덮어쓰기 전의 도감 동료가 합류한다', () {
      final caster = PartyMember.createPreset(3)
        ..espLevel = 17
        ..esp = 15
        ..accEsp = 60;
      final party = [
        caster,
        for (var i = 1; i < 6; i++) PartyMember.createPreset(i + 1),
      ];
      final replaced = party[5];
      final target = Monster.create(62).withOverrides(name: '전투용 이름', level: 4);
      final result = BattleEngine(random: DeterministicRandom([0]))
          .executePlayerESP(caster, target, 43, party, enemies: [target]);
      expect(result.outcome, AttackOutcome.joined);

      final recruit = LoreJoin.telepathyRecruit(target.eNumber);
      LoreJoin.applyJoin(party, recruit, LoreJoin.forcedSixthSlotOption);
      expect(party, hasLength(6));
      expect(party[5], same(recruit));
      expect(party[5], isNot(same(replaced)));
      expect(recruit.name, Monster.create(62).name);
      expect(recruit.name, isNot(target.name));
      expect(recruit.battleLevel, 19);
      expect(recruit.esp, 0);
      expect(target.isDead, isTrue);
      expect(target.level, 0);
    });

    test('전투 ESP는 세 직업 또는 etc39 첫 비트가 있을 때만 시전한다', () {
      final knight = PartyMember.createPreset(1)
        ..espLevel = 5
        ..esp = 40;
      final target = Monster.create(1);
      final engine = BattleEngine(random: DeterministicRandom([0]));
      final denied = engine.executePlayerESP(
        knight,
        target,
        45,
        [knight],
        enemies: [target],
      );
      expect(denied.outcome, AttackOutcome.failed);
      expect(knight.esp, 40);
      expect(target.hp, 8);

      final granted = engine.executePlayerESP(
        knight,
        target,
        45,
        [knight],
        enemies: [target],
        espAccessGranted: true,
      );
      expect(granted.outcome, AttackOutcome.unconscious);
      expect(knight.esp, 20);

      final ninja = PartyMember.createPreset(8)
        ..playerClass = PlayerClass.ninja
        ..espLevel = 5
        ..esp = 20;
      final ninjaTarget = Monster.create(1);
      final native = engine.executePlayerESP(
        ninja,
        ninjaTarget,
        45,
        [ninja],
        enemies: [ninjaTarget],
      );
      expect(native.outcome, AttackOutcome.unconscious);
      expect(ninja.esp, 0);
    });

    test('적 단일·전체 마법은 원본 정신력 구간의 위력을 사용한다', () {
      final engine = BattleEngine(random: DeterministicRandom([0]));
      final singleTarget = PartyMember.createPreset(1)
        ..hp = 100
        ..resistance = 0
        ..ac = 0;
      final singleCaster = Monster(
        eNumber: 1,
        name: '단일 시전자',
        strength: 0,
        mentality: 20,
        endurance: 10,
        resistance: 0,
        agility: 0,
        accArms: 0,
        accMagic: 20,
        ac: 0,
        special: 0,
        castLevel: 1,
        specialCastLevel: 0,
        level: 2,
      );
      engine.executeMonsterTurn(singleCaster, [singleTarget], [singleCaster]);
      expect(singleTarget.hp, 80); // mentality 20: 10 * level 2

      final groupTargets = [
        PartyMember.createPreset(1)
          ..hp = 100
          ..resistance = 0
          ..ac = 0,
        PartyMember.createPreset(3)
          ..hp = 100
          ..resistance = 0
          ..ac = 0,
      ];
      final groupCaster = Monster(
        eNumber: 1,
        name: '전체 시전자',
        strength: 0,
        mentality: 21,
        endurance: 10,
        resistance: 0,
        agility: 0,
        accArms: 0,
        accMagic: 20,
        ac: 0,
        special: 0,
        castLevel: 3,
        specialCastLevel: 0,
        level: 2,
      );
      engine.executeMonsterTurn(groupCaster, groupTargets, [groupCaster]);
      expect([for (final target in groupTargets) target.hp], [84, 84]);
      // mentality 21: 8 * level 2, 대상마다 16
    });

    test('적 치료는 사망·기절·일반 HP를 원본 순서대로 처리한다', () {
      final engine = BattleEngine();
      final healer = Monster.create(1);
      final dead = Monster.create(2)
        ..hp = 0
        ..isDead = true
        ..isUnconscious = true;
      engine.executeEnemyCure(healer, dead, 50);
      expect(dead.isDead, isFalse);
      expect(dead.isUnconscious, isTrue); // 사망 해제만 수행한다.
      expect(dead.hp, 0);

      final unconscious = Monster.create(2)
        ..hp = 0
        ..isUnconscious = true;
      engine.executeEnemyCure(healer, unconscious, 50);
      expect(unconscious.isUnconscious, isFalse);
      expect(unconscious.hp, 1);

      final healthy = Monster.create(2)..hp = Monster.create(2).maxHp - 1;
      engine.executeEnemyCure(healer, healthy, 50);
      expect(healthy.hp, healthy.endurance * healthy.level);
    });

    test('적 자기 치료는 시전 등급별 확률과 level * mentality / 4 회복량을 따른다', () {
      Monster healer(int castLevel) => Monster(
        eNumber: 1,
        name: '치료사',
        strength: 0,
        mentality: 20,
        endurance: 20,
        resistance: 0,
        agility: 0,
        accArms: 0,
        accMagic: 20,
        ac: 0,
        special: 0,
        castLevel: castLevel,
        specialCastLevel: 0,
        level: 5,
        hp: 10,
      );

      final fourth = healer(4);
      final target = PartyMember.createPreset(1);
      final cured = BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(fourth, [target], [fourth]);
      expect(cured.single.outcome, AttackOutcome.cured);
      expect(fourth.hp, 35);

      final fifth = healer(5);
      final uncured = BattleEngine(random: DeterministicRandom([0, 2, 0]))
          .executeMonsterTurn(fifth, [target], [fifth]);
      expect(
        uncured.any((result) => result.outcome == AttackOutcome.cured),
        isFalse,
      );
      expect(fifth.hp, 10);
    });

    test('5단계 적은 단일 공격을 고른 뒤 빈사 적 무리를 전체 치료한다', () {
      final caster = _supportCaster(5);
      final fallen = _supportCaster(0)
        ..hp = 0
        ..isUnconscious = true;
      final wounded = _supportCaster(0)..hp = 1;
      final enemies = [caster, fallen, wounded];
      final party = [PartyMember.createPreset(1)];

      final results = BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, party, enemies);

      expect(
        results.map((result) => result.outcome),
        everyElement(AttackOutcome.cured),
      );
      expect(results.length, 3);
      expect(caster.hp, 66); // level 5 * mentality 20 div 6
      expect(fallen.isUnconscious, isFalse);
      expect(fallen.hp, 1);
      expect(wounded.hp, 17);
    });

    test('5단계 적이 전체 공격을 고르면 빈사 무리를 치료하지 않는다', () {
      final caster = _supportCaster(5);
      final enemies = [
        caster,
        _supportCaster(0)..hp = 1,
        _supportCaster(0)..hp = 1,
      ];
      final party = [
        PartyMember.createPreset(1)..hp = 100,
        PartyMember.createPreset(3)..hp = 100,
        PartyMember.createPreset(4)..hp = 100,
      ];

      final results = BattleEngine(random: DeterministicRandom([0, 2]))
          .executeMonsterTurn(caster, party, enemies);

      expect(
        results.any((result) => result.outcome == AttackOutcome.cured),
        isFalse,
      );
      expect(enemies.map((enemy) => enemy.hp), [50, 1, 1]);
      expect(results.first.message, contains('일행 모두'));
    });

    test('6단계 적은 방어도 약화를 빈사 무리 치료보다 먼저 시도한다', () {
      final caster = _supportCaster(6);
      final enemies = [
        caster,
        _supportCaster(0)..hp = 1,
        _supportCaster(0)..hp = 1,
      ];
      final party = [
        PartyMember.createPreset(1)
          ..ac = 6
          ..luck = 0,
        PartyMember.createPreset(3)
          ..ac = 6
          ..luck = 0,
      ];

      final results = BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, party, enemies);

      expect(
        results.map((result) => result.outcome),
        everyElement(AttackOutcome.debuffed),
      );
      expect(party.map((member) => member.ac), [5, 5]);
      expect(enemies.map((enemy) => enemy.hp), [50, 1, 1]);
    });

    test('6단계 적은 방어 약화 조건이 없으면 빈사 적 무리를 치료한다', () {
      final caster = _supportCaster(6);
      final fallen = _supportCaster(0)
        ..hp = 0
        ..isUnconscious = true;
      final enemies = [caster, fallen, _supportCaster(0)..hp = 1];
      final party = [PartyMember.createPreset(1)..ac = 0];

      final results = BattleEngine(random: DeterministicRandom([0, 1]))
          .executeMonsterTurn(caster, party, enemies);

      expect(results.length, 3);
      expect(
        results.map((result) => result.outcome),
        everyElement(AttackOutcome.cured),
      );
      expect(caster.hp, 66);
      expect(fallen.hp, 1);
    });

    test('5단계 적의 단일 마법은 HP가 가장 낮은 행동 가능 대상을 고른다', () {
      final caster = _supportCaster(5);
      final party = [
        PartyMember.createPreset(1)
          ..hp = 100
          ..resistance = 0
          ..ac = 0,
        PartyMember.createPreset(3)
          ..hp = 60
          ..resistance = 0
          ..ac = 0,
        PartyMember.createPreset(4)
          ..hp = 80
          ..resistance = 0
          ..ac = 0,
      ];

      BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, party, [caster]);

      expect(party.map((member) => member.hp), [100, 10, 80]);
    });

    test('5단계 마법의 대상 수와 최저 HP 판정에서 빈자리·기절 대원을 제외한다', () {
      final caster = _supportCaster(5);
      final party = [
        PartyMember.createPreset(1)
          ..hp = 0
          ..unconscious = 1,
        PartyMember.createPreset(3)
          ..name = ''
          ..hp = 1,
        PartyMember.createPreset(4)
          ..hp = 100
          ..resistance = 0
          ..ac = 0,
      ];

      BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, party, [caster]);

      expect(party.map((member) => member.hp), [0, 1, 50]);
    });

    test('특수 시전 적은 원본 번호에서 소환수를 만들고 같은 턴에 공격한다', () {
      final caster = Monster.create(62).withOverrides(special: 0, castLevel: 0);
      final enemies = [caster];
      final party = [PartyMember.createPreset(1)..hp = 1000];

      final results = BattleEngine(random: DeterministicRandom([0, 0, 0, 1, 0]))
          .executeMonsterTurn(caster, party, enemies);

      expect(results.first.outcome, AttackOutcome.summoned);
      expect(enemies, hasLength(2));
      expect(enemies.last.eNumber, 42); // 62 + random(4) - 20
      expect(enemies.last.hp, enemies.last.endurance * enemies.last.level);
      expect(results.length, greaterThan(1)); // 소환 뒤에도 기본 공격을 수행한다.
    });

    test('소환 시 7칸이 가득 차면 가장 앞의 사망 슬롯을 다시 사용한다', () {
      final caster = Monster.create(62).withOverrides(special: 0, castLevel: 0);
      final dead = Monster.create(1)..isDead = true;
      final enemies = [
        caster,
        Monster.create(1),
        dead,
        Monster.create(1),
        Monster.create(1)..isDead = true,
        Monster.create(1)..isDead = true,
        Monster.create(1)..isDead = true,
      ];

      BattleEngine(random: DeterministicRandom([2, 0, 0])).executeMonsterTurn(
        caster,
        [PartyMember.createPreset(1)..hp = 1000],
        enemies,
      );

      expect(enemies, hasLength(7));
      expect(enemies[2].eNumber, 42);
      expect(enemies[2].isDead, isFalse);
      expect(enemies[4].isDead, isTrue);
    });

    test('원본 1번 적은 특수 시전 단계가 있어도 소환하지 않는다', () {
      final caster = Monster.create(1)..specialCastLevel = 1;
      final enemies = [caster];

      final results = BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, [PartyMember.createPreset(1)], enemies);

      expect(enemies, hasLength(1));
      expect(
        results.any((result) => result.outcome == AttackOutcome.summoned),
        isFalse,
      );
    });

    test('정신 지배는 6번 동료의 능력을 적으로 복사하고 원래 슬롯을 비운다', () {
      final caster = Monster.create(67).withOverrides(special: 0);
      final formerAlly = PartyMember.createPreset(7)
        ..name = 'Rigel'
        ..playerClass = PlayerClass.hunter
        ..battleLevel = 3
        ..magicLevel = 8
        ..endurance = 12
        ..hp = 1
        ..ac = 7;
      final party = [
        for (var i = 1; i <= 5; i++) PartyMember.createPreset(i),
        formerAlly,
      ];
      final enemies = [
        caster,
        Monster.create(1),
        Monster.create(1),
        Monster.create(1),
      ];

      final results = BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, party, enemies);

      expect(results.first.outcome, AttackOutcome.converted);
      expect(enemies, hasLength(5));
      final converted = enemies.last;
      expect(converted.eNumber, 1);
      expect(converted.name, 'Rigel');
      expect(converted.endurance, 12);
      expect(converted.hp, 36); // 현재 HP 1 대신 원본 turn_mind의 최대 HP
      expect(converted.ac, 7);
      expect(converted.special, 2); // 사냥꾼의 기절 특수 공격
      expect(converted.castLevel, 2);
      expect(converted.specialCastLevel, 0);
      expect(formerAlly.name, isEmpty);
      expect(formerAlly.isBattleActive, isFalse);
      expect(results.length, greaterThan(1)); // 변환 뒤에도 기본 공격을 수행한다.
    });

    test('정신 지배는 적이 7명일 때 사망 슬롯을 교체한다', () {
      final caster = Monster.create(67).withOverrides(special: 0, castLevel: 0);
      final formerAlly = PartyMember.createPreset(7)..name = '동료';
      final party = [
        for (var i = 1; i <= 5; i++) PartyMember.createPreset(i),
        formerAlly,
      ];
      final enemies = [
        caster,
        Monster.create(1),
        Monster.create(1)..isDead = true,
        Monster.create(1),
        Monster.create(1),
        Monster.create(1),
        Monster.create(1),
      ];

      BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, party, enemies);

      expect(enemies, hasLength(7));
      expect(enemies[2].name, '동료');
      expect(enemies[2].isDead, isFalse);
      expect(formerAlly.name, isEmpty);
    });

    test('6번 동료가 없거나 적 7명이 모두 살아 있으면 정신 지배를 건너뛴다', () {
      final caster = Monster.create(67).withOverrides(special: 0, castLevel: 0);
      final party = [
        for (var i = 1; i <= 5; i++) PartyMember.createPreset(i),
        PartyMember.createPreset(7)..name = '',
      ];
      final enemies = [caster];
      BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, party, enemies);
      expect(enemies, hasLength(2)); // 소환만 가능하다.

      party[5].name = '동료';
      final fullEnemies = [
        caster,
        for (var i = 0; i < 6; i++) Monster.create(1),
      ];
      final results = BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, party, fullEnemies);
      expect(fullEnemies, hasLength(7));
      expect(party[5].name, '동료');
      expect(
        results.any((result) => result.outcome == AttackOutcome.converted),
        isFalse,
      );
    });

    test('전체 즉사 저주는 사망·회피·빗나감을 판정한 뒤 일반 공격을 계속한다', () {
      final caster = Monster.create(68).withOverrides(castLevel: 0);
      final doomed = PartyMember.createPreset(1)
        ..hp = 10000
        ..luck = 0;
      final lucky = PartyMember.createPreset(3)
        ..hp = 10000
        ..luck = 20
        ..resistance = 0
        ..ac = 0;
      final missed = PartyMember.createPreset(4)
        ..hp = 10000
        ..luck = 0;
      final enemies = [caster, for (var i = 0; i < 3; i++) Monster.create(1)];

      final results = BattleEngine(
        random: DeterministicRandom([0, 0, 0, 0, 0, 0, 59, 49, 1, 0]),
      ).executeMonsterTurn(caster, [doomed, lucky, missed], enemies);

      expect(results.take(3).map((result) => result.outcome), [
        AttackOutcome.killed,
        AttackOutcome.resisted,
        AttackOutcome.miss,
      ]);
      expect(doomed.dead, 1);
      expect(doomed.hp, 0);
      expect(lucky.dead, 0);
      expect(missed.dead, 0);
      expect(results.length, greaterThan(3));
      expect(lucky.hp, lessThan(10000)); // 살아남은 대상에게 후속 일반 공격
    });

    test('전체 즉사 저주로 파티가 전멸하면 후속 대상 공격을 중단한다', () {
      final caster = Monster.create(68).withOverrides(castLevel: 0);
      final doomed = PartyMember.createPreset(1)
        ..hp = 100
        ..luck = 0;
      final enemies = [caster, for (var i = 0; i < 3; i++) Monster.create(1)];

      final results = BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, [doomed], enemies);

      expect(results.map((result) => result.outcome), [AttackOutcome.killed]);
      expect(doomed.isBattleActive, isFalse);
    });

    test('독 특수 공격은 행동 가능한 적이 네 명 이상일 때만 발동한다', () {
      final caster = Monster.create(1)
        ..special = 1
        ..agility = 30;
      final target = PartyMember.createPreset(1)
        ..hp = 1000
        ..luck = 0;
      final engine = BattleEngine(random: DeterministicRandom([0]));

      final alone = engine.executeMonsterTurn(caster, [target], [caster]);
      expect(target.poison, 0);
      expect(alone, isEmpty); // 무기 비교가 동점이고 시전 등급 0이면 쉰다.

      final group = [caster, for (var i = 0; i < 3; i++) Monster.create(1)];
      final special = engine.executeMonsterTurn(caster, [target], group);
      expect(special.single.outcome, AttackOutcome.debuffed);
      expect(target.poison, 1);

      target.poison = 0;
      group.last.isUnconscious = true;
      engine.executeMonsterTurn(caster, [target], group);
      expect(target.poison, 0); // 의식불명 적은 네 명 조건에서 제외한다.
    });

    test('특수 공격이 빗나가거나 회피되면 일반 공격을 추가하지 않는다', () {
      final caster = Monster.create(1)
        ..special = 1
        ..agility = 30;
      final group = [caster, for (var i = 0; i < 3; i++) Monster.create(1)];
      final missedTarget = PartyMember.createPreset(1)
        ..hp = 1000
        ..luck = 0;
      final missed = BattleEngine(random: DeterministicRandom([0, 0, 39]))
          .executeMonsterTurn(caster, [missedTarget], group);
      expect(missed.map((result) => result.outcome), [AttackOutcome.miss]);
      expect(missedTarget.hp, 1000);
      expect(missedTarget.poison, 0);

      final luckyTarget = PartyMember.createPreset(1)
        ..hp = 1000
        ..luck = 20;
      final resisted = BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, [luckyTarget], group);
      expect(resisted.map((result) => result.outcome), [
        AttackOutcome.resisted,
      ]);
      expect(luckyTarget.hp, 1000);
      expect(luckyTarget.poison, 0);
    });

    test('독·기절 특수 공격은 이미 같은 상태인 대원을 대상으로 고르지 않는다', () {
      final caster = Monster.create(1)
        ..special = 1
        ..agility = 30;
      final enemies = [caster, for (var i = 0; i < 3; i++) Monster.create(1)];
      final poisoned = PartyMember.createPreset(1)..poison = 1;
      final clean = PartyMember.createPreset(3)..luck = 0;

      final poisonResult = BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, [poisoned, clean], enemies);
      expect(poisonResult.single.outcome, AttackOutcome.debuffed);
      expect(clean.poison, 1);

      caster.special = 2;
      final unconscious = PartyMember.createPreset(1)
        ..hp = 0
        ..unconscious = 1;
      final conscious = PartyMember.createPreset(3)..luck = 0;
      final stunResult = BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(caster, [unconscious, conscious], enemies);
      expect(stunResult.single.outcome, AttackOutcome.unconscious);
      expect(conscious.unconscious, 1);
      expect(unconscious.unconscious, 1);
    });

    test('무기·마법 선택은 원본 명중치 난수를 비교하고 시전 등급 0은 쉴 수 있다', () {
      final orc = Monster.create(1);
      final idleTarget = PartyMember.createPreset(1)..hp = 1000;
      final idle = BattleEngine(random: DeterministicRandom([0]))
          .executeMonsterTurn(orc, [idleTarget], [orc]);
      expect(idle, isEmpty);
      expect(idleTarget.hp, 1000);

      final armedTarget = PartyMember.createPreset(1)
        ..hp = 1000
        ..resistance = 0
        ..ac = 0;
      final armed = BattleEngine(
        random: DeterministicRandom([1, 0, 0, 9, 0, 0]),
      ).executeMonsterTurn(orc, [armedTarget], [orc]);
      expect(armed, hasLength(1));
      expect(armedTarget.hp, lessThan(1000));
    });

    test('공격력이 0인 적은 무기 난수가 높아도 마법을 시전한다', () {
      final sprite = Monster.create(35);
      final target = PartyMember.createPreset(1)
        ..hp = 1000
        ..resistance = 0
        ..ac = 0;

      final results = BattleEngine(random: DeterministicRandom([0, 1, 0]))
          .executeMonsterTurn(sprite, [target], [sprite]);

      expect(results.first.message, contains('마법'));
      expect(target.hp, lessThan(1000));
    });

    test('무기·마법 명중치가 모두 있으면 두 난수의 대소관계로 행동을 정한다', () {
      Monster hybrid() => Monster(
        eNumber: 1,
        name: '혼합 공격자',
        strength: 10,
        mentality: 5,
        endurance: 10,
        resistance: 0,
        agility: 0,
        accArms: 10,
        accMagic: 10,
        ac: 0,
        special: 0,
        castLevel: 1,
        specialCastLevel: 0,
        level: 2,
      );
      final weaponCaster = hybrid();
      final weaponTarget = PartyMember.createPreset(1)
        ..hp = 1000
        ..resistance = 0
        ..ac = 0;
      final weapon = BattleEngine(random: DeterministicRandom([1, 0]))
          .executeMonsterTurn(weaponCaster, [weaponTarget], [weaponCaster]);
      expect(weapon, hasLength(1));

      final magicCaster = hybrid();
      final magicTarget = PartyMember.createPreset(1)
        ..hp = 1000
        ..resistance = 0
        ..ac = 0;
      final magic = BattleEngine(random: DeterministicRandom([0, 1]))
          .executeMonsterTurn(magicCaster, [magicTarget], [magicCaster]);
      expect(magic, hasLength(2));
      expect(magic.first.message, contains('마법'));
    });

    test('염력 13~14단계 중독은 저항과 ESP 명중 판정을 모두 통과해야 한다', () {
      final caster = PartyMember.createPreset(3)
        ..espLevel = 13
        ..esp = 60
        ..accEsp = 5;
      final party = [caster];
      final resistant = Monster.create(1)..resistance = 40;
      final resisted = BattleEngine(random: DeterministicRandom([12, 0]))
          .executePlayerESP(caster, resistant, 45, party, enemies: [resistant]);
      expect(resisted.outcome, AttackOutcome.resisted);
      expect(resistant.isPoisoned, isFalse);

      final missedTarget = Monster.create(1);
      final missed = BattleEngine(random: DeterministicRandom([12, 50, 39]))
          .executePlayerESP(
            caster,
            missedTarget,
            45,
            party,
            enemies: [missedTarget],
          );
      expect(missed.outcome, AttackOutcome.miss);
      expect(missedTarget.isPoisoned, isFalse);

      final poisonedTarget = Monster.create(1);
      final success = BattleEngine(random: DeterministicRandom([12, 50, 0]))
          .executePlayerESP(
            caster,
            poisonedTarget,
            45,
            party,
            enemies: [poisonedTarget],
          );
      expect(success.outcome, AttackOutcome.debuffed);
      expect(poisonedTarget.isPoisoned, isTrue);
      expect(caster.esp, 0);
    });

    test('염력 15~17단계 심장 정지는 저항·부분 피해·저체력 기절·성공을 구분한다', () {
      final caster = PartyMember.createPreset(3)
        ..espLevel = 15
        ..esp = 80
        ..accEsp = 5;
      final party = [caster];
      final resistant = Monster.create(1)
        ..hp = 20
        ..resistance = 20;
      final resisted = BattleEngine(random: DeterministicRandom([14, 0]))
          .executePlayerESP(caster, resistant, 45, party, enemies: [resistant]);
      expect(resisted.outcome, AttackOutcome.resisted);
      expect(resistant.resistance, 15);
      expect(resistant.hp, 20);
      expect(resistant.isUnconscious, isFalse);

      final sturdy = Monster.create(1)..hp = 20;
      final graze = BattleEngine(random: DeterministicRandom([14, 50, 79]))
          .executePlayerESP(caster, sturdy, 45, party, enemies: [sturdy]);
      expect(graze.outcome, AttackOutcome.hit);
      expect(sturdy.hp, 15);
      expect(sturdy.isUnconscious, isFalse);

      final weak = Monster.create(1)..hp = 8;
      final weakHit = BattleEngine(random: DeterministicRandom([14, 50, 79]))
          .executePlayerESP(caster, weak, 45, party, enemies: [weak]);
      expect(weakHit.outcome, AttackOutcome.unconscious);
      expect(weak.hp, 0);
      expect(weak.isUnconscious, isTrue);

      final successTarget = Monster.create(1)..hp = 20;
      final success = BattleEngine(random: DeterministicRandom([14, 50, 0]))
          .executePlayerESP(
            caster,
            successTarget,
            45,
            party,
            enemies: [successTarget],
          );
      expect(success.outcome, AttackOutcome.unconscious);
      expect(successTarget.hp, 20); // 원본은 명중 시 HP를 건드리지 않는다.
      expect(successTarget.isUnconscious, isTrue);
      expect(caster.esp, 0);
    });

    test('염력 18단계 이상 환상은 저항 시 민첩, 성공 시 두 정확도를 낮춘다', () {
      final caster = PartyMember.createPreset(3)
        ..espLevel = 18
        ..esp = 60
        ..accEsp = 5;
      final party = [caster];
      final resistant = Monster.create(3)..resistance = 10;
      final agility = resistant.agility;
      final resisted = BattleEngine(random: DeterministicRandom([17, 0]))
          .executePlayerESP(caster, resistant, 45, party, enemies: [resistant]);
      expect(resisted.outcome, AttackOutcome.resisted);
      expect(resistant.agility, agility - 5);

      final missedTarget = Monster.create(3)..resistance = 0;
      final arms = missedTarget.accArms;
      final magic = missedTarget.accMagic;
      final missed = BattleEngine(random: DeterministicRandom([17, 39, 29]))
          .executePlayerESP(
            caster,
            missedTarget,
            45,
            party,
            enemies: [missedTarget],
          );
      expect(missed.outcome, AttackOutcome.miss);
      expect(missedTarget.accArms, arms);
      expect(missedTarget.accMagic, magic);

      final hitTarget = Monster.create(3)..resistance = 0;
      final hit = BattleEngine(random: DeterministicRandom([17, 39, 0]))
          .executePlayerESP(caster, hitTarget, 45, party, enemies: [hitTarget]);
      expect(hit.outcome, AttackOutcome.debuffed);
      expect(hitTarget.accArms, arms - 1);
      expect(hitTarget.accMagic, magic - 1);
      expect(caster.esp, 0);
    });

    test('2. 플레이어 무기 공격 명중 및 대미지 공식 검증', () {
      // 주사위: [명중(0: 0 <= accArms), 분산(0: 분산감소 0%), 저항(99: 저항 실패), 방어차감 난수(0: +1/10)]
      final mockRandom = DeterministicRandom([0, 0, 99, 0]);
      final engine = BattleEngine(random: mockRandom);

      final hero = PartyMember.createPreset(
        1,
      ); // Hercules: strength=17, accArms=15, level=1, weaPower=3 (기사 기본)
      hero.equipWeapon(Item.weapons[4]); // 장검 (power 10 + 기사 보너스 50% = 15)
      expect(hero.weaPower, equals(15));

      final orc = Monster.create(1); // Orc: HP=8, AC=1, Level=1, Resistance=0
      expect(orc.hp, equals(8));

      // Base Damage = 17 * 15 * 1 ~/ 20 = 255 ~/ 20 = 12
      // Variance = 0% 감소 -> 12
      // Resistance = 99 >= 0 -> 저지 실패
      // DefReduce = round(1 * 1 * (0 + 1) / 10) = round(0.1) = 0
      // Final Damage = 12 - 0 = 12
      final result = engine.executePlayerWeaponAttack(hero, orc);

      expect(
        result.outcome,
        equals(AttackOutcome.unconscious),
      ); // 체력 8인데 12 대미지 -> 기절
      expect(result.damage, equals(12));
      expect(orc.hp, equals(0));
      expect(orc.isUnconscious, isTrue);
      expect(orc.isDead, isFalse);
      expect(hero.experience, greaterThan(0));
    });

    test('3. 기절(의식불명) 적에 대한 처형 즉사 판정 검증', () {
      final engine = BattleEngine();
      final hero = PartyMember.createPreset(1);
      final orc = Monster.create(1);

      orc.hp = 0;
      orc.isUnconscious = true;
      orc.isDead = false;

      final result = engine.executePlayerWeaponAttack(hero, orc);
      expect(result.outcome, equals(AttackOutcome.killed));
      expect(orc.isDead, isTrue);
    });

    test('4. 마법 공격 SP 소모 및 대미지 공식 검증', () {
      // [명중(0 < 18), 저항(99 >= 0), 방어난수(0)]
      final mockRandom = DeterministicRandom([0, 99, 0]);
      final engine = BattleEngine(random: mockRandom);

      final mage = PartyMember.createPreset(
        3,
      ); // Merlin: mentality=19, accMagic=18, magicLevel=1, SP=19
      final troll = Monster.create(
        2,
      ); // Troll: HP=6, AC=1, Level=1, Resistance=0

      // 1번 마법 시전 (magicIndex=1)
      // SP 소모: round(1 * 1 * 1 / 2) = round(0.5) = 1
      // 기본 위력: 1 * 1 * 1 * 2 = 2
      // DefReduce: round(1 * 1 * 1 / 10) = 0
      // Final Damage: 2
      final initialSp = mage.sp;
      final result = engine.executePlayerMagicAttack(mage, troll, 1);

      expect(mage.sp, equals(initialSp - 1));
      expect(result.outcome, equals(AttackOutcome.hit));
      expect(result.damage, equals(2));
      expect(troll.hp, equals(4)); // 6 - 2 = 4
    });

    test('5. 적의 공격 및 파티원 기절/사망 누적 판정 검증', () {
      // [명중(0 < accArms), 대미지난수(9: (9+1)/10 = 10/10), 플레이어 저항(49 >= 11), 플레이어 방어난수(0)]
      final mockRandom = DeterministicRandom([0, 9, 49, 0]);
      final engine = BattleEngine(random: mockRandom);

      final giant = Monster.create(6); // Giant: Strength=15, Level=2, accArms=8
      // Enemy Base Dmg = 15 * 2 * 10 / 10 = 30
      final hero = PartyMember.createPreset(
        1,
      ); // Hercules: endurance=17, level=1, AC=1 (기사 기본)
      hero.hp = 10;

      // 1차 피격: HP 10 -> 0 이하로 떨어져 기절(unconscious = 1)
      final r1 = engine.executeEnemyWeaponAttack(giant, hero);
      expect(r1.outcome, equals(AttackOutcome.unconscious));
      expect(hero.isUnconscious, isTrue);
      expect(hero.isDead, isFalse);
      expect(hero.unconscious, greaterThan(0));

      // 2차 피격: 기절 상태에서 추가 대미지를 받아 unconscious 누적치가 endurance * level(17)을 초과하면 사망
      final r2 = engine.executeEnemyWeaponAttack(giant, hero);
      expect(hero.isDead, isTrue);
      expect(r2.outcome, equals(AttackOutcome.killed));
    });

    test('6. 도망(RunAway) 확률 공식 검증', () {
      // Random(50) <= agility
      // Hercules agility = 15
      final hero = PartyMember.createPreset(1);

      // 주사위 10 -> 10 <= 15 -> 성공
      final engineSuccess = BattleEngine(random: DeterministicRandom([10]));
      expect(engineSuccess.checkRunAway(hero), isTrue);

      // 주사위 40 -> 40 > 15 -> 실패
      final engineFail = BattleEngine(random: DeterministicRandom([40]));
      expect(engineFail.checkRunAway(hero), isFalse);
    });

    test('7. 원작 `with enemy[i] do` 적별 덮어쓰기(이름/방어도/레벨)', () {
      // 원작 map 11 미이라의 방: `name := 'Sphinx'; level := 4; E_number := 20`
      final sphinx = Monster.create(35)
          .withOverrides(name: 'Sphinx', level: 4, special: 0, eNumber: 20);
      expect(sphinx.name, 'Sphinx');
      expect(sphinx.level, 4);
      expect(sphinx.eNumber, 20);
      expect(sphinx.special, 0);
      // 원작은 `level` 을 바꾸면 최대 HP 도 `endurance * level` 로 다시 잡는다.
      expect(sphinx.maxHp, sphinx.endurance * 4);
      expect(sphinx.hp, sphinx.maxHp);

      // 원작 map 18: `enemy[2] do begin name := 'Dragon''s tail'; ac := 8; end;`
      final tail = Monster.create(39)
          .withOverrides(name: "Dragon's tail", ac: 8);
      expect(tail.name, "Dragon's tail");
      expect(tail.ac, 8);
      // 레벨을 건드리지 않으면 HP 는 그대로다.
      expect(tail.level, Monster.create(39).level);
      expect(tail.hp, Monster.create(39).hp);
    });
  });
}
