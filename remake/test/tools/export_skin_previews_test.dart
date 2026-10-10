import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/game/sprite_sheet.dart';

/// Generate preview PNGs from the actual renderer, not imagined map artwork.
/// flutter test test/tools/export_skin_previews_test.dart
///   --dart-define=EXPORT_SKIN_PREVIEWS=true
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export actual original and crystal map previews', () async {
    final library = SpriteLibrary.instance;
    await library.load();
    final dir = Directory('build/skin-previews')..createSync(recursive: true);
    LoreDialogueManager.instance.loadFlags({'etc1': 1});
    for (final skin in GraphicsSkin.values) {
      await library.activate(skin);
      for (final font in ['TOWN', 'GROUND', 'DEN', 'KEEP']) {
        final sheet = library.get(font)!;
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        for (var i = 0; i < sheet.count; i++) {
          final x = (i % 8 * 80).toDouble();
          final y = (i ~/ 8 * 100).toDouble();
          sheet.draw(canvas, i, Rect.fromLTWH(x, y, 80, 80));
          final label = TextPainter(
            text: TextSpan(
              text: '$i',
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          label.paint(canvas, Offset(x + 4, y + 80));
          label.dispose();
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(640, 700);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/${skin.id}-$font-slots.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }
      for (final (id, x, y, label) in [
        (6, 51, 31, 'town'),
        (6, 51, 69, 'market'),
        (1, 50, 48, 'field'),
        (11, 30, 30, 'dungeon'),
        (21, 25, 25, 'castle'),
        (4, 50, 50, 'swamp'),
        (5, 25, 25, 'lava'),
      ]) {
        final info = LoreWorldManager.mapRegistry[id]!;
        final game = LoreGame(
          initialMapId: id,
          initialPlayerX: x,
          initialPlayerY: y,
        );
        game.currentMap = await LoreMapData.loadFromAsset(
          info.fileName,
          category: info.category.name,
        );
        game.onGameResize(Vector2(616, 616));
        final recorder = ui.PictureRecorder();
        game.render(ui.Canvas(recorder));
        final picture = recorder.endRecording();
        final image = await picture.toImage(616, 616);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/${skin.id}-$label.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }
    }
    await library.activate(GraphicsSkin.original);
    LoreDialogueManager.instance.loadFlags({});
  }, skip: !const bool.fromEnvironment('EXPORT_SKIN_PREVIEWS'));
}
