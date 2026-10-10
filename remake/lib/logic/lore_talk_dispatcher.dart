import '../data/lore_script.dart';
import '../game/lore_world_manager.dart';

enum LoreTalkSource { facility, procedure, none }

enum LoreTalkProcedure { waterFieldLord, talkMode }

class LoreTalkDispatch {
  final LoreTalkSource source;
  final int? facility;
  final LoreTalkProcedure? procedure;

  const LoreTalkDispatch._(this.source, {this.facility, this.procedure});

  const LoreTalkDispatch.facility(int value)
    : this._(LoreTalkSource.facility, facility: value);
  const LoreTalkDispatch.procedure(LoreTalkProcedure value)
    : this._(LoreTalkSource.procedure, procedure: value);
  const LoreTalkDispatch.none() : this._(LoreTalkSource.none);
}

/// `LORETALK.talkmode`/facility selection before the player enters the tile.
///
/// Facilities use original coordinates; all dialogue runs source talkmode.
/// Empty source branches never consult a second event owner.
class LoreTalkDispatcher {
  LoreTalkDispatcher._();

  static const directLocations = {
    (10, 25, 18): LoreTalkProcedure.waterFieldLord,
  };

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
    final procedure = directLocations[(mapId, x, y)];
    if (procedure != null) return LoreTalkDispatch.procedure(procedure);
    if (const {6, 7, 9, 10, 24, 27}.contains(mapId)) {
      return const LoreTalkDispatch.procedure(LoreTalkProcedure.talkMode);
    }
    return const LoreTalkDispatch.none();
  }
}
