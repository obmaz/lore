import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_field_logic.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/script_world_reducer.dart';

/// LORESUB.PAS:1012-1024 FindGold string[9], page loop and longint store.
/// Actual BGI double-page painting is not claimed by these numeric tests.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_findgold.json').readAsStringSync(),
  );
  test(
    'native Str string[9] truncation and gold overflow match shared owner',
    () {
      for (final row in fixture['cases']) {
        final events = row['events'];
        expect(events[0], ['clear']);
        expect(events[1], ['page', 1 - row['page']]);
        expect(events[3], ['page', row['page']]);
        expect(events[2], events[4]);
        expect(LoreFieldLogic.goldFoundMessage(row['money']), events[2][2]);
        expect(
          LoreFieldLogic.goldFoundMessage((row['money'] as int) + 0x100000000),
          events[2][2],
        );
        expect(
          LoreFieldLogic.applyGoldFound(row['gold'], row['money']),
          row['afterGold'],
        );
      }
    },
  );
  test('all direct treasure owners share native message and apply reward before acknowledgement', () {
    const sites = <(int, int, int, int)>[
      (9, 10, 24, 5000),
      (9, 12, 26, 5000),
      (9, 15, 25, 5000),
      (9, 16, 23, 5000),
      (9, 18, 27, 5000),
      (11, 20, 30, 5000),
      (11, 18, 36, 5000),
      (11, 35, 32, 5000),
      (11, 33, 36, 5000),
      (11, 35, 14, 5000),
      (11, 14, 16, 5000),
      (11, 37, 12, 5000),
      (14, 6, 6, 1000),
      (14, 18, 10, 2500),
      (14, 6, 44, 400),
      (14, 31, 30, 600),
      (14, 31, 8, 1500),
      (14, 14, 28, 1000),
      (15, 10, 48, 6000),
      (15, 11, 48, 6000),
      (15, 40, 48, 6000),
      (15, 41, 48, 6000),
    ];
    for (final (map, x, y, amount) in sites) {
      final run = LoreSpecialEventDispatcher.resolve(
        action: LoreTileAction.special,
        mapId: map,
        x: x,
        y: y,
        context: const ScriptContext(tileAtPlayer: 0),
        party: const [],
        scripts: LoreScriptEngine(),
      ).script!;
      final native = (fixture['cases'] as List).firstWhere(
        (r) => r['money'] == amount && r['gold'] == 2147483647,
      );
      expect(run.outcome.messages, contains(native['events'][2][2]));
      expect(run.outcome.goldDelta, amount);
      expect(run.hasPendingScene, isFalse);
      expect(run.hasPendingChoice, isFalse);
      expect(run.awaitingBattle, isFalse);
      expect(run.outcome.events.where((e) => e.kind == 'message'), isEmpty);
      final result = ScriptWorldReducer.applyResources(
        const ScriptResources(gold: 2147483647, food: 20),
        run.outcome,
      );
      expect(result.gold, native['afterGold']);
      expect(result.food, 20);
    }
  });
}
