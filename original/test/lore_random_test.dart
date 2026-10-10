import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/logic/lore_lava_logic.dart';
import 'package:lore/models/party_member.dart';

void main() {
  test('integer Random matches the original EXE instruction stream', () {
    final fixture = jsonDecode(
      File('test/fixtures/dos_random_stream.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final scenario in fixture['cases'] as List) {
      final random = LoreRandom(scenario['initialSeed'] as int);
      for (final call in scenario['calls'] as List) {
        expect(random.nextInt(call['bound'] as int), call['value']);
        expect(random.seed, call['seed']);
      }
    }
  });

  test('battle Random adapter preserves native zero-bound draws and seeds', () {
    final fixture = jsonDecode(
      File('test/fixtures/dos_random_stream.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final scenario in fixture['cases'] as List) {
      final random = LoreRandom(scenario['initialSeed'] as int);
      final battle = LoreBattle(
        party: [PartyMember.createPreset(1)],
        enemy: [Monster.create(1)],
        random: random,
        print: (_, _) {},
      );
      for (final call in scenario['calls'] as List) {
        expect(battle.rnd(call['bound'] as int), call['value']);
        expect(random.seed, call['seed']);
      }
    }
  });

  test('lava consumes Random(0) for all empty zero-luck slots', () {
    // LOREMAIN.PAS:83 rolls Random(40) AND Random(player[i].luck) per slot.
    // Original EXE advance #12 is 2039224980, even when the range is zero.
    final random = LoreRandom(0);
    expect(
      LoreLavaLogic.rollDamages(
        List.generate(6, (_) => PartyMember.blank()),
        random,
      ),
      [56, 76, 57, 43, 56, 76],
    );
    expect(random.seed, 2039224980);
  });

  test('Randomize packs DOS time words, with hundredths precision', () {
    expect(
      LoreRandom.fromClock(DateTime(1993, 1, 1, 18, 52, 37, 890)).seed,
      0x25591234,
    );
  });
}
