import 'lore_source_memory.dart';

/// Main's #0/ReadKey branch; a modern key event supplies the atomic scan byte.
class LoreMainKey {
  static ({bool ok, int dx, int dy, int face}) extended(
    int scan, {
    required int face,
    required bool town,
    required int mapId,
  }) {
    scan = LorePascal.byte(scan);
    var dx = 0;
    var dy = 0;
    switch (scan) {
      case 72:
        dy = -1;
        face = town ? 1 : 5;
      case 80:
        dy = 1;
        face = town ? 0 : 4;
      case 75:
        dx = -1;
        face = town ? 3 : 7;
      case 77:
        dx = 1;
        face = town ? 2 : 6;
    }
    if (mapId == 26) face += 4;
    return (
      ok: dx != 0 || dy != 0,
      dx: dx,
      dy: dy,
      face: LorePascal.byte(face),
    );
  }
}
