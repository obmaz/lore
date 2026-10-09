import 'support/source_audio_platform.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/sprite_sheet.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/graphics_settings.dart';
import 'package:lore/widgets/app_settings_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(installSourceAudioPlatform);
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    testWidgets('app menu switches skins without advancing the field at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({});
      final sprites = SpriteLibrary.instance;
      sprites.resetForTest();
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        sprites.resetForTest();
        LoreDialogueManager.instance.loadFlags({});
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
      await tester.runAsync(() async {
        await sprites.activate(GraphicsSkin.crystal);
        await sprites.activate(GraphicsSkin.original);
      });
      final random = LoreRandom(12345);
      await tester.pumpWidget(
        MaterialApp(home: MainGameScreen(encounterRandom: random)),
      );
      final finder = find.byType(GameWidget<LoreGame>);
      final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
      await tester.runAsync(
        () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
      );
      await tester.pump(const Duration(milliseconds: 300));
      final map = game.currentMap!;
      final tiles = map.tileSnapshot();
      final flags = LoreDialogueManager.instance.getSaveFlags();
      final seed = random.seed;
      final position = (game.playerX, game.playerY, game.playerDirection);

      await tester.tap(find.byKey(const ValueKey('app-settings')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppSettingsDialog), findsOneWidget);
      for (final key in [
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.keyG,
        LogicalKeyboardKey.space,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }
      final crystal = find.byKey(const ValueKey('skin-crystal'));
      await tester.ensureVisible(crystal);
      await tester.tap(crystal);
      await tester.pump();
      for (var i = 0; i < 30 && GraphicsSettings.instance.busy; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(GraphicsSettings.instance.busy, isFalse);
      await tester.pump();
      expect(sprites.activeSkin, GraphicsSkin.crystal);
      expect(game.currentMap, same(map));
      expect(map.tileSnapshot(), tiles);
      expect((game.playerX, game.playerY, game.playerDirection), position);
      expect(LoreDialogueManager.instance.getSaveFlags(), flags);
      expect(random.seed, seed);
      expect(tester.takeException(), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppSettingsDialog), findsNothing);
      expect(random.seed, seed);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        (game.playerX, game.playerY),
        (position.$1, position.$2 + 1),
        reason: 'Field keyboard focus is restored after closing the menu',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
