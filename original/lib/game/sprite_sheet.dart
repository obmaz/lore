/// Source-indexed PNG atlases, with the original FNT renderer as fallback.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

const int kSpriteSize = 20;

class SpriteSheet {
  final ui.Image image;
  final double tileSize;
  final int count;

  const SpriteSheet({
    required this.image,
    required this.tileSize,
    required this.count,
  });

  Rect? sourceRect(int index) {
    if (index < 0 || index >= count) return null;
    final columns = image.width ~/ tileSize;
    return Rect.fromLTWH(
      (index % columns) * tileSize,
      (index ~/ columns) * tileSize,
      tileSize,
      tileSize,
    );
  }

  void draw(
    Canvas canvas,
    int index,
    Rect destRect, {
    bool opaqueBackground = false,
    Color background = Colors.black,
  }) {
    final source = sourceRect(index);
    if (source == null) return;
    if (opaqueBackground) {
      canvas.drawRect(destRect, Paint()..color = background);
    }
    canvas.drawImageRect(
      image,
      source,
      destRect,
      Paint()..filterQuality = FilterQuality.none,
    );
  }
}

class SpriteLibrary {
  static final SpriteLibrary instance = SpriteLibrary._internal();
  SpriteLibrary._internal();

  static const manifestPath = 'assets/images/manifest.json';
  final Map<String, SpriteSheet> _sheets = {};
  final List<ui.Image> _images = [];
  Future<void>? _loadFuture;
  bool usingImages = false;
  String? loadError;

  bool get hasImages => _sheets.isNotEmpty;
  SpriteSheet? get(String fontName) => _sheets[fontName.toUpperCase()];

  Future<void> load({AssetBundle? bundle}) =>
      _loadFuture ??= _loadOriginal(bundle ?? rootBundle);

  Future<void> _loadOriginal(AssetBundle bundle) async {
    try {
      final manifest = jsonDecode(
        await bundle.loadString(manifestPath),
      ) as Map<String, dynamic>;
      if (manifest['version'] != 1) {
        throw const FormatException('지원하지 않는 원작 PNG 버전');
      }
      final fonts = manifest['fonts'] as Map<String, dynamic>;
      final sheets = <String, SpriteSheet>{};
      for (final entry in fonts.entries) {
        final info = entry.value as Map<String, dynamic>;
        final bytes = await bundle.load('assets/images/${info['file']}');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        late final ui.Image image;
        try {
          image = (await codec.getNextFrame()).image;
          _images.add(image);
        } finally {
          codec.dispose();
        }
        final tileSize = (manifest['tileSize'] as num).toDouble();
        final count = info['count'] as int;
        if (tileSize <= 0 ||
            count <= 0 ||
            image.width % tileSize != 0 ||
            image.height % tileSize != 0 ||
            (image.width ~/ tileSize) * (image.height ~/ tileSize) < count) {
          throw const FormatException('원작 PNG 크기와 타일 배치가 일치하지 않습니다');
        }
        sheets[entry.key.toUpperCase()] = SpriteSheet(
          image: image,
          tileSize: tileSize,
          count: count,
        );
      }
      if (![
        'CHARA',
        'TOWN',
        'GROUND',
        'DEN',
        'KEEP',
      ].every(sheets.containsKey)) {
        throw const FormatException('필수 원작 PNG 타일 시트가 누락되었습니다');
      }
      _sheets.addAll(sheets);
      usingImages = true;
    } catch (error) {
      for (final image in _images) {
        image.dispose();
      }
      _images.clear();
      usingImages = false;
      loadError = error.toString();
    }
  }

  void resetForTest() {
    _loadFuture = null;
    usingImages = false;
    loadError = null;
    _sheets.clear();
    for (final image in _images) {
      image.dispose();
    }
    _images.clear();
  }
}
