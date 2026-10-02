import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/widgets/dpad_widget.dart';
import 'package:lore/widgets/message_log_view.dart';
import 'package:lore/widgets/party_status_view.dart';
import 'package:lore/widgets/viewport_view.dart';

Future<void> openGame(WidgetTester tester, Size size) async {
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
  await tester.pumpWidget(const MaterialApp(home: MainGameScreen()));
  final state = tester.state<GameWidgetState<LoreGame>>(
    find.byType(GameWidget<LoreGame>),
  );
  await tester.runAsync(() => state.loaderFuture);
  await tester.pump();
}

void main() {
  testWidgets(
    'portrait fills width with a square map above party and dialogue',
    (tester) async {
      await openGame(tester, const Size(390, 844));
      final viewport = tester.getRect(find.byType(ViewportView));
      final game = tester.getSize(find.byType(GameWidget<LoreGame>));
      final party = tester.getRect(find.byType(PartyStatusView));
      final messages = tester.getRect(find.byType(MessageLogView));
      expect(viewport.left, 0);
      expect(viewport.width, 390);
      expect(viewport.height, 390);
      expect(game.width, game.height);
      expect(party.top, greaterThanOrEqualTo(viewport.bottom));
      expect(messages.top, greaterThan(party.bottom));
      expect(messages.bottom, 844);
      expect(find.byType(TabBar), findsNothing);

      final pad = tester.getRect(find.byType(DPadWidget));
      expect(messages.contains(pad.topLeft), isTrue);
      expect(messages.contains(pad.bottomRight), isTrue);
      expect(pad.center.dx, greaterThan(messages.center.dx));
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byType(DPadWidget),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, .6);
      final log = tester.widget<MessageLogView>(find.byType(MessageLogView));
      expect(log.controlsInset, greaterThanOrEqualTo(pad.width));

      // The translucent overlay still receives movement taps.
      final engine = tester
          .widget<GameWidget<LoreGame>>(find.byType(GameWidget<LoreGame>))
          .game!;
      engine.currentMap = LoreMapData(
        name: 'TEST',
        xmax: 20,
        ymax: 20,
        grid: List.generate(20, (_) => List.filled(20, 42)),
      );
      engine.playerX = 6;
      engine.playerY = 6;
      await tester.tap(find.byIcon(Icons.arrow_right));
      await tester.pump();
      expect((engine.playerX, engine.playerY), (7, 6));
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 480), const Size(768, 1024)]) {
    testWidgets('4:3 portrait $size shares character/dialogue tabs', (
      tester,
    ) async {
      await openGame(tester, size);
      final viewport = tester.getRect(find.byType(ViewportView));
      expect(viewport.width, size.width);
      expect(viewport.height, size.width);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(MessageLogView), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, '캐릭터'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(PartyStatusView), findsOneWidget);
      expect(tester.getRect(find.byType(ViewportView)), viewport);
      await tester.tap(find.widgetWithText(Tab, '대화'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(DPadWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('square screens keep usable panels instead of overflowing', (
    tester,
  ) async {
    await openGame(tester, const Size(600, 600));
    expect(find.byType(TabBar), findsOneWidget);
    final viewport = tester.getSize(find.byType(ViewportView));
    expect(viewport.width, viewport.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rotation keeps a square map and usable tabs without overflow', (
    tester,
  ) async {
    await openGame(tester, const Size(390, 844));
    final before = tester
        .widget<GameWidget<LoreGame>>(find.byType(GameWidget<LoreGame>))
        .game!;
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    final game = tester
        .widget<GameWidget<LoreGame>>(find.byType(GameWidget<LoreGame>))
        .game!;
    expect(game, same(before));
    final viewport = tester.getSize(find.byType(ViewportView));
    expect(viewport.width, viewport.height);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(DPadWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
