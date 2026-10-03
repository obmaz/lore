import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/field_hotkeys.dart';
import 'package:lore/logic/lore_main_procedures.dart';
import 'package:lore/models/party_member.dart';

class _SequenceRandom implements Random {
  final List<int> values;
  final List<int> bounds = [];
  int index = 0;

  _SequenceRandom(this.values);

  @override
  int nextInt(int max) {
    bounds.add(max);
    return values[index++];
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// LOREMAIN.PAS field procedures (Main, Move_Mode, enter_swamp, enter_lava,
/// enter_water) and LORESUB.PAS `DetectGameOver`.
void main() {
  test(
    'Main redispatches the current tile after every original field menu',
    () {
      for (final action in [
        FieldAction.openMenu,
        FieldAction.viewParty,
        FieldAction.viewCharacter,
        FieldAction.quickView,
        FieldAction.castSpell,
        FieldAction.extrasense,
        FieldAction.rest,
        FieldAction.gameOption,
      ]) {
        expect(LoreMainProcedures.mainRedispatchesCurrentTile(action), isTrue);
      }
      expect(
        LoreMainProcedures.mainRedispatchesCurrentTile(FieldAction.toggleSound),
        isFalse,
      );
      expect(
        LoreMainProcedures.mainRedispatchesCurrentTile(FieldAction.none),
        isFalse,
      );
    },
  );

  test(
    'enter_lava rolls every slot before displaying and applying damage',
    () async {
      final party = [for (var i = 1; i <= 6; i++) PartyMember.createPreset(i)];
      party[2].name = '';
      final beforeHp = party.first.hp;
      final random = _SequenceRandom(List.filled(12, 0));
      final trace = <String>[];

      await LoreMainProcedures.enterLava(
        party: party,
        random: random,
        scrollToParty: () => trace.add('scroll'),
        showLavaWarning: () => trace.add('warning:${random.bounds.length}'),
        showDamage: (member, damage) =>
            trace.add('damage:${member.name}:$damage:${random.bounds.length}'),
        displayCondition: () => trace.add('condition'),
        gameOver: () async => trace.add('gameOver'),
      );

      expect(random.bounds.length, 12);
      expect(random.bounds.where((bound) => bound == 40).length, 6);
      expect(trace.first, 'scroll');
      expect(trace[1], 'warning:12');
      expect(trace.where((entry) => entry.startsWith('damage:')).length, 5);
      expect(
        trace.where((entry) => entry.startsWith('damage:')),
        everyElement(endsWith(':12')),
      );
      expect(party.first.hp, lessThan(beforeHp));
      expect(trace, contains('condition'));
    },
  );

  test(
    'enter_swamp advances poison, then rolls six slots before messages',
    () async {
      final party = [
        for (var i = 1; i <= 6; i++) PartyMember.createPreset(i)..luck = 20,
      ];
      party.first
        ..poison = 10
        ..hp = 2
        ..luck = 1;
      final random = _SequenceRandom([0, 0, 0, 0, 0, 0]);
      final trace = <String>[];

      await LoreMainProcedures.enterSwamp(
        party: party,
        scrollToParty: () => trace.add('scroll'),
        swampWalkSteps: () => 0,
        setSwampWalkSteps: (_) => trace.add('protected'),
        random: random,
        showSwampWarning: () => trace.add('warning:${random.bounds.length}'),
        showPoisonMessage: (member) => trace.add('poison:${member.name}'),
        displayCondition: () => trace.add('condition'),
        displayHealthAndCondition: () => trace.add('health'),
        gameOver: () async => trace.add('gameOver'),
      );

      expect(random.bounds, List.filled(6, 20));
      expect((party.first.poison, party.first.hp), (1, 1));
      expect(trace, [
        'scroll',
        'warning:6',
        'poison:${party.first.name}',
        'condition',
        'health',
      ]);
    },
  );

  test('enter_swamp consumes protection without a poison roll', () async {
    final party = [for (var i = 1; i <= 6; i++) PartyMember.createPreset(i)];
    var steps = 1;
    final random = _SequenceRandom([]);
    final trace = <String>[];

    await LoreMainProcedures.enterSwamp(
      party: party,
      scrollToParty: () => trace.add('scroll'),
      swampWalkSteps: () => steps,
      setSwampWalkSteps: (value) {
        steps = value;
        trace.add('steps:$value');
      },
      random: random,
      showSwampWarning: () => trace.add('warning'),
      showPoisonMessage: (_) => trace.add('poison'),
      displayCondition: () => trace.add('condition'),
      displayHealthAndCondition: () => trace.add('health'),
      gameOver: () async => trace.add('gameOver'),
    );

    expect(steps, 0);
    expect(random.bounds, isEmpty);
    expect(trace, ['scroll', 'steps:0']);
  });

  test(
    'Move_Mode advances poison before mind reading and encounter roll',
    () async {
      final party = [for (var i = 1; i <= 6; i++) PartyMember.createPreset(i)];
      party.first
        ..poison = 10
        ..hp = 2;
      var mindRead = 2;
      final trace = <String>[];

      await LoreMainProcedures.moveMode(
        party: party,
        scrollToParty: () => trace.add('scroll'),
        displayHealthAndCondition: () => trace.add('display'),
        gameOver: () async => trace.add('gameOver'),
        mindReadSteps: () => mindRead,
        setMindReadSteps: (value) {
          mindRead = value;
          trace.add('mindRead:$value');
        },
        encounterFrequency: () => 2,
        random: (bound) {
          trace.add('random:$bound');
          return 0;
        },
        encounterEnemy: () => trace.add('encounter'),
      );

      expect((party.first.poison, party.first.hp, mindRead), (1, 1, 1));
      expect(trace, [
        'scroll',
        'display',
        'mindRead:1',
        'random:40',
        'encounter',
      ]);
    },
  );

  test(
    'Move_Mode skips empty slots and detects a wiped party before rolling',
    () async {
      final party = [
        for (var i = 1; i <= 6; i++) PartyMember.createPreset(i)..dead = 1,
      ];
      party.first
        ..name = ''
        ..poison = 10;
      final trace = <String>[];
      await LoreMainProcedures.moveMode(
        party: party,
        scrollToParty: () => trace.add('scroll'),
        displayHealthAndCondition: () => trace.add('display'),
        gameOver: () async => trace.add('gameOver'),
        mindReadSteps: () => 0,
        setMindReadSteps: (_) => trace.add('mindRead'),
        encounterFrequency: () => 1,
        random: (bound) {
          trace.add('random:$bound');
          return 1;
        },
        encounterEnemy: () => trace.add('encounter'),
      );
      expect(party.first.poison, 10);
      expect(trace, ['scroll', 'gameOver', 'random:20']);
    },
  );

  test(
    'Move_Mode waits for GameOver, then reads etc[5]/etc[7] after a reload',
    () async {
      final party = [
        for (var i = 1; i <= 6; i++) PartyMember.createPreset(i)..dead = 1,
      ];
      final gameOver = Completer<void>();
      var mindRead = 0;
      var frequency = 1;
      final trace = <String>[];
      final run = LoreMainProcedures.moveMode(
        party: party,
        scrollToParty: () {},
        displayHealthAndCondition: () {},
        gameOver: () {
          trace.add('gameOver');
          return gameOver.future;
        },
        mindReadSteps: () => mindRead,
        setMindReadSteps: (value) => trace.add('mindRead:$value'),
        encounterFrequency: () => frequency,
        random: (bound) {
          trace.add('random:$bound');
          return 1;
        },
        encounterEnemy: () => trace.add('encounter'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(trace, ['gameOver']);
      // `Load` replaced party.etc[5] and party.etc[7].
      mindRead = 3;
      frequency = 2;
      gameOver.complete();
      await run;
      expect(trace, ['gameOver', 'mindRead:2', 'random:40']);
    },
  );

  test('enter_water consumes spell, scrolls, then rolls and enters battle', () {
    var steps = 2;
    final trace = <String>[];

    LoreMainProcedures.enterWater(
      waterWalkSteps: () => steps,
      setWaterWalkSteps: (value) {
        steps = value;
        trace.add('steps:$value');
      },
      scrollToParty: () => trace.add('scroll'),
      encounterFrequency: 2,
      random: (bound) {
        trace.add('random:$bound');
        return 0;
      },
      encounterEnemy: () => trace.add('encounter'),
      restorePosition: () => trace.add('restore'),
    );

    expect(steps, 1);
    expect(trace, ['steps:1', 'scroll', 'random:60', 'encounter']);
  });

  test('enter_water restores position without consuming random when dry', () {
    var steps = 0;
    final trace = <String>[];

    LoreMainProcedures.enterWater(
      waterWalkSteps: () => steps,
      setWaterWalkSteps: (value) {
        steps = value;
        trace.add('steps:$value');
      },
      scrollToParty: () => trace.add('scroll'),
      encounterFrequency: 3,
      random: (bound) {
        trace.add('random:$bound');
        return 0;
      },
      encounterEnemy: () => trace.add('encounter'),
      restorePosition: () => trace.add('restore'),
    );

    expect(steps, 0);
    expect(trace, ['restore']);
  });

  test('enter_water does not request battle on a nonzero roll', () {
    var steps = 1;
    final trace = <String>[];

    LoreMainProcedures.enterWater(
      waterWalkSteps: () => steps,
      setWaterWalkSteps: (value) {
        steps = value;
        trace.add('steps:$value');
      },
      scrollToParty: () => trace.add('scroll'),
      encounterFrequency: 1,
      random: (bound) {
        trace.add('random:$bound');
        return 29;
      },
      encounterEnemy: () => trace.add('encounter'),
      restorePosition: () => trace.add('restore'),
    );

    expect(steps, 0);
    expect(trace, ['steps:0', 'scroll', 'random:30']);
  });
}
