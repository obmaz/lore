import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/bgi_font_decoder.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_bgi_fill.dart';
import 'package:lore/logic/lore_load_weather.dart';
import 'package:lore/logic/lore_source_memory.dart';

// LORESUB.PAS setscrolltype:284-325 / Scroll:230-234, native EGAVGA masks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fills = jsonDecode(
    File('test/fixtures/dos_fill_patterns.json').readAsStringSync(),
  );
  final load = jsonDecode(
    File('test/fixtures/dos_load_state.json').readAsStringSync(),
  );
  test('all native patterns and source weather selectors agree', () {
    expect(LoreBgiFill.patterns, fills['patterns']);
    for (final row in load['weather']) {
      final etc = LorePartyEtc()..[12] = row['raw'];
      final state = LoreScrollState()
        ..form = row['before'][0]
        ..color = row['before'][1]
        ..putStyle = row['before'][2];
      state.restore(etc);
      expect([state.form, state.color, state.putStyle], row['after']);
      expect(etc.read(12), row['etc12']);
    }
  });
  test(
    'actual Canvas OR output follows native pattern rows at every pixel',
    () async {
      final font = await BgiFontDecoder.loadFromAsset('GROUND');
      for (final form in [1, 3, 6, 9]) {
        for (final color in [1, 6]) {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          font.renderOrSprite(
            canvas,
            42,
            const ui.Rect.fromLTWH(0, 0, 20, 20),
            fillForm: form,
            fillColor: color,
            sourceX: 40,
            sourceY: 60,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(20, 20);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          for (var y = 0; y < 20; y++) {
            for (var x = 0; x < 20; x++) {
              final int mask = fills['patterns'][form][(60 + y) & 7];
              final background = mask & (128 >> ((40 + x) & 7)) != 0
                  ? color
                  : 0;
              final index = font.decodedSprites[42][y][x] | background;
              final c = index == 0
                  ? const ui.Color(0xff000000)
                  : BgiFontDecoder.vgaPalette[index];
              final offset = (y * 20 + x) * 4;
              expect(
                [
                  bytes.getUint8(offset),
                  bytes.getUint8(offset + 1),
                  bytes.getUint8(offset + 2),
                  bytes.getUint8(offset + 3),
                ],
                [
                  (c.r * 255).round(),
                  (c.g * 255).round(),
                  (c.b * 255).round(),
                  255,
                ],
              );
            }
          }
          image.dispose();
          picture.dispose();
        }
      }
    },
  );

  test('actual field renderer applies all six restored selectors', () async {
    final font = await BgiFontDecoder.loadFromAsset('TOWN');
    for (var selector = 0; selector <= 5; selector++) {
      final state = LoreScrollState()..restore(LorePartyEtc()..[12] = selector);
      final game =
          LoreGame(initialPlayerX: 6, initialPlayerY: 6, sourceScroll: state)
        ..currentMapId = 6
            ..townFont = font
            ..currentMap = LoreMapData(
              name: 'TEST',
              xmax: 20,
              ymax: 20,
              grid: List.generate(20, (_) => List.filled(20, 42)),
            )
            ..peekAt(6, 6)
            ..onGameResize(Vector2(220, 220));
      final recorder = ui.PictureRecorder();
      game.render(ui.Canvas(recorder));
      final picture = recorder.endRecording();
      final image = await picture.toImage(220, 220);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      // The inner nine tiles are the original Scroll's 180x180 map area.
      for (var y = 20; y < 200; y++) {
        for (var x = 20; x < 200; x++) {
          final tile = font.decodedSprites[42][y % 20][x % 20];
          final int mask = selector == 0
              ? 0
              : fills['patterns'][state.form][y & 7];
          final index = tile | (mask & (128 >> (x & 7)) != 0 ? state.color : 0);
          final c = index == 0
              ? const ui.Color(0xff000000)
              : BgiFontDecoder.vgaPalette[index];
          final offset = (y * 220 + x) * 4;
          expect(
            [
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            ],
            [(c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round()],
            reason: 'selector$selector ($x,$y)',
          );
        }
      }
      image.dispose();
      picture.dispose();
    }
  });
}
