import 'support/source_audio_platform.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';

// LORESUB.PAS Display_Condition and LOREMAIN.PAS Move_Mode:
// rendering must not silently run ReturnCondition before source call sites.
void main() {
  setUp(installSourceAudioPlatform);
  testWidgets('field log repaint leaves condition counters untouched', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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
    final hero = PartyMember.createPreset(1);
    await tester.pumpWidget(
      MaterialApp(home: MainGameScreen(initialParty: [hero])),
    );
    final gameFinder = find.byType(GameWidget<LoreGame>);
    await tester.runAsync(
      () => tester.state<GameWidgetState<LoreGame>>(gameFinder).loaderFuture,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    hero.hp = -1;
    hero.unconscious = 0;
    hero.dead = 0;
    tester.widget<GameWidget<LoreGame>>(gameFinder).game!.onLog?.call('');
    await tester.pump();
    expect((hero.hp, hero.unconscious, hero.dead), (-1, 0, 0));
    await tester.pumpWidget(const SizedBox());
  });
  // LORESPEC.PAS:222-230: the sixth-slot desertion waits before BattleMode.
  testWidgets(
    'Mad Joe desertion is shown and acknowledged before prison battle',
    (tester) async {
      for (final channel in [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
      }
      addTearDown(() => LoreDialogueManager.instance.loadFlags({}));
      final info = LoreWorldManager.mapRegistry[6]!;
      final map = await LoreMapData.loadFromAsset(
        info.fileName,
        category: info.category.name,
      );
      map.setTile(51, 12, 0);
      final party = [for (var i = 0; i < 6; i++) PartyMember.createPreset(1)];
      party[5].name = 'Mad Joe';
      await tester.pumpWidget(
        MaterialApp(
          home: MainGameScreen(
            initialSaveData: SaveData(
              slot: 1,
              slotName: 'Prison',
              timestamp: DateTime.utc(1993),
              mapId: 6,
              mapTitle: info.title,
              playerX: 51,
              playerY: 13,
              gold: 100,
              food: 20,
              party: party,
              flags: const {'etc50': 2},
              mapTiles: map.tileSnapshot(),
            ),
          ),
        ),
      );
      final game = find.byType(GameWidget<LoreGame>);
      await tester.runAsync(
        () => tester.state<GameWidgetState<LoreGame>>(game).loaderFuture,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final activeParty = tester
          .widget<GameWidget<LoreGame>>(game)
          .game!
          .partyProvider!();
      // An unrelated member needs ReturnCondition only at the desertion boundary.
      activeParty[0].hp = -1;
      activeParty[0].unconscious = 0;
      activeParty[0].dead = 0;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      for (
        var i = 0;
        i < 20 && find.textContaining('배신하고').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.textContaining('배신하고'), findsWidgets);
      expect(activeParty[5].name, 'Mad Joe');
      expect(activeParty[0].unconscious, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      for (
        var i = 0;
        i < 20 && find.textContaining('도망을').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.textContaining('도망을'), findsWidgets);
      expect(activeParty[5].name, '');
      expect(activeParty[0].unconscious, 1);
      expect(party[5].name, 'Mad Joe'); // Input save DTO remains independent.
      expect(find.byType(BattleViewportView), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(BattleViewportView), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
