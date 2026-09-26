import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_creation.dart';
import 'package:lore/models/party_member.dart';

class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw Exception('asset not found');
}

/// 원작 `LORECRET.PAS` 캐릭터 생성 데이터 검증.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => LoreCreationData.instance.resetDataForTest());
  tearDown(() => LoreCreationData.instance.resetDataForTest());

  test('1. creation.json 을 읽어 10명/10문항/8계급을 얻는다', () async {
    await LoreCreationData.instance.load(force: true);
    final d = LoreCreationData.instance;
    expect(d.usingJson, isTrue, reason: d.loadError);
    expect(d.characters.length, 10);
    expect(d.questions.length, 10);
    expect(d.classes.length, 8);
    expect(d.characterNames.first, 'Hercules');
    expect(d.characterNames.last, 'Algol');
    // 원작 Display/Name/Profile 문구
    expect(d.text('Display', 0), '또다른 지식의 성전  제 1 부');
    expect(d.text('Display', 1), '캐릭터 만들기 프로그램   제 1.5 탄');
    expect(d.text('Name', 0), '당신의 이름은 :');
    expect(d.text('Second', 1), '남아있는 지수 :');
    expect(d.text('Fourth', 0), '당신과 동행하게될 4 명의 용사를');
  });

  test('2. 성향 문항의 선택지/스탯 매핑이 원작과 같다', () async {
    await LoreCreationData.instance.load(force: true);
    final qs = LoreCreationData.instance.questions;

    expect(qs[0].lines.single, contains('한 밤중에'));
    expect(qs[0].options.map((o) => o.stat).toList(), [1, 2, 3]);
    expect(qs[1].options.map((o) => o.stat).toList(), [1, 2, 4]);
    expect(qs[2].options.map((o) => o.stat).toList(), [1, 2, 5]);
    expect(qs[3].options.map((o) => o.stat).toList(), [1, 3, 4]);
    expect(qs[9].options.map((o) => o.stat).toList(), [3, 4, 5]);
    // 원작 6번 문항의 2번 선택지는 두 줄로 이어진다.
    expect(qs[5].options[1].text, contains('탈출구인 이 문을 끝까지'));
  });

  test('3. 스탯 환산표(0→5 … 6→20, 그 외 10)', () async {
    await LoreCreationData.instance.load(force: true);
    final d = LoreCreationData.instance;
    expect(d.statValue(0), 5);
    expect(d.statValue(1), 7);
    expect(d.statValue(2), 11);
    expect(d.statValue(3), 14);
    expect(d.statValue(4), 17);
    expect(d.statValue(5), 19);
    expect(d.statValue(6), 20);
    expect(d.statValue(9), 10);
  });

  test('4. 계급 조건은 원작 판정식대로 평가된다', () async {
    await LoreCreationData.instance.load(force: true);
    final classes = LoreCreationData.instance.classes;
    final knight = classes.firstWhere((c) => c.playerClass == PlayerClass.knight);
    final mage = classes.firstWhere((c) => c.playerClass == PlayerClass.mage);

    // 기사: strength>13, endurance>13, agility>11, accuracy>11
    expect(
      knight.satisfied(
        strength: 17,
        mentality: 5,
        concentration: 5,
        endurance: 17,
        resistance: 11,
        agility: 15,
        accuracy: 15,
        luck: 10,
      ),
      isTrue,
    );
    expect(
      knight.satisfied(
        strength: 10,
        mentality: 5,
        concentration: 5,
        endurance: 10,
        resistance: 11,
        agility: 5,
        accuracy: 5,
        luck: 10,
      ),
      isFalse,
    );
    // 마법사: mentality>13, accuracy>14
    expect(
      mage.satisfied(
        strength: 5,
        mentality: 19,
        concentration: 5,
        endurance: 5,
        resistance: 5,
        agility: 5,
        accuracy: 15,
        luck: 5,
      ),
      isTrue,
    );
  });

  test('5. 동료 10명이 원작 `Character` 표의 능력치를 갖는다', () async {
    await LoreCreationData.instance.load(force: true);
    final chars = LoreCreationData.instance.characters;

    final hercules = chars.firstWhere((c) => c.name == 'Hercules');
    expect(hercules.playerClass, PlayerClass.knight);
    expect(hercules.strength, 17);
    expect(hercules.endurance, 17);
    expect(hercules.sex, Gender.male);

    final betelgeuse = chars.firstWhere((c) => c.name == 'Betelgeuse');
    expect(betelgeuse.sex, Gender.female);
    expect(betelgeuse.playerClass, PlayerClass.mage);
    expect(betelgeuse.mentality, 17);

    final algol = chars.firstWhere((c) => c.name == 'Algol');
    expect(algol.playerClass, PlayerClass.ninja);
    expect(algol.resistance, 17);
    expect(algol.luck, 16);

    // 원작 표에 존재하는 계급: 기사(1)/마법사(2)/전사(4)/전투승(5)/닌자(6)
    expect(
      chars.map((c) => c.playerClass).toSet(),
      containsAll(<PlayerClass>[
        PlayerClass.knight,
        PlayerClass.mage,
        PlayerClass.warrior,
        PlayerClass.monk,
        PlayerClass.ninja,
      ]),
    );
  });

  test('6. 원작 `Fourth` 초기화(체력=인내력, 무기 위력 등)', () async {
    await LoreCreationData.instance.load(force: true);
    final data = LoreCreationData.instance;

    final knight = data.characters
        .firstWhere((c) => c.playerClass == PlayerClass.knight)
        .toMember();
    knight.applyCreationInit();
    expect(knight.hp, knight.endurance);
    expect(knight.sp, knight.mentality);
    expect(knight.ac, 1);
    expect(knight.weaPower, 3);
    expect(knight.battleLevel, 1);

    final monk = data.characters
        .firstWhere((c) => c.playerClass == PlayerClass.monk)
        .toMember();
    monk.applyCreationInit();
    expect(monk.weaPower, 12);
    expect(monk.ac, 0);

    // 전사는 accuracy[1] 이 accMagic 으로, accEsp = 8
    final warrior = data.characters
        .firstWhere((c) => c.playerClass == PlayerClass.warrior)
        .toMember();
    final warriorAcc = warrior.accArms;
    warrior.applyCreationInit();
    expect(warrior.accMagic, warriorAcc);
    expect(warrior.accEsp, 8);

    // 마법사는 accMagic = accuracy[1], accArms = 5
    final mage = data.characters
        .firstWhere((c) => c.playerClass == PlayerClass.mage)
        .toMember();
    final mageAcc = mage.accArms;
    mage.applyCreationInit();
    expect(mage.accArms, 5);
    expect(mage.accMagic, mageAcc);
    expect(mage.accEsp, 5);
  });

  test('7. JSON 이 없으면 내장 표(원문)로 폴백한다', () async {
    await LoreCreationData.instance.load(
      bundle: _MissingBundle(),
      force: true,
    );
    final d = LoreCreationData.instance;
    expect(d.usingJson, isFalse);
    expect(d.loadError, isNotNull);
    expect(d.characters.length, 10);
    expect(d.questions.length, 10);
    expect(d.characters.first.name, 'Hercules');
    expect(d.text('Third', 0), '당신의 원하는 계급을 고르시오');
    expect(d.initial['gold'], 2000);
    expect(d.initial['food'], 20);
  });
}
