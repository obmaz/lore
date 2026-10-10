import '../data/lore_dialogue_scripts.dart';
import '../models/party_member.dart';
import 'lore_dialogue_flow.dart';
import 'lore_dialogue_io.dart';
import 'lore_source_memory.dart';

export 'lore_dialogue_io.dart' show LoreTalkModeIo;

/// Compatibility entry point for source replay and modern town interactions.
/// One script owns both; only explicit dialogue edges differ on mobile.
class LoreTalkMode {
  static Future<void> run({
    required int mapId,
    required int targetX,
    required int targetY,
    required int x,
    required int y,
    required List<PartyMember> party,
    required LorePartyEtc etc,
    required int Function(int) roll,
    required LoreTalkModeIo io,
    bool continuous = false,
  }) => LoreDialogueScripts.town.run(
    DialogueContext(
      mapId: mapId,
      targetX: targetX,
      targetY: targetY,
      x: x,
      y: y,
      party: party,
      etc: etc,
      roll: roll,
      io: io,
      continuous: continuous,
    ),
  );
}
