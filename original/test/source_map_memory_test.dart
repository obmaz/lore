import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';

class SlicedMapBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final buffer = Uint8List.fromList([
      99,
      99,
      3,
      2,
      9,
      0,
      52,
      128,
      54,
      255,
      99,
    ]);
    return ByteData.sublistView(buffer, 2, 10);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'rectangular MAP bytes preserve Pascal map[x,y] without transposition',
    () {
      final map = LoreMapData.fromBytes(
        'TEST',
        Uint8List.fromList([3, 2, 9, 0, 52, 128, 54, 255]),
        category: 'den',
      );
      expect((map.xmax, map.ymax), (3, 2));
      expect(map.getTile(3, 1), 52);
      expect(map.getTile(1, 2), 128);
      map.setTile(2, 1, 54);
      expect(map.grid, [
        [9, 54, 52],
        [128, 54, 255],
      ]);
      expect(map.tileSnapshot(), [9, 54, 52, 128, 54, 255]);
      map.applyTileSnapshot([41, 42, 43, 44, 45, 46]);
      expect(map.getTile(3, 2), 46);
      expect(map.getTile(3, 1), 43);
      expect(() => map.setTile(0, 1, 45), throwsRangeError);
    },
  );

  test('asset loader honors ByteData view offset and length', () async {
    final binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      return SlicedMapBundle().load('TEST.MAP');
    });
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
      rootBundle.evict('assets/maps/SLICE_TEST.MAP');
    });
    final map = await LoreMapData.loadFromAsset('SLICE_TEST', category: 'den');
    expect(map.tileSnapshot(), [9, 0, 52, 128, 54, 255]);
  });

  test('malformed MAP data fails instead of creating gameplay walls', () {
    for (final bytes in [
      <int>[],
      [3],
      [0, 1],
      [101, 1],
      [2, 3, 44],
    ]) {
      expect(
        () => LoreMapData.fromBytes('BAD', Uint8List.fromList(bytes)),
        throwsFormatException,
      );
    }
  });

  test('all 27 map identities retain their source tile snapshots', () async {
    for (final entry in LoreWorldManager.mapRegistry.entries) {
      final info = entry.value;
      final bytes = await rootBundle.load('assets/maps/${info.fileName}.MAP');
      final map = await LoreMapData.loadFromAsset(
        info.fileName,
        category: info.category.name,
      );
      final payload = bytes.buffer.asUint8List(
        bytes.offsetInBytes + 2,
        map.xmax * map.ymax,
      );
      expect(map.tileSnapshot(), payload, reason: 'map ${entry.key}');
      expect(map.getTile(map.xmax, map.ymax), payload.last);
    }
  });
}
