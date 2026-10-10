import 'support/source_audio_platform.dart';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LOREMENU.PAS `GameOption` on the game screen: SelectMode item 7 and the
/// G hotkey, item 5 (`Save`).
/// Returning from G runs Move_Mode; this menu regression excludes encounters.
class _NoEncounterRandom implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.99;
}

void main() {
  setUp(installSourceAudioPlatform);
  Future<void> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      LoreDialogueManager.instance.loadFlags({});
      LoreScriptEngine.instance.resetForTest();
    });
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          sourceReplayBattle: true,
          encounterRandom: _NoEncounterRandom(),
          initialSaveData: SaveData(
            slot: 1,
            slotName: SaveManager.slotNames.first,
            timestamp: DateTime.utc(1993),
            mapId: 1,
            mapTitle: 'GROUND 1',
            playerX: 50,
            playerY: 50,
            gold: 2000,
            food: 20,
            party: [PartyMember.createPreset(1)],
            flags: const {},
            mapTiles: List.filled(100 * 100, 44),
            consumedScripts: const ['session-only'],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Space -> item 7 runs the GameOption select', (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    await tester.tap(find.textContaining(LoreMenuText.selectModeOption));
    await settle(tester);
    expect(find.text(LoreMenuText.optionTitle), findsOneWidget);
    expect(find.text(LoreMenuText.optionQuit), findsOneWidget);
  });

  testWidgets(
    'difficulty can store encounter 4..5; the next map load makes it 2',
    (tester) async {
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await settle(tester);
      await tester.tap(find.text(LoreMenuText.optionDifficulty));
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape); // maxenemy -> 5
      await settle(tester);
      await tester.tap(find.text(LoreMenuText.optionEncounter1)); // 6 - 1
      await settle(tester);
      final etc = LoreDialogueManager.instance.partyEtc;
      expect([etc.read(7), etc.read(8)], [5, 5]);
      final game = tester
          .widget<GameWidget<LoreGame>>(find.byType(GameWidget<LoreGame>))
          .game!;
      await tester.runAsync(() => game.loadMapById(1));
      expect(etc.read(7), 2);
    },
  );

  testWidgets('G -> 5 -> slot saves the session history and etc bytes', (
    tester,
  ) async {
    await open(tester);
    final sourceEtc = LoreDialogueManager.instance.partyEtc;
    sourceEtc[3] = 29;
    sourceEtc[7] = 3;
    sourceEtc[8] = 7;

    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await settle(tester);
    expect(find.text(LoreMenuText.optionTitle), findsOneWidget);
    await tester.tap(find.text(LoreMenuText.optionSave));
    await settle(tester);
    expect(find.text(LoreMenuText.optionLoadPrompt), findsOneWidget);
    await tester.tap(find.text(SaveManager.slotNames.first));
    await settle(tester);
    expect(find.text(LoreMenuText.optionSaveDone), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text(LoreMenuText.optionSaveDone), findsNothing);

    final restored = await SaveManager.instance.loadGame(1);
    expect(restored?.consumedScripts, ['session-only']);
    expect(restored?.etc['swampWalkSteps'], 29);
    expect(restored?.etc['encounterFrequency'], 3);
    expect(restored?.flags['etc3'], 29);
    expect(restored?.flags['etc7'], 3);
    expect(restored?.flags['etc8'], 7);
    expect(
      [restored?.mapId, restored?.playerX, restored?.playerY],
      [1, 50, 50],
    );
  });
}
