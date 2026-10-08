import 'lore_source_memory.dart';

/// LORESUB Load's weather CASE and setscrolltype's etc[12] writes.
/// This restores the saved selector, not the original BGI compositor.
abstract final class LoreLoadWeather {
  static void normalize(LorePartyEtc etc) {
    final weather = etc.read(12);
    if (weather < 1 || weather > 5) etc[12] = 0;
  }
}
