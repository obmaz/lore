import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_town_shops.dart';
import 'package:lore/models/party_member.dart';

class _Io implements LoreShopIo {
  _Io(this.answers, {this.gold = 0, this.food = 20});

  final List<int> answers;
  final List<String> trace = [];
  @override
  int gold;
  @override
  int food;

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
  }) async {
    trace.add('select:$title:${items.length}:$clean');
    return answers.removeAt(0);
  }

  @override
  void displayCondition() => trace.add('display');
}

class _Seq implements Random {
  _Seq(this.value);
  final int value;
  @override
  int nextInt(int max) => value;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

/// LORESUB.PAS `Grocery`, `Weapon_Shop`, `Train_Center` and `Hospital`.
void main() {
  PartyMember knight() => PartyMember.createPreset(1);
  PartyMember monk() =>
      PartyMember.createPreset(1)..playerClass = PlayerClass.monk;

  group('Grocery', () {
    test(
      'packages cost k*100 for k*10 food, capped at 255, then thankyou',
      () async {
        final io = _Io([4], gold: 1000, food: 250);
        await LoreTownShops.grocery(io);
        expect((io.gold, io.food), (700, 255));
        expect(io.trace.sublist(0, 2), ['15:여기는 식료품점 입니다.', '15:몇개를 원하십니까 ?']);
        expect(io.trace[2], 'select::6:false');
        expect(io.trace.sublist(3), ['clear', '7:${LoreTownShops.thankYou}']);
      },
    );

    test('필요 없습니다 / Esc -> asyouwish; short gold -> notenoughmoney', () async {
      for (final k in [0, 1]) {
        final io = _Io([k], gold: 1000);
        await LoreTownShops.grocery(io);
        expect(io.trace.sublist(3), ['clear', '7:${LoreTownShops.asYouWish}']);
        expect(io.gold, 1000);
      }
      final poor = _Io([6], gold: 499);
      await LoreTownShops.grocery(poor);
      expect(poor.trace.last, '7:${LoreTownShops.notEnoughMoney}');
      expect(poor.gold, 499);
    });
  });

  group('Weapon_Shop', () {
    test(
      'Esc on the category select leaves with Display_Condition and Clear',
      () async {
        final io = _Io([0]);
        await LoreTownShops.weaponShop(io, [knight()]);
        expect(io.trace, [
          '15:여기는 무기상점입니다.',
          '15:우리들은 무기, 방패, 갑옷을 팔고있습니다.',
          '15:어떤 종류를 원하십니까 ?',
          'select::3:false',
          'display',
          'clear',
        ]);
      },
    );

    test('weapons: price check, monk refusal, knight bonus, stays in the item menu', () async {
      final hero = knight();
      // category 1, sword (4, 5000), whom 1 (name list index 1), then Esc, Esc.
      final io = _Io([1, 4, 1, 0, 0], gold: 6000);
      await LoreTownShops.weaponShop(io, [hero]);
      expect(io.gold, 1000);
      expect(hero.weapon, 4);
      expect(hero.weaPower, 10 + (10 * 0.5).round());
      expect(io.trace, contains('15:누가 이 장검를 사용하시겠습니까 ?'));
      expect(io.trace, contains('10:한명을 고르시오 ---'));
      // after the purchase the weapon menu is shown again (goto second)
      final menus = io.trace.where((t) => t == '15:어떤 무기를 원하십니까 ?').length;
      expect(menus, 2);
    });

    test(
      'a monk refuses, not enough gold repeats the menu after a key',
      () async {
        final fighter = monk();
        final io = _Io([1, 1, 1, 9, 0, 0], gold: 600);
        await LoreTownShops.weaponShop(io, [fighter]);
        expect(io.trace, contains('13:전투승은 이 무기가 필요없습니다.'));
        expect(fighter.weapon, isNot(1));
        expect(io.gold, 600);
        expect(io.trace, contains('7:${LoreTownShops.notEnoughMoney}'));
      },
    );

    test('shield and armor menus, prices and AC (knight +1, cap 10)', () async {
      final hero = knight();
      final io = _Io([2, 1, 1, 0, 3, 5, 1, 0, 0], gold: 300000);
      await LoreTownShops.weaponShop(io, [hero]);
      expect(hero.shield, 1);
      expect(hero.shiPower, 1);
      expect(hero.armor, 5);
      expect(hero.armPower, 6);
      expect(hero.ac, 8); // 1 + 6 + knight 1
      expect(io.gold, 300000 - 1000 - 200000);
      expect(io.trace, contains('15:어떤 방패를 원하십니까 ?'));
      expect(io.trace, contains('15:어떤 갑옷을 원하십니까 ?'));
      expect(io.trace, contains('15:누가 이 금제 갑옷을 사용하시겠습니까 ?'));
    });

    test('Esc on whom prints asyouwish with a key and no charge', () async {
      final io = _Io([1, 1, 0, 0, 0], gold: 600);
      await LoreTownShops.weaponShop(io, [knight()]);
      expect(io.gold, 600);
      expect(io.trace, contains('7:${LoreTownShops.asYouWish}'));
    });
  });

  group('Train_Center', () {
    test('level thresholds follow the source case over long', () {
      for (final (exp, level) in [
        (0, 1),
        (1499, 1),
        (1500, 2),
        (5999, 2),
        (6000, 3),
        (19999, 3),
        (20000, 4),
        (49999, 4),
        (50000, 5),
        (149999, 5),
        (150000, 6),
        (2699999, 14),
        (2700000, 15),
        (5099999, 19),
        (5100000, 20),
      ]) {
        expect(LoreTownShops.levelForExperience(exp), level, reason: '$exp');
      }
    });

    test('too little experience prints the ExpData sentence (with the source typo)', () async {
      final hero = knight()
        ..experience = 0
        ..battleLevel = 14;
      final io = _Io([1, 0], gold: 10);
      await LoreTownShops.trainCenter(io, [hero], _Seq(0));
      expect(io.trace, contains('7: 당신은 아직 전투 경험이 부족합니다.'));
      expect(io.trace, contains('7: 당신이 다음 레벨이 되려면 경험치가 270000'));
      expect(io.trace, contains('7: 이상 이어야 합니다.'));
    });

    test(
      'a level jump costs gold once; missing gold is printed as gold - cost',
      () async {
        final hero = knight()
          ..experience = 6000
          ..battleLevel = 1;
        var io = _Io([1, 0], gold: 1);
        await LoreTownShops.trainCenter(io, [hero], _Seq(0));
        expect(io.trace, contains('7:당신은 금 -4개가 더 필요합니다.'));
        expect(hero.battleLevel, 1);
        io = _Io([1, 0], gold: 5);
        await LoreTownShops.trainCenter(io, [hero], _Seq(29));
        expect(hero.battleLevel, 3);
        expect(io.gold, 0);
        expect(io.trace, contains('15:${hero.name}의 레벨은 3입니다.'));
      },
    );

    test('level 20 is free and ends with the farewell Talk', () async {
      final hero = knight()
        ..experience = 6000000
        ..battleLevel = 10;
      final io = _Io([1, 0], gold: 0);
      await LoreTownShops.trainCenter(io, [hero], _Seq(0));
      expect(hero.battleLevel, 20);
      expect(io.trace, contains('7:당신은 최고 레벨에 도달했습니다.'));
      expect(io.trace, contains('7:더 이상 저희들은 가르칠 필요가 없습니다.'));
    });
  });

  group('Hospital', () {
    test(
      'wounds cost (max-hp)*level div 2 + 1 and return to the who menu',
      () async {
        final hero = knight()..hp = 1;
        final maxHp = hero.endurance * hero.battleLevel;
        final cost = (maxHp - 1) * hero.battleLevel ~/ 2 + 1;
        final io = _Io([1, 1, 0], gold: cost + 5);
        await LoreTownShops.hospital(io, [hero]);
        expect(hero.hp, maxHp);
        expect(io.gold, 5);
        expect(io.trace, contains('15:${hero.name}는 그의 모든 건강이 회복되었다'));
        expect(io.trace.last, 'clear');
      },
    );

    test('refusals loop to the treatment menu (goto second)', () async {
      final hero = knight();
      final io = _Io([1, 1, 2, 3, 4, 0, 0], gold: 100000);
      await LoreTownShops.hospital(io, [hero]);
      expect(io.trace, contains('15:${hero.name}는 치료할 필요가 없습니다'));
      expect(io.trace, contains('15:${hero.name}는 독에 걸리지 않았습니다'));
      expect(io.trace, contains('15:${hero.name}는 의식불명이 아닙니다'));
      expect(io.trace, contains('15:${hero.name}는 죽지 않았습니다'));
      expect(io.gold, 100000);
    });

    test(
      'poison 10*level, consciousness 2*unconscious, revive 100*dead+400',
      () async {
        final a = knight()..poison = 3;
        final b = PartyMember.createPreset(3)..unconscious = 7;
        final c = PartyMember.createPreset(5)
          ..dead = 2
          ..unconscious = 9999;
        final io = _Io([1, 2, 2, 1, 2, 3, 3, 2, 4, 0], gold: 100000);
        await LoreTownShops.hospital(io, [a, b, c]);
        expect(a.poison, 0);
        expect((b.unconscious, b.hp), (0, 1));
        expect(c.dead, 0);
        expect(c.unconscious, c.endurance * c.battleLevel);
        expect(io.gold, 100000 - a.battleLevel * 10 - 14 - (2 * 100 + 400));
      },
    );

    test(
      'not enough gold prints the message and stays in the treatment menu',
      () async {
        final hero = knight()..poison = 1;
        final io = _Io([1, 2, 0, 0], gold: 0);
        await LoreTownShops.hospital(io, [hero]);
        expect(io.trace, contains('7:${LoreTownShops.notEnoughMoney}'));
        expect(hero.poison, 1);
      },
    );
  });
}
