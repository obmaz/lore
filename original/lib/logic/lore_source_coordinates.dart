import 'lore_source_memory.dart';

/// LORESUB.PAS at/on. The original EXE compares signed 16-bit arguments,
/// with 16-bit ADD instructions before at's comparisons (not a map clamp).
class LoreSourceCoordinates {
  LoreSourceCoordinates._();

  static bool at(int x, int y, int x1, int y1, int xx, int yy) =>
      LorePascal.integer(x + x1) == LorePascal.integer(xx) &&
      LorePascal.integer(y + y1) == LorePascal.integer(yy);

  static bool on(int x, int y, int xx, int yy) =>
      LorePascal.integer(x) == LorePascal.integer(xx) &&
      LorePascal.integer(y) == LorePascal.integer(yy);
}
