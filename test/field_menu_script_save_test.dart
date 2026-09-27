import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/field_menu_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('메뉴 저장은 현재 화면 세션의 1회성 사건 이력을 기록한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    LoreScriptEngine.instance.consumedScripts.add('global-only');
    addTearDown(LoreScriptEngine.instance.consumedScripts.clear);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FieldMenuDialog(
            party: [PartyMember.createPreset(1)],
            gold: 2000,
            food: 20,
            initialTab: FieldMenuTab.gameOption,
            consumedScriptsProvider: () => ['session-only'],
            onLog: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.text('저장').first;
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final restored = await SaveManager.instance.loadGame(1);
    expect(restored?.consumedScripts, ['session-only']);
  });
}
