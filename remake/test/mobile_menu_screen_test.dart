import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/logic/field_magic_logic.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/services/source_palette.dart';
import 'package:lore/theme/mobile_theme.dart';
import 'package:lore/widgets/equipment_art.dart';
import 'package:lore/widgets/jrpg_battle_stage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoEncounterRandom implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => .99;
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await settle(tester);
    await tester.tap(find.text(text).hitTestable().last);
    await settle(tester);
  }

  Future<LoreGame> open(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({});
    SourcePalette.instance.reset();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      LoreDialogueManager.instance.loadFlags({});
      LoreScriptEngine.instance.resetForTest();
      SourcePalette.instance.reset();
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: SourcePalette.wrap,
        theme: MobileTheme.theme,
        home: MainGameScreen(
          encounterRandom: _NoEncounterRandom(),
          initialSaveData: SaveData(
            slot: 1,
            slotName: '본 게임 데이타',
            timestamp: DateTime.utc(1993),
            mapId: 1,
            mapTitle: 'GROUND1',
            playerX: 50,
            playerY: 50,
            gold: 2000,
            food: 20,
            party: [
              PartyMember.createPreset(1),
              PartyMember.createPreset(3)..magicLevel = 12,
            ],
            flags: const {'etc1': 2, 'etc7': 1, 'etc8': 5},
            mapTiles: List.filled(10000, 44),
          ),
        ),
      ),
    );
    final finder = find.byType(GameWidget<LoreGame>);
    final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
    await tester.runAsync(
      () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
    );
    await settle(tester);
    return game;
  }

  for (final size in [const Size(360, 480), const Size(390, 844)]) {
    testWidgets(
      'party hub keeps selected caster and cancels ESP without spending at $size',
      (tester) async {
        final game = await open(tester, size);
        final mage = game.partyProvider!()[1]..esp = 100;
        expect(find.byKey(const ValueKey('field-extrasense')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('field-status')));
        await settle(tester);
        await tap(tester, mage.name);
        await tap(tester, '장비');
        expect(find.byType(EquipmentArt), findsNWidgets(3));
        expect(find.text('맨손'), findsOneWidget);
        for (final art in tester.widgetList<BattleSprite>(
          find.byType(BattleSprite),
        )) {
          expect(tester.getSize(find.byWidget(art)).width, greaterThan(0));
        }
        await tap(tester, '초감각');
        await tap(tester, '초감각 사용');
        expect(find.text('${mage.name} · 초감각').hitTestable(), findsOneWidget);
        await tap(tester, '돌아가기');
        expect(find.text('초감각 사용').hitTestable(), findsOneWidget);
        expect(mage.esp, 100);
        await tap(tester, '초감각 사용');
        await tap(tester, LoreMenuText.espNames[2]);
        expect(
          find.textContaining('인물을 만나 대화하세요').hitTestable(),
          findsOneWidget,
        );
        expect(LoreDialogueManager.instance.partyEtc.read(5), 3);
        await tap(tester, '탐험으로 돌아가기');
        expect(find.byType(Dialog), findsNothing);
        // Main dispatches the current field cell once, consuming one mind-read step.
        expect(LoreDialogueManager.instance.partyEtc.read(5), 2);
        expect(mage.esp, 100);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'modern save cards preserve slot numbering and metadata at $size',
      (tester) async {
        final game = await open(tester, size);
        final saved = SaveData(
          slot: 4,
          slotName: SaveManager.slotNames[3],
          timestamp: DateTime.utc(2026, 10, 9, 12, 34),
          mapId: 6,
          mapTitle: '기존 성내 마을',
          playerX: 51,
          playerY: 31,
          gold: 777,
          food: 10,
          party: [PartyMember.createPreset(1)],
          flags: const {},
        );
        await SaveManager.instance.saveGame(saved);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
        await settle(tester);
        await tap(tester, LoreMenuText.optionSave);
        expect(find.textContaining('기존 성내 마을 · 2026-10-09'), findsOneWidget);
        await tap(tester, SaveManager.slotNames[3]);
        await tap(tester, '계속');
        final fourth = await SaveManager.instance.loadGame(4);
        expect(fourth!.mapId, game.currentMapId);
        expect(fourth.gold, 2000);
        expect(await SaveManager.instance.hasSave(3), isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
        await settle(tester);
        await tap(tester, LoreMenuText.optionSave);
        await tap(tester, SaveManager.slotNames[0]);
        await tap(tester, '계속');
        expect(
          (await SaveManager.instance.loadGame(1))!.mapId,
          game.currentMapId,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'modern nested menus stay inside the palette without mutating records at $size',
      (tester) async {
        final game = await open(tester, size);
        final records = [for (final p in game.partyProvider!()) p.toJson()];
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await settle(tester);
        expect(SourcePalette.instance.grayscale, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await settle(tester);
        expect(find.text('상세를 볼 일행').hitTestable(), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('source-palette')),
            matching: find.byType(Dialog),
          ),
          findsOneWidget,
        );
        expect([for (final p in game.partyProvider!()) p.toJson()], records);
        expect((game.playerX, game.playerY), (50, 50));
        await tap(tester, '닫기');
        expect(SourcePalette.instance.grayscale, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'actual field menu preserves deep back and casts exactly once at $size',
      (tester) async {
        final game = await open(tester, size);
        final mage = game.partyProvider!()[1];
        final sp = mage.sp;
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await settle(tester);
        await tap(tester, LoreMenuText.selectModeCast);
        await tap(tester, mage.name);
        await tap(tester, LoreMenuText.castSpellPhenomina);
        await tap(tester, '공간 이동');
        await tap(tester, '북쪽');
        await tap(tester, '돌아가기');
        expect(find.text('방향 선택').hitTestable(), findsOneWidget);
        expect(mage.sp, sp);
        await tap(tester, '돌아가기');
        expect(find.text('변화 마법').hitTestable(), findsOneWidget);
        await tap(tester, '돌아가기');
        expect(
          find.text(LoreMenuText.castSpellKind).hitTestable(),
          findsOneWidget,
        );
        await tap(tester, '돌아가기');
        expect(find.text('마법을 사용할 일행').hitTestable(), findsOneWidget);
        await tap(tester, '돌아가기');
        expect(
          find.text(LoreMenuText.selectModePrompt).hitTestable(),
          findsOneWidget,
        );
        expect(mage.sp, sp);
        await tap(tester, LoreMenuText.selectModeCast);
        await tap(tester, mage.name);
        await tap(tester, LoreMenuText.castSpellPhenomina);
        await tap(tester, FieldMagicLogic.phenominaSpellNames.first);
        expect(find.byType(Dialog), findsNothing);
        expect(LoreDialogueManager.instance.partyEtc.read(1), 3);
        expect(mage.sp, sp - 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
