import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/field_menu_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('메뉴 저장은 현재 화면 세션의 1회성 사건 이력을 기록한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    LoreScriptEngine.instance.consumedScripts.add('global-only');
    addTearDown(LoreScriptEngine.instance.consumedScripts.clear);
    final sourceEtc = LoreDialogueManager.instance.partyEtc;
    sourceEtc.clear();
    sourceEtc.restoreFieldCounters({});
    addTearDown(() => LoreDialogueManager.instance.loadFlags({}));
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
            etc: sourceEtc.fieldCounters(),
            etcProvider: sourceEtc.fieldCounters,
            onLog: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The menu was opened before a spell/option callback updated these bytes.
    // Saving must use the current values, not its initial widget snapshot.
    sourceEtc[3] = 29;
    sourceEtc[7] = 3;
    sourceEtc[8] = 7;
    final save = find.text(LoreMenuText.optionSave).first;
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final restored = await SaveManager.instance.loadGame(1);
    expect(restored?.consumedScripts, ['session-only']);
    expect(restored?.etc['swampWalkSteps'], 29);
    expect(restored?.etc['encounterFrequency'], 3);
    expect(restored?.flags['etc3'], 29);
    expect(restored?.flags['etc7'], 3);
    expect(restored?.flags['etc8'], 7);
  });
}
