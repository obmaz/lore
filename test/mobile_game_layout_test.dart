import 'package:flame/game.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lore/widgets/game_screen_layout.dart';
import 'package:flutter/services.dart';
import 'package:lore/widgets/field_action_bar.dart';
import 'package:lore/widgets/quick_view_dialog.dart';
import 'package:lore/widgets/esp_dialog.dart';
import 'package:lore/widgets/field_menu_dialog.dart';
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
      expect(
        tester.widget<MessageLogView>(find.byType(MessageLogView)).logs,
        isEmpty,
      );
      expect(find.textContaining('좌표:'), findsNothing);
      expect(find.textContaining('Flutter Engine'), findsNothing);
      final viewport = tester.getRect(find.byType(ViewportView));
      final game = tester.getSize(find.byType(GameWidget<LoreGame>));
      final party = tester.getRect(find.byType(PartyStatusView));
      final messages = tester.getRect(find.byType(MessageLogView));
      expect(viewport.left, 0);
      expect(viewport.width, 390);
      expect(viewport.height, 390);
      expect(game.width, game.height);
      final actions = tester.getRect(find.byType(FieldActionBar));
      expect(actions.top, greaterThanOrEqualTo(viewport.bottom));
      expect(party.top, greaterThanOrEqualTo(actions.bottom));
      expect(actions.height, greaterThanOrEqualTo(44));
      expect(
        find.descendant(
          of: find.byType(ViewportView),
          matching: find.byType(FieldActionBar),
        ),
        findsNothing,
      );
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
      final side = math.min(size.width, size.height - 256);
      expect(viewport.width, side);
      expect(viewport.height, side);
      expect(find.byKey(const ValueKey('panel-tab-party')), findsOneWidget);
      final messages = tester.getRect(find.byType(MessageLogView));
      final actions = tester.getRect(find.byType(FieldActionBar));
      expect(actions.top, greaterThanOrEqualTo(viewport.bottom));
      expect(messages.top, greaterThanOrEqualTo(actions.bottom));
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
    final actions = tester.getRect(find.byType(FieldActionBar));
    final map = tester.getRect(find.byType(ViewportView));
    expect(actions.left, greaterThanOrEqualTo(map.right));
    expect(actions.top, map.top);
    final menu = tester.getRect(
      find.byKey(const ValueKey('field-action-menu')),
    );
    final status = tester.getRect(
      find.byKey(const ValueKey('field-action-status')),
    );
    final esp = tester.getRect(
      find.byKey(const ValueKey('field-action-extrasense')),
    );
    expect(status.top, greaterThanOrEqualTo(menu.bottom));
    expect(esp.top, greaterThanOrEqualTo(status.bottom));
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
  testWidgets('moved field commands open dialogs and restore keyboard input', (
    tester,
  ) async {
    await openGame(tester, const Size(390, 844));
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tester.tap(find.byKey(const ValueKey('field-action-status')));
    await settle();
    expect(find.byType(QuickViewDialog), findsOneWidget);
    expect(find.text('중독'), findsOneWidget);
    expect(find.text('죽음'), findsOneWidget);
    expect(find.textContaining('QUICK VIEW'), findsNothing);
    await tester.tap(find.text('확인'));
    await settle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle();
    expect(find.byType(FieldMenuDialog), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await settle();
    await tester.tap(find.byKey(const ValueKey('field-action-extrasense')));
    await settle();
    expect(find.byType(EspDialog), findsOneWidget);
    expect(find.textContaining('EXTRASENSE'), findsNothing);
    expect(find.textContaining('Clairvoyance'), findsNothing);
    expect(find.textContaining('소모 ESP'), findsNothing);
    await tester.tap(find.text('닫기'));
    await settle();
    await tester.tap(find.byKey(const ValueKey('field-action-menu')));
    await settle();
    expect(find.byType(FieldMenuDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
