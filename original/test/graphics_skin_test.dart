import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/game/sprite_sheet.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/services/graphics_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BrokenSkinBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final text = await rootBundle.loadString(key);
    if (!key.contains('/crystal/')) return text;
    final manifest = jsonDecode(text) as Map<String, dynamic>;
    manifest['fonts']['TOWN']['tiles'][1] = 999;
    return jsonEncode(manifest);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sprites = SpriteLibrary.instance;
  setUp(() {
    sprites.resetForTest();
    SharedPreferences.setMockInitialValues({});
    LoreDialogueManager.instance.loadFlags({'etc1': 1, 'etc45': 193});
  });
  tearDown(() {
    sprites.resetForTest();
    LoreDialogueManager.instance.loadFlags({});
  });

  Future<Uint8List> render(LoreGame game) async {
    final recorder = ui.PictureRecorder();
    game.render(ui.Canvas(recorder));
    final picture = recorder.endRecording();
    final image = await picture.toImage(308, 308);
    final bytes = await image.toByteData();
    final result = Uint8List.fromList(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
    return result;
  }

  test(
    'crystal atlas keeps source slots and transparent directional heroes',
    () async {
      await sprites.activate(GraphicsSkin.crystal);
      for (final name in ['CHARA', 'TOWN', 'GROUND', 'DEN', 'KEEP']) {
        final sheet = sprites.get(name)!;
        expect(sheet.count, 56);
        for (var i = 0; i < sheet.count; i++) {
          final rect = sheet.sourceRect(i);
          if (rect == null) {
            expect(sheet.fallback?.sourceRect(i), isNotNull);
          } else {
            expect(rect.right, lessThanOrEqualTo(sheet.image.width));
            expect(rect.bottom, lessThanOrEqualTo(sheet.image.height));
          }
        }
      }
      final hero = sprites.get('CHARA')!;
      expect({for (var i = 0; i < 8; i++) hero.sourceRect(i)}.length, 8);
      expect(
        hero.sourceRect(8),
        isNull,
        reason: 'Original composite cutscene pieces retain their PNG frames',
      );
      final pixels = (await hero.image.toByteData())!;
      expect(
        pixels.getUint8(3),
        0,
        reason: 'Hero sheet has real alpha, no black box',
      );
    },
  );

  test(
    'invalid mapping fails atomically and preserves the current PNG skin',
    () async {
      await sprites.load();
      final original = sprites.get('TOWN');
      await expectLater(
        sprites.activate(GraphicsSkin.crystal, bundle: _BrokenSkinBundle()),
        throwsFormatException,
      );
      expect(sprites.activeSkin, GraphicsSkin.original);
      expect(sprites.get('TOWN'), same(original));
      await sprites.activate(GraphicsSkin.crystal);
      expect(sprites.activeSkin, GraphicsSkin.crystal);
    },
  );

  test('small-map walls, paths and hazards stay visually distinguishable', () async {
    await sprites.activate(GraphicsSkin.crystal);
    Future<List<double>> averageColor(String font, int slot) async {
      final recorder = ui.PictureRecorder();
      sprites
          .get(font)!
          .draw(
            ui.Canvas(recorder),
            slot,
            const Rect.fromLTWH(0, 0, 28, 28),
            opaqueBackground: true,
          );
      final picture = recorder.endRecording();
      final image = await picture.toImage(28, 28);
      final data = (await image.toByteData())!;
      final mean = List<double>.filled(3, 0);
      for (var i = 0; i < data.lengthInBytes; i += 4) {
        for (var c = 0; c < 3; c++) {
          mean[c] += data.getUint8(i + c) / (28 * 28);
        }
      }
      image.dispose();
      picture.dispose();
      return mean;
    }

    double brightness(List<double> color) =>
        color[0] * 0.2126 + color[1] * 0.7152 + color[2] * 0.0722;
    for (final (font, wall, floor) in [
      ('TOWN', 7, 44),
      ('DEN', 1, 44),
      ('KEEP', 29, 46),
    ]) {
      expect(
        brightness(await averageColor(font, floor)) -
            brightness(await averageColor(font, wall)),
        greaterThan(25),
        reason:
            '$font: walking paths must be lighter than their solid walls at 28px',
      );
    }
    for (final font in ['TOWN', 'GROUND', 'DEN', 'KEEP']) {
      final hazards = font == 'TOWN' ? [24, 25, 26] : [48, 49, 50];
      final colors = [
        for (final slot in hazards) await averageColor(font, slot),
      ];
      for (var a = 0; a < colors.length; a++) {
        for (var b = a + 1; b < colors.length; b++) {
          final difference = [
            for (var c = 0; c < 3; c++) (colors[a][c] - colors[b][c]).abs(),
          ].reduce((x, y) => x + y);
          expect(
            difference,
            greaterThan(100),
            reason: '$font: water, marsh and lava need distinct color families',
          );
        }
      }
    }
  });

  test(
    'all 27 maps keep tiles, classification, face, flags and RNG across skins',
    () async {
      await sprites.load();
      final flags = LoreDialogueManager.instance.getSaveFlags();
      for (final info in LoreWorldManager.mapRegistry.values) {
        final random = LoreRandom(0x12345678);
        final game = LoreGame(
          initialMapId: info.mapId,
          initialPlayerX: 25,
          initialPlayerY: 25,
          random: random,
        );
        game.currentMap = await LoreMapData.loadFromAsset(
          info.fileName,
          category: info.category.name,
        );
        game.onGameResize(Vector2(308, 308));
        final map = game.currentMap!;
        final tiles = map.tileSnapshot();
        final categories = [for (var t = 0; t < 256; t++) map.actionForTile(t)];
        final face = game.playerSpriteIndex;
        for (final skin in GraphicsSkin.values) {
          await sprites.activate(skin);
          await render(game);
          expect(game.currentMap, same(map));
          expect(map.tileSnapshot(), tiles, reason: 'map ${info.mapId}');
          expect([
            for (var t = 0; t < 256; t++) map.actionForTile(t),
          ], categories);
          expect((game.playerX, game.playerY), (25, 25));
          expect(game.playerSpriteIndex, face);
          expect(random.seed, 0x12345678);
          expect(LoreDialogueManager.instance.getSaveFlags(), flags);
        }
      }
    },
  );

  test(
    'darkness and see-through remain source-controlled in both skins',
    () async {
      await sprites.load();
      final game = LoreGame(
        initialMapId: 11,
        initialPlayerX: 6,
        initialPlayerY: 6,
      );
      game.currentMap = LoreMapData(
        name: 'T_DEN1',
        category: 'den',
        xmax: 20,
        ymax: 20,
        grid: List.generate(20, (_) => List.filled(20, 0)),
      );
      game.onGameResize(Vector2(308, 308));
      game.peekAt(6, 6); // No hero drawn, so darkness is directly comparable.
      LoreDialogueManager.instance.partyEtc[1] = 0;
      final originalDark = await render(game);
      await sprites.activate(GraphicsSkin.crystal);
      expect(await render(game), originalDark);
      LoreDialogueManager.instance.partyEtc[1] = 1;
      game.seeThroughSpecial = true;
      for (final skin in GraphicsSkin.values) {
        await sprites.activate(skin);
        final pixels = await render(game);
        for (var i = 0; i < pixels.length; i += 4) {
          expect(pixels.sublist(i, i + 4), [0, 0, 0, 255]);
        }
      }
    },
  );

  test(
    'graphics preferences survive restart without writing any game save',
    () async {
      const originalSave = '{"party":"unchanged"}';
      SharedPreferences.setMockInitialValues({
        'lore_save_slot_1': originalSave,
      });
      final settings = GraphicsSettings();
      await settings.select(GraphicsSkin.crystal);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lore_save_slot_1'), originalSave);
      expect(prefs.getKeys(), {
        'lore_save_slot_1',
        GraphicsSettings.preferenceKey,
      });
      await sprites.activate(GraphicsSkin.original);
      await GraphicsSettings().restore();
      expect(sprites.activeSkin, GraphicsSkin.crystal);
      expect(prefs.getString('lore_save_slot_1'), originalSave);
      settings.dispose();
    },
  );
}
