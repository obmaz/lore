import '../data/lore_script.dart';
import '../game/lore_world_manager.dart';
import 'lore_ent_procedures.dart';
import 'lore_spec_procedures.dart';

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
    int? x,
    int? y,
  }) {
    if (!confirmed) return const LorePortalPlan(LorePortalAction.cancelled);
    final id = portal.scriptId;
    if (id == 'keep1-exit-guard') {
      final guard = LoreSpecProcedures.keep1ExitGuard(context, x!, y!);
      return guard == null
          ? const LorePortalPlan(LorePortalAction.loadMap)
          : LorePortalPlan(
              LorePortalAction.runPreScript,
              scripts.startProcedure(guard, context),
            );
    }
    if (id == 'castle-exit-skeleton') {
      final skeleton = LoreSpecProcedures.castleExitSkeleton(context, x!, y!);
      return skeleton == null
          ? const LorePortalPlan(LorePortalAction.loadMap)
          : LorePortalPlan(
              LorePortalAction.runPreScript,
              scripts.startProcedure(skeleton, context),
            );
    }
    if (id == 'portal-9-13-swamp-gate') {
      final speech = LoreSpecProcedures.swampGateSpeech(context);
      return speech == null
          ? const LorePortalPlan(LorePortalAction.loadMap)
          : LorePortalPlan(
              LorePortalAction.runPreScript,
              scripts.startProcedure(speech, context),
            );
    }
    if (id == 'keep2-exit-guard') {
      final guard = LoreSpecProcedures.keep2ExitGuard(context, scripts.roll);
      return guard == null
          ? const LorePortalPlan(LorePortalAction.loadMap)
          : LorePortalPlan(
              LorePortalAction.runPreScript,
              scripts.startProcedure(guard, context),
            );
    }
    if (id != null) {
      final source = LoreEntProcedures.beforeLoad(
        portal,
        context,
        scripts.roll,
      );
      if (source != null) {
        return LorePortalPlan(
          LorePortalAction.runPreScript,
          scripts.startProcedure(source, context),
        );
      }
      if (LoreEntProcedures.isSourceGuardedEntrance(id)) {
        return const LorePortalPlan(LorePortalAction.loadMap);
      }
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
