import '../data/lore_script.dart';
import '../game/lore_world_manager.dart';

enum LorePortalAction {
  cancelled,
  runPreScript,
  waitForBattle,
  blocked,
  loadMap,
}

class LorePortalPlan {
  final LorePortalAction action;
  final ScriptRun? preScript;

  const LorePortalPlan(this.action, [this.preScript]);
}

/// Orders `LORESUB` confirmation and `LOREENT` pre-entry work independently
/// of the dialog, map renderer, and battle screen.
class LorePortalSession {
  LorePortalSession._();

  static LorePortalPlan begin({
    required bool confirmed,
    required PortalInfo portal,
    required ScriptContext context,
    required LoreScriptEngine scripts,
  }) {
    if (!confirmed) return const LorePortalPlan(LorePortalAction.cancelled);
    final id = portal.scriptId;
    if (id != null) {
      final pre = scripts.startById(id, context);
      if (pre != null) {
        return LorePortalPlan(LorePortalAction.runPreScript, pre);
      }
    }
    return const LorePortalPlan(LorePortalAction.loadMap);
  }

  static LorePortalAction afterPreScript({
    required bool completed,
    required bool waitingForBattle,
    required bool blockMove,
  }) {
    if (waitingForBattle) return LorePortalAction.waitForBattle;
    if (!completed) return LorePortalAction.cancelled;
    if (blockMove) return LorePortalAction.blocked;
    return LorePortalAction.loadMap;
  }
}
