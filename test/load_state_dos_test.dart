import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_load_weather.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/services/audio_manager.dart';

/// LORESUB.PAS:1729-1746,1762-1770 Load CASEs, with setscrolltype:284-325.
/// Successful resource/state selection only; DOS errors and BGI pixels excluded.

class _NoLoadRandom implements Random {
  @override
  int nextInt(int max) => throw StateError('Load consumed RNG');
  @override
  bool nextBool() => throw StateError('Load consumed RNG');
  @override
  double nextDouble() => throw StateError('Load consumed RNG');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = jsonDecode(
    File('test/fixtures/dos_load_state.json').readAsStringSync(),
  );
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    void silence(String channel) => messenger.setMockStreamHandler(
      EventChannel(channel),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    silence('xyz.luan/audioplayers.global/events');
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          silence(
            'xyz.luan/audioplayers/events/${(call.arguments as Map)['playerId']}',
          );
        }
        return 1;
      },
    );
  });
  tearDown(() => LoreDialogueManager.instance.loadFlags({}));

  test('Load CASE and setter match native weather stores for all bytes', () {
    expect(native['weather'].length, 1536);
    for (final row in native['weather']) {
      final etc = LorePartyEtc({for (var i = 1; i <= 100; i++) i: i - 1});
      etc[12] = row['raw'];
      final before = Map<int, int>.from(etc);
      final state = LoreScrollState()
        ..form = row['before'][0]
        ..color = row['before'][1]
        ..putStyle = row['before'][2];
      state.restore(etc);
      expect(state.mode.index, row['mode']);
      expect([state.form, state.color, state.putStyle], row['after']);
      expect(etc.read(12), row['etc12']);
      for (final entry in before.entries) {
        if (entry.key != 12) expect(etc.read(entry.key), entry.value);
      }
      state.restore(etc);
      expect([state.form, state.color, state.putStyle], row['after']);
    }
  });

  test(
    'all 27 actual map loads select native font bytes and BGM resources',
    () async {
      var callbacks = 0;
      final game = LoreGame(
        random: _NoLoadRandom(),
        onMapLoaded: () => callbacks++,
      );
      await game
          .onLoad(); // Real asset decoder path, not placeholder font objects.
      final etc = LoreDialogueManager.instance.partyEtc;
      for (var i = 1; i <= 100; i++) {
        etc[i] = i;
      }
      final before = Map<int, int>.from(etc);
      final initialCallbacks = callbacks;
      for (final id in [
        ...List.generate(27, (i) => i + 1),
        ...List.generate(27, (i) => 27 - i),
      ]) {
        final row = native['resources'][id];
        final font = (row['font'] as String).toUpperCase();
        final music = RegExp(r'Music(\d)\.Bgm').firstMatch(row['music'])![1]!;
        final expectedTrack = BgmTrack.values.singleWhere(
          (track) => track.assetPath.startsWith('audio/music${music}_'),
        );
        await game.loadMapById(id, startX: 1, startY: 1);
        expect(game.currentMapId, id);
        expect(game.currentMap!.category, row['font']);
        expect(LoreWorldManager.mapRegistry[id]!.fontName, font);
        expect(game.selectedTileFontName, font);
        expect(game.selectedTileFont, isNotNull);
        expect(
          game.selectedTileFont!.data,
          File('repo_source/LORE_1993_runtime/$font.FNT').readAsBytesSync(),
        );
        expect(AudioManager.instance.currentBgm, expectedTrack);
        expect(etc, before);
        final snapshot = game.currentMap!.tileSnapshot();
        snapshot[0] = 47;
        await game.loadMapById(id, startX: 1, startY: 1, mapTiles: snapshot);
        expect(game.currentMap!.tileSnapshot(), snapshot);
        expect(game.selectedTileFontName, font);
        expect(AudioManager.instance.currentBgm, expectedTrack);
      }
      expect(callbacks - initialCallbacks, 108);
      // These share a MAP file but have distinct original position/resources.
      expect(native['resources'][25]['font'], 'den');
      expect(native['resources'][26]['font'], 'town');
    },
  );
}
