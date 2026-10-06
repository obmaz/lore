import 'dart:math';

/// Integer Random/Randomize from the shipped LORE.EXE, not Dart's generator.
/// The x86-16 routine advances RandSeed with 0x08088405 * seed + 1 and returns
/// its high word modulo the Word range. Random(0) still advances the seed.
/// See test/fixtures/dos_random_stream.json for unmodified machine-code runs.
class LoreRandom implements Random {
  int _seed;

  LoreRandom(int seed) : _seed = seed & 0xffffffff;

  /// DOS int 21h/AH=2Ch: CX = hour:minute, DX = second:hundredth.
  /// Randomize stores CX as the low word and DX as the high word.
  factory LoreRandom.fromClock([DateTime? time]) {
    final now = time ?? DateTime.now();
    return LoreRandom(
      ((now.second << 8 | now.millisecond ~/ 10) << 16) |
          (now.hour << 8 | now.minute),
    );
  }

  int get seed => _seed;

  int _advance() {
    // Split the multiplication into 16-bit limbs: a full 32-bit product
    // exceeds JavaScript's exact integer range before truncation.
    final low = _seed & 0xffff;
    final high = _seed ~/ 0x10000;
    final product = low * 0x8405 + 1;
    final upper = (product ~/ 0x10000 + low * 0x0808 + high * 0x8405) & 0xffff;
    return _seed = upper * 0x10000 + (product & 0xffff);
  }

  @override
  int nextInt(int max) {
    RangeError.checkValueInInterval(max, 0, 0xffff, 'Word range');
    final high = _advance() ~/ 0x10000;
    return max == 0 ? 0 : high % max;
  }

  @override
  bool nextBool() => nextInt(2) != 0;

  /// Random interface adapter; gameplay only uses the verified integer form.
  @override
  double nextDouble() => _advance() / 0x100000000;
}
