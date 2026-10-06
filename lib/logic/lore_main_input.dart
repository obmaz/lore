import 'dart:async';

/// The shared `c` used by LOREMAIN.Main and the source input procedures.
/// Only its Esc/non-Esc value is needed by Main's final tile-dispatch guard.
/// A scope belongs to one field command; later reads replace earlier reads.
class LoreMainInput {
  static final Object _key = Object();

  bool lastKeyWasEscape = false;

  static LoreMainInput? get current => Zone.current[_key] as LoreMainInput?;

  void read({required bool escape}) => lastKeyWasEscape = escape;

  static void record({required bool escape}) => current?.read(escape: escape);

  Future<void> run(Future<void> Function() procedure) =>
      runZoned(procedure, zoneValues: {_key: this});
}
