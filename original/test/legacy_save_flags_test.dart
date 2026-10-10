import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';

/// LORESPEC.PAS:25-35 keeps the map 1 food tree in `party.etc[32]` bit8.
void main() {
  tearDown(() => LoreDialogueManager.instance.loadFlags({}));

  test('a legacy food tree Boolean becomes etc[32] bit8', () {
    final manager = LoreDialogueManager.instance
      ..loadFlags({'foodTreeHarvested': true});
    expect(manager.partyEtc.hasBit(32, 8), isTrue);
  });

  test('a saved raw etc[32] byte takes precedence over the Boolean', () {
    final manager = LoreDialogueManager.instance
      ..loadFlags({'foodTreeHarvested': true, 'etc32': 0});
    expect(manager.partyEtc.hasBit(32, 8), isFalse);
  });
}
