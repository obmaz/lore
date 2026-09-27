import '../data/lore_script.dart';
import '../game/lore_dialogue_manager.dart';
import '../game/lore_world_manager.dart';
import '../models/party_member.dart';

enum LoreTalkSource { facility, script, dialogue, none }

class LoreTalkDispatch {
  final LoreTalkSource source;
  final int? facility;
  final ScriptRun? script;
  final String? dialogue;

  const LoreTalkDispatch._(
    this.source, {
    this.facility,
    this.script,
    this.dialogue,
  });

  const LoreTalkDispatch.facility(int value)
    : this._(LoreTalkSource.facility, facility: value);
  const LoreTalkDispatch.script(ScriptRun value)
    : this._(LoreTalkSource.script, script: value);
  const LoreTalkDispatch.dialogue(String value)
    : this._(LoreTalkSource.dialogue, dialogue: value);
  const LoreTalkDispatch.none() : this._(LoreTalkSource.none);
}

/// `LORETALK.talkmode`/facility selection before the player enters the tile.
///
/// A conditional JSON script may be followed by ordinary resident dialogue.
/// The first available source owns this interaction, so later sources are not
/// executed or allowed to mutate progression during the same command.
class LoreTalkDispatcher {
  LoreTalkDispatcher._();

  static LoreTalkDispatch resolve({
    required int mapId,
    required int x,
    required int y,
    required String heroName,
    required ScriptContext? context,
    required List<PartyMember>? party,
    required int mindReadCount,
    required LoreWorldManager world,
    required LoreScriptEngine scripts,
    required LoreDialogueManager dialogues,
  }) {
    final facility = world.findFacility(mapId, x, y);
    if (facility != null) return LoreTalkDispatch.facility(facility);
    if (context != null) {
      final script = scripts.startTalk(mapId, x, y, context);
      if (script != null) return LoreTalkDispatch.script(script);
    }
    final dialogue = dialogues.getDialogue(
      mapId,
      x,
      y,
      heroName,
      party: party,
      mindReadCount: mindReadCount,
    );
    return dialogue == null
        ? const LoreTalkDispatch.none()
        : LoreTalkDispatch.dialogue(dialogue);
  }
}
