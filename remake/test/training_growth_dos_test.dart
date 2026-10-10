import 'support/source_audio_platform.dart';
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
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/logic/lore_town_shops.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Rolls implements Random {
  _Rolls([this.values = const []]);
  final List<int> values;
  final List<int> bounds = [];
  @override
  int nextInt(int max) {
    bounds.add(max);
    final value = values.isEmpty ? max - 1 : values[bounds.length - 1];
    expect(value, inInclusiveRange(0, max - 1));
    return value;
  }

  @override
  bool nextBool() => throw UnimplementedError();
  @override
  double nextDouble() => throw UnimplementedError();
}

class _Io implements LoreShopIo {
  _Io(this.answers, this.gold, this.party);
  final List<int> answers;
  final List<PartyMember> party;
  @override
  int gold;
  @override
  int food = 100;
  @override
  void clear() {}
  @override
  void print(int color, String text) {}
  @override
  Future<void> pressAnyKey() async {}
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

/// LORESUB.PAS Train_Center: independent DOS records and source random branches.
void main() {
  setUp(installSourceAudioPlatform);
  final fixture = jsonDecode(
    File('test/fixtures/dos_training_growth.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = fixture['cases'] as List;
  List<PartyMember> party(Map<String, dynamic> entry) => [
    for (final record in entry['input'] as List)
      PartyMember.fromJson(Map<String, dynamic>.from(record)),
  ];
  void check(List<PartyMember> members, Map<String, dynamic> entry) {
    expect(members.length, 6);
    for (final (i, member) in members.indexed) {
      expect(
        member.toJson(),
        entry['observed'][i],
        reason: 'native training ${entry['slot']}, record ${i + 1}',
      );
    }
  }

  for (final raw in cases) {
    final entry = Map<String, dynamic>.from(raw);
    final slot = entry['slot'] as int;
    test(
      'Train_Center slot $slot matches full native records and gold',
      () async {
        final members = party(entry);
        final io = _Io([slot, 0], entry['initialGold'], members);
        final random = _Rolls();
        await LoreTownShops.trainCenter(io, members, random);
        check(members, entry);
        expect(io.gold, entry['observedGold']);
        expect(entry['initialGold'] - io.gold, entry['observedCost']);
        expect(random.bounds, [30]);
      },
    );
  }

  test('Ninja second random(21) is consumed only in resistance18..19', () {
    for (final resistance in [17, 18, 19, 20]) {
      final ninja = PartyMember.createPreset(6)
        ..playerClass = PlayerClass.ninja
        ..battleLevel = 1
        ..luck = 10
        ..resistance = resistance
        ..agility = 255;
      final rng = _Rolls([0, 20]);
      ninja.trainLevelUp(5, random: rng);
      expect(
        rng.bounds,
        resistance == 18 || resistance == 19 ? [30, 21] : [30],
      );
      expect(ninja.resistance, resistance < 20 ? resistance + 1 : 20);
      expect(ninja.agility, resistance == 20 ? 0 : 255);
    }
    final ninja = PartyMember.createPreset(6)
      ..playerClass = PlayerClass.ninja
      ..luck = 10
      ..resistance = 18;
    final rng = _Rolls([0, 10]);
    ninja.trainLevelUp(5, random: rng);
    expect(ninja.resistance, 18); // luck < random(21), strict comparison
    expect(rng.bounds, [30, 21]);
  });

  test('class10 growth and free level20 consume no random numbers', () async {
    final hero = PartyMember.createPreset(10)
      ..playerClass = PlayerClass.demigod
      ..battleLevel = 1;
    final rng = _Rolls();
    hero.trainLevelUp(5, random: rng);
    expect(rng.bounds, isEmpty);
    expect([hero.battleLevel, hero.magicLevel, hero.espLevel], [5, 5, 5]);
    final mage = PartyMember.createPreset(2)
      ..playerClass = PlayerClass.mage
      ..experience = 5100000
      ..battleLevel = 19
      ..magicLevel = 19
      ..espLevel = 10;
    final before = mage.toJson();
    final io = _Io([1, 0], 0, [mage]);
    await LoreTownShops.trainCenter(io, [mage], rng);
    expect(mage.toJson(), {...before, 'battleLevel': 20});
    expect(io.gold, 0);
    expect(rng.bounds, isEmpty);
  });

  testWidgets('mobile six-class training and Save match native DOS', (
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
    final input = Map<String, dynamic>.from(cases.first);
    final expected = Map<String, dynamic>.from(cases.last);
    final tiles = List.filled(10000, 44)
      ..[(12 - 1) * 100 + (21 - 1)] = 52; // original training NPC
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          sourceReplayBattle: true,
          initialSaveData: SaveData(
            slot: 1,
            slotName: SaveManager.slotNames.first,
            timestamp: DateTime.utc(1993),
            mapId: 6,
            mapTitle: 'TOWN1',
            playerX: 21,
            playerY: 11,
            gold: input['initialGold'],
            food: 100,
            party: party(input),
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

    await tester.runAsync(
      () => tester
          .state<GameWidgetState<LoreGame>>(find.byType(GameWidget<LoreGame>))
          .loaderFuture,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle();
    expect(find.text(' 여기는 군사 훈련소 입니다.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle();
    for (final member in party(input)) {
      await tester.tap(find.text(member.name).last);
      await settle();
      expect(find.text('${member.name}의 레벨은 5입니다.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle();
    }
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
    check(saved!.party, expected);
    expect(saved.gold, expected['observedGold']);
    expect([saved.mapId, saved.playerX, saved.playerY], [6, 21, 11]);
  });
}
