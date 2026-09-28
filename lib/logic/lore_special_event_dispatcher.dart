import '../data/lore_script.dart';
import '../game/lore_dungeon_event_manager.dart';
import '../models/party_member.dart';
import 'lore_tile_protocol.dart';
import 'lore_spec_procedures.dart';

class LoreSpecialEventDispatch {
  final ScriptRun? script;
  final DungeonEventResult? legacy;

  const LoreSpecialEventDispatch({this.script, this.legacy});
}

/// 원본 `specialevent` 호출의 단일 진입점.
///
/// JSON이 정상 로드되면 JSON 규칙이 사건의 기준이다. 조건이 거짓이어서 규칙이
/// 발동하지 않는 경우에도 옛 처리기로 재시도하지 않는다. JSON을 로드할 수 없을
/// 때에만 기존 Dart 사건 처리기를 사용한다.
class LoreSpecialEventDispatcher {
  LoreSpecialEventDispatcher._();

  static LoreSpecialEventDispatch resolve({
    required LoreTileAction action,
    required int mapId,
    required int x,
    required int y,
    required ScriptContext context,
    required List<PartyMember> party,
    required LoreScriptEngine scripts,
    required LoreDungeonEventManager legacy,
  }) {
    if (action != LoreTileAction.special) {
      return const LoreSpecialEventDispatch();
    }
    if (mapId == 1) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map1Food(context, scripts),
      );
    }
    if (mapId == 4 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map4(x, y, context, scripts),
      );
    }
    if (mapId == 6 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map6(x, y, context, scripts),
      );
    }
    if (mapId == 7 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map7(x, y, context, scripts),
      );
    }
    if (mapId == 8 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map8(x, y, context, scripts),
      );
    }
    if (mapId == 9 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map9(x, y, context, scripts),
      );
    }
    if (mapId == 10 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map10(x, y, context, scripts),
      );
    }
    if (mapId == 11 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map11(x, y, context, scripts),
      );
    }
    if (mapId == 12 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map12(x, y, context, scripts),
      );
    }
    if (mapId == 13 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map13(x, y, context, scripts),
      );
    }
    if (mapId == 14 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map14(x, y, context, scripts),
      );
    }
    if (mapId == 15 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map15(x, y, context, scripts),
      );
    }
    if (mapId == 16 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map16(x, y, context, scripts),
      );
    }
    if (mapId == 17 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map17(x, y, context, scripts),
      );
    }
    if (mapId == 18 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map18(x, y, context, scripts),
      );
    }
    if (mapId == 19 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map19(x, y, context, scripts),
      );
    }
    if (mapId == 20 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map20(x, y, context, scripts),
      );
    }
    if (mapId == 21 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map21(x, y, context, scripts),
      );
    }
    if (mapId == 22 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map22(x, y, context, scripts),
      );
    }
    if (mapId == 23 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map23(x, y, context, scripts),
      );
    }
    if (mapId == 24 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map24(x, y, context, scripts),
      );
    }
    if (mapId == 25 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map25(x, y, context, scripts),
      );
    }
    if (mapId == 26 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map26(x, y, context, scripts),
      );
    }
    if (mapId == 27 && scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: LoreSpecProcedures.map27(x, y, context, scripts),
      );
    }
    if (scripts.usingJson) {
      return LoreSpecialEventDispatch(
        script: scripts.startStep(mapId, x, y, context),
      );
    }
    return LoreSpecialEventDispatch(
      legacy: legacy.checkEvent(mapId, x, y, party),
    );
  }
}
