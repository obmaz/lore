import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LoreGame mapGame(double side) {
    final game = LoreGame(initialPlayerX: 6, initialPlayerY: 6);
    game.currentMap = LoreMapData(
      name: 'TEST',
      xmax: 20,
      ymax: 20,
      grid: List.generate(20, (_) => List.filled(20, 42)),
    );
    game.onGameResize(Vector2(side, side));
    return game;
  }

  for (final side in [240, 390, 768]) {
    test(
      '11x11 map fills every edge at ${side}px without changing tiles',
      () async {
        final game = mapGame(side.toDouble());
        final tiles = game.currentMap!.tileSnapshot();
        final recorder = ui.PictureRecorder();
        game.render(ui.Canvas(recorder));
        final picture = recorder.endRecording();
        final image = await picture.toImage(side, side);
        final pixels = (await image.toByteData())!;
        for (final point in [
          (0, 0),
          (side - 1, 0),
          (0, side - 1),
          (side - 1, side - 1),
        ]) {
          expect(pixels.getUint8((point.$2 * side + point.$1) * 4 + 3), 255);
        }
        expect(game.currentMap!.tileSnapshot(), tiles);
        expect((game.playerX, game.playerY), (6, 6));
        image.dispose();
        picture.dispose();
      },
    );
  }

  test('cutscene early returns restore the scaled canvas', () {
    final game = mapGame(390);
    for (final mode in ['entry', 'descent', 'peek']) {
      game.chamberEntryFrame = mode == 'entry' ? (0, 0) : null;
      game.chamberDescentRow = mode == 'descent' ? 0 : null;
      game.peekX = mode == 'peek' ? 8 : null;
      game.peekY = mode == 'peek' ? 8 : null;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final saves = canvas.getSaveCount();
      game.render(canvas);
      expect(canvas.getSaveCount(), saves);
      recorder.endRecording().dispose();
    }
  });
}
