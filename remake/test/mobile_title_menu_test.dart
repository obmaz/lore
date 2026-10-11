import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_creation.dart';
import 'package:lore/screens/character_creation_screen.dart';
import 'package:lore/theme/mobile_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/source_audio_platform.dart';

void main() {
  setUp(installSourceAudioPlatform);
  testWidgets('mobile title does not expose the enemy data utility', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => LoreCreationData.instance.load(force: true));
    await tester.pumpWidget(
      MaterialApp(
        theme: MobileTheme.theme,
        home: CharacterCreationScreen(
          mobilePresentation: true,
          onGameStart: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('저장 불러오기'), findsOneWidget);
    expect(find.text('Enemy data'), findsNothing);
    expect(find.byTooltip('Enemy data'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
