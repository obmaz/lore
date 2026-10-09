/// LORECRET.PAS Display/First/Third: source RGB stores and Delay durations.
class LoreCreationPaletteFrame {
  const LoreCreationPaletteFrame(this.milliseconds, this.colors);
  final int milliseconds;
  final List<(int, int, int, int)> colors;
}

abstract final class LoreCreationPalette {
  static List<LoreCreationPaletteFrame> get displayBorder => [
    for (var i = 0; i <= 63; i++)
      LoreCreationPaletteFrame(20, [(9, i, 0, 32 - i ~/ 2)]),
    for (var i = 0; i <= 63; i++)
      LoreCreationPaletteFrame(20, [(9, 63 - i, 0, i)]),
  ];

  static List<LoreCreationPaletteFrame> get displayTitle => [
    for (var i = 0; i <= 31; i++)
      LoreCreationPaletteFrame(80, [
        (5, i, 0, 31),
        (13, i * 2, 0, 31 + i),
        (11, 0, i * 2, 31 + i),
        (1, 0, i ~/ 3, 31 - i ~/ 3),
      ]),
  ];

  static List<LoreCreationPaletteFrame> get display => [
    ...displayBorder,
    const LoreCreationPaletteFrame(0, [
      (5, 0, 0, 31),
      (13, 0, 0, 31),
      (11, 0, 0, 31),
    ]),
    ...displayTitle,
  ];

  static List<LoreCreationPaletteFrame> get divider => [
    for (var i = 23; i <= 63; i++)
      LoreCreationPaletteFrame(20, [(8, 40, 10 - (i - 23) ~/ 4, i)]),
    for (var i = 23; i <= 63; i++)
      LoreCreationPaletteFrame(20, [(8, 63 - i, 0, 63)]),
  ];
}

/// Third checks endpoints before advancing, and resets on each invalid reply.
class LoreCreationClassPulse {
  int value = 31;
  int direction = 1;
  int next() {
    if (value == 40) direction = -1;
    if (value == 20) direction = 1;
    return value += direction;
  }
}

class LoreCreationConfirmationPulse {
  int value = 15;
  int next() {
    value++;
    if (value > 63) value = 15;
    return value;
  }
}
