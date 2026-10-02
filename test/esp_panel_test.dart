import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/esp_dialog.dart';
import 'package:lore/widgets/esp_panel.dart';

/// LOREMENU.PAS `Extrasense` / LORESUB.PAS `ReturnMagic`: 화면 문구는 원작 문자열만 쓴다.
void main() {
  test('ESP 이름은 LORESUB.PAS ReturnMagic 41..45 원문이다', () {
    expect(LoreMenuText.espNames, ['투시', '예언', '독심', '천리안', '염력']);
    expect(LoreMenuText.phenominaNames.first, '마법의 햇불');
  });

  testWidgets('ESP 대화창은 원작 문구만 보인다', (tester) async {
    final member = PartyMember.createPreset(3)..esp = 30;
    final logs = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EspDialog(party: [member], onLog: logs.add),
        ),
      ),
    );
    expect(find.text(LoreMenuText.selectModeEsp), findsOneWidget);
    expect(find.text(EspPanel.chooseWhom), findsOneWidget);
    expect(find.text(LoreMenuText.espKind), findsOneWidget);
    for (final name in LoreMenuText.espNames) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.textContaining('Clairvoyance'), findsNothing);
    expect(find.textContaining('EXTRASENSE'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('esp-1')));
    await tester.pump();
    expect(find.text(LoreMenuText.espSeeThrough), findsOneWidget);
    expect(member.esp, 20);

    // 염력(5)은 전투 모드 전용.
    await tester.tap(find.byKey(const ValueKey('esp-5')));
    await tester.pump();
    expect(find.text('염력${LoreMenuText.espBattleOnly}'), findsOneWidget);
    expect(member.esp, 20);
  });
}
