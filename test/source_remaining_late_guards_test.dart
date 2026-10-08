import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_mirror_enemy.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/script_world_reducer.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = String.fromCharCodes(
    File('repo_source/LORE_1993_src/LORESPEC.PAS').readAsBytesSync(),
  );
  test(
    'map23 mirror FOR and empty-name branch cover all masks and list lengths',
    () {
      final match = RegExp(
        r"for i := (\d+) to (\d+) do begin\s*if player\[i\]\.name = '' then joinenemy\(i,(\d+)\)\s*else turn_mind\(i,i\);\s*enemy\[i\]\.E_number := (\d+);",
      ).firstMatch(source)!;
      final first = int.parse(match[1]!), last = int.parse(match[2]!);
      final fallback = Monster.create(int.parse(match[3]!));
      final marker = int.parse(match[4]!);
      for (var mask = 0; mask < 64; mask++) {
        for (var length = 0; length <= 7; length++) {
          final party = [
            for (var i = 0; i < length; i++)
              PartyMember.createPreset(1)
                ..name = i == 6
                    ? 'Outside'
                    : ((mask & (1 << i)) == 0 ? '' : 'Slot$i')
                ..dead = 1
                ..unconscious = 1
                ..hp = 0,
          ];
          final before = [for (final p in party) p.toJson()];
          final enemies = createMindMirrorEnemies(party);
          expect(enemies.length, last - first + 1);
          for (var slot = first; slot <= last; slot++) {
            final enemy = enemies[slot - first];
            final named = slot <= party.length && party[slot - 1].name != '';
            expect(enemy.eNumber, marker);
            expect(enemy.name, named ? party[slot - 1].name : fallback.name);
            // This verifies branch/slot ownership, not turn_mind arithmetic.
            if (!named) {
              expect(
                [
                  enemy.strength,
                  enemy.mentality,
                  enemy.endurance,
                  enemy.resistance,
                  enemy.agility,
                  enemy.accArms,
                  enemy.accMagic,
                  enemy.ac,
                  enemy.special,
                  enemy.castLevel,
                  enemy.specialCastLevel,
                  enemy.level,
                  enemy.hp,
                ],
                [
                  fallback.strength,
                  fallback.mentality,
                  fallback.endurance,
                  fallback.resistance,
                  fallback.agility,
                  fallback.accArms,
                  fallback.accMagic,
                  fallback.ac,
                  fallback.special,
                  fallback.castLevel,
                  fallback.specialCastLevel,
                  fallback.level,
                  fallback.hp,
                ],
              );
            }
            expect(
              [enemy.isDead, enemy.isUnconscious, enemy.isPoisoned],
              [false, false, false],
            );
          }
          expect(party.map((p) => p.toJson()).toList(), before);
        }
      }
    },
  );
  test(
    'MENACE source guard obeys raw bytes; increment follows acknowledgement',
    () {
      expect(source, contains('(on(25,8) or on(26,8)) and (party.etc[10]=3)'));
      final body = source.substring(
        source.indexOf('(on(25,8) or on(26,8))'),
        source.indexOf('if (on(6,6))'),
      );
      expect(
        body.indexOf('PressAnyKey;'),
        lessThan(body.indexOf('inc(party.etc[10]);')),
      );
      for (var value = 0; value < 256; value++) {
        for (final alias in [0, 3, 255]) {
          for (final position in [
            (25, 8),
            (26, 8),
            (24, 8),
            (27, 8),
            (25, 7),
            (26, 9),
          ]) {
            final (x, y) = position;
            final run = LoreSpecProcedures.map14(
              x,
              y,
              ScriptContext(
                tileAtPlayer: 52,
                sourceEtc: {10: value},
                questSteps: {'lordahn': alias},
              ),
              LoreScriptEngine(),
            );
            final triggered = value == 3 && (x == 25 || x == 26) && y == 8;
            expect(run != null, triggered, reason: '$position:$value:$alias');
            if (run == null) continue;
            expect(run.outcome.sourceEtcWrites, isEmpty);
            expect(run.outcome.questChanges, isEmpty);
            final after = run.acknowledgeScene();
            expect(after.outcome.sourceEtcWrites, [(index: 10, value: 4)]);
            final state = ScriptWorldReducer.applyProgress(
              ScriptProgressState(
                flags: const {},
                quests: {'lordahn': alias},
                sourceEtc: {10: value, 100: 255},
              ),
              after.outcome,
            );
            expect(state.sourceEtc[10], 4);
            expect(state.sourceEtc[100], 255);
            expect(state.quests['lordahn'], 4);
          }
        }
      }
    },
  );
  test('Skeleton first choice only recruits; wait precedes exit flag', () {
    expect(
      source,
      contains('if k = 1 then begin\r\n                   join(19,6);'),
    );
    for (var raw = 0; raw < 256; raw++) {
      final procedure = LoreSpecProcedures.castleExitSkeleton(
        ScriptContext(sourceEtc: {31: raw}),
        51,
        96,
      );
      expect(procedure == null, raw.isOdd);
      if (procedure == null) continue;
      for (final choice in [0, 1]) {
        var run = LoreScriptEngine().startProcedure(
          procedure,
          const ScriptContext(),
        );
        run = run.acknowledgeScene().choose(choice);
        expect(
          run.outcome.recruits.map((r) => r.key),
          choice == 0 ? ['skeleton'] : [],
        );
        expect(run.outcome.setFlags, isNot(contains('etc31_bit1')));
        // Accepted recruitment refreshes condition before its PressAnyKey.
        if (run.pendingConditionRefresh) {
          run = run.acknowledgeConditionRefresh();
        }
        expect(run.hasPendingScene, true);
        final after = run.acknowledgeScene();
        expect(after.outcome.setFlags, contains('etc31_bit1'));
      }
    }
  });
}
