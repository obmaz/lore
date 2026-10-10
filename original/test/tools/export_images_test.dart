import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/bgi_font_decoder.dart';

import '../../tool/png_encoder.dart';

/// 원작 `.FNT` 픽셀 데이터를 PNG 스프라이트 시트로 내보내는 도구.
///
/// ```sh
/// flutter test test/tools/export_images_test.dart --dart-define=EXPORT_IMAGES=true
/// ```
///
/// 산출물:
/// - `assets/images/chara.png`  (CHARA.FNT - 캐릭터, 배경 투명)
/// - `assets/images/town.png` / `ground.png` / `den.png` / `keep.png` (타일)
/// - `assets/images/manifest.json`
void main() {
  const enabled = bool.fromEnvironment('EXPORT_IMAGES');

  test('FNT 스프라이트를 assets/images/*.png 로 내보낸다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory('assets/images')..createSync(recursive: true);

    // (폰트, 파일명, 배경 불투명 여부)
    const fonts = <(String, String, bool)>[
      ('CHARA', 'chara.png', false),
      ('TOWN', 'town.png', true),
      ('GROUND', 'ground.png', true),
      ('DEN', 'den.png', true),
      ('KEEP', 'keep.png', true),
    ];

    final manifest = <String, dynamic>{
      'version': 1,
      'tileSize': BgiFontDecoder.width,
      'source': '원작 CHARA.FNT / TOWN.FNT / GROUND.FNT / DEN.FNT / KEEP.FNT',
      'fonts': <String, dynamic>{},
    };

    for (final (font, fileName, opaque) in fonts) {
      final decoder = await BgiFontDecoder.loadFromAsset(font);
      final count = decoder.totalSprites;
      final w = BgiFontDecoder.width;
      final h = BgiFontDecoder.height;

      final rgba = Uint8List(w * count * h * 4);
      for (var s = 0; s < count; s++) {
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final colorIdx = decoder.decodedSprites[s][y][x];
            final Color color = BgiFontDecoder.vgaPalette[colorIdx];
            final px = s * w + x;
            final off = (y * (w * count) + px) * 4;
            final isBg = colorIdx == 0;
            rgba[off] = (color.r * 255).round();
            rgba[off + 1] = (color.g * 255).round();
            rgba[off + 2] = (color.b * 255).round();
            rgba[off + 3] = (isBg && opaque) ? 255 : (color.a * 255).round();
          }
        }
      }

      final png = encodePng(width: w * count, height: h, rgba: rgba);
      File('${dir.path}/$fileName').writeAsBytesSync(png);
      (manifest['fonts'] as Map<String, dynamic>)[font] = {
        'file': fileName,
        'count': count,
      };
      // ignore: avoid_print
      print('wrote ${dir.path}/$fileName (${png.length} bytes, $count tiles)');
    }

    File(
      '${dir.path}/manifest.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));

    expect(File('${dir.path}/chara.png').existsSync(), isTrue);
    expect(File('${dir.path}/manifest.json').existsSync(), isTrue);
  }, skip: !enabled);
}
