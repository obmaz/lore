import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

// Only CASE ownership is proved here. Individual procedures retain their own
// arithmetic, continuation and unresolved hardware contracts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'source part1/part2 CASE routes every coordinate to exactly its owner',
    () {
      final source = String.fromCharCodes(
        File('repo_source/LORE_1993_src/LORESPEC.PAS').readAsBytesSync(),
      );
      final split = source.indexOf('Procedure specialevent_part2;');
      final part1 = RegExp(r'^      (\d+) :', multiLine: true)
          .allMatches(source.substring(0, split))
          .map((m) => int.parse(m[1]!))
          .toSet();
      final part2 = RegExp(r'^      (\d+) :', multiLine: true)
          .allMatches(source.substring(split))
          .map((m) => int.parse(m[1]!))
          .toSet();
      expect(part1, {1, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16});
      expect(part2, {17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27});
      expect(
        source,
        contains(
          'if party.map < 17 then specialevent_part1 else specialevent_part2;',
        ),
      );
      final owners = {
        4: LoreSpecProcedures.map4,
        6: LoreSpecProcedures.map6,
        7: LoreSpecProcedures.map7,
        8: LoreSpecProcedures.map8,
        9: LoreSpecProcedures.map9,
        10: LoreSpecProcedures.map10,
        11: LoreSpecProcedures.map11,
        12: LoreSpecProcedures.map12,
        13: LoreSpecProcedures.map13,
        14: LoreSpecProcedures.map14,
        15: LoreSpecProcedures.map15,
        16: LoreSpecProcedures.map16,
        17: LoreSpecProcedures.map17,
        18: LoreSpecProcedures.map18,
        19: LoreSpecProcedures.map19,
        20: LoreSpecProcedures.map20,
        21: LoreSpecProcedures.map21,
        22: LoreSpecProcedures.map22,
        23: LoreSpecProcedures.map23,
        24: LoreSpecProcedures.map24,
        25: LoreSpecProcedures.map25,
        26: LoreSpecProcedures.map26,
        27: LoreSpecProcedures.map27,
      };
      for (var map = 0; map < 256; map++) {
        final selected = (map < 17 ? part1 : part2).contains(map);
        final limit = selected ? 100 : 2;
        for (var x = 1; x <= limit; x++) {
          for (var y = 1; y <= limit; y++) {
            const context = ScriptContext(tileAtPlayer: 0);
            final engine = LoreScriptEngine(random: Random(1993));
            final directEngine = LoreScriptEngine(random: Random(1993));
            final actual = LoreSpecialEventDispatcher.resolve(
              action: LoreTileAction.special,
              mapId: map,
              x: x,
              y: y,
              context: context,
              party: const [],
              scripts: engine,
            ).script;
            final expected = !selected
                ? null
                : map == 1
                ? LoreSpecProcedures.map1Food(context, directEngine)
                : owners[map]!(x, y, context, directEngine);
            expect(
              actual?.script.id,
              expected?.script.id,
              reason: '$map:$x:$y',
            );
            expect(actual?.script.map, expected?.script.map);
            expect(engine.consumedScripts, directEngine.consumedScripts);
            if (actual != null) expect(actual.script.map, map);
          }
        }
      }
      for (final action in LoreTileAction.values.where(
        (a) => a != LoreTileAction.special,
      )) {
        for (var map = 1; map <= 27; map++) {
          expect(
            LoreSpecialEventDispatcher.resolve(
              action: action,
              mapId: map,
              x: 50,
              y: 50,
              context: const ScriptContext(tileAtPlayer: 0),
              party: const [],
              scripts: LoreScriptEngine(),
            ).script,
            isNull,
          );
        }
      }
    },
  );
}
