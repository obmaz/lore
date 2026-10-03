import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_join.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';

/// LORESPEC.PAS:600-640 (map 12 Rigel) with LORESUB.PAS `ReturnJoinMember`:
/// refusing the slot runs `dec(y); scroll(TRUE); exit` and nothing else.
void main() {
  Future<LoreGame> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      LoreDialogueManager.instance.loadFlags({});
      LoreScriptEngine.instance.resetForTest();
      LoreWorldManager.instance.resetRulesForTest();
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    void silence(String channel) => messenger.setMockStreamHandler(
      EventChannel(channel),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    silence('xyz.luan/audioplayers.global/events');
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          silence(
            'xyz.luan/audioplayers/events/${(call.arguments as Map)['playerId']}',
          );
        }
        return 1;
      },
    );
    final map = await LoreMapData.loadFromAsset('T_DEN2', category: 'den');
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          initialSaveData: SaveData(
            slot: 1,
            slotName: 'Rigel',
            timestamp: DateTime.utc(1993),
            mapId: 12,
            mapTitle: 'T_DEN2',
            playerX: 12,
            playerY: 47,
            gold: 100,
            food: 20,
            party: [PartyMember.createPreset(1), PartyMember.createPreset(3)],
            flags: const {'etc31': 0, 'etc1': 3},
            mapTiles: map.tileSnapshot(),
          ),
        ),
      ),
    );
    final finder = find.byType(GameWidget<LoreGame>);
    final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
    await tester.runAsync(
      () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
    );
    await tester.pump();
    return game;
  }

  Future<void> tick(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('refusing the Rigel slot moves y - 1 without asyouwish', (
    tester,
  ) async {
    final game = await open(tester);
    game.tryMove(0, 1);
    await tick(tester);
    expect([game.playerX, game.playerY], [12, 48]);
    // PressAnyKey after the first two lines.
    while (find
        .byKey(const ValueKey('script-scene-continue'))
        .evaluate()
        .isNotEmpty) {
      await tester.tap(
        find.byKey(const ValueKey('script-scene-continue')).last,
      );
      await tick(tester);
    }
    await tester.tap(find.text('좋소, 같이 모험을 합시다'));
    await tick(tester);
    expect(find.text(LoreJoin.joinMenuPrompt), findsOneWidget);
    // m[1..5] = player[2..6].name, m[5] = '보조 일원으로 둠' (no slot numbers).
    expect(find.text(PartyMember.createPreset(3).name), findsWidgets);
    expect(find.text(LoreJoin.reserveSlotLabel), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tick(tester);
    await tick(tester);
    expect(find.text(LoreJoin.joinMenuPrompt), findsNothing);
    expect([game.playerX, game.playerY], [12, 47]);
    expect(find.textContaining(LoreJoin.joinCancelled), findsNothing);
    expect(LoreDialogueManager.instance.partyEtc.read(31) & 2, 0);
  });
}
