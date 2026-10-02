import 'dart:math';

import '../data/lore_script.dart';
import '../game/lore_world_manager.dart';
import '../models/party_member.dart';

/// Source-order effects shared by every `LOREENT.entermode` map branch.
/// The destination and ordinary text are game-pack data; exceptional effects
/// remain here until they can be compared against the source at runtime.
class LoreEntProcedures {
  LoreEntProcedures._();

  static bool isSourceGuardedEntrance(String id) =>
      id == 'portal-5-23-frostdragon' ||
      id == 'portal-21-22-lavagate' ||
      id == 'portal-23-25-dungeon' ||
      id == 'portal-25-26-chamber';

  /// `LOREENT.PAS:16-367` destination clauses. Call only for a tile that
  /// `LOREMAIN.Main` classified as `entermode`. The map 1-5 `at` checks use
  /// the target position; later cases are reached through their entrance tile.
  /// Pre-battle and post-load effects run at the same portal boundary.
  static PortalInfo? entranceAt(int mapId, int x, int y) {
    const frost = 'portal-5-23-frostdragon';
    const gate = 'portal-21-22-lavagate';
    const dungeon = 'portal-23-25-dungeon';
    const chamber = 'portal-25-26-chamber';
    return switch (mapId) {
      1 => switch ((x, y)) {
        (20, 11) => const PortalInfo(
          targetMapId: 6,
          targetX: 51,
          targetY: 95,
          name: 'CASTLE LORE',
        ),
        (76, 57) => const PortalInfo(
          targetMapId: 7,
          targetX: 37,
          targetY: 70,
          name: 'LASTDITCH',
        ),
        (17, 89) => const PortalInfo(
          targetMapId: 14,
          targetX: 25,
          targetY: 45,
          name: 'MENACE',
        ),
        (20, 6) => const PortalInfo(
          targetMapId: 27,
          targetX: 15,
          targetY: 45,
          name: 'ANOTHER LORE',
        ),
        _ => null,
      },
      2 => switch ((x, y)) {
        (19, 26) => const PortalInfo(
          targetMapId: 8,
          targetX: 38,
          targetY: 70,
          name: 'VALIANT PEOPLES',
        ),
        (31, 82) => const PortalInfo(
          targetMapId: 9,
          targetX: 26,
          targetY: 45,
          name: 'GAIA TERRA',
        ),
        (82, 47) => const PortalInfo(
          targetMapId: 15,
          targetX: 25,
          targetY: 70,
          name: 'QUAKE',
        ),
        (44, 7) => const PortalInfo(
          targetMapId: 16,
          targetX: 20,
          targetY: 35,
          name: 'WIVERN',
        ),
        _ => null,
      },
      3 => switch ((x, y)) {
        (74, 19) => const PortalInfo(
          targetMapId: 10,
          targetX: 25,
          targetY: 70,
          name: 'WATER FIELD',
        ),
        (23, 62) => const PortalInfo(
          targetMapId: 17,
          targetX: 56,
          targetY: 94,
          name: 'NOTICE',
        ),
        (96, 42) => const PortalInfo(
          targetMapId: 18,
          targetX: 25,
          targetY: 94,
          name: 'LOCKUP',
        ),
        _ => null,
      },
      4 => switch ((x, y)) {
        (48, 35) => const PortalInfo(
          targetMapId: 21,
          targetX: 25,
          targetY: 45,
          name: 'SWAMP KEEP',
        ),
        (48, 57) => const PortalInfo(
          targetMapId: 19,
          targetX: 25,
          targetY: 45,
          name: 'EVIL GOD',
        ),
        (82, 16) => const PortalInfo(
          targetMapId: 20,
          targetX: 25,
          targetY: 95,
          name: 'MUDDY',
        ),
        _ => null,
      },
      5 => switch ((x, y)) {
        (15, 31) => const PortalInfo(
          targetMapId: 22,
          targetX: 25,
          targetY: 45,
          name: 'IMPERIUM MINOR',
        ),
        (34, 14) => const PortalInfo(
          targetMapId: 23,
          targetX: 25,
          targetY: 45,
          name: 'EVIL CONCENTRATION',
          scriptId: frost,
        ),
        _ => null,
      },
      7 => const PortalInfo(
        targetMapId: 11,
        targetX: 25,
        targetY: 45,
        name: 'PYRAMID',
      ),
      8 => const PortalInfo(
        targetMapId: 12,
        targetX: 25,
        targetY: 70,
        name: 'EVIL SEAL',
      ),
      10 => const PortalInfo(
        targetMapId: 16,
        targetX: 20,
        targetY: 9,
        name: 'WIVERN',
      ),
      13 => const PortalInfo(
        targetMapId: 21,
        targetX: 25,
        targetY: 6,
        name: 'SWAMP KEEP',
      ),
      16 => const PortalInfo(
        targetMapId: 10,
        targetX: 26,
        targetY: 8,
        name: 'WATER FIELD',
      ),
      21 =>
        y <= 6
            ? const PortalInfo(
                targetMapId: 13,
                targetX: 81,
                targetY: 68,
                name: 'SWAMP GATE',
              )
            : const PortalInfo(
                targetMapId: 22,
                targetX: 25,
                targetY: 6,
                name: 'IMPERIUM MINOR',
                scriptId: gate,
              ),
      22 =>
        y <= 6
            ? const PortalInfo(
                targetMapId: 21,
                targetX: 25,
                targetY: 20,
                name: 'SWAMP KEEP',
              )
            : const PortalInfo(
                targetMapId: 24,
                targetX: 25,
                targetY: 45,
                name: 'LAST SHELTER',
              ),
      23 => const PortalInfo(
        targetMapId: 25,
        targetX: 25,
        targetY: 45,
        name: 'DUNGEON OF EVIL',
        scriptId: dungeon,
      ),
      25 => const PortalInfo(
        targetMapId: 26,
        targetX: 25,
        targetY: 15,
        name: 'CHAMBER OF NECROMANCER',
        scriptId: chamber,
      ),
      _ => null,
    };
  }

  /// The four guarded `entermode` branches, stopped at the existing generic
  /// battle effect boundary. Flags and random choice are read in Pascal order.
  static LoreScript? beforeLoad(
    PortalInfo portal,
    ScriptContext context,
    int Function(int upperBound) roll,
  ) {
    final id = portal.scriptId;
    List<ScriptStep>? steps;
    switch (id) {
      case 'portal-5-23-frostdragon':
        if (context.flags.contains('frostDragonDefeated')) return null;
        final monsters = List<int>.filled(7, 54);
        monsters[roll(5) + 1] = 69;
        steps = [
          for (final line in const [
            ' 나는 EVIL CONCENTRATION 성의 입구를 지키는',
            '임무를 맡고 있는 Frost Dragon이다. 내가 지',
            '키고 있는한 너희들은 한 발자국도 들여놓지',
            '않을것이다.',
          ])
            ScriptStep(kind: 'say', text: line),
          ScriptStep(
            kind: 'battle',
            monsters: monsters,
            battleTitle: 'Frost Dragon',
            battleEnemyFirst: true,
            battleVictoryFlags: const ['frostDragonDefeated'],
            battleRunAwaySteps: const [ScriptStep(kind: 'block', block: true)],
          ),
        ];
      case 'portal-21-22-lavagate':
        const leftKey = 'lavaGateKeyLeft';
        const rightKey = 'lavaGateKeyRight';
        const leftDead = 'lavaGateLeftGuardianDefeated';
        const rightDead = 'lavaGateRightGuardianDefeated';
        if (!context.flags.contains(leftKey) ||
            !context.flags.contains(rightKey)) {
          steps = const [
            ScriptStep(kind: 'say', text: ' 라바 게이트는 작동되지 않았다.'),
            ScriptStep(kind: 'block', block: true),
          ];
          break;
        }
        final monsters = <int>[];
        final defeatedFlags = <int, String>{};
        if (!context.flags.contains(leftDead)) {
          monsters.add(65);
          defeatedFlags[monsters.length] = leftDead;
        }
        if (!context.flags.contains(rightDead)) {
          monsters.add(64);
          defeatedFlags[monsters.length] = rightDead;
        }
        if (monsters.isEmpty) {
          if (context.flags.contains('lavaGateGuardiansCleared')) return null;
          steps = const [
            ScriptStep(kind: 'flag', key: 'lavaGateGuardiansCleared'),
          ];
        } else {
          steps = [
            ScriptStep(
              kind: 'battle',
              monsters: monsters,
              battleTitle: 'IMPERIUM MINOR 수문장',
              battleEnemyFirst: true,
              battleEnemyDefeatFlags: defeatedFlags,
              battleVictoryFlags: const ['lavaGateGuardiansCleared'],
              battleContinueOnRunAway: true,
            ),
          ];
        }
      case 'portal-23-25-dungeon':
        if (context.flags.contains('dungeonOfEvilCleared')) return null;
        steps = const [
          ScriptStep(kind: 'say', text: ' 이 동굴에 들어 가겠다고?'),
          ScriptStep(kind: 'say', text: ' 하!, 우습군. 너희들에게는 여기의 Draconian'),
          ScriptStep(kind: 'say', text: '족들의 모습이 보이지 않는 모양이군.'),
          ScriptStep(
            kind: 'battle',
            monsters: [62, 62, 70, 62, 62, 62, 62],
            battleTitle: 'ArchiDraconian',
            battleEnemyFirst: true,
            battleVictoryIfEnemyDead: 3,
            battleRunAwaySteps: [ScriptStep(kind: 'block', block: true)],
          ),
          ScriptStep(kind: 'flag', key: 'dungeonOfEvilCleared'),
        ];
      case 'portal-25-26-chamber':
        steps = const [
          ScriptStep(kind: 'sourceEtc', sourceEtcIndex: 1, sourceEtcValue: 1),
          ScriptStep(kind: 'torch', torchLit: true),
          ScriptStep(
            kind: 'scene',
            scene: ScriptScene(
              title: 'Necromancer',
              actors: [72],
              lines: [' 두말이 필요없다. 덤벼라 !!'],
            ),
          ),
          ScriptStep(
            kind: 'battle',
            monsters: [63, 63, 63, 63, 63, 72],
            battleTitle: 'Necromancer',
            battleRunAwaySteps: [
              ScriptStep(kind: 'teleport', tileX: 25, tileY: 45),
              ScriptStep(kind: 'block', block: true),
            ],
          ),
        ];
      default:
        return null;
    }
    return LoreScript(
      id: id!,
      trigger: 'portal',
      map: portal.targetMapId,
      once: false,
      require: const ScriptRequire(),
      steps: steps,
    );
  }

  /// `LOREENT.PAS:233-259`: Ancient Evil speaks before `load` on the first
  /// crossing from SWAMP KEEP to IMPERIUM MINOR.
  static LoreScript? ancientEvilBeforeLoad({
    required int fromMap,
    required int toMap,
    required Set<String> flags,
  }) {
    if (fromMap != 21 ||
        toMap != 22 ||
        flags.contains('ancientEvilSpeechGiven')) {
      return null;
    }
    return const LoreScript(
      id: 'loreent-ancient-evil',
      trigger: 'enter',
      map: 22,
      once: false,
      require: ScriptRequire(),
      steps: [
        ScriptStep(kind: 'say', text: ' 역시 당신들은 나의 예상대로 마지막  대륙까'),
        ScriptStep(kind: 'say', text: '지 무난하게 왔군요. 이번에 가게될 LAVA 대륙'),
        ScriptStep(kind: 'say', text: '은 이 세계에 있는 모든 대륙중에서 가장 작은'),
        ScriptStep(kind: 'say', text: '대륙이오. 적의 요새도 또한 2개 밖에 없는 곳'),
        ScriptStep(kind: 'say', text: '이오. 하지만 이번에 도착할 IMPERIUM MINOR나'),
        ScriptStep(kind: 'say', text: '마지막으로 거칠 EVIL CONCENTRATION 은 말 그'),
        ScriptStep(kind: 'say', text: '대로 악의 집결지인 것이오. 거기에는 최강의'),
        ScriptStep(kind: 'say', text: '괴물들과 Necromancer 의 심복들로 가득차있는'),
        ScriptStep(kind: 'say', text: '곳이지만 IMPERIUM MINOR의 지하에는 마지막으'),
        ScriptStep(kind: 'say', text: '로 살아남은 사람들의 도시가 있소. 원래 거기'),
        ScriptStep(kind: 'say', text: '는 Ancient Evil이 전에 세운 악의 동굴이었지'),
        ScriptStep(kind: 'say', text: '만 Necromancer의 침략으로 지상의 도시가 함'),
        ScriptStep(kind: 'say', text: '락되자 그 곳의 사람들은 모두 거기로 피난 했'),
        ScriptStep(kind: 'say', text: '던 것이고 거기는 Ancient Evil의 영적인 힘으'),
        ScriptStep(kind: 'say', text: '로 보호되고 있어서 적들이 침략을하지 못하는'),
        ScriptStep(kind: 'say', text: '이유가 되지요. 그러므로 모든 도움과 물자는'),
        ScriptStep(kind: 'say', text: '거기서 받도록하시오.'),
        ScriptStep(kind: 'say', text: ' 그러면, 나는 당신이 Necromancer와 상대하게'),
        ScriptStep(kind: 'say', text: '될 때 다시 Ancient Evil과 같이 나타나겠소.'),
        ScriptStep(kind: 'flag', key: 'ancientEvilSpeechGiven'),
      ],
    );
  }

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

  /// Tile writes immediately following `load` in `LOREENT.entermode`.
  /// The caller supplies the freshly loaded map and the current party state.
  static void afterMapLoadTiles({
    required int fromMap,
    required int toMap,
    required Set<String> partyNames,
    required Set<String> flags,
    required Map<String, int> questSteps,
    required void Function(int x, int y, int tile) setTile,
  }) {
    switch ((fromMap, toMap)) {
      case (1, 6):
        for (final (x, y, tile) in const [
          (49, 52, 47),
          (50, 52, 44),
          (51, 52, 44),
          (52, 52, 44),
          (53, 52, 47),
          (49, 53, 47),
          (50, 53, 44),
          (51, 53, 44),
          (52, 53, 44),
          (53, 53, 45),
        ]) {
          setTile(x, y, tile);
        }
        for (var x = 49; x <= 53; x++) {
          setTile(x, 88, 44);
        }
      // LOREENT.PAS from map 1, and the LORESPEC.PAS:515-521 map 11 exit.
      case (1, 7) || (11, 7):
        if (partyNames.contains('Polaris')) setTile(37, 41, 44);
      case (3, 10) || (16, 10):
        if (flags.contains('loreHunterJoined')) setTile(40, 56, 44);
      case (7, 11):
        if ((questSteps['lastditch'] ?? 0) > 1) {
          setTile(25, 44, 50);
          setTile(26, 44, 50);
        }
      case (8, 12):
        if ((questSteps['gaia'] ?? 0) > 1) setTile(18, 9, 0);
      case (22, 24):
        if (flags.contains('programmerMet')) setTile(33, 10, 47);
      case (25, 26):
        for (var y = 16; y <= 19; y++) {
          for (var x = 24; x <= 26; x++) {
            setTile(x, y, 16);
          }
        }
    }
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
