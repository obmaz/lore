import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/script_equip_reducer.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/models/party_member.dart';

PartyMember member(String name, PlayerClass playerClass, {int weapon = 0}) =>
    PartyMember(
      name: name,
      playerClass: playerClass,
      strength: 12,
      mentality: 10,
      concentration: 10,
      endurance: 12,
      resistance: 10,
      agility: 10,
      accArms: 10,
      accMagic: 10,
      accEsp: 10,
      luck: 10,
      weapon: weapon,
      weaPower: weapon == 0 ? null : 9,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = LoreScriptEngine.instance;

  test('황금 방패와 갑옷은 LORESPEC의 장착 문구를 쓴다', () {
    final hero = member('Hero', PlayerClass.knight);
    expect(
      ScriptEquipReducer.completionMessage(hero, (
        kind: 'shield',
        index: 5,
        power: 5,
        prompt: true,
        onlyUnarmed: false,
      )),
      'Hero가 황금의 방패를 장착했다.',
    );
    expect(
      ScriptEquipReducer.completionMessage(hero, (
        kind: 'armor',
        index: 5,
        power: 6,
        prompt: true,
        onlyUnarmed: false,
      )),
      'Hero가 황금의 갑옷을 장착했다.',
    );
  });

  setUp(engine.resetForTest);
  tearDown(engine.resetForTest);

  test('맵 6 기본 무장은 빈 슬롯·무장 대원·전투승을 건너뛰고 보정 없이 지급한다', () async {
    await engine.load();
    expect(
      engine.startStep(6, 41, 79, const ScriptContext(tileAtPlayer: 0)),
      isNull,
    );
    final equip = LoreSpecProcedures.map6(
      41,
      79,
      const ScriptContext(tileAtPlayer: 0),
      engine,
    )!.acknowledgeScene().outcome.equips.single;
    final party = [
      member('기사', PlayerClass.knight),
      member('전투승', PlayerClass.monk),
      member('무장', PlayerClass.warrior, weapon: 2),
      member('', PlayerClass.warrior),
    ];
    final before = party.map((m) => m.toJson()).toList();

    final result = ScriptEquipReducer.apply(party, equip);

    expect(result.accepted, isTrue);
    expect(result.equippedIndexes, [0]);
    expect(result.party[0].weapon, 1);
    expect(result.party[0].weaPower, 5); // 원작 직접 대입: 기사 1.5배 없음.
    for (var i = 1; i < party.length; i++) {
      expect(result.party[i], isNot(same(party[i])));
      expect(result.party[i].toJson(), before[i]);
    }
    expect(party.map((m) => m.toJson()).toList(), before);
  });

  test('선택형 창은 취소·전투승 거절 시 재시도되고 기사에게만 보정된다', () async {
    await engine.load();
    const context = ScriptContext();
    final party = [
      member('기사', PlayerClass.knight),
      member('전투승', PlayerClass.monk),
      member('', PlayerClass.warrior),
    ];
    final run = engine.startStep(11, 30, 44, context)!;
    final equip = run.outcome.equips.single;
    expect(run.requiresEquipmentCommit, isTrue);
    expect(engine.consumedScripts, isNot(contains(run.script.id)));

    final cancelled = ScriptEquipReducer.apply(party, equip);
    expect(cancelled.accepted, isFalse);
    expect(cancelled.equippedIndexes, isEmpty);
    expect(engine.startStep(11, 30, 44, context), isNotNull);

    final monk = ScriptEquipReducer.apply(party, equip, selectedIndex: 1);
    expect(monk.accepted, isFalse);
    expect(monk.rejectedMonk, isTrue);
    expect(monk.party, same(party));
    expect(engine.startStep(11, 30, 44, context), isNotNull);

    final blank = ScriptEquipReducer.apply(party, equip, selectedIndex: 2);
    expect(blank.accepted, isFalse);
    expect(blank.equippedIndexes, isEmpty);

    final knight = ScriptEquipReducer.apply(party, equip, selectedIndex: 0);
    expect(knight.accepted, isTrue);
    expect(knight.equippedIndexes, [0]);
    expect(knight.party[0].weapon, 3);
    expect(knight.party[0].weaPower, 18);
    expect(party[0].weapon, 0);
    run.completeEquipment();
    expect(engine.consumedScripts, contains(run.script.id));
  });

  test('방패와 갑옷은 기사 AC 보너스를 합산하고 10에서 제한한다', () async {
    await engine.load();
    final shield = engine
        .startStep(14, 16, 20, const ScriptContext())!
        .outcome
        .equips
        .single;
    final armor = engine
        .startStep(15, 45, 19, const ScriptContext())!
        .outcome
        .equips
        .single;
    final party = [member('기사', PlayerClass.knight)];

    final withShield = ScriptEquipReducer.apply(
      party,
      shield,
      selectedIndex: 0,
    );
    expect(withShield.party.single.ac, 6);
    final withArmor = ScriptEquipReducer.apply(
      withShield.party,
      armor,
      selectedIndex: 0,
    );
    expect(withArmor.party.single.shield, 5);
    expect(withArmor.party.single.armor, 5);
    expect(withArmor.party.single.ac, 10);
    expect(party.single.ac, 1);
  });
}
