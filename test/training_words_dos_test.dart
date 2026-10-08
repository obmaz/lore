import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/logic/lore_town_shops.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/lore_select_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Rolls implements Random {
  final bounds = <int>[];
  @override
  int nextInt(int max) {
    bounds.add(max);
    return max - 1;
  }

  @override
  bool nextBool() => throw StateError('unexpected RNG');
  @override
  double nextDouble() => throw StateError('unexpected RNG');
}

class _Io implements LoreShopIo {
  _Io(this.answers);
  final List<int> answers;
  final lines = <String>[];
  @override
  int gold = 100;
  @override
  int food = 20;
  @override
  void clear() {}
  @override
  void print(int color, String text) => lines.add(text);
  @override
  void displayCondition() {}
  @override
  Future<void> pressAnyKey() async {}
  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  }) async => answers.removeAt(0);
}

/// LORESUB.PAS:1359,1360,1367 Train_Center selector and persistent local j.
/// First unassigned local is an explicit port fault, not guessed stack memory.
void main() {
  final native = jsonDecode(
    File('test/fixtures/dos_training_words.json').readAsStringSync(),
  );
  test(
    'all small-XP and both complete word selector spaces match native CASEs',
    () {
      for (var word = 0; word < 65536; word++) {
        final negative = word - 65536;
        final expected = native['negativeWords'][word];
        if (expected == native['unassigned']) {
          expect(
            () => LoreTownShops.levelForExperience(negative),
            throwsStateError,
          );
          expect(
            LoreTownShops.levelForExperience(negative, previousLevel: 13),
            13,
          );
        } else {
          expect(LoreTownShops.levelForExperience(negative), expected);
          expect(
            LoreTownShops.levelForExperience(negative, previousLevel: 13),
            expected,
          );
        }
        expect(
          LoreTownShops.levelForExperience((65536 + word) * 10000),
          native['quotientWords'][word],
        );
      }
      for (var xp = 0; xp < 20000; xp++) {
        expect(LoreTownShops.levelForExperience(xp), native['smallXp'][xp]);
      }
      for (final row in native['retention']) {
        expect(
          LoreTownShops.levelForExperience(
            row['xp'],
            previousLevel: row['previous'],
          ),
          row['result'],
        );
      }
    },
  );

  List<PartyMember> party() => [
    PartyMember.createPreset(1)
      ..name = 'First'
      ..battleLevel = 2
      ..experience = 1500,
    PartyMember.createPreset(1)
      ..name = 'Second'
      ..battleLevel = 1
      ..experience = -1,
  ];

  test('actual training retains next-level j across goto, but never invents first j', () async {
    final members = party();
    final beforeFirst = members.first.toJson();
    final beforeSecond = members.last.toJson();
    final io = _Io([1, 2, 0]);
    final random = _Rolls();
    await LoreTownShops.trainCenter(io, members, random);
    // The first insufficient-XP message writes j := level[1]+1 = 3.
    // The next member's unmatched negative-XP CASE leaves that known j intact.
    expect(members.first.toJson(), beforeFirst);
    expect(members.last.toJson(), {...beforeSecond, 'battleLevel': 3});
    expect(io.gold, 95); // source level3 price, not a guessed level1/2.
    expect(io.lines, contains('Second의 레벨은 3입니다.'));
    expect(random.bounds, [30]);
    final firstFault = party();
    final before = [for (final p in firstFault) p.toJson()];
    final faultIo = _Io([2]);
    final faultRandom = _Rolls();
    await expectLater(
      LoreTownShops.trainCenter(faultIo, firstFault, faultRandom),
      throwsStateError,
    );
    expect([for (final p in firstFault) p.toJson()], before);
    expect(faultIo.gold, 100);
    expect(faultRandom.bounds, isEmpty);
  });

  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    testWidgets(
      'actual training window preserves local j and saves native price: $size',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          LoreDialogueManager.instance.loadFlags({});
          LoreScriptEngine.instance.resetForTest();
        });
        final random = _Rolls();
        await tester.pumpWidget(
          MaterialApp(
            home: MainGameScreen(
              encounterRandom: random,
              initialSaveData: SaveData(
                slot: 1,
                slotName: 'training',
                timestamp: DateTime.utc(1993),
                mapId: 6,
                mapTitle: 'TOWN1',
                playerX: 51,
                playerY: 31,
                gold: 100,
                food: 20,
                party: party(),
                flags: const {},
              ),
            ),
          ),
        );
        final finder = find.byType(GameWidget<LoreGame>);
        final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
        await tester.runAsync(
          () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
        );
        Future<void> settle() async {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }

        await settle();
        final beforeFirst = game.partyProvider!().first.toJson();
        final beforeSecond = game.partyProvider!()[1].toJson();
        game.onFacilityEntered!(3);
        await settle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle();
        Future<void> choose(String name) async {
          await tester.tap(
            find.descendant(
              of: find.byType(LoreSelectView),
              matching: find.text(name),
            ),
          );
          await settle();
        }

        await choose('First');
        expect(find.text(' 당신은 아직 전투 경험이 부족합니다.'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle();
        await choose('Second');
        expect(find.text('Second의 레벨은 3입니다.'), findsOneWidget);
        expect(game.partyProvider!().first.toJson(), beforeFirst);
        expect(game.partyProvider!()[1].toJson(), {
          ...beforeSecond,
          'battleLevel': 3,
        });
        expect(random.bounds, [30]);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settle();
        expect(find.byType(LoreSelectView), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
        await settle();
        await tester.tap(find.text(LoreMenuText.optionSave));
        await settle();
        await tester.tap(find.text(SaveManager.slotNames.first));
        await settle();
        final saved = (await SaveManager.instance.loadGame(1))!;
        expect(saved.gold, 95);
        expect(saved.party[1].battleLevel, 3);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
