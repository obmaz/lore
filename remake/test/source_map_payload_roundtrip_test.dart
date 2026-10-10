import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_game.dart';

// LORESUB.PAS Load 1710/1719 and Save 1787. Expectations use the original
// shipped MAP bytes and explicit Pascal y-outer/x-inner indexing, not port assets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all original map payloads and changed save snapshots retain source order',
    () async {
      final fixture = jsonDecode(
        File('test/fixtures/source_load_facing.json').readAsStringSync(),
      );
      final maps = <int, dynamic>{
        for (final r in fixture['cases']) r['map']: r,
      };
      for (final entry in maps.entries) {
        final raw = File(
          'repo_source/LORE_1993_runtime/${entry.value['name']}.MAP',
        ).readAsBytesSync();
        final width = raw[0], height = raw[1];
        final game = LoreGame();
        await game.loadMapById(entry.key, startX: 1, startY: 1);
        final map = game.currentMap!;
        expect((map.xmax, map.ymax), (width, height));
        final saved = <int>[];
        for (var y = 1; y <= height; y++) {
          for (var x = 1; x <= width; x++) {
            expect(
              map.getTile(x, y),
              raw[2 + (y - 1) * width + x - 1],
              reason: '${entry.key}: $x,$y',
            );
            // Distinct x/y and byte boundaries catch transpose, stride and range bugs.
            final changed = (x * 13 + y * 71 + entry.key) & 255;
            map.setTile(x, y, changed);
            saved.add(changed);
          }
        }
        expect(map.tileSnapshot(), saved);
        await game.loadMapById(
          entry.key,
          startX: width,
          startY: height,
          mapTiles: saved,
        );
        for (var y = 1; y <= height; y++) {
          for (var x = 1; x <= width; x++) {
            expect(
              game.currentMap!.getTile(x, y),
              saved[(y - 1) * width + x - 1],
            );
          }
        }
        final base = await LoreMapData.loadFromAsset(
          entry.value['name'],
          category: entry.value['category'],
        );
        expect(base.tileSnapshot(), raw.sublist(2, 2 + width * height));
      }
    },
  );
}
