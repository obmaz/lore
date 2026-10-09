import 'dart:async';

import 'package:flutter/services.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
// The plugin exports its interface but not its MethodChannel implementation.
// Subclass it in this test-only adapter to retain existing channel observers.
// ignore: implementation_imports
import 'package:audioplayers_platform_interface/src/audioplayers_platform.dart';

/// The existing audio-channel stubs never send onPrepared. ByteSource waits
/// for this event, so source CRT tones need a prepared/completed device model.
void installSourceAudioPlatform() {
  if (AudioplayersPlatformInterface.instance is SourceAudioPlatform) return;
  AudioplayersPlatformInterface.instance = SourceAudioPlatform();
}

class SourceAudioPlatform extends AudioplayersPlatform {
  final _events = <String, StreamController<AudioEvent>>{};
  final _bytePlayers = <String>{};
  final sourceBytes = <Uint8List>[];
  @override
  Stream<AudioEvent> getEventStream(String playerId) => _events
      .putIfAbsent(playerId, () => StreamController<AudioEvent>.broadcast())
      .stream;
  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) async {
    await super.setSourceBytes(playerId, bytes, mimeType: mimeType);
    sourceBytes.add(Uint8List.fromList(bytes));
    _bytePlayers.add(playerId);
    _events[playerId]!.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> resume(String playerId) async {
    await super.resume(playerId);
    if (_bytePlayers.contains(playerId)) {
      // Complete after AudioPlayer's resume continuation, without fake timers.
      scheduleMicrotask(
        () => scheduleMicrotask(
          () => _events[playerId]!.add(
            const AudioEvent(eventType: AudioEventType.complete),
          ),
        ),
      );
    }
  }
}
