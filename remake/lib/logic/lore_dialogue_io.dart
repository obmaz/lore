import '../data/lore_script.dart';
import 'lore_window_io.dart';

/// Source waits stop their procedure when the owning game screen is disposed.
abstract interface class LoreTalkIo implements LoreWindowIo {
  bool get isOpen;
}

abstract interface class LoreTalkModeIo implements LoreTalkIo {
  void setTile(int x, int y, int tile);
  void refresh();
  void cprint(
    int color,
    int highlight,
    String before,
    String word,
    String after,
  );
  void message(int color, String text);
  Future<void> recruit(LoreScript procedure);
  Future<String> challengeKey();
  Future<void> blinkRemains(int dx, int dy);
}
