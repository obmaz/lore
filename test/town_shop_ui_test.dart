import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LORESUB.PAS `Grocery` through the game screen's text window.
void main() {
  testWidgets('the grocery window sells food and leaves thankyou in the log', (
    tester,
  ) async {
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
            mapId: 6,
            mapTitle: 'TOWN 1',
            playerX: 51,
            playerY: 31,
            gold: 1000,
            food: 20,
            party: [PartyMember.createPreset(1)],
            flags: const {},
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

    game.onFacilityEntered!(4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('여기는 식료품점 입니다.'), findsOneWidget);
    expect(find.text('몇개를 원하십니까 ?'), findsOneWidget);
    await tester.tap(find.text('20 인분 : 금 200 개'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The window closes; thankyou stays in the message log.
    expect(find.text('몇개를 원하십니까 ?'), findsNothing);
    expect(find.text('매우 고맙습니다.', skipOffstage: false), findsOneWidget);
  });
}
