import 'support/source_audio_platform.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/logic/lore_town_shops.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Io implements LoreShopIo {
  _Io(this.answers, this.gold, this.party);
  final List<int> answers;
  final List<PartyMember> party;
  final List<String> trace = [];
  @override
  int gold;
  @override
  int food = 100;
  @override
  void clear() => trace.add('clear');
  @override
  void print(int color, String text) => trace.add('$color:$text');
  @override
  Future<void> pressAnyKey() async => trace.add('key');
  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  }) async => answers.removeAt(0);
  @override
  void displayCondition() => PartyMember.simpleDisCond(party);
}

/// LORESUB.PAS Hospital: independently saved original DOS costs at three
/// product boundaries, including the signed product BEFORE div2.
void main() {
  setUp(installSourceAudioPlatform);
  final fixture = jsonDecode(
    File('test/fixtures/dos_hospital_wound.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final entry in fixture['cases'] as List) {
    final slot = entry['slot'] as int;
    List<PartyMember> party() => [
      for (final record in entry['input'] as List)
        PartyMember.fromJson(Map<String, dynamic>.from(record)),
    ];
    void check(List<PartyMember> members) {
      expect(members.length, 6);
      for (final (i, m) in members.indexed) {
        expect(
          m.toJson(),
          entry['observed'][i],
          reason: 'treatment $slot native slot ${i + 1}',
        );
      }
    }

    test(
      'Hospital product boundary $slot matches native records and gold',
      () async {
        final members = party();
        PartyMember.simpleDisCond(members);
        final io = _Io([slot, 1, 0], entry['initialGold'], members);
        await LoreTownShops.hospital(io, members);
        check(members);
        expect(io.gold, entry['observedGold']);
        expect(entry['initialGold'] - io.gold, entry['observedCost']);
        expect(
          io.trace,
          contains('15:${members[slot - 1].name}는 그의 모든 건강이 회복되었다'),
        );
      },
    );
    testWidgets('mobile Hospital boundary $slot treatment and Save match DOS', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(() {
        LoreDialogueManager.instance.loadFlags({});
        LoreScriptEngine.instance.resetForTest();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final tiles = List.filled(10000, 44)
        ..[(14 - 1) * 100 + (87 - 1)] = 52; // original town hospital NPC tile
      await tester.pumpWidget(
        MaterialApp(
          home: MainGameScreen(
            initialSaveData: SaveData(
              slot: 1,
              slotName: SaveManager.slotNames.first,
              timestamp: DateTime.utc(1993),
              mapId: 6,
              mapTitle: 'TOWN1',
              playerX: 87,
              playerY: 13,
              gold: entry['initialGold'],
              food: 100,
              party: party(),
              flags: const {},
              mapTiles: tiles,
            ),
          ),
        ),
      );
      Future<void> settle() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      final gameFinder = find.byType(GameWidget<LoreGame>);
      await tester.runAsync(
        () => tester.state<GameWidgetState<LoreGame>>(gameFinder).loaderFuture,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle();
      expect(find.text('여기는 병원입니다.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle();
      await tester.tap(find.text(entry['input'][slot - 1]['name']).last);
      await settle();
      await tester.tap(find.text('상처를 치료'));
      await settle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await settle();
      await tester.tap(find.text(LoreMenuText.optionSave));
      await settle();
      await tester.tap(find.text(SaveManager.slotNames.first));
      await settle();
      final saved = await SaveManager.instance.loadGame(1);
      expect(saved, isNotNull);
      check(saved!.party);
      expect(saved.gold, entry['observedGold']);
      expect([saved.mapId, saved.playerX, saved.playerY], [6, 87, 13]);
    });
  }
}
