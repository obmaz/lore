import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 1993년 Borland Pascal BGI 4-plane 16-color 폰트/스프라이트(.FNT) 디코더
class BgiFontDecoder {
  static const int spriteBytes = 246;
  static const int width = 20;
  static const int height = 20;

  // DOS VGA 16-Color Standard Palette (ARGB)
  static const List<Color> vgaPalette = [
    Colors.transparent, // 0: Black (스프라이트에서는 배경 투명 처리)
    Color(0xFF0000AA), // 1: Blue (원작 머리색/어두운 톤)
    Color(0xFF00AA00), // 2: Green
    Color(0xFF00AAAA), // 3: Cyan
    Color(0xFFAA0000), // 4: Red
    Color(0xFFAA00AA), // 5: Magenta
    Color(0xFFAA5500), // 6: Brown (피부/살구색 톤)
    Color(0xFFAAAAAA), // 7: Light Gray
    Color(0xFF555555), // 8: Dark Gray (바지/쇠사슬)
    Color(0xFF5555FF), // 9: Light Blue
    Color(0xFF55FF55), // 10: Light Green
    Color(0xFF55FFFF), // 11: Light Cyan
    Color(0xFFFF5555), // 12: Light Red (갑옷 하이라이트)
    Color(0xFFFF55FF), // 13: Light Magenta
    Color(0xFFFFFF55), // 14: Yellow
    Color(0xFFFFFFFF), // 15: White
  ];

  final Uint8List data;
  final int totalSprites;

  // [spriteIndex][y][x] = color index (0..15)
  late final List<List<List<int>>> decodedSprites;

  BgiFontDecoder(this.data) : totalSprites = data.length ~/ spriteBytes {
    decodedSprites = List.generate(totalSprites, (idx) => _decodeSprite(idx));
  }

  List<List<int>> _decodeSprite(int spriteIdx) {
    final offset = spriteIdx * spriteBytes;
    final grid = List.generate(height, (_) => List.filled(width, 0));

    if (offset + spriteBytes > data.length) return grid;

    for (int y = 0; y < height; y++) {
      final rowOffset = offset + 4 + y * 12;
      for (int x = 0; x < width; x++) {
        final byteIdx = x ~/ 8;
        final bit = 7 - (x % 8);

        final p0 = data[rowOffset + byteIdx];
        final p1 = data[rowOffset + 3 + byteIdx];
        final p2 = data[rowOffset + 6 + byteIdx];
        final p3 = data[rowOffset + 9 + byteIdx];

        final c0 = (p0 >> bit) & 1;
        final c1 = (p1 >> bit) & 1;
        final c2 = (p2 >> bit) & 1;
        final c3 = (p3 >> bit) & 1;

        // BGI GetImage stores each scanline in high-to-low color planes.
        // Independently checked against LORE.EXE in DOSBox (tile 42).
        final colorIndex = (c0 << 3) | (c1 << 2) | (c2 << 1) | c3;
        grid[y][x] = colorIndex;
      }
    }
    return grid;
  }

  /// Canvas에 특정 스프라이트 픽셀 렌더링
  void renderSprite(
    Canvas canvas,
    int spriteIndex,
    Rect destRect, {
    bool opaqueBackground = false,
    Color defaultBg = Colors.black,
  }) {
    if (spriteIndex < 0 || spriteIndex >= totalSprites) return;

    final grid = decodedSprites[spriteIndex];
    final pixelW = destRect.width / width;
    final pixelH = destRect.height / height;

    if (opaqueBackground) {
      final bgPaint = Paint()..color = defaultBg;
      canvas.drawRect(destRect, bgPaint);
    }

    final paint = Paint()..style = PaintingStyle.fill;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final colorIdx = grid[y][x];
        if (colorIdx == 0) continue; // 투명 픽셀 통과

        paint.color = vgaPalette[colorIdx];
        canvas.drawRect(
          Rect.fromLTWH(
            destRect.left + x * pixelW,
            destRect.top + y * pixelH,
            pixelW + 0.3, // 틈새 방지
            pixelH + 0.3,
          ),
          paint,
        );
      }
    }
  }

  /// Asset에서 폰트 파일 로드
  static Future<BgiFontDecoder> loadFromAsset(String fontName) async {
    final assetPath = 'assets/fonts/$fontName.FNT';
    final byteData = await rootBundle.load(assetPath);
    return BgiFontDecoder(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    );
  }
}
