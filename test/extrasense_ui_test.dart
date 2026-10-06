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
import 'package:lore/services/audio_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LOREMENU.PAS `Extrasense` on the game screen: 투시 blanks the special
/// cells while its text waits for a key; 천리안 scrolls the view and Esc ends it.
void main() {
  Future<LoreGame> open(WidgetTester tester, PartyMember esper) async {
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
            party: [esper],
            flags: const {},
            mapTiles: List.filled(100 * 100, 44),
          ),
        ),
      ),
    );
    final finder = find.byType(GameWidget<LoreGame>);
    final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
    await tester.runAsync(
      () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
    );
    await tester.pump(const Duration(milliseconds: 300));
    return game;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pickKind(WidgetTester tester, String name) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await settle(tester);
    await tester.tap(find.text(PartyMember.createPreset(3).name).last);
    await settle(tester);
    await tester.tap(find.text(name));
    await settle(tester);
  }

  testWidgets('투시 blanks the special cells until the key', (tester) async {
    final esper = PartyMember.createPreset(3)
      ..playerClass = PlayerClass.esper
      ..esp = 30;
    final game = await open(tester, esper);
    await pickKind(tester, '투시');
    expect(game.seeThroughSpecial, isTrue);
    expect(find.text(LoreMenuText.espSeeThrough), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(game.seeThroughSpecial, isFalse);
    expect(esper.esp, 20);
  });

  testWidgets('천리안 scrolls the view per key and Esc restores it', (
    tester,
  ) async {
    final esper = PartyMember.createPreset(3)
      ..playerClass = PlayerClass.esper
      ..esp = 100
      ..espLevel = 4;
    final game = await open(tester, esper);
    await pickKind(tester, '천리안');
    await tester.tap(find.text('북쪽${LoreMenuText.espClairvoyanceUse}'));
    await settle(tester);
    expect(find.text(LoreMenuText.espClairvoyanceBusy), findsOneWidget);
    expect([game.viewCenterX, game.viewCenterY], [50, 49]);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect([game.viewCenterX, game.viewCenterY], [50, 48]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text(LoreMenuText.espClairvoyanceBusy), findsNothing);
    expect([game.viewCenterX, game.viewCenterY], [50, 50]);
    expect(esper.esp, 80);
  });
  testWidgets(
    'closing the clairvoyance route keeps the game route and restores sound',
    (tester) async {
      final audio = AudioManager.instance;
      audio.sourceSoundEnabled = true;
      addTearDown(() => audio.sourceSoundEnabled = true);
      final esper = PartyMember.createPreset(3)
        ..playerClass = PlayerClass.esper
        ..esp = 100
        ..espLevel = 4;
      final game = await open(tester, esper);
      await pickKind(tester, '천리안');
      await tester.tap(find.text('북쪽${LoreMenuText.espClairvoyanceUse}'));
      await settle(tester);
      expect(audio.sourceSoundEnabled, isFalse);
      Navigator.of(tester.element(find.byType(MainGameScreen))).pop();
      await settle(tester);
      expect(audio.sourceSoundEnabled, isTrue);
      expect(find.byType(MainGameScreen), findsOneWidget);
      expect([game.viewCenterX, game.viewCenterY], [50, 50]);
      expect(tester.takeException(), isNull);
    },
  );

  for (final soundEnabled in [true, false]) {
    testWidgets(
      'disposing clairvoyance restores previous sound $soundEnabled',
      (tester) async {
        final audio = AudioManager.instance;
        audio.sourceSoundEnabled = soundEnabled;
        addTearDown(() => audio.sourceSoundEnabled = true);
        final esper = PartyMember.createPreset(3)
          ..playerClass = PlayerClass.esper
          ..esp = 100
          ..espLevel = 4;
        final game = await open(tester, esper);
        await pickKind(tester, '천리안');
        await tester.tap(find.text('북쪽${LoreMenuText.espClairvoyanceUse}'));
        await settle(tester);
        expect(audio.sourceSoundEnabled, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(audio.sourceSoundEnabled, soundEnabled);
        expect([game.viewCenterX, game.viewCenterY], [50, 50]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
