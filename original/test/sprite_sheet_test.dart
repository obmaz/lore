import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/sprite_sheet.dart';

class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw Exception('asset not found');
}

/// 이미지 파일(PNG) 기반 스프라이트 렌더링 검증.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SpriteLibrary.instance.resetForTest());
  tearDown(() => SpriteLibrary.instance.resetForTest());

  group('이미지 스프라이트 시트 (assets/images/*.png)', () {
    test('1. 매니페스트와 PNG를 로드한다', () async {
      await SpriteLibrary.instance.load();

      expect(
        SpriteLibrary.instance.usingImages,
        isTrue,
        reason: 'PNG 로드 실패: ${SpriteLibrary.instance.loadError}',
      );

      for (final name in ['CHARA', 'TOWN', 'GROUND', 'DEN', 'KEEP']) {
        final sheet = SpriteLibrary.instance.get(name);
        expect(sheet, isNotNull, reason: '$name 스프라이트 시트');
        expect(sheet!.count, 56, reason: name);
        expect(sheet.tileSize, kSpriteSize, reason: name);
        // 20x20 타일이 56개 이어붙은 가로 스트립
        expect(sheet.image.width, kSpriteSize * 56, reason: name);
        expect(sheet.image.height, kSpriteSize, reason: name);
      }
    });

    test('2. 에셋이 없으면 FNT 폴백 상태가 된다', () async {
      await SpriteLibrary.instance.load(bundle: _MissingBundle());

      expect(SpriteLibrary.instance.usingImages, isFalse);
      expect(SpriteLibrary.instance.hasImages, isFalse);
      expect(SpriteLibrary.instance.loadError, isNotNull);
      // null이면 LoreGame이 기존 FNT 디코더로 그린다
      expect(SpriteLibrary.instance.get('CHARA'), isNull);
    });

    test('3. 범위를 벗어난 인덱스는 그리지 않는다(예외 없음)', () async {
      await SpriteLibrary.instance.load();
      final sheet = SpriteLibrary.instance.get('CHARA')!;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // 유효 범위 밖 인덱스 호출이 예외를 던지지 않아야 한다
      sheet.draw(canvas, -1, ui.Rect.zero);
      sheet.draw(canvas, sheet.count, ui.Rect.zero);
      sheet.draw(canvas, 0, const ui.Rect.fromLTWH(0, 0, 20, 20));
      recorder.endRecording();
    });
  });
}
