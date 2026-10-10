/// Original embedded EGAVGA driver fill masks (LORESUB.PAS Scroll).
/// Rows use the most significant bit for the leftmost source pixel.
abstract final class LoreBgiFill {
  static const patterns = <List<int>>[
    [0, 0, 0, 0, 0, 0, 0, 0],
    [255, 255, 255, 255, 255, 255, 255, 255],
    [255, 255, 0, 0, 255, 255, 0, 0],
    [1, 2, 4, 8, 16, 32, 64, 128],
    [224, 193, 131, 7, 14, 28, 56, 112],
    [240, 120, 60, 30, 15, 135, 195, 225],
    [165, 210, 105, 180, 90, 45, 150, 75],
    [255, 136, 136, 136, 255, 136, 136, 136],
    [129, 66, 36, 24, 24, 36, 66, 129],
    [204, 51, 204, 51, 204, 51, 204, 51],
    [128, 0, 8, 0, 128, 0, 8, 0],
    [136, 0, 34, 0, 136, 0, 34, 0],
  ];

  static int background(int form, int color, int x, int y) {
    RangeError.checkValidIndex(form, patterns, 'fill form');
    return patterns[form][y & 7] & (128 >> (x & 7)) != 0 ? color : 0;
  }

  /// BGI OrPut combines the four color-index planes, not the RGB channels.
  static int orPixel(int tile, int form, int color, int x, int y) =>
      tile | background(form, color, x, y);
}
