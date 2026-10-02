import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_ent_procedures.dart';
import 'package:lore/logic/lore_portal_session.dart';
import 'package:lore/models/party_member.dart';

class _SequenceRandom implements Random {
  final List<int> values;
  final List<int> bounds = [];
  var index = 0;

  _SequenceRandom(this.values);

  @override
  int nextInt(int max) {
    bounds.add(max);
    return values[index++];
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  test('최종 방 진입 후 원본의 하강 프레임은 4에서 0까지 다섯 번이다', () {
    expect(LoreEntProcedures.chamberDescentRows, [4, 3, 2, 1, 0]);
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Frost Dragon direct procedure rolls source slots and blocks retreat',
    () {
      const portal = PortalInfo(
        targetMapId: 23,
        targetX: 25,
        targetY: 45,
        name: 'EVIL CONCENTRATION',
        scriptId: 'portal-5-23-frostdragon',
      );
      final first = LoreEntProcedures.beforeLoad(
        portal,
        const ScriptContext(),
        (_) => 0,
      )!;
      final last = LoreEntProcedures.beforeLoad(
        portal,
        const ScriptContext(),
        (_) => 4,
      )!;
      expect(first.steps.last.monsters, [54, 69, 54, 54, 54, 54, 54]);
      expect(last.steps.last.monsters, [54, 54, 54, 54, 54, 69, 54]);
      expect(first.steps.last.battleEnemyFirst, isTrue);
      expect(first.steps.last.battleRunAwaySteps.single.block, isTrue);
      expect(
        LoreEntProcedures.beforeLoad(
          portal,
          const ScriptContext(flags: {'frostDragonDefeated'}),
          (_) => fail('defeated guardian must not roll'),
        ),
        isNull,
      );
    },
  );

  test('lava gate direct procedure selects only surviving guardians', () {
    const portal = PortalInfo(
      targetMapId: 22,
      targetX: 25,
      targetY: 6,
      name: 'IMPERIUM MINOR',
      scriptId: 'portal-21-22-lavagate',
    );
    final engine = LoreScriptEngine();
    const keys = {'lavaGateKeyLeft', 'lavaGateKeyRight'};
    LorePortalPlan begin(Set<String> flags) => LorePortalSession.begin(
      confirmed: true,
      portal: portal,
      context: ScriptContext(flags: flags),
      scripts: engine,
    );
    expect(begin({}).preScript?.outcome.blockMove, isTrue);
    expect(begin(keys).preScript?.outcome.battleMonsters, [65, 64]);
    expect(
      begin({...keys, 'lavaGateLeftGuardianDefeated'})
          .preScript
          ?.outcome
          .battleMonsters,
      [64],
    );
    expect(
      begin({...keys, 'lavaGateRightGuardianDefeated'})
          .preScript
          ?.outcome
          .battleMonsters,
      [65],
    );
    expect(
      begin({
        ...keys,
        'lavaGateLeftGuardianDefeated',
        'lavaGateRightGuardianDefeated',
      }).preScript?.outcome.setFlags,
      ['lavaGateGuardiansCleared'],
    );
    expect(
      begin({
        ...keys,
        'lavaGateLeftGuardianDefeated',
        'lavaGateRightGuardianDefeated',
        'lavaGateGuardiansCleared',
      }).action,
      LorePortalAction.loadMap,
    );
  });

  test(
    'dungeon and chamber direct procedures preserve battle continuations',
    () {
      final engine = LoreScriptEngine();
      const dungeon = PortalInfo(
        targetMapId: 25,
        targetX: 25,
        targetY: 45,
        name: 'DUNGEON OF EVIL',
        scriptId: 'portal-23-25-dungeon',
      );
      final guard = LorePortalSession.begin(
        confirmed: true,
        portal: dungeon,
        context: const ScriptContext(),
        scripts: engine,
      ).preScript!;
      expect(guard.outcome.battleMonsters, [62, 62, 70, 62, 62, 62, 62]);
      expect(guard.continueAfterRunAway().outcome.blockMove, isTrue);
      expect(
        guard.continueAfterRunAway(defeatedEnemySlots: {3}).outcome.setFlags,
        contains('dungeonOfEvilCleared'),
      );

      const chamber = PortalInfo(
        targetMapId: 26,
        targetX: 25,
        targetY: 15,
        name: 'CHAMBER OF NECROMANCER',
        scriptId: 'portal-25-26-chamber',
      );
      final boss = LorePortalSession.begin(
        confirmed: true,
        portal: chamber,
        context: const ScriptContext(),
        scripts: engine,
      ).preScript!.acknowledgeScene();
      expect(boss.outcome.battleMonsters, [63, 63, 63, 63, 63, 72]);
      expect(boss.outcome.battleEnemyFirst, isFalse);
      expect(boss.outcome.torchLit, isTrue);
      expect(boss.continueAfterRunAway().outcome.blockMove, isTrue);
      expect(boss.continueAfterRunAway().outcome.teleportY, 45);
    },
  );

  test('Ancient Evil speaks once before the 21 to 22 load', () {
    final speech = LoreEntProcedures.ancientEvilBeforeLoad(
      fromMap: 21,
      toMap: 22,
      flags: {},
    )!;
    final run = LoreScriptEngine().startProcedure(
      speech,
      const ScriptContext(),
    );
    expect(run.outcome.messages, hasLength(19));
    expect(run.outcome.setFlags, ['ancientEvilSpeechGiven']);
    expect(
      LoreEntProcedures.ancientEvilBeforeLoad(
        fromMap: 21,
        toMap: 22,
        flags: {'ancientEvilSpeechGiven'},
      ),
      isNull,
    );
    expect(
      LoreEntProcedures.ancientEvilBeforeLoad(fromMap: 5, toMap: 22, flags: {}),
      isNull,
    );
  });

  test('sixth-slot Draconian is struck before the dungeon guard battle', () {
    final party = [for (var i = 1; i <= 6; i++) PartyMember.createPreset(i)];
    party[5].name = 'Draconian';
    expect(LoreEntProcedures.strikeDraconianBeforeDungeon(party), isTrue);
    expect((party[5].hp, party[5].unconscious, party[5].dead), (0, 1, 30000));

    party[5].name = 'Other';
    party[5].hp = 10;
    expect(LoreEntProcedures.strikeDraconianBeforeDungeon(party), isFalse);
    expect(party[5].hp, 10);
  });

  test('live entrance completion restores the camera and map 26 facing', () {
    final game = LoreGame(initialMapId: 25);
    game.peekAt(30, 30);
    game.playerDirection = 2;
    game.currentMapId = 26;
    LoreEntProcedures.afterMapLoadBeforeScripts(
      fromMap: 25,
      toMap: 26,
      setDirection: (direction) => game.playerDirection = direction,
    );
    game.finishEntrance();
    expect(game.playerDirection, 1);
    expect(game.isPeeking, isFalse);
  });

  test('chamber entry consumes ten ordered pairs before boss combat', () {
    final random = _SequenceRandom([4, 4, ...List.filled(18, 0)]);
    final frames = LoreEntProcedures.chamberEntryFrames(random);
    expect(frames.length, 10);
    expect(frames.first, (0, -1));
    expect(frames.last, (-4, -4));
    expect(random.bounds, List.filled(20, 9));
  });

  test('completed chamber entry faces north before restoring the view', () {
    final trace = <String>[];
    LoreEntProcedures.afterMapLoadBeforeScripts(
      fromMap: 25,
      toMap: 26,
      setDirection: (direction) => trace.add('face:$direction'),
    );
    LoreEntProcedures.finishEntrance(() => trace.add('scroll'));
    expect(trace, ['face:1', 'scroll']);

    trace.clear();
    LoreEntProcedures.afterMapLoadBeforeScripts(
      fromMap: 1,
      toMap: 6,
      setDirection: (direction) => trace.add('face:$direction'),
    );
    LoreEntProcedures.finishEntrance(() => trace.add('scroll'));
    expect(trace, ['scroll']);
  });

  test('sign displays text then opens the KEEP3 lever tile', () {
    final trace = <String>[];
    LoreEntProcedures.sign(
      mapId: 23,
      x: 25,
      y: 27,
      messageFor: (mapId, x, y) {
        trace.add('lookup:$mapId:$x:$y');
        return 'lever';
      },
      display: (message) => trace.add('display:$message'),
      setTile: (x, y, tile) => trace.add('tile:$x:$y:$tile'),
    );
    expect(trace, ['lookup:23:25:27', 'display:lever', 'tile:25:27:52']);
  });
}
