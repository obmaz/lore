/// 이미지 파일(PNG) 기반 스프라이트 렌더링 지원.
///
/// 원작 `.FNT`(BGI 4-plane) 픽셀을 미리 PNG 스프라이트 시트로 내보내 두고,
/// 게임은 이미지가 있으면 그것을 그리고, 없으면 기존 FNT 디코더로 폴백한다.
///
/// 이미지 생성:
/// ```sh
/// flutter test test/tools/export_images_test.dart --dart-define=EXPORT_IMAGES=true
/// ```
/// 산출물: `assets/images/<font>.png` (20x20 타일 가로 스트립) + `manifest.json`
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// 타일 1장 크기(원작 FNT와 동일).
const int kSpriteSize = 20;

/// 폰트 1종의 스프라이트 시트.
class SpriteSheet {
  final ui.Image image;
  final int tileSize;
  final int count;

  const SpriteSheet({
    required this.image,
    required this.tileSize,
    required this.count,
  });

  /// [index]번 스프라이트를 [destRect]에 그린다.
  void draw(
    Canvas canvas,
    int index,
    Rect destRect, {
    bool opaqueBackground = false,
    Color background = Colors.black,
  }) {
    if (index < 0 || index >= count) return;
    if (opaqueBackground) {
      canvas.drawRect(destRect, Paint()..color = background);
    }
    final src = Rect.fromLTWH(
      (index * tileSize).toDouble(),
      0,
      tileSize.toDouble(),
      tileSize.toDouble(),
    );
    canvas.drawImageRect(
      image,
      src,
      destRect,
      Paint()..filterQuality = FilterQuality.none,
    );
  }
}

/// 게임 전체에서 사용하는 스프라이트 시트 모음.
class SpriteLibrary {
  static final SpriteLibrary instance = SpriteLibrary._internal();
  SpriteLibrary._internal();

  final Map<String, SpriteSheet> _sheets = {};
  bool _loaded = false;
  bool usingImages = false;
  String? loadError;

  /// 이미지 스프라이트를 사용 중인지(디버그/테스트용).
  bool get hasImages => _sheets.isNotEmpty;

  SpriteSheet? get(String fontName) => _sheets[fontName.toUpperCase()];

  /// `assets/images/manifest.json`과 각 PNG를 읽는다. 실패하면 FNT 폴백.
  Future<void> load({AssetBundle? bundle}) async {
    if (_loaded) return;
    final b = bundle ?? rootBundle;
    try {
      final manifest = json.decode(
        await b.loadString('assets/images/manifest.json'),
      ) as Map<String, dynamic>;
      final tileSize = manifest['tileSize'] as int? ?? kSpriteSize;
      final fonts = manifest['fonts'] as Map<String, dynamic>;
      for (final entry in fonts.entries) {
        final info = entry.value as Map<String, dynamic>;
        final bytes = await b.load('assets/images/${info['file']}');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        _sheets[entry.key.toUpperCase()] = SpriteSheet(
          image: frame.image,
          tileSize: tileSize,
          count: info['count'] as int? ?? 0,
        );
      }
      usingImages = _sheets.isNotEmpty;
    } catch (e) {
      _sheets.clear();
      usingImages = false;
      loadError = e.toString();
    }
    _loaded = true;
  }

  void resetForTest() {
    _loaded = false;
    usingImages = false;
    loadError = null;
    _sheets.clear();
  }
}
