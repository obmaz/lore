enum LoreCompanionInput { none, profile, finish, restart }

/// Fourth's ten flags, clamped cursor and two-choice inner loop.
class LoreCreationCompanions {
  LoreCreationCompanions({
    Set<int> selected = const {},
    this.cursor = 1,
    this.choosing = false,
  }) {
    RangeError.checkValueInInterval(cursor, 1, 10, 'cursor');
    if (selected.length > 4 || selected.any((id) => id < 1 || id > 10)) {
      throw ArgumentError.value(selected);
    }
    for (final id in selected) {
      flags[id] = 1;
    }
  }
  final flags = List<int>.filled(11, 0);
  int cursor;
  bool choosing;
  Set<int> get selected => {
    for (var id = 1; id <= 10; id++)
      if (flags[id] == 1) id,
  };
  bool get complete => selected.length == 4;

  LoreCompanionInput readKey(int key, {int scan = 0}) {
    if (complete) {
      return key == 27 ? LoreCompanionInput.restart : LoreCompanionInput.finish;
    }
    if (choosing) {
      if (key == 49) {
        flags[cursor] = 1;
        choosing = false;
      }
      if (key == 50) {
        choosing = false;
        return LoreCompanionInput.profile;
      }
      if (key == 27) choosing = false;
      return LoreCompanionInput.none;
    }
    var delta = 0;
    if (key == 0) {
      key = scan;
      if (scan == 72) delta = -1;
      if (scan == 80) delta = 1;
    }
    if (delta != 0) {
      cursor += delta;
      if (cursor < 1 || cursor > 10) cursor -= delta;
    }
    if (key == 13 && flags[cursor] == 0) choosing = true;
    return LoreCompanionInput.none;
  }

  void join(int id) {
    RangeError.checkValueInInterval(id, 1, 10, 'id');
    if (complete || flags[id] != 0) return;
    cursor = id;
    choosing = true;
    readKey(49);
  }
}
