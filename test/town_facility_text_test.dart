import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/town_logic.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/town_facilities_dialog.dart';

/// LORESUB.PAS Weapon_Shop / Train_Center / Hospital / Grocery wording.
void main() {
  Future<({List<String> logs, List<int> gold})> open(
    WidgetTester tester,
    TownFacilityType type,
    List<PartyMember> party,
    int gold,
  ) async {
    final logs = <String>[];
    final goldLog = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TownFacilitiesDialog(
            facilityType: type,
            party: party,
            gold: gold,
            onGoldChanged: goldLog.add,
            onLog: logs.add,
          ),
        ),
      ),
    );
    return (logs: logs, gold: goldLog);
  }

  testWidgets('each facility opens with its first source Print line', (
    tester,
  ) async {
    final party = [PartyMember.createPreset(1)];
    for (final (type, text) in [
      (TownFacilityType.weaponShop, '여기는 무기상점입니다.'),
      (TownFacilityType.hospital, '여기는 병원입니다.'),
      (TownFacilityType.trainCenter, ' 여기는 군사 훈련소 입니다.'),
      (TownFacilityType.grocery, '여기는 식료품점 입니다.'),
    ]) {
      await open(tester, type, party, 100);
      expect(find.text(text), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('Train_Center selection prints the source refusals', (
    tester,
  ) async {
    final hero = PartyMember.createPreset(1)
      ..experience = 0
      ..battleLevel = 1;
    final out = await open(tester, TownFacilityType.trainCenter, [hero], 1);
    await tester.tap(find.byKey(ValueKey('train-${hero.name}')));
    await tester.pump();
    expect(out.logs.first, ' 당신은 아직 전투 경험이 부족합니다.');
    expect(out.logs[1], startsWith(' 당신이 다음 레벨이 되려면 경험치가 '));
    expect(out.logs[1], endsWith(' 이상 이어야 합니다.'));
    // Enough experience but not enough gold: `str(party.gold-long)` is negative.
    hero.experience = 1500;
    out.logs.clear();
    await tester.tap(find.byKey(ValueKey('train-${hero.name}')));
    await tester.pump();
    final offer = TownLogic.evaluateTraining(hero);
    expect(out.logs.single, '당신은 금 ${1 - offer.cost}개가 더 필요합니다.');
  });

  test('ExpData prints the source strings, typos included', () {
    expect(TownLogic.expDataFor(2), '1500');
    expect(TownLogic.expDataFor(15), '270000');
    expect(TownLogic.expDataFor(20), '510000');
    expect(TownLogic.expDataText.length, 19);
  });

  test('Train_Center j = 20 only sets level[1]', () {
    final mage = PartyMember.createPreset(3)
      ..battleLevel = 5
      ..magicLevel = 5
      ..espLevel = 5
      ..experience = 6000000;
    final offer = TownLogic.evaluateTraining(mage);
    expect(offer.targetLevel, 20);
    expect(offer.cost, 0);
    final lines = TownLogic.applyTraining(mage, offer);
    expect(lines, [TownLogic.trainMaxLevel, TownLogic.trainNoNeedToTeach]);
    expect([mage.battleLevel, mage.magicLevel, mage.espLevel], [20, 5, 5]);
  });

  test(
    'Train_Center growth draws luck > random(30) from the injected generator',
    () {
      PartyMember make() => PartyMember.createPreset(1)
        ..battleLevel = 1
        ..luck = 15
        ..strength = 10
        ..experience = 6000;
      final a = make();
      final b = make();
      final offerA = TownLogic.evaluateTraining(a);
      final offerB = TownLogic.evaluateTraining(b);
      TownLogic.applyTraining(a, offerA, random: Random(4));
      TownLogic.applyTraining(b, offerB, random: Random(4));
      expect(
        [a.strength, a.endurance, a.agility],
        [b.strength, b.endurance, b.agility],
      );
      // The recorded draw is exactly one random(30) for the fighter.
      final probe = Random(4);
      final grew = 15 > probe.nextInt(30);
      expect(a.strength, grew ? 11 : 10);
    },
  );
}
