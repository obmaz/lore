/// `LORESUB.PAS` `Grocery` (1156-1178), `Weapon_Shop` (1180-1327),
/// `Train_Center` (1329-1514) and `Hospital` (1517-1634), ported directly
/// with their `goto` loops. `party.gold`/`party.food` and the display
/// refreshes go through [LoreShopIo].
library;

import 'dart:math';

import '../models/party_member.dart';
import 'lore_sub_text.dart';
import 'lore_window_io.dart';

/// The four town facilities (`entermode` `talk` cases 1..4 of the source).
enum TownFacilityType { weaponShop, hospital, trainCenter, grocery }

abstract interface class LoreShopIo implements LoreWindowIo {
  /// `party.gold` (longint).
  int get gold;
  set gold(int value);

  /// `party.food` (byte).
  int get food;
  set food(int value);

  /// `Display_Condition` / `DisplayHP` / `DisplayCondition`.
  void displayCondition();
}

class LoreTownShops {
  const LoreTownShops._();

  // ---- LORESUB helpers -----------------------------------------------------

  static const String asYouWish = '당신이 바란다면 ...';
  static const String notEnoughMoney = '당신은 충분한 돈이 없습니다.';
  static const String thankYou = '매우 고맙습니다.';

  /// `Message(color, s)`: clear, then print.
  static void _message(LoreWindowIo io, int color, String text) {
    io.clear();
    io.print(color, text);
  }

  static void _asYouWish(LoreWindowIo io) => _message(io, 7, asYouWish);
  static void _notEnoughMoney(LoreWindowIo io) =>
      _message(io, 7, notEnoughMoney);

  /// `Talk(s)`: print and wait.
  static Future<void> _talk(LoreWindowIo io, String text) async {
    io.print(7, text);
    await io.pressAnyKey();
  }

  static PartyMember _slot(List<PartyMember> party, int i) =>
      i <= party.length ? party[i - 1] : PartyMember.blank();

  /// `ChooseWhom(FALSE)`: the named slots below `한명을 고르시오 ---`;
  /// returns the slot number (1..6) or 0.
  static Future<int> chooseWhom(
    LoreWindowIo io,
    List<PartyMember> party,
  ) async {
    final slots = [
      for (var i = 1; i <= 6; i++)
        if (_slot(party, i).name.isNotEmpty) i,
    ];
    io.print(10, LoreSubText.chooseOne);
    final k = await io.select('', [
      for (final i in slots) _slot(party, i).name,
    ], clean: false);
    return k == 0 ? 0 : slots[k - 1];
  }

  // ---- Grocery -------------------------------------------------------------

  static Future<void> grocery(LoreShopIo io) async {
    io.print(15, '여기는 식료품점 입니다.');
    io.print(15, '몇개를 원하십니까 ?');
    var k = await io.select('', [
      '필요 없습니다',
      for (var i = 1; i <= 5; i++) '${i * 10} 인분 : 금 ${i * 100} 개',
    ], clean: false);
    if (k < 2) {
      _asYouWish(io);
      return;
    }
    k -= 1;
    if (io.gold < k * 100) {
      _notEnoughMoney(io);
      return;
    }
    io.gold = io.gold - k * 100;
    k = k * 10;
    io.food = io.food + k > 255 ? 255 : io.food + k;
    _message(io, 7, thankYou);
  }

  // ---- Weapon_Shop ---------------------------------------------------------

  static const List<int> _weaponPrice = [
    500, 1500, 3000, 5000, 10000, 30000, 60000, 80000, 100000, //
  ];
  static const List<int> _weaponPower = [5, 7, 9, 10, 15, 20, 30, 40, 50];
  static const List<int> _defensePrice = [
    1000, 5000, 25000, 80000, 100000, 200000, //
  ];

  static Future<void> weaponShop(LoreShopIo io, List<PartyMember> party) async {
    while (true) {
      // first:
      io.print(15, '여기는 무기상점입니다.');
      io.print(15, '우리들은 무기, 방패, 갑옷을 팔고있습니다.');
      io.print(15, '어떤 종류를 원하십니까 ?');
      final h = await io.select('', const ['무기류', '방패류', '갑옷류'], clean: false);
      if (h == 0) {
        io.displayCondition();
        io.clear();
        return;
      }
      if (h == 1) {
        await _weapons(io, party);
      } else {
        await _defense(io, party, h);
      }
    }
  }

  /// `second:` — returns on Esc (`goto first`).
  static Future<void> _weapons(LoreShopIo io, List<PartyMember> party) async {
    while (true) {
      io.print(15, '어떤 무기를 원하십니까 ?');
      final k = await io.select('', [
        for (var i = 1; i <= 9; i++)
          '${LoreSubText.weaponLabel(i)} : 금 ${_weaponPrice[i - 1]} 개',
      ], clean: false);
      if (k == 0) return;
      final long = _weaponPrice[k - 1];
      if (io.gold < long) {
        _notEnoughMoney(io);
        await io.pressAnyKey();
        io.clear();
        continue;
      }
      io.print(15, '누가 이 ${LoreSubText.weaponLabel(k)}를 사용하시겠습니까 ?');
      final j = await chooseWhom(io, party);
      if (j > 0) {
        final member = _slot(party, j);
        if (member.playerClass == PlayerClass.monk) {
          io.print(13, '전투승은 이 무기가 필요없습니다.');
          await io.pressAnyKey();
          continue;
        }
        member.equipWeaponRaw(k, _weaponPower[k - 1]);
        io.gold = io.gold - long;
      } else {
        _asYouWish(io);
        await io.pressAnyKey();
      }
      io.clear();
    }
  }

  /// `third:` for shields (h = 2) and armor (h = 3).
  static Future<void> _defense(
    LoreShopIo io,
    List<PartyMember> party,
    int h,
  ) async {
    final kind = h == 2 ? '방패' : '갑옷';
    final object = h == 2 ? '방패를' : '갑옷을';
    while (true) {
      io.print(15, '어떤 $object 원하십니까 ?');
      final k = await io.select('', [
        for (var i = 1; i <= 5; i++)
          '${LoreSubText.defenseLabel(i)} $kind : 금 ${_defensePrice[i + h - 3]} 개',
      ], clean: false);
      if (k == 0) return;
      final long = _defensePrice[k + h - 3];
      if (io.gold < long) {
        _notEnoughMoney(io);
        await io.pressAnyKey();
        io.clear();
        continue;
      }
      io.print(15, '누가 이 ${LoreSubText.defenseLabel(k)} $object 사용하시겠습니까 ?');
      final j = await chooseWhom(io, party);
      if (j > 0) {
        final member = _slot(party, j);
        final power = h == 3 ? k + 1 : k;
        if (h == 2) {
          member.equipShieldRaw(k, power);
        } else {
          member.equipArmorRaw(k, power);
        }
        io.gold = io.gold - long;
      } else {
        _asYouWish(io);
        await io.pressAnyKey();
      }
      io.clear();
    }
  }

  // ---- Train_Center ----------------------------------------------------------

  /// `ExpData[2..20]` with the source's typos (`270000`, `510000`).
  static const List<String> expData = [
    '1500', '6000', '20000', '50000', //
    '150000', '250000', '500000', '800000', '1050000',
    '1320000', '1620000', '1950000', '2310000', '270000',
    '3120000', '3570000', '4050000', '4560000', '510000',
  ];

  static const List<int> _trainCost = [
    2, 3, 5, 8, 15, 25, 40, 70, 120, 200, //
    350, 600, 1000, 1700, 3000, 5000, 8300, 14000, 24000, 40000,
  ];

  /// The level `j` the experience allows (`case long of ...`).
  static int levelForExperience(int experience) {
    if (experience < 20000) {
      return experience < 1500 ? 1 : (experience < 6000 ? 2 : 3);
    }
    final long = experience ~/ 10000;
    if (long <= 4) return 4;
    if (long <= 14) return 5;
    if (long <= 24) return 6;
    if (long <= 49) return 7;
    if (long <= 79) return 8;
    if (long <= 104) return 9;
    if (long <= 131) return 10;
    if (long <= 161) return 11;
    if (long <= 194) return 12;
    if (long <= 230) return 13;
    if (long <= 269) return 14;
    if (long <= 311) return 15;
    if (long <= 356) return 16;
    if (long <= 404) return 17;
    if (long <= 455) return 18;
    if (long <= 509) return 19;
    return 20;
  }

  static Future<void> trainCenter(
    LoreShopIo io,
    List<PartyMember> party,
    Random random,
  ) async {
    io.print(15, ' 여기는 군사 훈련소 입니다.');
    io.print(15, ' 만약 당신이 충분한 전투 경험을 쌓았다면, 당신은 더욱 능숙하게 무기를 다룰것입니다.');
    await io.pressAnyKey();
    io.clear();
    while (true) {
      // first:
      io.print(15, '누가 훈련을 받겠습니까 ?');
      final k = await chooseWhom(io, party);
      if (k == 0) {
        io.displayCondition();
        io.clear();
        return;
      }
      final member = _slot(party, k);
      final j = levelForExperience(member.experience);
      if (member.battleLevel < j) {
        final long = _trainCost[j - 1];
        if (j == 20) {
          member.battleLevel = 20;
          io.print(7, '당신은 최고 레벨에 도달했습니다.');
          await _talk(io, '더 이상 저희들은 가르칠 필요가 없습니다.');
          continue;
        }
        if (io.gold < long) {
          await _talk(io, '당신은 금 ${io.gold - long}개가 더 필요합니다.');
          continue;
        }
        io.gold = io.gold - long;
        io.print(15, '${member.name}의 레벨은 $j입니다.');
        member.trainLevelUp(j, random: random);
        await io.pressAnyKey();
      } else {
        io.print(7, ' 당신은 아직 전투 경험이 부족합니다.');
        if (member.battleLevel >= 1 && member.battleLevel <= 19) {
          final next = member.battleLevel + 1;
          io.print(7, '');
          io.print(7, '');
          // `cPrint(7,11,' 당신이 다음 레벨이 되려면 경험치가 ',ExpData[j],'')`
          io.print(7, ' 당신이 다음 레벨이 되려면 경험치가 ${expData[next - 2]}');
          io.print(7, ' 이상 이어야 합니다.');
        }
        await io.pressAnyKey();
      }
    }
  }

  // ---- Hospital --------------------------------------------------------------

  static Future<void> hospital(LoreShopIo io, List<PartyMember> party) async {
    io.print(15, '여기는 병원입니다.');
    await io.pressAnyKey();
    while (true) {
      // first:
      io.print(15, '누가 치료를 받겠습니까 ?');
      final k = await chooseWhom(io, party);
      if (k == 0) {
        io.displayCondition();
        io.clear();
        return;
      }
      final p = _slot(party, k);
      var again = false;
      while (!again) {
        // second:
        final j = await io.select('어떤 치료입니까 ?', const [
          '상처를 치료',
          '독을 제거',
          '의식의 회복',
          '부활',
        ], clean: false);
        if (j == 0) {
          io.clear();
          break; // goto first
        }
        final done = await _treat(io, p, j);
        again = done;
      }
    }
  }

  /// One treatment; true = `goto first`, false = `goto second`.
  static Future<bool> _treat(LoreShopIo io, PartyMember p, int j) async {
    final maxHp = p.endurance * p.battleLevel;
    switch (j) {
      case 1:
        if (p.dead > 0) {
          io.print(7, '${p.name}는 이미 죽은 상태입니다');
        } else if (p.unconscious > 0) {
          io.print(7, '${p.name}는 이미 의식불명입니다');
        } else if (p.poison > 0) {
          io.print(7, '${p.name}는 독이 퍼진 상태입니다');
        } else if (p.hp >= maxHp) {
          io.print(15, '${p.name}는 치료할 필요가 없습니다');
        }
        if (p.dead > 0 || p.unconscious > 0 || p.poison > 0 || p.hp >= maxHp) {
          await io.pressAnyKey();
          return false;
        }
        final cost = (maxHp - p.hp) * p.battleLevel ~/ 2 + 1;
        if (io.gold < cost) {
          _notEnoughMoney(io);
          await io.pressAnyKey();
          return false;
        }
        io.gold = io.gold - cost;
        p.hp = maxHp;
        final s = p.sex == Gender.male ? '그의' : '그녀의';
        io.print(15, '${p.name}는 $s 모든 건강이 회복되었다');
        io.displayCondition();
        await io.pressAnyKey();
        return true;
      case 2:
        if (p.dead > 0) {
          io.print(7, '${p.name}는 이미 죽은 상태입니다');
        } else if (p.unconscious > 0) {
          io.print(7, '${p.name}는 이미 의식불명입니다');
        } else if (p.poison == 0) {
          io.print(15, '${p.name}는 독에 걸리지 않았습니다');
        }
        if (p.dead > 0 || p.unconscious > 0 || p.poison == 0) {
          await io.pressAnyKey();
          return false;
        }
        final cost = p.battleLevel * 10;
        if (io.gold < cost) {
          _notEnoughMoney(io);
          await io.pressAnyKey();
          return false;
        }
        io.gold = io.gold - cost;
        p.poison = 0;
        io.print(15, '${p.name}는 독이 제거 되었습니다');
        io.displayCondition();
        await io.pressAnyKey();
        return true;
      case 3:
        if (p.dead > 0) {
          io.print(7, '${p.name}는 이미 죽은 상태입니다');
        } else if (p.unconscious == 0) {
          io.print(15, '${p.name}는 의식불명이 아닙니다');
        }
        if (p.dead > 0 || p.unconscious == 0) {
          await io.pressAnyKey();
          return false;
        }
        final cost = p.unconscious * 2;
        if (io.gold < cost) {
          _notEnoughMoney(io);
          await io.pressAnyKey();
          return false;
        }
        io.gold = io.gold - cost;
        p.unconscious = 0;
        p.hp = 1;
        io.print(15, '${p.name}는 의식을 차렸습니다');
        io.displayCondition();
        await io.pressAnyKey();
        return true;
      default:
        if (p.dead == 0) {
          io.print(15, '${p.name}는 죽지 않았습니다');
          await io.pressAnyKey();
          return false;
        }
        final cost = p.dead * 100 + 400;
        if (io.gold < cost) {
          _notEnoughMoney(io);
          await io.pressAnyKey();
          return false;
        }
        io.gold = io.gold - cost;
        p.dead = 0;
        if (p.unconscious > maxHp) p.unconscious = maxHp;
        io.print(15, '${p.name}는 다시 살아났습니다');
        io.displayCondition();
        await io.pressAnyKey();
        return true;
    }
  }
}
