import 'dart:async';

import 'package:flame/game.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lore/widgets/game_screen_layout.dart';
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
      expect(
        party.height,
        greaterThanOrEqualTo(GameScreenLayout.minimumPartyHeight),
      );
      expect(
        messages.height,
        greaterThanOrEqualTo(GameScreenLayout.minimumMessagesHeight),
      );
      expect(messages.top, greaterThan(party.bottom));
      expect(messages.bottom, 844);
      expect(find.byKey(const ValueKey('panel-tab-party')), findsNothing);

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

  testWidgets(
    'holding the pad walks on, and a dialog pushed on top cancels the hold',
    (tester) async {
      await openGame(tester, const Size(390, 844));
      final engine = tester
          .widget<GameWidget<LoreGame>>(find.byType(GameWidget<LoreGame>))
          .game!;
      engine.currentMap = LoreMapData(
        name: 'TEST',
        xmax: 40,
        ymax: 40,
        grid: List.generate(40, (_) => List.filled(40, 42)),
      );
      engine.playerX = 6;
      engine.playerY = 6;
      final hold = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.arrow_right)),
      );
      expect(engine.playerX, 7); // at once
      await tester.pump(DPadWidget.repeatDelay);
      expect(engine.playerX, 8);
      await tester.pump(DPadWidget.repeatInterval * 4);
      expect(engine.playerX, 12);
      // Pushing a route cancels the active pointers (Navigator), which ends the
      // repeat: nothing moves under a dialog or a source `Select` window.
      final context = tester.element(find.byType(MainGameScreen));
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(content: Text('window')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final at = engine.playerX;
      await tester.pump(DPadWidget.repeatInterval * 5);
      expect(engine.playerX, at);
      await hold.up();
      Navigator.of(context).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 480),
    const Size(768, 1024),
    const Size(390, 480),
    const Size(980, 1100),
  ]) {
    testWidgets('4:3 portrait $size shares character/dialogue tabs', (
      tester,
    ) async {
      await openGame(tester, size);
      final viewport = tester.getRect(find.byType(ViewportView));
      // Includes the 40px command row outside the square map.
      final side = math.min(size.width, size.height - 244);
      expect(viewport.width, side);
      expect(viewport.height, side);
      expect(find.byKey(const ValueKey('panel-tab-party')), findsOneWidget);
      final messages = tester.getRect(find.byType(MessageLogView));
      expect(messages.top, greaterThanOrEqualTo(viewport.bottom));
      expect(messages.height, greaterThanOrEqualTo(200));
      final tab = tester.getRect(find.byKey(const ValueKey('panel-tab-party')));
      expect(tab.right, lessThanOrEqualTo(messages.left));
      final pad = tester.getRect(find.byType(DPadWidget));
      expect(find.byType(MessageLogView), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('panel-tab-party')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(PartyStatusView), findsOneWidget);
      expect(
        tester.getRect(find.byType(PartyStatusView)).height,
        greaterThanOrEqualTo(200),
      );
      expect(find.byType(DPadWidget), findsOneWidget);
      expect(tester.getRect(find.byType(DPadWidget)), pad);
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
      expect(tester.getRect(find.byType(DPadWidget)), pad);
      expect(tester.getRect(find.byType(ViewportView)), viewport);
      await tester.tap(find.byKey(const ValueKey('panel-tab-dialogue')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(DPadWidget), findsOneWidget);
      expect(tester.getRect(find.byType(DPadWidget)), pad);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('square screens keep usable panels instead of overflowing', (
    tester,
  ) async {
    await openGame(tester, const Size(600, 600));
    expect(find.byKey(const ValueKey('panel-tab-party')), findsOneWidget);
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
    expect(
      tester.getRect(find.byType(MessageLogView)).top,
      greaterThanOrEqualTo(tester.getRect(find.byType(ViewportView)).bottom),
    );
    expect(
      tester.getRect(find.byType(MessageLogView)).height,
      greaterThanOrEqualTo(200),
    );
    expect(find.byKey(const ValueKey('panel-tab-party')), findsOneWidget);
    expect(find.byType(DPadWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
