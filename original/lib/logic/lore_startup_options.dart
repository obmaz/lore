/// LORE.PAS / LOREHELP.PAS use only ParamStr(1), with exact source spellings.
/// Later arguments are ignored and options are not combined.
enum LoreStartupMode { title, creation, game, help }

class LoreStartupOptions {
  const LoreStartupOptions({
    this.mode = LoreStartupMode.title,
    this.musicEnabled = true,
  });
  final LoreStartupMode mode;
  final bool musicEnabled;
  factory LoreStartupOptions.parse(List<String> arguments) {
    final first = arguments.isEmpty ? '' : arguments.first;
    return switch (first) {
      '/m' || '/M' => const LoreStartupOptions(musicEnabled: false),
      '/g' || '/G' => const LoreStartupOptions(mode: LoreStartupMode.game),
      '/c' || '/C' => const LoreStartupOptions(mode: LoreStartupMode.creation),
      '/?' ||
      '-?' ||
      '?' => const LoreStartupOptions(mode: LoreStartupMode.help),
      _ => const LoreStartupOptions(),
    };
  }
}
