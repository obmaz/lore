import 'dart:async';

import 'support/source_audio_platform.dart';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/widgets/dpad_widget.dart';
import 'package:lore/widgets/message_log_view.dart';
import 'package:lore/widgets/viewport_view.dart';
import 'package:lore/widgets/mobile_viewport_gate.dart';

Future<void> openGame(WidgetTester tester, Size size) async {
  installSourceAudioPlatform();
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
  for (final size in [
    const Size(320, 480),
    const Size(320, 1280 / 3),
    const Size(768, 1024),
    const Size(390, 844),
    const Size(360, 780),
  ]) {
    testWidgets('mobile square map and dedicated RIGHT keypad at $size', (
      tester,
    ) async {
      await openGame(tester, size);
      final viewport = tester.getRect(find.byType(ViewportView));
      final map = tester.getSize(find.byType(GameWidget<LoreGame>));
      final messages = tester.getRect(find.byType(MessageLogView));
      final pad = tester.getRect(find.byType(DPadWidget));
      final menu = tester.getRect(find.byKey(const ValueKey('field-menu')));
      expect(viewport.width, closeTo(viewport.height, .01));
      expect(map.width, closeTo(map.height, .01));
      expect(viewport.top, greaterThan(0));
      expect(pad.left, greaterThanOrEqualTo(menu.right));
      expect(pad.top, greaterThanOrEqualTo(messages.bottom));
      expect(pad.bottom, lessThanOrEqualTo(size.height));
      expect(viewport.overlaps(pad), isFalse);
      expect(messages.overlaps(pad), isFalse);
      for (final icon in [
        Icons.arrow_drop_up,
        Icons.arrow_left,
        Icons.arrow_right,
        Icons.arrow_drop_down,
      ]) {
        final box = tester.getSize(
          find
              .ancestor(of: find.byIcon(icon), matching: find.byType(Listener))
              .first,
        );
        expect(box.width, greaterThanOrEqualTo(48));
        expect(box.height, greaterThanOrEqualTo(48));
      }
      // Read-only panels never replace or move the map, and dismiss on back.
      await tester.tap(find.byKey(const ValueKey('panel-tab-party')));
      await tester.pump(const Duration(milliseconds: 350));
      Navigator.of(tester.element(find.byType(MainGameScreen))).pop();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.getRect(find.byType(ViewportView)), viewport);
      final game = tester
          .widget<GameWidget<LoreGame>>(find.byType(GameWidget<LoreGame>))
          .game!;
      game.currentMap = LoreMapData(
        name: 'TEST',
        xmax: 20,
        ymax: 20,
        grid: List.generate(20, (_) => List.filled(20, 42)),
      );
      game.playerX = 6;
      game.playerY = 6;
      await tester.tap(find.byIcon(Icons.arrow_right));
      await tester.pump();
      expect((game.playerX, game.playerY), (7, 6));
      expect(tester.takeException(), isNull);
    });
  }

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

  test('game canvas fits every viewport within the portrait aspect range', () {
    for (final viewport in [
      const Size(768, 1024),
      const Size(360, 780),
      const Size(390, 844),
      const Size(844, 390),
      const Size(600, 600),
      const Size(360, 900),
      const Size(1280, 900),
    ]) {
      final canvas = MobileViewportGate.contentSize(viewport);
      expect(canvas.width, lessThanOrEqualTo(viewport.width));
      expect(canvas.height, lessThanOrEqualTo(viewport.height));
      expect(canvas.height / canvas.width, greaterThanOrEqualTo(4 / 3 - 1e-9));
      expect(canvas.height / canvas.width, lessThanOrEqualTo(19.5 / 9 + 1e-9));
      expect(
        canvas.width == viewport.width || canvas.height == viewport.height,
        isTrue,
      );
    }
    expect(
      MobileViewportGate.contentSize(const Size(844, 390)),
      const Size(292.5, 390),
    );
    expect(
      MobileViewportGate.contentSize(const Size(600, 600)),
      const Size(450, 600),
    );
    expect(
      MobileViewportGate.contentSize(const Size(360, 900)),
      const Size(360, 780),
    );
  });

  testWidgets(
    'resize stops a held keypad and keeps the same game playable on every screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
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
      await tester.pumpWidget(
        const MaterialApp(builder: gateBuilder, home: MainGameScreen()),
      );
      final finder = find.byType(GameWidget<LoreGame>);
      await tester.runAsync(
        () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
      );
      await tester.pump();
      final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
      game.currentMap = LoreMapData(
        name: 'TEST',
        xmax: 40,
        ymax: 40,
        grid: List.generate(40, (_) => List.filled(40, 42)),
      );
      game.playerX = 6;
      game.playerY = 6;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.arrow_right)),
      );
      expect(game.playerX, 7);
      tester.view.physicalSize = const Size(600, 600);
      await tester.pump();
      await tester.pump(DPadWidget.repeatDelay + DPadWidget.repeatInterval * 5);
      expect(game.playerX, 7);
      await gesture.up();
      for (final screen in [
        const Size(600, 600),
        const Size(844, 390),
        const Size(360, 900),
        const Size(1280, 900),
        const Size(390, 844),
      ]) {
        tester.view.physicalSize = screen;
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('unsupported-aspect-ratio')),
          findsNothing,
        );
        final frame = tester.getRect(
          find.byKey(const ValueKey('mobile-game-frame')),
        );
        expect(frame.size, MobileViewportGate.contentSize(screen));
        expect(frame.center, Offset(screen.width / 2, screen.height / 2));
        expect(tester.widget<GameWidget<LoreGame>>(finder).game, same(game));
        final at = game.playerX;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(game.playerX, at + 1);
        final afterKey = game.playerX;
        await tester.tap(find.byIcon(Icons.arrow_right));
        await tester.pump();
        expect(game.playerX, afterKey + 1);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

Widget gateBuilder(BuildContext context, Widget? child) =>
    MobileViewportGate(child: child!);
