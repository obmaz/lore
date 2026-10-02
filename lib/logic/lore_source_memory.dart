import 'dart:collection';
import 'dart:typed_data';

/// Storage conversions are separate from expression evaluation. Do not mask
/// every intermediate calculation: Pascal promotes operands before assignment.
class LorePascal {
  LorePascal._();

  static int byte(int value) => value & 0xff;
  static int word(int value) => value & 0xffff;
  static int integer(int value) => ((value + 0x8000) & 0xffff) - 0x8000;
  static int longint(int value) =>
      ((value + 0x80000000) & 0xffffffff) - 0x80000000;

  /// Turbo Pascal `div` truncates toward zero; `mod` keeps the dividend's sign.
  static int div(int dividend, int divisor) => dividend ~/ divisor;
  static int mod(int dividend, int divisor) =>
      dividend - div(dividend, divisor) * divisor;

  /// LORESUB.PAS:82-84: bit1 = 1 ... bit8 = 128.
  static int bit(int number) {
    RangeError.checkValueInInterval(number, 1, 8, 'bit');
    return 1 << (number - 1);
  }
}

/// `LORESUB.PAS:40-47`: party.etc[1..100] of byte.
///
/// The Map interface keeps existing save/flag adapters usable. Missing entries
/// read as null through Map, or zero through [read], and explicit zero writes
/// remain present so old Boolean aliases cannot override the source value.
/// Writes retain the low byte (unchecked byte storage); invalid indices fail
/// instead of emulating DOS memory corruption. Compiler overflow behavior for
/// other fields must be audited before applying the conversions above.
class LorePartyEtc extends MapBase<int, int> {
  static const int lengthInBytes = 100;
  final Map<int, int> _values = {};

  LorePartyEtc([Map<int, int> values = const {}]) {
    addAll(values);
  }

  factory LorePartyEtc.fromBytes(List<int> bytes) {
    if (bytes.length != lengthInBytes) {
      throw FormatException('LORE party.etc requires exactly 100 bytes');
    }
    return LorePartyEtc({
      for (var index = 1; index <= lengthInBytes; index++)
        index: bytes[index - 1],
    });
  }

  static void checkIndex(int index) =>
      RangeError.checkValueInInterval(index, 1, lengthInBytes, 'etc index');

  int read(int index) {
    checkIndex(index);
    return _values[index] ?? 0;
  }

  bool hasBit(int index, int bit) => read(index) & LorePascal.bit(bit) != 0;

  void setBit(int index, int bit, [bool enabled = true]) {
    final mask = LorePascal.bit(bit);
    this[index] = enabled ? read(index) | mask : read(index) & ~mask;
  }

  Uint8List toBytes() => Uint8List.fromList([
    for (var index = 1; index <= lengthInBytes; index++) read(index),
  ]);

  Map<int, int> snapshot() => Map<int, int>.unmodifiable(_values);

  @override
  int? operator [](Object? key) => _values[key];

  @override
  void operator []=(int key, int value) {
    checkIndex(key);
    _values[key] = LorePascal.byte(value);
  }

  @override
  Iterable<int> get keys => _values.keys;

  @override
  void clear() => _values.clear();

  @override
  int? remove(Object? key) => _values.remove(key);
}
