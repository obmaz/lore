import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_portal_session.dart';
import 'package:lore/logic/lore_swamp_logic.dart';
import 'package:lore/logic/lore_ent_procedures.dart';
import 'package:lore/logic/script_world_reducer.dart';
import 'package:lore/models/party_member.dart';

class _Rolls implements Random {
  _Rolls(this.values);
  final List<int> values;
  final bounds = <int>[];
  @override
  int nextInt(int max) {
    bounds.add(max);
    return values[bounds.length - 1];
  }

  @override
  bool nextBool() => throw StateError('unexpected bool');
  @override
  double nextDouble() => throw StateError('unexpected double');
}

// LORESPEC.PAS sgn/food, LOREMAIN.PAS six swamp rolls, LOREENT.PAS entry
// guards and LORESUB.PAS wantenter. Expected predicates come from Pascal,
// not executable JSON rules. BGI waits/pixels are outside this test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all signed sgn values and every pyramid starting cell preserve axis order',
    () {
      final source = String.fromCharCodes(
        File('repo_source/LORE_1993_src/LORESPEC.PAS').readAsBytesSync(),
      );
      expect(source, contains('if eq > 0 then sgn := 1'));
      expect(source, contains('else if eq < 0 then sgn := -1'));
      for (var n = -32768; n <= 32767; n++) {
        expect(LoreSpecProcedures.sourceSign(n), n.compareTo(0));
      }
      for (var x = 76; x <= 86; x++) {
        for (var y = 71; y <= 81; y++) {
          final run = LoreSpecProcedures.map13(
            x,
            y,
            const ScriptContext(tileAtPlayer: 52),
            LoreScriptEngine(),
          )!;
          final expected = <(int, int)>[];
          var cx = x, cy = y;
          while (cx != 81) {
            final dx = cx < 81 ? 1 : -1;
            expected.add((dx, 0));
            cx += dx;
          }
          while (cy != 77) {
            final dy = cy < 77 ? 1 : -1;
            expected.add((0, dy));
            cy += dy;
          }
          expect(run.outcome.nudges.map((n) => (n.dx, n.dy)), expected);
        }
      }
    },
  );
  test(
    'all food/flag bytes, all other bits preserved, independent saturation',
    () {
      final source = String.fromCharCodes(
        File('repo_source/LORE_1993_src/LORESPEC.PAS').readAsBytesSync(),
      );
      expect(source, contains('if party.food > 155 then party.food := 255'));
      final scripts = LoreScriptEngine();
      final manager = LoreDialogueManager.instance;
      addTearDown(() => manager.loadFlags({}));
      for (var flag = 0; flag < 256; flag++) {
        final run = LoreSpecProcedures.map1Food(
          ScriptContext(
            tileAtPlayer: 0,
            sourceEtc: {32: flag},
            flags: const {'etc32_bit8'},
          ),
          scripts,
        )!;
        expect(
          run.outcome.setFlags,
          (flag & 128) == 0 ? ['etc32_bit8'] : <String>[],
        );
        manager.loadFlags({'etc32': flag});
        for (final name in run.outcome.setFlags) {
          manager.setFlag(name);
        }
        expect(manager.partyEtc.read(32), flag | 128);
        for (var food = 0; food < 256; food++) {
          final expected = (flag & 128) != 0
              ? food
              : food > 155
              ? 255
              : food + 100;
          expect(
            ScriptWorldReducer.applyResources(
              ScriptResources(gold: 17, food: food),
              run.outcome,
            ).food,
            expected,
          );
        }
      }
    },
  );
  test(
    'six ordered swamp draws for every luck byte and roll, excluding seventh',
    () {
      final source = String.fromCharCodes(
        File('repo_source/LORE_1993_src/LOREMAIN.PAS').readAsBytesSync(),
      );
      expect(
        source,
        contains("if random(20)+1 >= player[i].luck then m[i] := '!';"),
      );
      for (var luck = 0; luck < 256; luck++) {
        for (var roll = 0; roll < 20; roll++) {
          final rolls = [
            for (var slot = 0; slot < 6; slot++) (roll + slot) % 20,
          ];
          final party = [
            for (var slot = 0; slot < 7; slot++)
              PartyMember.blank()
                ..name = slot.isEven ? 'Slot$slot' : ''
                ..luck = luck,
          ];
          final random = _Rolls(rolls);
          expect(LoreSwampLogic.rollPoisonedSlots(party, random), [
            for (var slot = 0; slot < 6; slot++)
              if (slot.isEven && rolls[slot] + 1 >= luck) slot,
          ]);
          expect(random.bounds, List.filled(6, 20));
        }
      }
    },
  );
  test(
    'all raw entry flags, entrance points and first-choice-only confirmation',
    () {
      final source = String.fromCharCodes(
        File('repo_source/LORE_1993_src/LORESUB.PAS').readAsBytesSync(),
      );
      expect(
        source,
        contains('if k = 1 then wantenter := TRUE else wantenter := FALSE;'),
      );
      for (var key = 0; key < 256; key++) {
        expect(LorePortalSession.acceptsChoice(key), key == 1);
        for (final from in [3, 16]) {
          final writes = <(int, int, int)>[];
          LoreEntProcedures.afterMapLoadTiles(
            fromMap: from,
            toMap: 10,
            partyNames: const {},
            flags: key & 8 == 0 ? {'loreHunterJoined'} : {},
            questSteps: const {},
            sourceEtc: {38: key},
            setTile: (x, y, t) => writes.add((x, y, t)),
          );
          expect(writes, key & 8 != 0 ? [(40, 56, 44)] : <(int, int, int)>[]);
        }
      }
      for (var map = 0; map < 256; map++) {
        for (final point in [
          (17, 89),
          (16, 89),
          (17, 88),
          (17, 90),
          (18, 89),
        ]) {
          final portal = LoreEntProcedures.entranceAt(map, point.$1, point.$2);
          if (map == 1) {
            expect(portal != null, point == (17, 89));
          }
        }
      }
    },
  );
}
