import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/script_party_reducer.dart';
import 'package:lore/models/party_member.dart';

PartyMember member(String name) => PartyMember(
  name: name,
  playerClass: PlayerClass.knight,
  strength: 12,
  mentality: 11,
  concentration: 10,
  endurance: 13,
  resistance: 9,
  agility: 8,
  accArms: 7,
  accMagic: 6,
  accEsp: 5,
  luck: 14,
  experience: 1200,
  weapon: 2,
  weaPower: 8,
  poison: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('경험치와 직업은 이름 있는 대원에게만 적용하고 입력을 보존한다', () {
    final hero = member('영웅');
    final empty = member('');
    final beforeHero = hero.toJson();
    final beforeEmpty = empty.toJson();

    final result = ScriptPartyReducer.applyProgress([
      hero,
      empty,
    ], const ScriptOutcome(expDelta: 1000, partyClassId: 10));

    expect(result, hasLength(2));
    expect(result[0], isNot(same(hero)));
    expect(result[0].experience, 2200);
    expect(result[0].playerClass, PlayerClass.demigod);
    expect(result[0].battleLevel, 1); // 훈련소 방문 전에는 승급하지 않는다.
    expect(result[0].toJson(), {
      ...beforeHero,
      'experience': 2200,
      'classId': 10,
    });
    expect(result[1], isNot(same(empty)));
    expect(result[1].toJson(), beforeEmpty);
    expect(hero.toJson(), beforeHero);
    expect(empty.toJson(), beforeEmpty);
  });

  test('성주 알현의 실제 스크립트 보상이 파티에 적용된다', () async {
    final engine = LoreScriptEngine.instance;
    engine.resetForTest();
    addTearDown(engine.resetForTest);
    await engine.load();

    final run = engine.startTalk(
      6,
      51,
      28,
      const ScriptContext(questSteps: {'lordahn': 4}),
    )!;
    final result = ScriptPartyReducer.applyProgress([
      member('영웅'),
      member(''),
    ], run.outcome);

    expect(run.outcome.expDelta, 1000);
    expect(result[0].experience, 2200);
    expect(result[1].experience, 1200);
    expect(result[0].battleLevel, 1);
  });
}
