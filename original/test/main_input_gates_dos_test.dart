import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flame/components.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_main_key.dart';

// LOREMAIN.PAS:146/162/192. Supported atomic arrow events only: DOS polling,
// unsupported extended-key face writes and Tab DAC conversion remain separate.
void main() {
  final data = jsonDecode(
    File('test/fixtures/dos_main_input_gates.json').readAsStringSync(),
  );
  test('all native scan bytes and positions preserve ok/deltas/face', () {
    for (final row in data['scans'] as List) {
      final expected = row['result'];
      final actual = LoreMainKey.extended(
        row['scan'],
        face: 3,
        town: row['position'] == 0,
        mapId: row['mapId'],
      );
      expect(
        (actual.ok, actual.dx, actual.dy, actual.face),
        (expected['ok'], expected['dx'], expected['dy'], expected['face']),
      );
    }
    for (final row in data['faceWraps'] as List) {
      final actual = LoreMainKey.extended(
        row['scan'],
        face: row['face'],
        town: true,
        mapId: 26,
      );
      expect(actual.face, row['result']['face']);
    }
  });
  test(
    'undeclared CHARA index fails when rendered rather than reading DOS memory',
    () {
      final game = LoreGame()
        ..currentMapId = 26
        ..currentMap = LoreMapData(
          name: 'INPUT',
          category: 'town',
          xmax: 20,
          ymax: 20,
          grid: List.generate(20, (_) => List.filled(20, 42)),
        )
        ..playerX = 10
        ..playerY = 10
        ..playerDirection = 3;
      for (var i = 0; i < 13; i++) {
        game.handleSourceScanByte(71);
      }
      expect(game.playerSpriteIndex, 59);
      game.onGameResize(Vector2(400, 400));
      final recorder = PictureRecorder();
      expect(() => game.render(Canvas(recorder)), throwsRangeError);
      recorder.endRecording().dispose();
    },
  );
  test(
    'map26 unsupported extended events change face without dispatch or RNG',
    () {
      var steps = 0;
      final game =
          LoreGame(
              onStepTaken: () {
                steps++;
                return false;
              },
            )
            ..currentMapId = 26
            ..currentMap = LoreMapData(
              name: 'INPUT',
              category: 'town',
              xmax: 20,
              ymax: 20,
              grid: List.generate(20, (_) => List.filled(20, 42)),
            )
            ..playerX = 10
            ..playerY = 10
            ..playerDirection = 3;
      expect(game.playerSpriteIndex, 7);
      game.handleKeyEvent(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.home,
          logicalKey: LogicalKeyboardKey.home,
          timeStamp: Duration.zero,
        ),
      );
      expect(game.playerSpriteIndex, 11);
      expect((game.playerX, game.playerY, steps), (10, 10, 0));
      game.handleSourceScanByte(79);
      expect(game.playerSpriteIndex, 15);
      game.handleSourceScanByte(72);
      expect((game.playerX, game.playerY, game.playerSpriteIndex), (10, 9, 5));
      game.applySourceFace(4);
      expect(game.playerSpriteIndex, 4);
      game.playerDirection = 2;
      expect(game.playerSpriteIndex, 6);
    },
  );
  test('actual map1/map26 arrow adapter matches original deltas and faces', () {
    final keys = {
      72: LogicalKeyboardKey.arrowUp,
      75: LogicalKeyboardKey.arrowLeft,
      77: LogicalKeyboardKey.arrowRight,
      80: LogicalKeyboardKey.arrowDown,
    };
    for (final row in data['scans'] as List) {
      if (!keys.containsKey(row['scan']) ||
          row['position'] != (row['mapId'] == 26 ? 0 : 1)) {
        continue;
      }
      final category = row['mapId'] == 26 ? 'town' : 'ground';
      final game = LoreGame()
        ..currentMapId = row['mapId']
        ..currentMap = LoreMapData(
          name: 'INPUT',
          category: category,
          xmax: 20,
          ymax: 20,
          grid: List.generate(20, (_) => List.filled(20, 42)),
        )
        ..playerX = 10
        ..playerY = 10;
      game.handleKeyEvent(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowUp,
          logicalKey: keys[row['scan']]!,
          timeStamp: Duration.zero,
        ),
      );
      expect(
        (game.playerX - 10, game.playerY - 10),
        (row['result']['dx'], row['result']['dy']),
      );
      expect(game.playerSpriteIndex, row['result']['face']);
    }
  });
  test('idle modifier delivery changes no field state', () {
    final game = LoreGame()
      ..playerX = 10
      ..playerY = 11
      ..playerDirection = 3;
    for (final key in [
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.altLeft,
    ]) {
      game.handleKeyEvent(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.shiftLeft,
          logicalKey: key,
          timeStamp: Duration.zero,
        ),
      );
      expect((game.playerX, game.playerY, game.playerDirection), (10, 11, 3));
    }
    expect(data['polls'][0]['result']['events'], ['poll']);
  });
}
