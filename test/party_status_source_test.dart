import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/theme/retro_theme.dart';
import 'package:lore/widgets/party_status_view.dart';

void main() {
  testWidgets(
    'Display_Condition keeps seven source columns and colors on a short phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 180);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PartyStatusView(
              members: [
                PartyMemberStatus(
                  name: 'Hero',
                  hp: 100,
                  maxHp: 200,
                  sp: 50,
                  maxSp: 90,
                  esp: 80,
                  ac: 7,
                  level: 2,
                  condition: 'poisoned',
                ),
                PartyMemberStatus(
                  name: '',
                  hp: 0,
                  maxHp: 0,
                  sp: 0,
                  maxSp: 0,
                  level: 0,
                ),
              ],
            ),
          ),
        ),
      );
      for (final value in [
        'Hero',
        '100',
        '50',
        '80',
        '7',
        '2',
        'poisoned',
        'Reserved',
      ]) {
        expect(find.text(value), findsOneWidget);
      }
      expect(
        tester.widget<Text>(find.text('poisoned')).style!.color,
        RetroTheme.white,
      );
      expect(
        tester.widget<Text>(find.text('Reserved')).style!.color,
        RetroTheme.lightRed,
      );
      for (final prefix in ['Lv.', 'HP:', 'SP:', '/200', '/90']) {
        expect(find.textContaining(prefix), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
