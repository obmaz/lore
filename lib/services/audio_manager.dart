import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum BgmTrack {
  title('audio/music1_title.mp3'),
  town('audio/music2_town.mp3'),
  ground('audio/music3_ground.mp3'),
  den('audio/music4_den.mp3'),
  keep('audio/music5_keep.mp3');

  final String assetPath;
  const BgmTrack(this.assetPath);
}

enum SfxSound {
  hit('audio/hit.wav'),
  scream1('audio/scream1.wav'),
  scream2('audio/scream2.wav');

  final String assetPath;
  const SfxSound(this.assetPath);
}

class AudioManager {
  static final AudioManager instance = AudioManager._internal();

  factory AudioManager() => instance;

  AudioManager._internal() {
    _init();
  }

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  BgmTrack? _currentBgm;
  bool _isMuted = false;

  /// Source SoundOn: temporary voice/beep suppression, independent of BGM.
  bool sourceSoundEnabled = true;
  double _bgmVolume = 0.6;
  double _sfxVolume = 1.0;

  bool get isMuted => _isMuted;
  BgmTrack? get currentBgm => _currentBgm;
  double get bgmVolume => _bgmVolume;
  double get sfxVolume => _sfxVolume;

  void setBgmVolume(double volume) {
    _bgmVolume = volume.clamp(0.0, 1.0);
    _bgmPlayer.setVolume(_bgmVolume);
  }

  void setSfxVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
    _sfxPlayer.setVolume(_sfxVolume);
  }

  void _init() {
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
  }

  /// BGM 재생 (동일 곡이면 이어 재생)
  Future<void> playBgm(BgmTrack track) async {
    if (_currentBgm == track && _bgmPlayer.state == PlayerState.playing) {
      return;
    }
    _currentBgm = track;
    if (_isMuted) return;

    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setVolume(_bgmVolume);
      await _bgmPlayer.play(AssetSource(track.assetPath));
      debugPrint('[AudioManager] Playing BGM: ${track.name}');
    } catch (e) {
      debugPrint('[AudioManager] Error playing BGM: $e');
    }
  }

  /// BGM 정지
  Future<void> stopBgm() async {
    _currentBgm = null;
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      debugPrint('[AudioManager] Error stopping BGM: $e');
    }
  }

  /// 효과음 단발 재생
  Future<void> playSfx(SfxSound sound) async {
    if (_isMuted || !sourceSoundEnabled) return;
    try {
      // 짧은 효과음 중첩 재생 지원을 위해 새 플레이어 또는 기존 플레이어 정지 후 재생
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(_sfxVolume);
      await _sfxPlayer.play(AssetSource(sound.assetPath));
    } catch (e) {
      debugPrint('[AudioManager] Error playing SFX: $e');
    }
  }

  /// 편의 메서드: 타격음
  void playHit() => playSfx(SfxSound.hit);

  /// 편의 메서드: 비명음 1 (적 또는 아군 피격)
  void playScream1() => playSfx(SfxSound.scream1);

  /// 편의 메서드: 비명음 2 (적 또는 아군 쓰러짐)
  void playScream2() => playSfx(SfxSound.scream2);

  /// 사운드 음소거 토글
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    if (_isMuted) {
      await _bgmPlayer.pause();
    } else {
      if (_currentBgm != null) {
        await _bgmPlayer.resume();
      }
    }
  }

  /// 리소스 해제
  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
  }
}
