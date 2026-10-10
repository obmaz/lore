/// The text window the original draws into (`Clear`, `Print`, `PressAnyKey`,
/// `Select`), as the procedures use it. Pixel positions (`hany`, `yinit`) are
/// layout: lines stack from the top and a select is listed below them.
library;

abstract interface class LoreWindowIo {
  /// `Clear`.
  void clear();

  /// `Print(color, text)` / `SetColor(c); HPrintXY(..)` text line.
  void print(int color, String text);

  /// `PressAnyKey`: the prompt, a key (or tap), then `Clear`.
  Future<void> pressAnyKey();

  /// `Select(yinit, maxsum, total, clean, TRUE)` — 1-based, 0 = Esc. [title]
  /// is `m[0]` (color 12), [maxsum] defaults to all items; the window is
  /// cleared first when [clean] and always afterwards (`lastclean`).
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  });
}
