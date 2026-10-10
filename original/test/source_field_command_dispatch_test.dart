import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/field_hotkeys.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';

// LOREMAIN.PAS Main ASCII UpCase/arrow gates and LOREMENU.PAS SelectMode.
void main() {
  final actions = <String, FieldAction>{
    'ViewParty': FieldAction.viewParty,
    'ViewCharacter': FieldAction.viewCharacter,
    'QuickView': FieldAction.quickView,
    'CastSpell': FieldAction.castSpell,
    'Extrasense': FieldAction.extrasense,
    'Rest': FieldAction.rest,
    'GameOption': FieldAction.gameOption,
  };
  test('all input bytes and Select results match independently parsed Pascal CASEs', () {
    final main = String.fromCharCodes(
      File('repo_source/LORE_1993_src/LOREMAIN.PAS').readAsBytesSync(),
    );
    final body = main.substring(
      main.indexOf('case upcase(c) of'),
      main.indexOf('if c = #0 then'),
    );
    final keys = {
      for (final m in RegExp(r"'([A-Z])' : (\w+);").allMatches(body))
        m[1]!.codeUnitAt(0): actions[m[2]]!,
    };
    expect(keys.length, 7);
    final menu = String.fromCharCodes(
      File('repo_source/LORE_1993_src/LOREMENU.PAS').readAsBytesSync(),
    );
    final select = menu.substring(menu.lastIndexOf('case k of'));
    final cases = {
      for (final m in RegExp(r'(\d+) : (\w+);').allMatches(select))
        int.parse(m[1]!): actions[m[2]] ?? FieldAction.none,
    };
    expect(cases.length, 8);
    for (var byte = 0; byte < 256; byte++) {
      final upper = byte >= 97 && byte <= 122 ? byte - 32 : byte;
      final logical = byte == 8
          ? LogicalKeyboardKey.backspace
          : LogicalKeyboardKey(byte >= 65 && byte <= 90 ? byte + 32 : byte);
      expect(
        FieldHotkeys.resolve(logical),
        byte == 32
            ? FieldAction.openMenu
            : byte == 8
            ? FieldAction.toggleSound
            : keys[upper] ?? FieldAction.none,
        reason: 'ASCII $byte',
      );
      expect(
        FieldHotkeys.fromSelect(byte),
        cases[byte] ?? FieldAction.none,
        reason: 'Select $byte',
      );
    }
  });
  test(
    'every scan byte changes geometry only for the four source arrow codes',
    () {
      final keys = {
        72: LogicalKeyboardKey.arrowUp,
        80: LogicalKeyboardKey.arrowDown,
        75: LogicalKeyboardKey.arrowLeft,
        77: LogicalKeyboardKey.arrowRight,
      };
      for (var scan = 0; scan < 256; scan++) {
        final game = LoreGame()
          ..currentMap = LoreMapData(
            name: 'TEST',
            category: 'town',
            xmax: 20,
            ymax: 20,
            grid: List.generate(20, (_) => List.filled(20, 42)),
          )
          ..playerX = 10
          ..playerY = 10;
        game.handleKeyEvent(
          KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.arrowUp,
            logicalKey: keys[scan] ?? LogicalKeyboardKey(0x200000000 + scan),
            timeStamp: Duration.zero,
          ),
        );
        final delta = switch (scan) {
          72 => (0, -1),
          80 => (0, 1),
          75 => (-1, 0),
          77 => (1, 0),
          _ => (0, 0),
        };
        expect((game.playerX, game.playerY), (10 + delta.$1, 10 + delta.$2));
      }
    },
  );
}
