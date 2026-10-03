import '../data/lore_script.dart';
import '../game/lore_world_manager.dart';

import 'lore_talk_procedures.dart';

enum LoreTalkSource { facility, script, none }

class LoreTalkDispatch {
  final LoreTalkSource source;
  final int? facility;
  final ScriptRun? script;

  const LoreTalkDispatch._(this.source, {this.facility, this.script});

  const LoreTalkDispatch.facility(int value)
    : this._(LoreTalkSource.facility, facility: value);
  const LoreTalkDispatch.script(ScriptRun value)
    : this._(LoreTalkSource.script, script: value);
  const LoreTalkDispatch.none() : this._(LoreTalkSource.none);
}

/// `LORETALK.talkmode`/facility selection before the player enters the tile.
///
/// The first available source owns the interaction: a facility, then the
/// direct per-map procedure, then the generic script table. A map that has a
/// direct procedure never falls through when it prints nothing (the source
/// `talkmode` prints nothing for a cell it has no case for), and there is no
/// other text source: the invented one-line dialogues were removed.
class LoreTalkDispatcher {
  LoreTalkDispatcher._();

  static LoreTalkDispatch resolve({
    required int mapId,
    required int x,
    required int y,
    required ScriptContext? context,
    required LoreWorldManager world,
    required LoreScriptEngine scripts,
  }) {
    final facility = world.findFacility(mapId, x, y);
    if (facility != null) return LoreTalkDispatch.facility(facility);
    if (context != null && scripts.usingJson) {
      final ScriptRun? owned = switch (mapId) {
        6 => LoreTalkProcedures.map6(x, y, context, scripts),
        7 => LoreTalkProcedures.map7(x, y, context, scripts),
        9 => LoreTalkProcedures.map9(x, y, context, scripts),
        10 => LoreTalkProcedures.map10(x, y, context, scripts),
        24 => LoreTalkProcedures.map24(x, y, context, scripts),
        27 => LoreTalkProcedures.map27(x, y, context, scripts),
        _ => null,
      };
      if (owned != null) return LoreTalkDispatch.script(owned);
      if (const {6, 7, 9, 10, 24, 27}.contains(mapId)) {
        return const LoreTalkDispatch.none();
      }
    }
    if (context != null) {
      final script = scripts.startTalk(mapId, x, y, context);
      if (script != null) return LoreTalkDispatch.script(script);
    }
    return const LoreTalkDispatch.none();
  }
}
