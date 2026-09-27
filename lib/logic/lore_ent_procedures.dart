import 'dart:math';

import '../models/party_member.dart';

/// Source-order effects shared by every `LOREENT.entermode` map branch.
/// The destination and ordinary text are game-pack data; exceptional effects
/// remain here until they can be compared against the source at runtime.
class LoreEntProcedures {
  LoreEntProcedures._();

  /// `LOREENT.PAS:293-309`: the sixth-slot Draconian is struck before the
  /// ArchiDraconian guard battle. Returns whether the scene must be shown.
  static bool strikeDraconianBeforeDungeon(List<PartyMember> party) {
    if (party.length < 6 || party[5].name != 'Draconian') return false;
    party[5]
      ..hp = 0
      ..unconscious = 1
      ..dead = 30000;
    return true;
  }

  /// `LOREENT.PAS:323-335`: the chamber entry consumes two random values for
  /// each of ten animation frames before showing the boss and starting battle.
  /// The frame positions are returned for the renderer; consuming them also
  /// keeps the following battle on the source random stream.
  static List<(int x, int y)> chamberEntryFrames(Random random) {
    final frames = <(int x, int y)>[];
    for (var frame = 0; frame < 10; frame++) {
      final x = random.nextInt(9) - 4;
      var y = random.nextInt(9) - 4;
      if (x == 0 && y == 0) y = -1;
      frames.add((x, y));
    }
    return frames;
  }

  /// `LOREENT.PAS:355-362`: the party descends five rows before the chamber
  /// floor is opened. The source iterates j from 4 down to 0.
  static const chamberDescentRows = [4, 3, 2, 1, 0];

  /// `LOREENT.PAS:353-354`: map 26's descent sets the alternate north face
  /// before its post-load map changes and final scroll.
  static void afterMapLoadBeforeScripts({
    required int fromMap,
    required int toMap,
    required void Function(int direction) setDirection,
  }) {
    if (fromMap == 25 && toMap == 26) setDirection(1);
  }

  /// `LOREENT.PAS:367`, reached after the map's post-load effects.
  static void finishEntrance(void Function() scrollToParty) => scrollToParty();

  /// `LOREENT.PAS:370-488`: the sign text is supplied by the game pack,
  /// while the KEEP3 sign's tile mutation is a source-specific effect.
  static void sign({
    required int mapId,
    required int x,
    required int y,
    required String? Function(int mapId, int x, int y) messageFor,
    required void Function(String message) display,
    required void Function(int x, int y, int tile) setTile,
  }) {
    display(messageFor(mapId, x, y) ?? '푯말에 쓰여있기로 ...');
    if (mapId == 23) setTile(25, 27, 52);
  }
}
