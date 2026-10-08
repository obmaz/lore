import 'lore_source_memory.dart';

/// LORESUB Load's weather CASE and setscrolltype's etc[12] writes.
/// This restores the saved selector, not the original BGI compositor.
abstract final class LoreLoadWeather {
  static void normalize(LorePartyEtc etc) {
    final weather = etc.read(12);
    if (weather < 1 || weather > 5) etc[12] = 0;
  }
}

enum LoreScrollMode { normal, snow, rain, autumn, wilderness, strongrain }

/// Source numeric scroll state. Modern map drawing remains a separate adapter.
class LoreScrollState {
  LoreScrollMode mode = LoreScrollMode.normal;
  int form = 0;
  int color = 0;
  int putStyle = 0;

  void restore(LorePartyEtc etc) {
    LoreLoadWeather.normalize(etc);
    mode = LoreScrollMode.values[etc.read(12)];
    if (mode == LoreScrollMode.normal) {
      putStyle = 0; // CopyPut; normal does not clear scrollform/scrollcolor.
      return;
    }
    putStyle = 2; // OrPut.
    final pattern = switch (mode) {
      LoreScrollMode.snow => (1, 1),
      LoreScrollMode.rain => (3, 1),
      LoreScrollMode.autumn => (1, 6),
      LoreScrollMode.wilderness => (9, 1),
      LoreScrollMode.strongrain => (6, 1),
      LoreScrollMode.normal => throw StateError('normal handled above'),
    };
    form = pattern.$1;
    color = pattern.$2;
  }
}
