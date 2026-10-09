import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/bgi_font_decoder.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/sprite_sheet.dart';
import 'package:lore/logic/lore_load_weather.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/logic/lore_bgi_fill.dart';

class _RecordedFont extends BgiFontDecoder {
  _RecordedFont(this.calls) : super(Uint8List(56 * 246));
  final List<List<Object>> calls;
  void tile(int index, Rect rect, int operation) {
    final col = (rect.left / rect.width).round();
    final row = (rect.top / rect.height).round();
    if (col >= 1 && col <= 9 && row >= 1 && row <= 9) {
      calls.add(['put', 'font', col * 20, row * 20, index, operation]);
    }
  }

  @override
  void renderSprite(
    Canvas canvas,
    int index,
    Rect rect, {
    bool opaqueBackground = false,
    Color defaultBg = Colors.black,
  }) => tile(index, rect, 0);
  @override
  void renderOrSprite(
    Canvas canvas,
    int index,
    Rect rect, {
    required int fillForm,
    required int fillColor,
    required int sourceX,
    required int sourceY,
  }) => tile(index, rect, 2);
  @override
  void renderMaskedSprite(
    Canvas canvas,
    int face,
    Rect rect, {
    int Function(int x, int y)? backgroundPixel,
  }) {
    calls.add(['put', 'chara', 100, 100, face + 28, 3]);
    calls.add(['put', 'chara', 100, 100, face, 2]);
  }
}

// LORESUB.PAS Scroll: native9x9 visit order and actual field renderer routes.
// Pixel compositing is checked separately with original CHARA masks below.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = jsonDecode(
    File('test/fixtures/dos_scroll.json').readAsStringSync(),
  );
  setUp(() => SpriteLibrary.instance.resetForTest());
  tearDown(() => LoreDialogueManager.instance.loadFlags({}));
  var index = 0;
  for (final row in data['cases'] as List) {
    test('native Scroll renderer case ${index++}', () {
      final calls = <List<Object>>[];
      final font = _RecordedFont(calls);
      final state = LoreScrollState()
        ..form = 1
        ..color = 8;
      state.restore(LorePartyEtc()..[12] = row['weather']);
      expect([state.form, state.color, state.putStyle], row['style']);
      LoreDialogueManager.instance.loadFlags({'etc1': row['torch']});
      final mapId = switch (row['position']) {
        2 => 11,
        1 => 6,
        _ => 1,
      };
      final game =
          LoreGame(
              initialMapId: mapId,
              initialPlayerX: row['x'],
              initialPlayerY: row['y'],
              sourceScroll: state,
            )
            ..currentMap = LoreMapData(
              name: 'NATIVE',
              xmax: 100,
              ymax: 100,
              grid: List.generate(
                100,
                (y) => List.generate(
                  100,
                  (x) => ((x + 1) * 7 + (y + 1) * 13) % 55 + 1,
                ),
              ),
            )
            ..groundFont = font
            ..townFont = font
            ..denFont = font
            ..charaFont = font
            ..playerDirection = row['direction']
            ..onGameResize(Vector2(220, 220));
      if (!row['character']) game.peekAt(row['x'], row['y']);
      final recorder = ui.PictureRecorder();
      game.render(Canvas(recorder));
      recorder.endRecording().dispose();
      expect(game.playerSpriteIndex, row['face']);
      expect(calls, [
        for (final op in row['trace'])
          if (op[0] == 'put') op,
      ]);
    });
  }
  test(
    'original CHARA AND/OR includes opaque black over all16 backgrounds',
    () async {
      final font = await BgiFontDecoder.loadFromAsset('CHARA');
      for (var face = 0; face < 28; face++) {
        for (var background = 0; background < 16; background++) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 20, 20),
            Paint()
              ..color = background == 0
                  ? Colors.black
                  : BgiFontDecoder.vgaPalette[background],
          );
          font.renderMaskedSprite(
            canvas,
            face,
            const Rect.fromLTWH(0, 0, 20, 20),
            backgroundPixel: (_, _) => background,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(20, 20);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          for (var y = 0; y < 20; y++) {
            for (var x = 0; x < 20; x++) {
              final c =
                  (background & font.decodedSprites[face + 28][y][x]) |
                  font.decodedSprites[face][y][x];
              final color = c == 0
                  ? Colors.black
                  : BgiFontDecoder.vgaPalette[c];
              final offset = (y * 20 + x) * 4;
              expect(
                [
                  bytes.getUint8(offset),
                  bytes.getUint8(offset + 1),
                  bytes.getUint8(offset + 2),
                ],
                [
                  (color.r * 255).round(),
                  (color.g * 255).round(),
                  (color.b * 255).round(),
                ],
                reason: 'face=$face background=$background ($x,$y)',
              );
            }
          }
          image.dispose();
          picture.dispose();
        }
      }
    },
  );
  test(
    'map26 unsupported scans retain partial-mask face13 over source weather',
    () async {
      final chara = await BgiFontDecoder.loadFromAsset('CHARA');
      final font = await BgiFontDecoder.loadFromAsset('KEEP');
      for (final weather in [0, 5]) {
        final scroll = LoreScrollState()
          ..restore(LorePartyEtc()..[12] = weather);
        final game =
            LoreGame(
                initialMapId: 26,
                initialPlayerX: 10,
                initialPlayerY: 10,
                sourceScroll: scroll,
              )
              ..currentMap = LoreMapData(
                name: 'K_DEN2',
                xmax: 20,
                ymax: 20,
                grid: List.generate(20, (_) => List.filled(20, 42)),
              )
              ..groundFont = font
              ..townFont = font
              ..keepFont = font
              ..denFont = font
              ..charaFont = chara
              ..playerDirection = 1
              ..onGameResize(Vector2(220, 220));
        game.handleSourceScanByte(1);
        game.handleSourceScanByte(1);
        expect(game.playerSpriteIndex, 13);
        final recorder = ui.PictureRecorder();
        game.render(Canvas(recorder));
        final picture = recorder.endRecording();
        final image = await picture.toImage(220, 220);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (var y = 0; y < 20; y++) {
          for (var x = 0; x < 20; x++) {
            var background = font.decodedSprites[42][y][x];
            if (weather != 0) {
              final pattern = LoreBgiFill.patterns[scroll.form][(100 + y) & 7];
              if (pattern & (128 >> ((100 + x) & 7)) != 0) {
                background |= scroll.color;
              }
            }
            final result =
                (background & chara.decodedSprites[41][y][x]) |
                chara.decodedSprites[13][y][x];
            final c = result == 0
                ? Colors.black
                : BgiFontDecoder.vgaPalette[result];
            final offset = ((100 + y) * 220 + 100 + x) * 4;
            expect(
              [
                bytes.getUint8(offset),
                bytes.getUint8(offset + 1),
                bytes.getUint8(offset + 2),
              ],
              [(c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round()],
              reason: 'weather=$weather ($x,$y)',
            );
          }
        }
        image.dispose();
        picture.dispose();
      }
    },
  );
}
