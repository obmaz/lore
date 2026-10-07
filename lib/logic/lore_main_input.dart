import 'dart:async';

/// The shared `c` used by LOREMAIN.Main and the source input procedures.
/// Space after a hotkey procedure enters SelectMode before the final Esc guard.
/// A scope belongs to one field command; later reads replace earlier reads.
class LoreMainInput {
  static final Object _key = Object();

  bool lastKeyWasEscape = false;
  bool lastKeyWasSpace = false;
  bool lastKeyWasBackspace = false;

  static LoreMainInput? get current => Zone.current[_key] as LoreMainInput?;

  void read({
    required bool escape,
    bool space = false,
    bool backspace = false,
  }) {
    lastKeyWasEscape = escape;
    lastKeyWasSpace = space;
    lastKeyWasBackspace = backspace;
  }

  static void record({
    required bool escape,
    bool space = false,
    bool backspace = false,
  }) => current?.read(escape: escape, space: space, backspace: backspace);

  Future<void> run(Future<void> Function() procedure) =>
      runZoned(procedure, zoneValues: {_key: this});
}
