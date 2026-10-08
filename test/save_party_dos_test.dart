import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/logic/lore_save_party.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/party_status_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoEncounter implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.99;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = jsonDecode(
    File('test/fixtures/dos_new_game.json').readAsStringSync(),
  );
  List<PartyMember> decode(List<dynamic> rows) => [
    for (final row in rows)
      PartyMember.fromJson(Map<String, dynamic>.from(row)),
  ];
  SaveData save(int slot, List<PartyMember> party) => SaveData(
    slot: slot,
    slotName: SaveManager.slotNames[slot - 1],
    timestamp: DateTime.utc(1993),
    mapId: 1,
    mapTitle: 'GROUND 1',
    playerX: 50,
    playerY: 50,
    gold: 2000,
    food: 20,
    party: party,
    flags: const {'etc7': 3, 'etc8': 7},
    mapTiles: List.filled(10000, 44),
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    LoreDialogueManager.instance.loadFlags({});
    LoreScriptEngine.instance.resetForTest();
  });

  test(
    'original Save/Load loops transfer six full records, including empty names',
    () {
      final source = latin1.decode(
        File('repo_source/LORE_1993_src/LORESUB.PAS').readAsBytesSync(),
      );
      expect(source, contains('for i:= 1 to 6 do read(playerfile,player[i]);'));
      expect(
        source,
        contains('for i:= 1 to 6 do write(playerfile,player[i]);'),
      );
      final data = jsonDecode(
        File('test/fixtures/dos_save_party.json').readAsStringSync(),
      );
      expect(data['cases'].length, 384);
      for (final row in data['cases']) {
        final party = decode(row['inputs']);
        final before = [for (final p in party) p.toJson()];
        final snapshot = LoreSaveParty.snapshot(party);
        expect(
          [for (final p in snapshot) p.toJson()],
          row['saved'],
          reason: 'mask ${row['mask']} shift ${row['shift']}',
        );
        expect(row['loadScratchUnchanged'], isTrue);
        expect(snapshot.length, 6);
        for (var i = 0; i < 6; i++) {
          expect(identical(snapshot[i], party[i]), isFalse);
        }
        snapshot.first.name = 'Changed snapshot';
        expect([for (final p in party) p.toJson()], before);
      }
    },
  );

  test(
    'short legacy Flutter lists pad reserved slots without compressing blanks',
    () {
      for (var count = 0; count <= 7; count++) {
        final party = [
          for (var i = 0; i < count; i++)
            PartyMember.createPreset(1)..name = i.isEven ? '' : 'Slot$i',
        ];
        final result = LoreSaveParty.snapshot(party);
        expect(result.length, 6);
        for (var i = 0; i < 6; i++) {
          expect(
            result[i].toJson(),
            i < count ? party[i].toJson() : PartyMember.blank().toJson(),
          );
        }
      }
    },
  );

  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    for (final coldLoad in [false, true]) {
      testWidgets(
        'actual save, resume and resave retain six records: $size/cold=$coldLoad',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          // Captured native field save is after Display_Condition; the unused
          // zero record is then unconscious/dead, unlike pre-field Last.
          final fieldRecords = native['firstQuest']['records'];
          final party = decode(fieldRecords);
          final scratch = PartyMember.createPreset(1)..name = 'Unsaved scratch';
          final seven = [...party, scratch];
          await tester.pumpWidget(
            MaterialApp(
              home: MainGameScreen(
                encounterRandom: _NoEncounter(),
                initialParty: coldLoad ? null : seven,
                initialSaveData: coldLoad ? save(1, seven) : null,
              ),
            ),
          );
          Future<void> settle() async {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }

          await tester.pump(const Duration(milliseconds: 500));
          Future<void> saveSlot(int slot) async {
            await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
            await settle();
            await tester.tap(find.text(LoreMenuText.optionSave));
            await settle();
            await tester.tap(find.text(SaveManager.slotNames[slot - 1]));
            await settle();
            expect(find.text(LoreMenuText.optionSaveDone), findsOneWidget);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await settle();
          }

          await saveSlot(1);
          final first = (await SaveManager.instance.loadGame(1))!;
          expect([for (final p in first.party) p.toJson()], fieldRecords);
          expect(scratch.name, 'Unsaved scratch');
          // A legacy/application DTO may contain a seventh record. The actual
          // source Load owner must read six, not promote that scratch into play.
          final loaded = decode(fieldRecords);
          loaded.first.name = 'Reloaded hero';
          loaded[2].name = ''; // Keep the nonzero unnamed record in its slot.
          await SaveManager.instance.saveGame(save(2, [...loaded, scratch]));
          await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
          await settle();
          await tester.tap(find.text(LoreMenuText.optionResume));
          await settle();
          await tester.tap(find.text(SaveManager.slotNames[1]));
          await settle();
          if (find.byType(PartyStatusView).evaluate().isEmpty) {
            await tester.tap(find.byKey(const ValueKey('panel-tab-party')));
            await settle();
          }
          final statuses = tester
              .widget<PartyStatusView>(find.byType(PartyStatusView))
              .members;
          expect(statuses.length, 6);
          expect(statuses.first.name, 'Reloaded hero');
          expect(statuses[2].name, '');
          expect(statuses.any((p) => p.name == 'Unsaved scratch'), isFalse);
          await saveSlot(3);
          final restored = (await SaveManager.instance.loadGame(3))!;
          expect(
            [for (final p in restored.party) p.toJson()],
            [for (final p in loaded) p.toJson()],
          );
          expect(
            [restored.mapId, restored.playerX, restored.playerY],
            [1, 50, 50],
          );
          expect(restored.mapTiles, List.filled(10000, 44));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
