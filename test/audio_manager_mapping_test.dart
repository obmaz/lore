import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/services/audio_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (methodCall) async => 1,
    );
  });

  group('LORE 1993 현대식 오디오 & BGM 매핑 검증', () {
    test('1. 모든 BGM 트랙 파일이 assets/audio/ 에 존재하고 0바이트가 아니다', () {
      for (final track in BgmTrack.values) {
        final file = File('assets/${track.assetPath}');
        expect(file.existsSync(), isTrue, reason: 'BGM 파일 누락: ${track.assetPath}');
        expect(file.lengthSync(), greaterThan(100000), reason: 'BGM 파일 크기 비정상: ${track.assetPath}');
      }
    });

    test('2. 모든 SFX 효과음 파일이 assets/audio/ 에 존재하고 0바이트가 아니다', () {
      for (final sfx in SfxSound.values) {
        final file = File('assets/${sfx.assetPath}');
        expect(file.existsSync(), isTrue, reason: 'SFX 파일 누락: ${sfx.assetPath}');
        expect(file.lengthSync(), greaterThan(1000), reason: 'SFX 파일 크기 비정상: ${sfx.assetPath}');
      }
    });

    test('3. 원작 LORESUB.PAS 1720-1746 기준 27개 전 맵 BGM 트랙 정합성 검증', () {
      // 원작 LORESUB.PAS:
      // case party.map of
      //   1..5 : position := ground; (Music3.Bgm)
      //   6..10,24,26..27 : position := town; (Music2.Bgm)
      //   11..20,25 : position := den; (Music4.Bgm)
      //   else position := keep; (Music5.Bgm)
      for (int mapId = 1; mapId <= 27; mapId++) {
        final info = LoreWorldManager.mapRegistry[mapId];
        expect(info, isNotNull, reason: '맵 $mapId 메타데이터 누락');

        final expectedTrack = switch (mapId) {
          1 || 2 || 3 || 4 || 5 => BgmTrack.ground,
          6 || 7 || 8 || 9 || 10 || 24 || 26 || 27 => BgmTrack.town,
          11 || 12 || 13 || 14 || 15 || 16 || 17 || 18 || 19 || 20 || 25 =>
            BgmTrack.den,
          21 || 22 || 23 => BgmTrack.keep,
          _ => throw StateError('알 수 없는 맵 ID: $mapId'),
        };

        expect(
          info!.bgmTrack,
          equals(expectedTrack),
          reason: '맵 $mapId [${info.title}]의 BGM 트랙이 원작 명세와 다름',
        );
      }
    });

    test('4. AudioManager 볼륨 설정 및 음소거 토글 상태 정합성 검증', () async {
      final audio = AudioManager.instance;

      audio.setBgmVolume(0.8);
      expect(audio.bgmVolume, equals(0.8));

      audio.setBgmVolume(1.5); // 클램핑
      expect(audio.bgmVolume, equals(1.0));

      audio.setSfxVolume(0.5);
      expect(audio.sfxVolume, equals(0.5));

      final initialMute = audio.isMuted;
      await audio.toggleMute();
      expect(audio.isMuted, equals(!initialMute));
      await audio.toggleMute();
      expect(audio.isMuted, equals(initialMute));
    });
  });
}
