import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/logic/lore_game_over.dart';
import 'package:lore/logic/lore_sub_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/dpad_widget.dart';
import 'package:lore/widgets/encounter_viewport_view.dart';
import 'package:lore/widgets/game_over_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scripted `LoreGameOverIo`: answers selects in order and records the screen.
class _Io implements LoreGameOverIo {
  _Io(this.answers, {this.saves = const {1, 2, 3, 4}});
  final List<int> answers;
  final Set<int> saves;
  final List<String> trace = [];

  @override
  void clear() => trace.add('clear');

  @override
  void print(int color, String text) => trace.add('$color:$text');

  @override
  Future<void> pressAnyKey() async => trace.add('key');

  @override
  Future<int> select(
    String title,
    List<String> items, {
    required bool clean,
  }) async {
    trace.add('select:$title:${items.length}:$clean');
    return answers.removeAt(0);
  }

  @override
  Future<bool> load(int slot) async {
    trace.add('load:$slot');
    return saves.contains(slot);
  }
}

class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// LORESUB.PAS `GameOver` / `DetectGameOver` and the LOREBATT defeat call.
void main() {
  group('GameOver procedure', () {
    test(
      'etc[6] = 255: wiped-out text, key, load list; slot k-1 reloads',
      () async {
        final io = _Io([3]);
        final result = await LoreGameOver.run(255, io);
        expect(result.end, LoreGameOverEnd.reloaded);
        expect(result.etc6, isNull);
        expect(io.trace, [
          'clear',
          '13:${LoreSubText.allDead}',
          'key',
          'select:${LoreSubText.selectLoadGame}:5:true',
          '11:${LoreSubText.loadingGame}',
          'load:2',
          'clear',
        ]);
      },
    );

    test(
      'etc[6] = 255 with 없습니다 falls to the quit question; 아니오 returns',
      () async {
        final io = _Io([1, 1]);
        final result = await LoreGameOver.run(255, io);
        expect(result.end, LoreGameOverEnd.resumed);
        expect(io.trace.sublist(4), [
          '10:${LoreSubText.quitConfirm}',
          'select::2:false',
        ]);
        expect(
          (await LoreGameOver.run(255, _Io([0, 2]))).end,
          LoreGameOverEnd.halted,
        );
      },
    );

    test(
      'etc[6] = 1: defeat text, resume picks a slot and sets etc[6] := 255',
      () async {
        final io = _Io([1, 2]);
        final result = await LoreGameOver.run(1, io);
        expect(result.end, LoreGameOverEnd.reloaded);
        expect(result.etc6, 255);
        expect(io.trace, [
          'clear',
          '13:${LoreSubText.battleLost}',
          '10:${LoreSubText.battleLostAsk}',
          'select::2:false',
          'select:${LoreSubText.selectLoadGame}:5:true',
          '11:${LoreSubText.loadingGame}',
          'load:1',
          'clear',
        ]);
      },
    );

    test('etc[6] = 1: 끝낸다, Esc or 없습니다 halts', () async {
      for (final answers in [
        [2],
        [0],
        [1, 1],
        [1, 0],
      ]) {
        expect(
          (await LoreGameOver.run(1, _Io(answers))).end,
          LoreGameOverEnd.halted,
          reason: '$answers',
        );
      }
    });

    test('etc[6] = 0 (GameOption): only the quit question', () async {
      final io = _Io([2]);
      expect((await LoreGameOver.run(0, io)).end, LoreGameOverEnd.halted);
      expect(io.trace, ['10:${LoreSubText.quitConfirm}', 'select::2:false']);
    });

    test('a missing save halts through Load ErrorMessage', () async {
      final result = await LoreGameOver.run(1, _Io([1, 4], saves: {}));
      expect(result.end, LoreGameOverEnd.halted);
      expect(result.missingSlot, 3);
      expect(LoreGameOver.missingSaveLines(3), [
        '"party3.dat" not found.',
        'You need to CREATE CHARACTER.',
      ]);
    });
  });

  group('main screen', () {
    SaveData save(List<PartyMember> party, {int x = 50, int gold = 2000}) =>
        SaveData(
          slot: 1,
          slotName: SaveManager.slotNames.first,
          timestamp: DateTime.utc(1993, 7, 25),
          mapId: 1,
          mapTitle: 'GROUND 1',
          playerX: x,
          playerY: 50,
          gold: gold,
          food: 20,
          party: party,
          flags: const {},
          mapTiles: List.filled(100 * 100, 44),
          consumedScripts: const [],
        );

    Future<void> open(
      WidgetTester tester,
      SaveData start, {
      VoidCallback? onHalt,
    }) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        LoreDialogueManager.instance.loadFlags({});
      });
      for (final channel in [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: MainGameScreen(
            initialSaveData: start,
            encounterRandom: _ZeroRandom(),
            onHalt: onHalt,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> choose(WidgetTester tester, int k) async {
      await tester.tap(find.byKey(ValueKey('lore-select-$k')).last);
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'battle defeat → 이전의 게임을 재개한다 → 본 게임 데이타 reloads with etc[6] = 255',
      (tester) async {
        final saved = save([PartyMember.createPreset(3)], x: 40, gold: 777);
        SharedPreferences.setMockInitialValues({});
        await SaveManager.instance.saveGame(saved);
        await open(tester, save([PartyMember.createPreset(1)]));
        // A step on GROUND 1 with random 0 starts an encounter; engage it.
        tester
            .widget<DPadWidget>(find.byType(DPadWidget))
            .onDirectionPressed(1, 0);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('encounter-engage')));
        await tester.pump();
        tester
            .widget<BattleViewportView>(find.byType(BattleViewportView))
            .onDefeat();
        await tester.pump();
        await tester.pump();
        expect(find.byType(GameOverView), findsOneWidget);
        expect(find.text(LoreSubText.battleLost), findsOneWidget);
        expect(find.text(LoreSubText.allDead), findsNothing);
        await choose(tester, 1);
        expect(find.text(LoreSubText.selectLoadGame), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('lore-select-2')).last);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(find.byType(GameOverView), findsNothing);
        expect(find.byType(DPadWidget), findsOneWidget);
        expect(LoreDialogueManager.instance.lastBattleResult, 255);
        final game = tester
            .widget<GameWidget<LoreGame>>(find.byType(GameWidget<LoreGame>))
            .game!;
        expect(game.playerX, 40);
        expect(game.partyProvider!().map((m) => m.name), [
          PartyMember.createPreset(3).name,
        ]);
      },
    );

    testWidgets(
      'a wiped-out party: key, 없습니다, then << 아니오 >> returns to the field',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final dead = PartyMember.createPreset(1)..dead = 1;
        await open(tester, save([dead]));
        tester
            .widget<DPadWidget>(find.byType(DPadWidget))
            .onDirectionPressed(1, 0);
        await tester.pump();
        await tester.pump();
        expect(find.text(LoreSubText.allDead), findsOneWidget);
        expect(LoreDialogueManager.instance.lastBattleResult, 255);
        await tester.tap(find.byKey(const ValueKey('game-over-press-any-key')));
        await tester.pump();
        await tester.pump();
        await choose(tester, 1); // 없습니다
        expect(find.text(LoreSubText.quitConfirm), findsOneWidget);
        await choose(tester, 1); // << 아니오 >>
        await tester.pump();
        expect(find.byType(GameOverView), findsNothing);
      },
    );

    testWidgets('<< 예 >> halts with the source farewell text', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var halted = 0;
      final dead = PartyMember.createPreset(1)..dead = 1;
      await open(tester, save([dead]), onHalt: () => halted++);
      tester
          .widget<DPadWidget>(find.byType(DPadWidget))
          .onDirectionPressed(1, 0);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('game-over-press-any-key')));
      await tester.pump();
      await tester.pump();
      await choose(tester, 1);
      await choose(tester, 2); // << 예 >>
      expect(find.text(LoreGameOver.haltMessage), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(halted, 1);
      // `Halt` ends the program: Move_Mode never reaches its encounter roll
      // (random 0 would otherwise start an encounter).
      expect(find.byType(EncounterViewportView), findsNothing);
    });

    testWidgets('the keyboard alone drives PressAnyKey and both selects', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final dead = PartyMember.createPreset(1)..dead = 1;
      await open(tester, save([dead]));
      tester
          .widget<DPadWidget>(find.byType(DPadWidget))
          .onDirectionPressed(1, 0);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text(LoreSubText.allDead), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // PressAnyKey
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text(LoreSubText.selectLoadGame), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape); // k = 0
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text(LoreSubText.quitConfirm), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // wraps to 1
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // << 아니오 >>
      await tester.pump();
      await tester.pump();
      expect(find.byType(GameOverView), findsNothing);
    });

    testWidgets(
      'Load normalizes etc[7] to 1..3 (else 2) and etc[8] to 3..7 (else 5)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await open(tester, save([PartyMember.createPreset(1)]));
        final etc = LoreDialogueManager.instance.partyEtc;
        expect([etc.read(7), etc.read(8)], [2, 5]);
      },
    );
  });

  test('LORECRET Last writes the new party to all four slots', () async {
    SharedPreferences.setMockInitialValues({});
    final party = [PartyMember.createPreset(1), PartyMember.createPreset(3)];
    await SaveManager.instance.writeNewGame(party, mapTitle: 'CASTLE LORE');
    final slots = await SaveManager.instance.getAllSlots();
    for (var slot = 1; slot <= 4; slot++) {
      final save = slots[slot - 1]!;
      expect(save.slot, slot);
      expect(save.slotName, SaveManager.slotNames[slot - 1]);
      expect([save.mapId, save.playerX, save.playerY], [6, 51, 31]);
      expect([save.gold, save.food], [2000, 20]);
      expect(save.party.map((m) => m.name), party.map((m) => m.name));
      expect(save.flags, isEmpty);
      expect(save.etc, isEmpty);
      expect(save.mapTiles, isEmpty);
    }
  });
}
