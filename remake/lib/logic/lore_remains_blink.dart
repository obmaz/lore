import 'lore_source_memory.dart';

class LoreRemainsFrame {
  const LoreRemainsFrame(this.waitMilliseconds, this.x, this.y, this.tile);
  final int waitMilliseconds;
  final int x;
  final int y;
  final int tile;
}

/// LORETALK.PAS:827 et al: Delay, font48, Delay, font35, thirty times.
/// Coordinates are source pixels; the modern renderer scales these separately.
abstract final class LoreRemainsBlink {
  static Iterable<LoreRemainsFrame> frames(int dx, int dy) sync* {
    final x = LorePascal.integer(100 + 20 * dx);
    final y = LorePascal.integer(100 + 20 * dy);
    for (var k = 1; k <= 30; k++) {
      yield LoreRemainsFrame(k * 2, x, y, 48);
      yield LoreRemainsFrame((31 - k) * 2, x, y, 35);
    }
  }
}
