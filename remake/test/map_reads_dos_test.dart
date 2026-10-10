import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';

Uint8List _hex(String raw) => Uint8List.fromList([
  for (var i = 0; i < raw.length; i += 2)
    int.parse(raw.substring(i, i + 2), radix: 16),
]);

/// LORESUB.PAS:1712 Load: default/saved typed reads, fixed Pascal array stride.
/// Invalid map geometry raises FormatException rather than empty/unsafe DOS writes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = jsonDecode(
    File('test/fixtures/dos_map_reads.json').readAsStringSync(),
  );
  final rows = fixture['cases'] as List;
  test('all native map reads and synthetic rectangle/full-byte grids match runtime parser', () {
    expect(rows, hasLength(74));
    for (final row in rows) {
      final payload = _hex(row['payloadHex']);
      final w = row['width'] as int, h = row['height'] as int;
      expect(row['readCount'], 2 + w * h);
      expect(row['firstTargets'].take(2), [0x53d96, 0x53d97]);
      if (row['valid'] != true) {
        expect(
          () => LoreMapData.fromBytes(row['name'], payload),
          throwsFormatException,
        );
        if (w == 101) {
          expect(row['afterGuardChanged'], isTrue);
        }
        continue;
      }
      expect(row['afterGuardChanged'], isFalse);
      expect(row['lastTarget'], 0x53d43 + w * 100 + h);
      expect(row['finalIndices'], [w, h]);
      final native = _hex(row['nativeTilesHex']);
      final map = LoreMapData.fromBytes(row['name'], payload, category: 'den');
      expect(map.tileSnapshot(), native);
      for (var y = 1; y <= h; y++) {
        for (var x = 1; x <= w; x++) {
          expect(map.getTile(x, y), native[(y - 1) * w + x - 1]);
        }
      }
      final restored = map.tileSnapshot();
      map.setTile(1, 1, 255);
      map.applyTileSnapshot(restored);
      expect(map.tileSnapshot(), native);
    }
  });
  test('all 27 actual asset owners match original typed reads in their map category', () async {
    for (final entry in LoreWorldManager.mapRegistry.entries) {
      final info = entry.value;
      final row = rows.singleWhere(
        (r) => r['branch'] == 'defaultMap' && r['name'] == info.fileName,
      );
      final map = await LoreMapData.loadFromAsset(
        info.fileName,
        category: info.category.name,
      );
      expect((map.xmax, map.ymax), (row['width'], row['height']));
      expect(
        map.tileSnapshot(),
        _hex(row['nativeTilesHex']),
        reason: 'map ${entry.key}',
      );
      expect(map.category, info.category.name);
    }
  });
}
