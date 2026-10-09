import 'support/source_audio_platform.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/logic/field_magic_logic.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/logic/lore_sub_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LOREMENU.PAS `CastSpell` from the C hotkey on the game screen.
void main() {
  setUp(installSourceAudioPlatform);
  testWidgets('C -> ChooseWhom -> 변화 마법 -> 마법의 햇불 adds 1 to etc[1]', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      LoreDialogueManager.instance.loadFlags({});
      LoreScriptEngine.instance.resetForTest();
    });
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final mage = PartyMember.createPreset(3)..magicLevel = 4;
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          initialSaveData: SaveData(
            slot: 1,
            slotName: SaveManager.slotNames.first,
            timestamp: DateTime.utc(1993),
            mapId: 1,
            mapTitle: 'GROUND 1',
            playerX: 50,
            playerY: 50,
            gold: 2000,
            food: 20,
            party: [PartyMember.createPreset(1), mage],
            flags: const {'etc1': 2},
            mapTiles: List.filled(100 * 100, 44),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    final sp = mage.sp;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await settle();
    expect(find.text(LoreSubText.chooseOne), findsOneWidget);
    await tester.tap(find.text(mage.name).last);
    await settle();
    expect(find.text(LoreMenuText.castSpellKind), findsOneWidget);
    await tester.tap(find.text(LoreMenuText.castSpellPhenomina));
    await settle();
    // level 4: j = 4 div 2 + 1 = 3 of the 8 names, without SP costs.
    expect(
      find.text(FieldMagicLogic.phenominaSpellNames.first),
      findsOneWidget,
    );
    expect(find.textContaining('SP)'), findsNothing);
    await tester.tap(find.text(FieldMagicLogic.phenominaSpellNames.first));
    await settle();
    expect(LoreDialogueManager.instance.partyEtc.read(1), 3);
    final game = tester
        .widget<GameWidget<LoreGame>>(find.byType(GameWidget<LoreGame>))
        .game!;
    expect(game.partyProvider!()[1].sp, sp - 1);
    expect(mage.sp, sp);
  });
}
