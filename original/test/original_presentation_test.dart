import 'support/source_audio_platform.dart';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/sprite_sheet.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/widgets/browser_fullscreen_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(installSourceAudioPlatform);

  testWidgets(
    'original keeps source graphics and field input without app settings',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      // An obsolete setting must never select a remake skin after an upgrade.
      SharedPreferences.setMockInitialValues({'lore_graphics_skin': 'crystal'});
      SpriteLibrary.instance.resetForTest();
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        SpriteLibrary.instance.resetForTest();
      });
      await tester.runAsync(() => SpriteLibrary.instance.load());
      final sheet = SpriteLibrary.instance.get('CHARA')!;
      expect(sheet.image.width, kSpriteSize * 56);
      expect(sheet.image.height, kSpriteSize);
      await tester.pumpWidget(
        MaterialApp(home: MainGameScreen(encounterRandom: LoreRandom(12345))),
      );
      final field = find.byType(GameWidget<LoreGame>);
      final game = tester.widget<GameWidget<LoreGame>>(field).game!;
      await tester.runAsync(
        () => tester.state<GameWidgetState<LoreGame>>(field).loaderFuture,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BrowserFullscreenButton), findsOneWidget);
      expect(find.byTooltip('앱 설정'), findsNothing);
      expect(find.byKey(const ValueKey('app-settings')), findsNothing);
      final start = (game.playerX, game.playerY);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect((game.playerX, game.playerY), (start.$1, start.$2 + 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
