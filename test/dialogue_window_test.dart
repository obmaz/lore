import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_dialogue_history.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/dialogue_history_view.dart';
import 'package:lore/widgets/game_screen_layout.dart';
import 'package:lore/widgets/message_log_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LORETALK.PAS `Print` lines + `PressAnyKey` as one dialogue window, and the
/// `이전 대화` tab that keeps them afterwards.
void main() {
  test('history keeps the lines of each speech unchanged and bounded', () {
    final history = LoreDialogueHistory();
    var notified = 0;
    history.addListener(() => notified++);
    history.add([' 안녕하시오.', '이었던 사람이오.']);
    history.add([]);
    history.add(['talk']);
    expect(history.blocks, [
      [' 안녕하시오.', '이었던 사람이오.'],
      ['talk'],
    ]);
    expect(notified, 2);
    for (var i = 0; i < LoreDialogueHistory.maxBlocks + 5; i++) {
      history.add(['$i']);
    }
    expect(history.blocks.length, LoreDialogueHistory.maxBlocks);
    expect(history.blocks.last, ['${LoreDialogueHistory.maxBlocks + 4}']);
  });

  testWidgets('the history view stacks each speech as one block', (
    tester,
  ) async {
    final history = LoreDialogueHistory()
      ..add(['첫째 줄', '둘째 줄'])
      ..add(['다음 대화']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DialogueHistoryView(history: history)),
      ),
    );
    expect(find.text('첫째 줄'), findsOneWidget);
    expect(find.text('둘째 줄'), findsOneWidget);
    expect(find.text('다음 대화'), findsOneWidget);
    // No bullets, no highlight on the newest block.
    expect(find.textContaining('▶'), findsNothing);
    expect(find.textContaining('·'), findsNothing);
    history.add(['새 대화']);
    await tester.pump();
    expect(find.text('새 대화'), findsOneWidget);
  });

  for (final size in [const Size(1280, 720), const Size(390, 844)]) {
    testWidgets('an NPC speech is one window, then lives in 이전 대화 ($size)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(() {
        LoreDialogueManager.instance.loadFlags({});
        LoreScriptEngine.instance.resetForTest();
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final channel in [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
      }
      // `main()` loads the data before `runApp`.
      await tester.runAsync(() async {
        await LoreScriptEngine.instance.load();
        await LoreWorldManager.instance.loadData();
        await LoreDialogueManager.instance.loadData();
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
              playerX: 63,
              playerY: 9,
              gold: 100,
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

      game.tryMove(0, 1); // the NPC at (63, 10)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      const first = ' 안녕하시오. 나는 한때 이 곳의 유명한 도둑';
      const last = '운을 빌겠소.';
      // One window with every line; nothing reaches the message log.
      expect(find.byKey(const ValueKey('lore-press-any-key')), findsOneWidget);
      expect(find.text(first), findsOneWidget);
      expect(find.text(last), findsOneWidget);
      expect(
        tester.widget<MessageLogView>(find.byType(MessageLogView)).logs,
        isEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('lore-press-any-key')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('lore-press-any-key')), findsNothing);
      // The log stays free of speech; the history tab has it.
      expect(
        tester.widget<MessageLogView>(find.byType(MessageLogView)).logs,
        isEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('panel-tab-history')).first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(first), findsOneWidget);
      expect(find.text(last), findsOneWidget);
      expect(find.text(GameScreenLayout.historyLabel), findsWidgets);
    });
  }
}
