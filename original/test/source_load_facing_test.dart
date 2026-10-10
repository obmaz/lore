import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_world_manager.dart';

/// LORESUB.PAS:1677-1759, LOREMAIN.PAS:169-184. Expected faces come from
/// original Pascal map classes and MAP headers, independently of the registry.
class NoLoadRandom implements Random {
  @override
  int nextInt(int max) => throw StateError('Load must not consume RNG');
  @override
  bool nextBool() => throw StateError('Load must not consume RNG');
  @override
  double nextDouble() => throw StateError('Load must not consume RNG');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test(
    'all 27 map loads reset face at the original midpoint boundary',
    () async {
      final fixture = jsonDecode(
        File('test/fixtures/source_load_facing.json').readAsStringSync(),
      );
      final game = LoreGame(random: NoLoadRandom());
      for (final item in fixture['cases']) {
        game.playerDirection = 3;
        await game.loadMapById(item['map'], startX: 1, startY: item['y']);
        expect(game.currentMap!.name, item['name']);
        expect(game.currentMap!.category, item['category']);
        expect(game.currentMap!.ymax, item['height']);
        expect(
          game.playerSpriteIndex,
          item['face'],
          reason: 'map ${item['map']} y=${item['y']}',
        );
        final snapshot = game.currentMap!.tileSnapshot();
        snapshot[0] = 47;
        game.playerDirection = 2;
        await game.loadMapById(
          item['map'],
          startX: 1,
          startY: item['y'],
          mapTiles: snapshot,
        );
        expect(game.currentMap!.tileSnapshot(), snapshot);
        expect(
          game.playerSpriteIndex,
          item['face'],
          reason: 'restored map ${item['map']}',
        );
      }
    },
  );

  test(
    'every map uses original position class after all four arrows',
    () async {
      final fixture = jsonDecode(
        File('test/fixtures/source_load_facing.json').readAsStringSync(),
      );
      for (var id = 1; id <= 27; id++) {
        final item = fixture['cases'].firstWhere(
          (dynamic item) => item['map'] == id,
        );
        final game = LoreGame();
        await game.loadMapById(id, startX: 5, startY: 5);
        for (final (dx, dy, direction) in [
          (0, 1, 0),
          (0, -1, 1),
          (1, 0, 2),
          (-1, 0, 3),
        ]) {
          // Block movement so only the source arrow-facing assignment executes.
          game.currentMap!.setTile(5 + dx, 5 + dy, 16);
          game.tryMove(dx, dy);
          final bank = item['category'] == 'town' ? 0 : 4;
          expect(
            game.playerSpriteIndex,
            direction + bank + (id == 26 ? 4 : 0),
            reason: 'map $id arrow ($dx,$dy)',
          );
        }
        expect(LoreWorldManager.mapRegistry[id]!.fileName, item['name']);
      }
    },
  );
}
