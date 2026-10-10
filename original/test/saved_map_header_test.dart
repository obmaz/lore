import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_load_failure.dart';
import 'package:lore/services/save_manager.dart';

/// LORESUB.PAS:1675: a valid cold SaveN.map owns its header and tile payload.
/// Unknown map IDs and unsafe geometry remain explicit faults, not DOS memory.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = jsonDecode(
    File('test/fixtures/dos_load_phases.json').readAsStringSync(),
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
  List<int> tiles(Map record) => [
    for (var i = 0; i < (record['tilesHex'] as String).length; i += 2)
      int.parse(record['tilesHex'].substring(i, i + 2), radix: 16),
  ];
  test('all 27 cold saved maps load without any canonical map read', () async {
    for (final row in (native['cases'] as List).where(
      (r) => !r['warm'] && r['saved'],
    )) {
      final record = native['mapRecords'][row['mapRecord']] as Map;
      var baseReads = 0;
      final game = LoreGame(
        mapLoader: (name, {required category}) async {
          baseReads++;
          throw StateError('canonical MAP absent');
        },
      );
      await game.loadMapById(
        row['mapId'],
        mapTiles: tiles(record),
        mapWidth: record['width'],
        mapHeight: record['height'],
        snapshotName: 'save1.map',
      );
      expect(baseReads, 0);
      expect(game.currentMap!.tileSnapshot(), tiles(record));
      await expectLater(
        game.loadMapById(row['mapId']),
        throwsA(
          isA<LoreLoadFailure>().having(
            (e) => e.fileName,
            'fileName',
            '${row['mapName'].toLowerCase()}.map',
          ),
        ),
      );
      expect(baseReads, 1);
    }
  });
  test('snapshot header owns rectangular dimensions and ignores trailing bytes like native reads', () {
    final map = LoreMapData.fromSnapshot(
      'DEN1',
      width: 2,
      height: 3,
      tiles: [27, 28, 29, 30, 31, 32, 255],
      category: 'den',
    );
    expect((map.xmax, map.ymax), (2, 3));
    expect(map.tileSnapshot(), [27, 28, 29, 30, 31, 32]);
    for (final shape in [
      (null, 3),
      (2, null),
      (0, 3),
      (101, 3),
      (2, 0),
      (2, 101),
    ]) {
      expect(
        () => LoreMapData.fromSnapshot(
          'DEN1',
          width: shape.$1,
          height: shape.$2,
          tiles: [27, 28, 29, 30, 31, 32],
        ),
        throwsFormatException,
      );
    }
    expect(
      () => LoreMapData.fromSnapshot('DEN1', width: 2, height: 3, tiles: [27]),
      throwsFormatException,
    );
  });
  test(
    'invalid snapshot faults before base read and prevents continuation',
    () async {
      for (final shape in [
        (null, 3),
        (2, null),
        (0, 3),
        (101, 3),
        (2, 0),
        (2, 101),
        (2, 3),
      ]) {
        var reads = 0;
        final game = LoreGame(
          mapLoader: (name, {required category}) async {
            reads++;
            throw StateError('base must not repair an invalid snapshot');
          },
        );
        await expectLater(
          game.loadMapById(
            14,
            mapWidth: shape.$1,
            mapHeight: shape.$2,
            mapTiles: [27],
            snapshotName: 'save1.map',
          ),
          throwsA(
            isA<LoreLoadFailure>().having(
              (e) => e.fileName,
              'snapshot file',
              'save1.map',
            ),
          ),
        );
        expect(reads, 0);
        expect(game.currentMap, isNull);
        await expectLater(
          game.loadMapById(14),
          throwsA(isA<LoreLoadFailure>()),
        );
        expect(reads, 0);
        expect(game.tryMove(1, 0), isFalse);
      }
    },
  );
  test('v3 persists header while v2 and older snapshots remain headerless', () {
    final raw = {
      'schemaVersion': 3,
      'party': [],
      'flags': <String, dynamic>{},
      'mapWidth': 2,
      'mapHeight': 3,
      'mapTiles': [27, 28, 29, 30, 31, 32],
    };
    final saved = SaveData.fromJson(raw);
    final restored = SaveData.fromJson(jsonDecode(jsonEncode(saved.toJson())));
    expect((restored.mapWidth, restored.mapHeight), (2, 3));
    expect(restored.mapTiles, raw['mapTiles']);
    for (final version in [null, 1, 2]) {
      final old = Map<String, dynamic>.from(raw)
        ..['schemaVersion'] = version
        ..remove('mapWidth')
        ..remove('mapHeight');
      final legacy = SaveData.fromJson(old);
      expect(legacy.mapWidth, isNull);
      expect(legacy.mapHeight, isNull);
      expect(legacy.mapTiles, raw['mapTiles']);
      expect(legacy.toJson()['schemaVersion'], 3);
    }
  });
}
