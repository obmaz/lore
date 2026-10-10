/// LORECRET.PAS Second: source keyboard/cursor and point budget state.
/// Touch buttons adapt to the same source horizontal transition.
class LoreCreationAllocation {
  LoreCreationAllocation({List<int>? values, int cursor = 0})
    : values = List<int>.from(values ?? [0, 0, 0]),
      cursor = cursor {
    if (this.values.length != 3 ||
        this.values.any((v) => v < 0 || v > 20) ||
        this.values.fold(0, (a, b) => a + b) > 40) {
      throw ArgumentError.value(values, 'values');
    }
    RangeError.checkValueInInterval(cursor, 0, 2, 'cursor');
    remaining = 40 - this.values.fold(0, (a, b) => a + b);
  }
  final List<int> values;
  int cursor;
  late int remaining;

  /// c=0 consumes a scan byte. The final c is tested by repeat-until Enter.
  bool readKey(int key, {int scan = 0}) {
    var horizontal = 0, vertical = 0;
    if (key == 0) {
      key = scan;
      switch (scan) {
        case 72:
          vertical = -1;
        case 80:
          vertical = 1;
        case 75:
          horizontal = -1;
        case 77:
          horizontal = 1;
      }
    }
    if (vertical != 0) {
      cursor += vertical;
      if (cursor < 0 || cursor > 2) cursor -= vertical;
    }
    if (horizontal != 0) {
      final next = values[cursor] + horizontal;
      final budget = remaining - horizontal;
      if (next >= 0 && next <= 20 && budget >= 0 && budget <= 40) {
        values[cursor] = next;
        remaining = budget;
      }
    }
    return key == 13 && remaining == 0;
  }
}
