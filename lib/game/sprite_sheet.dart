/// PNG presentation assets. Source font slots remain the rendering API;
/// a skin maps those slots onto its atlas without touching the game map.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

const int kSpriteSize = 20;

enum GraphicsSkin {
  original(
    'original',
    '원작 그래픽',
    '1993년의 색감과 픽셀 아트',
    'assets/images/manifest.json',
    'assets/images/skins/original-preview.png',
  ),
  crystal(
    'crystal',
    '크리스털 판타지',
    '푸른 크리스털과 빛나는 성채의 새로운 모험',
    'assets/images/skins/crystal/manifest.json',
    'assets/images/skins/crystal/preview.png',
  );

  const GraphicsSkin(
    this.id,
    this.label,
    this.description,
    this.manifestPath,
    this.previewPath,
  );
  final String id, label, description, manifestPath, previewPath;
}

class SpriteOverlay {
  const SpriteOverlay(this.sheet, this.index);
  final SpriteSheet sheet;
  final int index;
}

/// Source-indexed PNG atlas. Optional layers and fallback slots preserve the
/// original ending's mask pieces. All mappings are presentation data only.
class SpriteSheet {
  final ui.Image image;
  final double tileSize;
  final int count;
  final int? columns;
  final List<int>? indices;
  final Map<int, SpriteOverlay> overlays;
  final SpriteSheet? fallback;
  final FilterQuality filterQuality;

  const SpriteSheet({
    required this.image,
    required this.tileSize,
    required this.count,
    this.columns,
    this.indices,
    this.overlays = const {},
    this.fallback,
    this.filterQuality = FilterQuality.none,
  });

  Rect? sourceRect(int index) {
    if (index < 0 || index >= count) return null;
    final slot = indices?[index] ?? index;
    if (slot < 0) return null;
    final cols = columns ?? image.width ~/ tileSize;
    return Rect.fromLTWH(
      (slot % cols * tileSize).toDouble(),
      (slot ~/ cols * tileSize).toDouble(),
      tileSize.toDouble(),
      tileSize.toDouble(),
    );
  }

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
    final src = sourceRect(index);
    if (src == null) {
      fallback?.draw(canvas, index, destRect);
    } else {
      canvas.drawImageRect(
        image,
        src,
        destRect,
        Paint()..filterQuality = filterQuality,
      );
    }
    final overlay = overlays[index];
    overlay?.sheet.draw(canvas, overlay.index, destRect);
  }
}

class SpriteLibrary extends ChangeNotifier {
  static final SpriteLibrary instance = SpriteLibrary._internal();
  SpriteLibrary._internal();

  final Map<GraphicsSkin, Map<String, SpriteSheet>> _skins = {};
  final Map<String, ui.Image> _images = {};
  Future<void>? _loadFuture;
  GraphicsSkin _activeSkin = GraphicsSkin.original;
  bool usingImages = false;
  String? loadError;

  GraphicsSkin get activeSkin => _activeSkin;
  bool get hasImages => _skins[GraphicsSkin.original]?.isNotEmpty ?? false;

  SpriteSheet? get(String fontName) =>
      _skins[_activeSkin]?[fontName.toUpperCase()] ??
      _skins[GraphicsSkin.original]?[fontName.toUpperCase()];

  Future<void> load({AssetBundle? bundle}) =>
      _loadFuture ??= _loadOriginal(bundle ?? rootBundle);

  Future<void> _loadOriginal(AssetBundle bundle) async {
    try {
      _skins[GraphicsSkin.original] = await _readSkin(
        GraphicsSkin.original,
        bundle,
      );
      usingImages = hasImages;
    } catch (e) {
      usingImages = false;
      loadError = e.toString();
    }
  }

  /// Load and validate everything before publishing the skin. A failed load
  /// leaves the rendered skin intact. No map reload or source game calls.
  Future<void> activate(GraphicsSkin skin, {AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    await load(bundle: assets);
    if (skin == _activeSkin) return;
    if (!_skins.containsKey(skin)) {
      _skins[skin] = await _readSkin(skin, assets);
    }
    _activeSkin = skin;
    notifyListeners();
  }

  Future<ui.Image> _readImage(String path, AssetBundle bundle) async {
    if (_images[path] case final image?) return image;
    final bytes = await bundle.load(path);
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    try {
      final image = (await codec.getNextFrame()).image;
      _images[path] = image;
      return image;
    } finally {
      codec.dispose();
    }
  }

  Future<Map<String, SpriteSheet>> _readSkin(
    GraphicsSkin skin,
    AssetBundle bundle,
  ) async {
    final manifest = jsonDecode(
      await bundle.loadString(skin.manifestPath),
    ) as Map<String, dynamic>;
    final version = manifest['version'];
    if (version != 1 && version != 2) {
      throw const FormatException('지원하지 않는 PNG 스킨 버전');
    }
    final directory = skin.manifestPath.substring(
      0,
      skin.manifestPath.lastIndexOf('/') + 1,
    );
    final fonts = manifest['fonts'] as Map<String, dynamic>;
    final sheets = <String, SpriteSheet>{};
    Future<SpriteSheet> readAtlas(Map<String, dynamic> info) async {
      final image = await _readImage('$directory${info['file']}', bundle);
      final columns = info['columns'] as int?;
      final tileSize =
          (info['tileSize'] as num? ??
                  manifest['tileSize'] as num? ??
                  kSpriteSize)
              .toDouble();
      final count = info['count'] as int;
      final indices = (info['tiles'] as List<dynamic>?)?.cast<int>();
      if (tileSize <= 0 || count <= 0) {
        throw const FormatException('PNG 타일 크기와 슬롯 수가 잘못되었습니다');
      }
      final cols = columns ?? image.width ~/ tileSize;
      if (cols <= 0 ||
          image.width % tileSize != 0 ||
          image.height % tileSize != 0 ||
          cols * tileSize != image.width ||
          (indices != null && indices.length != count)) {
        throw const FormatException('PNG 크기와 타일 배치가 일치하지 않습니다');
      }
      final capacity = cols * (image.height ~/ tileSize);
      if ((indices ?? List.generate(count, (i) => i)).any(
        (slot) => slot < -1 || slot >= capacity,
      )) {
        throw const FormatException('PNG 스킨의 타일 번호가 범위를 벗어났습니다');
      }
      return SpriteSheet(
        image: image,
        tileSize: tileSize,
        count: count,
        columns: cols,
        indices: indices,
        filterQuality: version == 2 ? FilterQuality.low : FilterQuality.none,
      );
    }

    final overlayInfo = manifest['overlayAtlas'] as Map<String, dynamic>?;
    final overlayAtlas = overlayInfo == null
        ? null
        : await readAtlas(overlayInfo);
    for (final entry in fonts.entries) {
      final name = entry.key.toUpperCase();
      final info = entry.value as Map<String, dynamic>;
      final atlas = await readAtlas(info);
      final fallback = _skins[GraphicsSkin.original]?[name];
      if (skin != GraphicsSkin.original &&
          (fallback == null || atlas.count != fallback.count)) {
        throw FormatException('$name: 원작 슬롯 수와 일치하지 않습니다');
      }
      final overlays = <int, SpriteOverlay>{};
      for (final item
          in (info['overlays'] as Map<String, dynamic>? ?? {}).entries) {
        final sourceSlot = int.parse(item.key);
        final overlaySlot = item.value as int;
        if (overlayAtlas == null ||
            sourceSlot < 0 ||
            sourceSlot >= atlas.count ||
            overlaySlot < 0 ||
            overlaySlot >= overlayAtlas.count) {
          throw const FormatException('PNG 스킨의 겹침 타일이 잘못되었습니다');
        }
        overlays[sourceSlot] = SpriteOverlay(overlayAtlas, overlaySlot);
      }
      sheets[name] = SpriteSheet(
        image: atlas.image,
        tileSize: atlas.tileSize,
        count: atlas.count,
        columns: atlas.columns,
        indices: atlas.indices,
        overlays: overlays,
        fallback: fallback,
        filterQuality: atlas.filterQuality,
      );
    }
    if (!['CHARA', 'TOWN', 'GROUND', 'DEN', 'KEEP'].every(sheets.containsKey)) {
      throw const FormatException('필수 PNG 타일 시트가 누락되었습니다');
    }
    return sheets;
  }

  void resetForTest() {
    _loadFuture = null;
    usingImages = false;
    loadError = null;
    _activeSkin = GraphicsSkin.original;
    _skins.clear();
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}
