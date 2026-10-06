import 'support/legacy_json_fixture_engine.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_battle_progress.dart';
import 'package:lore/logic/lore_special_event_dispatcher.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_tile_protocol.dart';
import 'package:lore/logic/script_battle_session.dart';
import 'package:lore/logic/script_party_reducer.dart';
import 'package:lore/logic/script_world_reducer.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/services/save_manager.dart';

class NoGuardianRandom implements Random {
  @override
  int nextInt(int max) =>
      throw StateError('LORESPEC.PAS:2009-2065 has no random draw');
  @override
  bool nextBool() => throw StateError('Unexpected random Boolean');
  @override
  double nextDouble() => throw StateError('Unexpected random double');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = jsonDecode(
    File('test/fixtures/map25_guardian_parity.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  ScriptRun start({
    int torch = 0,
    LegacyJsonFixtureEngine? engine,
    Set<String> flags = const {},
  }) => LoreSpecProcedures.map25(
    25,
    43,
    ScriptContext(tileAtPlayer: 0, sourceEtc: {1: torch}, flags: flags),
    engine ?? LegacyJsonFixtureEngine(random: NoGuardianRandom()),
  )!;

  test(
    'all 256 torch bytes survive; only zero is assigned one before the scene',
    () {
      for (var torch = 0; torch < 256; torch++) {
        final run = start(torch: torch, flags: {'torchActive'});
        final state = ScriptWorldReducer.applyProgress(
          ScriptProgressState(
            flags: const {},
            quests: const {},
            sourceEtc: {1: torch},
          ),
          run.outcome,
        );
        expect(state.sourceEtc[1], torch == 0 ? source['torchValue'] : torch);
        expect(run.outcome.sourceEtcWrites.length, torch == 0 ? 1 : 0);
        expect(run.pendingScene!.actors, source['introActors']);
        expect(run.pendingScene!.lines, source['introLines']);
        expect(run.awaitingBattle, isFalse);
        expect(run.outcome.battleMonsters, isEmpty);
        final battle = run.acknowledgeScene();
        expect(battle.awaitingBattle, isTrue);
        expect(battle.outcome.battleMonsters, source['battleMonsters']);
        expect(battle.outcome.battleEnemyFirst, source['enemyFirst']);
        final delta = battle.outcome.since(run.outcome);
        expect(delta.sourceEtcWrites, isEmpty);
        expect(delta.torchLit, isFalse);
        expect(delta.messages, isEmpty);
      }
    },
  );

  test(
    'source result replay: victory opens the row; escape/defeat never promote',
    () async {
      final original = await LoreMapData.loadFromAsset(
        'K_DEN2',
        category: 'den',
      );
      for (final raw in source['cases'] as List<dynamic>) {
        final item = raw as Map<String, dynamic>;
        final initial = start(torch: item['torch'] as int);
        final battle = initial.acknowledgeScene();
        final code = item['battleResult'] as int;
        final end = code == 0
            ? LoreBattleEnd.victory
            : code == 255
            ? LoreBattleEnd.defeat
            : LoreBattleEnd.runAway;
        final result = ScriptBattleSession.resolve(
          before: const LoreBattleProgressState(
            gold: 100,
            lastBattleResult: 0,
            flags: {},
          ),
          end: end,
          enemies: const [],
          pendingScript: battle,
        );
        final changed = ScriptWorldReducer.applyMap(
          ScriptMapState(
            mapId: 25,
            x: 25,
            y: 43,
            direction: 1,
            grid: original.grid,
          ),
          result.delta,
        );
        final expected = [for (final row in original.grid) List<int>.from(row)];
        for (final write in item['writes'] as List<dynamic>) {
          expected[(write[1] as int) - 1][(write[0] as int) - 1] =
              write[2] as int;
        }
        expect(changed.grid, expected);
        expect([changed.x - 25, changed.y - 43], item['nudge']);
        expect(result.delta.partyClassId, isNull);
        expect(result.delta.sourceEtcWrites, isEmpty);
        expect(result.delta.setFlags, isEmpty);
        if (code == 0) {
          final calm = result.continuation!;
          expect(calm.pendingScene!.lines, source['victoryLines']);
          expect(calm.outcome.since(battle.outcome).tileChanges, [
            for (final w in source['corridorWrites'] as List<dynamic>)
              (
                map: null,
                x: w[0] as int,
                y: w[1] as int,
                tile: w[2] as int,
                ifZero: null,
              ),
          ]);
          final guides = calm.acknowledgeScene();
          expect(guides.pendingScene!.actors, item['guideActors']);
          expect(guides.pendingScene!.lines, source['guideLines']);
          expect(guides.outcome.since(calm.outcome).tileOperations, isEmpty);
          expect(guides.outcome.partyClassId, isNull);
          final finish = guides.acknowledgeScene();
          expect(
            finish.outcome.since(guides.outcome).partyClassId,
            item['promotionClass'],
          );
          expect(finish.hasPendingScene, isFalse);
          expect(finish.awaitingBattle, isFalse);
        } else {
          expect(result.continuation?.hasPendingScene ?? false, isFalse);
          expect(result.delta.messages, isEmpty);
        }
      }
    },
  );

  test('promotion changes named slots 1..6 only, including dead members; slot 7 stays intact', () {
    final party = [
      for (var slot = 1; slot <= 7; slot++) PartyMember.createPreset(1),
    ];
    party[1].name = '';
    party[3].dead = 1;
    final before = [for (final member in party) member.toJson()];
    var run = start().acknowledgeScene().continueAfterBattle();
    run = run.acknowledgeScene();
    expect(
      ScriptPartyReducer.applyProgress(
        party,
        run.outcome,
      ).map((p) => p.toJson()).toList(),
      before,
    );
    final reward = run.acknowledgeScene().outcome.since(run.outcome);
    final after = ScriptPartyReducer.applyProgress(party, reward);
    for (var i = 0; i < 7; i++) {
      expect(after[i].toJson(), {
        ...before[i],
        if (i < 6 && party[i].name.isNotEmpty) 'classId': 10,
      });
      expect(party[i].toJson(), before[i]);
    }
  });

  test('greeting reads the current first slot at presentation, retaining empty/duplicate slots', () {
    final guide = start()
        .acknowledgeScene()
        .continueAfterBattle()
        .acknowledgeScene()
        .pendingScene!;
    expect(
      guide.withPartyNames(['새 동료', '기존 대원']).lines.first,
      ' 매우 수고하시는군요. 새 동료',
    );
    expect(guide.withPartyNames(['', '둘째 대원']).lines.first, ' 매우 수고하시는군요. ');
    expect(
      guide.withPartyNames(['같은 이름', '같은 이름']).lines.first,
      ' 매우 수고하시는군요. 같은 이름',
    );
    expect(guide.lines.first, source['guideLines'][0]);
  });

  test('saved floor suppresses revisits, while stale clear flags/consumption never suppress a source trigger', () async {
    final manager = LoreDialogueManager.instance;
    manager.loadFlags({});
    addTearDown(() => manager.loadFlags({}));
    final engine = LegacyJsonFixtureEngine(random: NoGuardianRandom());
    engine.consumedScripts.add('keep3-metal-guardian-y43');
    final battle = start(
      engine: engine,
      flags: {'keep3MetalGuardianCleared'},
    ).acknowledgeScene();
    final victory = battle.continueAfterBattle();
    final original = await LoreMapData.loadFromAsset('K_DEN2', category: 'den');
    final afterMap = ScriptWorldReducer.applyMap(
      ScriptMapState(
        mapId: 25,
        x: 25,
        y: 43,
        direction: 1,
        grid: original.grid,
      ),
      victory.outcome.since(battle.outcome),
    );
    final promoted = victory.acknowledgeScene().acknowledgeScene();
    final party = ScriptPartyReducer.applyProgress([
      PartyMember.createPreset(1),
    ], promoted.outcome);
    final save = SaveData.fromJson(
      jsonDecode(
        jsonEncode(
          SaveData(
            slot: 1,
            slotName: '수호자 격파',
            timestamp: DateTime.utc(1993),
            mapId: 25,
            mapTitle: 'CASTLE KEEP',
            playerX: 25,
            playerY: 43,
            gold: 100,
            food: 20,
            party: party,
            flags: {'etc1': 1, 'keep3MetalGuardianCleared': true},
            mapTiles: afterMap.grid.expand((row) => row).toList(),
          ).toJson(),
        ),
      ) as Map<String, dynamic>,
    );
    original.applyTileSnapshot(save.mapTiles);
    manager.loadFlags(save.flags);
    expect(save.party.single.playerClass, PlayerClass.demigod);
    expect(manager.partyEtc.read(1), 1);
    final result = LoreSpecialEventDispatcher.resolve(
      action: LoreTileAction.special,
      mapId: 25,
      x: 25,
      y: 43,
      context: ScriptContext(
        tileAtPlayer: original.getTile(25, 43),
        flags: manager
            .getFlagsCopy()
            .entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toSet(),
      ),
      party: save.party,
      scripts: engine,

    );
    expect(result.script, isNull);

    expect(
      start(
        engine: engine,
        flags: {'keep3MetalGuardianCleared'},
      ).hasPendingScene,
      isTrue,
    );
  });

  test(
    'JSON presence does not change direct guardian ownership or source stages',
    () {
      for (final json in [false, true]) {
        final engine = LegacyJsonFixtureEngine(random: NoGuardianRandom());
        if (json) {
          engine.loadFromJson(
            File('test/fixtures/legacy_rules/scripts.json').readAsStringSync(),
          );
        }
        final result = LoreSpecialEventDispatcher.resolve(
          action: LoreTileAction.special,
          mapId: 25,
          x: 25,
          y: 43,
          context: const ScriptContext(tileAtPlayer: 52, sourceEtc: {1: 0}),
          party: const [],
          scripts: engine,

        );

        expect(result.script!.pendingScene!.lines, source['introLines']);
        expect(
          result.script!.acknowledgeScene().outcome.battleMonsters,
          source['battleMonsters'],
        );
      }
    },
  );
}
