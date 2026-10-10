import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/bgi_font_decoder.dart';
import 'package:lore/game/sprite_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('BGI planes have weights 8,4,2,1 rather than 1,2,4,8', () {
    final bytes = Uint8List(BgiFontDecoder.spriteBytes);
    for (var plane = 0; plane < 4; plane++) {
      bytes[4 + plane * 3] = 1 << (7 - plane);
    }
    final pixels = BgiFontDecoder(bytes).decodedSprites.single;
    expect(pixels.first.take(4), [8, 4, 2, 1]);
  });

  test(
    'original DOS tile pixels agree with FNT and shipped PNG, all 400 pixels',
    () async {
      final fixture = jsonDecode(
        File('test/fixtures/dos_town_tile42.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final expected = (fixture['colors'] as List)
          .map((row) => (row as List).cast<int>())
          .toList();
      final font = await BgiFontDecoder.loadFromAsset('TOWN');
      expect(font.decodedSprites[42], expected);
      SpriteLibrary.instance.resetForTest();
      addTearDown(() => SpriteLibrary.instance.resetForTest());
      await SpriteLibrary.instance.load();
      final sheet = SpriteLibrary.instance.get('TOWN')!;
      final rgba = (await sheet.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 20; x++) {
          final offset = (y * sheet.image.width + 42 * 20 + x) * 4;
          final color = BgiFontDecoder.vgaPalette[expected[y][x]];
          expect(
            [
              rgba.getUint8(offset),
              rgba.getUint8(offset + 1),
              rgba.getUint8(offset + 2),
              rgba.getUint8(offset + 3),
            ],
            [
              (color.r * 255).round(),
              (color.g * 255).round(),
              (color.b * 255).round(),
              255,
            ],
            reason: 'DOS tile42 ($x,$y)',
          );
        }
      }
    },
  );
}
