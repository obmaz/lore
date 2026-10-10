import '../data/lore_dialogue_scripts.dart';
import '../models/party_member.dart';
import 'lore_dialogue_flow.dart';
import 'lore_dialogue_io.dart';
import 'lore_source_memory.dart';

export 'lore_dialogue_io.dart' show LoreTalkIo;

/// LORETALK.PAS:640-704, shared typed script and source-order effects.
class LoreWaterLord {
  static Future<void> run({
    required List<PartyMember> party,
    required LorePartyEtc etc,
    required LoreTalkIo io,
    bool continuous = false,
  }) => LoreDialogueScripts.waterLord.run(
    DialogueContext(party: party, etc: etc, io: io, continuous: continuous),
  );
}
