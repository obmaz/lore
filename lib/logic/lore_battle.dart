/// 원작 `LOREBATT.PAS` 전투 절차의 직접 이식.
///
/// 각 프로시저의 제어 흐름, 난수 호출 순서, 문구와 정수 연산(`div`, `round`)을
/// 원본 그대로 옮겼다. 화면 그리기(DisplayEnemies)와 키 대기는 `BattleViewportView`
/// 화면 어댑터가 맡는다. 전역 변수 `person`, `battle[1..6,1..3]`, `enemynumber`,
/// `enemy[1..7]` 는 [LoreBattle]의 필드이다(배열 번호는 원본처럼 1부터).
///
/// 컴파일러 동작 가정(원본 확인 불가, `docs/porting` 에 기록): 바이트 필드에
/// 저장될 때는 `dec(ac)` 가 0 에서 255 로, `resistance - 10` 이 5 에서 251 로
/// 돌아가는 것을 흉내 내고, Pascal `round` 는 .5 에서 0 에서 먼 쪽으로 올린다.
/// 바이트 곱셈 중간값(`ac*level*(random(10)+1)`, `strength*wea_power*level[1]`)이
/// 16비트 정수를 넘을 때 원본이 감기는지는 확인하지 못했으므로 마스킹하지 않는다.
library;

import 'dart:math';

import '../models/monster.dart';
import '../models/party_member.dart';
import 'lore_batt_text.dart';
import 'lore_sub_text.dart';

/// `Print(color, text)` 에 대응하는 출력.
typedef BattlePrint = void Function(int color, String text);

/// 소리 효과 이름: `hit`, `scream1`, `scream2`.
typedef BattleSound = void Function(String name);

/// 적과 파티 번호가 1부터 시작하는 `LOREBATT.PAS` 상태와 절차.
class LoreBattle {
  LoreBattle({
    required this.party,
    required this.enemy,
    required this.random,
    required this.print,
    this.sound,
    this.onTelepathyJoin,
    this.specialMagicLearned = true,
    this.espBit = false,
  });

  /// 화면과 공유하는 파티 목록(합류로 바뀔 수 있어 매번 이 목록을 읽는다).
  final List<PartyMember> party;
  final List<Monster> enemy;
  final Random random;
  final BattlePrint print;
  final BattleSound? sound;

  /// `join(E_number, 6)` — 독심술로 설득한 적을 6번 슬롯으로 편입한다.
  final void Function(int eNumber)? onTelepathyJoin;

  /// `party.etc[38] and bit1 > 0`.
  bool specialMagicLearned;

  final List<PartyMember> _blanks = [for (var i = 0; i < 7; i++) _blank()];

  /// `battle[person,1..3]` (index 0 unused).
  final List<List<int>> battle = [
    for (var i = 0; i < 7; i++) [0, 0, 0, 0],
  ];

  /// 전역 `person`.
  int person = 1;

  int get enemynumber => enemy.length;

  static PartyMember _blank() => PartyMember.blank();

  PartyMember p(int i) => i <= party.length ? party[i - 1] : _blanks[i - 1];

  // ------------------------------------------------------------------
  // 공용 보조
  // ------------------------------------------------------------------

  /// Pascal `random(n)`: n <= 0 이면 0.
  int rnd(int n) {
    // 범위 0 의 `random` 도 호출 횟수는 같게 유지한다(값은 0).
    if (n <= 0) {
      random.nextInt(1);
      return 0;
    }
    return random.nextInt(n);
  }

  /// Pascal `round(x)` (.5 는 0 에서 먼 쪽).
  static int pround(num x) => x >= 0 ? (x + 0.5).floor() : (x - 0.5).ceil();

  /// `LORESUB.PAS` `exist`.
  bool exist(int i) {
    final q = p(i);
    return q.name != '' && q.unconscious == 0 && q.dead == 0 && q.hp > 0;
  }

  String get sexData => p(person).sex == Gender.male ? '그' : '그녀';

  /// 바이트 필드의 `dec`.
  static int decByte(int v) => (v - 1) & 0xFF;

  void _snd(String name) => sound?.call(name);

  /// `LORESUB.PAS` `ReturnMessage(who, how, what, whom)`.
  String returnMessage(int who, int how, int what, int whom) {
    final actor = p(who).name;
    switch (how) {
      case 1:
        return LoreSubText.returnMessage(
          actor: actor,
          how: 1,
          what: p(who).weapon,
          target: enemy[whom - 1].name,
        );
      case 2:
      case 3:
      case 4:
      case 6:
        return LoreSubText.returnMessage(
          actor: actor,
          how: how,
          what: what,
          target: enemy[whom - 1].name,
        );
      case 5:
        return LoreSubText.returnMessage(
          actor: actor,
          how: 5,
          what: what,
          target: p(whom).name,
        );
      default:
        return LoreSubText.returnMessage(actor: actor, how: how);
    }
  }

  // ------------------------------------------------------------------
  // PlusExperience / PlusGold
  // ------------------------------------------------------------------

  void plusExperience(int who, int foe) {
    var plus = enemy[foe - 1].eNumber;
    plus = plus * plus * plus ~/ 8;
    if (plus == 0) plus = 1;
    if (!enemy[foe - 1].isUnconscious) {
      print(14, '${p(who).name}는 $plus${LoreBattText.expGainedMsg}');
      p(who).experience += plus;
    } else {
      for (var i = 1; i <= 6; i++) {
        if (exist(i)) p(i).experience += plus;
      }
    }
  }

  /// `PlusGold` (etc[6] = 2 의 도주 때는 호출하지 않는다). 얻은 금을 돌려준다.
  int plusGold() {
    var long = 0;
    for (var i = 1; i <= enemynumber; i++) {
      final j = enemy[i - 1].eNumber;
      final t = Monster.monsterTemplates[j - 1];
      var k = t.ac;
      if (k == 0) k = 1;
      long += t.level * t.level * t.level * k;
    }
    print(15, LoreBattText.goldFound('$long'));
    return long;
  }

  bool existEnemies() {
    var j = 0;
    for (var i = 1; i <= enemynumber; i++) {
      if (!enemy[i - 1].isDead) j++;
    }
    return j != 0;
  }

  // ------------------------------------------------------------------
  // 플레이어 행동
  // ------------------------------------------------------------------

  void attackOne() {
    final sex = sexData;
    var k = battle[person][3];
    if (enemy[k - 1].isDead) {
      if (!existEnemies()) return;
      battle[person][3] = battle[person][3] + 1;
      k = k + 1;
      if (battle[person][3] <= enemynumber) attackOne();
      return;
    }
    final foe = enemy[k - 1];
    print(
      15,
      returnMessage(person, battle[person][1], person, battle[person][3]),
    );
    if (foe.isUnconscious && !foe.isDead) {
      switch (rnd(4)) {
        case 0:
          print(
            12,
            '$sex${LoreBattText.killWeapon}${foe.name}${LoreBattText.killHeart}',
          );
        case 1:
          print(
            12,
            '${foe.name}${LoreBattText.killHead}$sex${LoreBattText.killHeadRest}',
          );
        case 2:
          print(12, LoreBattText.killBlood);
        case 3:
          print(12, LoreBattText.killTorn);
      }
      _snd('scream2');
      plusExperience(person, k);
      foe.hp = 0;
      foe.isDead = true;
      return;
    }
    final me = p(person);
    if (rnd(20) > me.accArms) {
      print(7, '$sex${LoreBattText.attackMissed}');
      return;
    }
    var i = pround(me.strength * me.weaPower * me.battleLevel ~/ 20);
    i = i - i * rnd(50) ~/ 100;
    if (rnd(100) < foe.resistance) {
      print(
        7,
        '${LoreBattText.enemyResisted}$sex${LoreBattText.enemyResistedRest}',
      );
      return;
    }
    final j = pround(foe.ac * foe.level * (rnd(10) + 1) / 10);
    i = i - j;
    if (i <= 0) {
      print(
        7,
        '${LoreBattText.enemyBlocked}$sex${LoreBattText.enemyBlockedRest}',
      );
      return;
    }
    foe.hp = foe.hp - i;
    if (foe.hp <= 0) {
      foe.hp = 0;
      foe.isUnconscious = false;
      foe.isDead = false;
      print(
        12,
        '${LoreBattText.enemyKnockedOut}$sex${LoreBattText.enemyKnockedOutRest}',
      );
      _snd('hit');
      plusExperience(person, k);
      foe.isUnconscious = true;
    } else {
      print(
        7,
        '${LoreBattText.enemyDamaged}$i${LoreBattText.enemyDamagedRest}',
      );
      _snd('hit');
    }
  }

  void castOne() {
    final sex = sexData;
    var j = battle[person][2];
    var k = battle[person][3];
    if (enemy[k - 1].isDead) {
      if (!existEnemies()) return;
      battle[person][3] = battle[person][3] + 1;
      k = k + 1;
      if (battle[person][3] <= enemynumber) castOne();
      return;
    }
    final foe = enemy[k - 1];
    print(
      15,
      returnMessage(
        person,
        battle[person][1],
        battle[person][2],
        battle[person][3],
      ),
    );
    if (foe.isUnconscious) {
      print(12, '$sex${LoreBattText.magicOnCorpse}');
      _snd('scream1');
      plusExperience(person, k);
      foe.hp = 0;
      foe.isDead = true;
      return;
    }
    final me = p(person);
    var i = pround(me.magicLevel * j * j / 2);
    if (me.sp < i) {
      print(7, LoreBattText.spNotEnough);
      return;
    }
    me.sp = me.sp - i;
    if (rnd(20) >= me.accMagic) {
      print(
        7,
        '${LoreBattText.magicMissed}${foe.name}${LoreBattText.magicMissedRest}',
      );
      return;
    }
    i = pround(j * j * me.magicLevel * 2);
    if (rnd(100) < foe.resistance) {
      print(
        7,
        '${foe.name}${LoreBattText.enemyResistedMagic}$sex${LoreBattText.enemyResistedMagicRest}',
      );
      return;
    }
    j = pround(foe.ac * foe.level * (rnd(10) + 1) / 10);
    i = i - j;
    if (i <= 0) {
      print(
        7,
        '${LoreBattText.enemyBlockedMagic}${foe.name}'
        '${LoreBattText.enemyBlockedMagicRest}$sex${LoreBattText.enemyBlockedMagicTail}',
      );
      return;
    }
    foe.hp = foe.hp - i;
    if (foe.hp <= 0) {
      print(
        12,
        '${foe.name}${LoreBattText.magicKnockedOut}$sex${LoreBattText.magicKnockedOutRest}',
      );
      _snd('hit');
      plusExperience(person, k);
      foe.hp = 0;
      foe.isUnconscious = true;
    } else {
      print(
        7,
        '${foe.name}${LoreBattText.magicDamaged}$i${LoreBattText.magicDamagedRest}',
      );
      _snd('hit');
    }
  }

  void castAll() {
    battle[person][3] = 1;
    while (battle[person][3] <= enemynumber) {
      castOne();
      battle[person][3] = battle[person][3] + 1;
    }
  }

  void castSpecial() {
    if (!specialMagicLearned) {
      print(7, LoreBattText.noAbility);
      return;
    }
    final me = p(person);
    final e = enemy[battle[person][3] - 1];
    switch (battle[person][2]) {
      case 1:
        if (me.sp < 10) {
          print(7, LoreBattText.spNotEnough);
          return;
        }
        me.sp = me.sp - 10;
        if (rnd(100) < e.resistance) {
          print(7, LoreBattText.poisonResisted);
          return;
        }
        if (rnd(40) > me.accMagic) {
          print(7, LoreBattText.poisonMissed);
          return;
        }
        print(4, '${e.name}${LoreBattText.poisoned}');
        e.isPoisoned = true;
      case 2:
        if (me.sp < 30) {
          print(7, LoreBattText.spNotEnough);
          return;
        }
        me.sp = me.sp - 30;
        if (rnd(100) < e.resistance) {
          print(7, LoreBattText.techResisted);
          return;
        }
        if (rnd(60) > me.accMagic) {
          print(7, LoreBattText.techMissed);
          return;
        }
        print(4, '${e.name}${LoreBattText.techRemoved}');
        e.special = 0;
      case 3:
        if (me.sp < 15) {
          print(7, LoreBattText.spNotEnough);
          return;
        }
        me.sp = me.sp - 15;
        if (rnd(100) < e.resistance) {
          print(7, LoreBattText.defenseResisted);
          return;
        }
        final j = e.ac < 5 ? 40 : 25;
        if (rnd(j) > me.accMagic) {
          print(7, LoreBattText.defenseMissed);
          return;
        }
        print(4, '${e.name}${LoreBattText.defenseLowered}');
        if (e.resistance < 31 || rnd(2) == 0) {
          e.ac = decByte(e.ac);
        } else {
          e.resistance = e.resistance - 10;
        }
      case 4:
        if (me.sp < 20) {
          print(7, LoreBattText.spNotEnough);
          return;
        }
        me.sp = me.sp - 20;
        if (rnd(200) < e.resistance) {
          print(7, LoreBattText.powerResisted);
          return;
        }
        if (rnd(30) > me.accMagic) {
          print(7, LoreBattText.powerMissed);
          return;
        }
        print(4, '${e.name}${LoreBattText.powerLowered}');
        if (e.level > 1) e.level = e.level - 1;
        if (e.resistance > 0) {
          // byte field: 5 - 10 stores 251 in an unchecked byte.
          e.resistance = (e.resistance - 10) & 0xFF;
        } else {
          e.resistance = 0;
        }
      case 5:
        if (me.sp < 15) {
          print(7, LoreBattText.spNotEnough);
          return;
        }
        me.sp = me.sp - 15;
        if (rnd(100) < e.resistance) {
          print(7, LoreBattText.magicBanResisted);
          return;
        }
        if (rnd(100) > me.accMagic) {
          print(7, LoreBattText.magicBanMissed);
          return;
        }
        if (e.castLevel > 1) {
          print(4, '${e.name}${LoreBattText.magicLowered}');
        } else {
          print(4, '${e.name}${LoreBattText.magicRemoved}');
        }
        if (e.castLevel > 0) e.castLevel = e.castLevel - 1;
      case 6:
        if (me.sp < 20) {
          print(7, LoreBattText.spNotEnough);
          return;
        }
        me.sp = me.sp - 20;
        if (rnd(100) < e.resistance) {
          print(7, LoreBattText.espBanResisted);
          return;
        }
        if (rnd(100) > me.accMagic) {
          print(7, LoreBattText.espBanMissed);
          return;
        }
        if (e.specialCastLevel > 1) {
          print(4, '${e.name}${LoreBattText.espLowered}');
        } else {
          print(4, '${e.name}${LoreBattText.espRemoved}');
        }
        if (e.specialCastLevel > 0) e.specialCastLevel = e.specialCastLevel - 1;
    }
  }

  /// `BattleESP` 의 `party.etc[39] and bit1 > 0` (직업 2/3/6 이 아니어도 허용).
  bool espBit;

  /// `BattleESP`.
  void battleESP() {
    final me = p(person);
    final cls = me.playerClass.id;
    if (!(cls == 2 || cls == 3 || cls == 6 || espBit)) {
      print(7, LoreBattText.noAbility);
      return;
    }
    if (battle[person][2] == 1 ||
        battle[person][2] == 2 ||
        battle[person][2] == 4) {
      print(
        7,
        '${LoreSubText.magicName(battle[person][2] + 40)}${LoreBattText.espBattleOnly}',
      );
      return;
    }
    if (battle[person][2] == 3) {
      final e = enemy[battle[person][3] - 1];
      if (me.esp < 15) {
        print(7, LoreBattText.espNotEnough);
        return;
      }
      me.esp = me.esp - 15;
      if (![
        6,
        10,
        20,
        24,
        27,
        29,
        33,
        35,
        40,
        47,
        53,
        62,
      ].contains(e.eNumber)) {
        print(7, LoreBattText.mindReadFailed);
        return;
      }
      var j = e.level;
      if (e.eNumber == 62) j = 17;
      if (j > me.espLevel && rnd(2) == 0) {
        print(7, LoreBattText.mindReadWeak);
        return;
      }
      if (rnd(60) > (me.espLevel - j) * 2 + me.accEsp) {
        print(7, LoreBattText.mindReadResisted);
        return;
      }
      print(11, LoreBattText.mindReadJoined);
      onTelepathyJoin?.call(e.eNumber);
      e.isDead = true;
      e.isUnconscious = true;
      e.hp = 0;
      e.level = 0;
      return;
    }
    if (me.esp < 20) {
      print(7, LoreBattText.espNotEnough);
      return;
    }
    me.esp = me.esp - 20;
    final k = rnd(me.espLevel) + 1;
    final sex = sexData;
    final target = enemy[battle[person][3] - 1];
    if (k >= 1 && k <= 6) {
      switch (k) {
        case 1 || 2:
          print(
            7,
            '${LoreBattText.espRocks}${target.name}${LoreBattText.espRocksRest}',
          );
        case 3 || 4:
          print(7, '${target.name}${LoreBattText.espGerms}');
        default:
          print(
            7,
            '$sex${LoreBattText.espWeapon}${target.name}${LoreBattText.espWeaponRest}',
          );
      }
      var j = target.hp;
      if (j < k * 10) {
        j = 0;
      } else {
        j = j - k * 10;
      }
      target.hp = j;
      if (target.isUnconscious && !target.isDead) {
        target.isDead = true;
        plusExperience(person, battle[person][3]);
      }
      if (j == 0 && !target.isUnconscious) {
        target.isUnconscious = true;
        plusExperience(person, battle[person][3]);
      }
    } else if (k >= 7 && k <= 10) {
      if (k == 7 || k == 8) {
        print(7, LoreBattText.espFission);
        print(7, LoreBattText.espFissionRest);
      } else {
        print(7, LoreBattText.espFusion);
        print(7, LoreBattText.espFusionRest);
      }
      for (var i = 1; i <= enemynumber; i++) {
        final en = enemy[i - 1];
        var j = en.hp;
        if (j < k * 5) {
          j = 0;
        } else {
          j = j - k * 5;
        }
        en.hp = j;
        if (en.isUnconscious && !en.isDead) {
          en.isDead = true;
          // 원본은 여기서 `battle[person,3]` 를 넘긴다(i 가 아님).
          plusExperience(person, battle[person][3]);
        }
        if (j == 0 && !en.isUnconscious) {
          en.isUnconscious = true;
          plusExperience(person, i);
        }
      }
    } else if (k == 11 || k == 12) {
      print(7, '$sex${LoreBattText.espFear}');
      final j = battle[person][3];
      final e = enemy[j - 1];
      if (rnd(40) < e.resistance) {
        e.resistance = e.resistance < 5 ? 0 : e.resistance - 5;
        return;
      }
      if (rnd(60) > me.accEsp) {
        e.endurance = e.endurance < 5 ? 0 : e.endurance - 5;
        return;
      }
      e.isDead = true;
      print(10, '${e.name}${LoreBattText.espFled}');
    } else if (k == 13 || k == 14) {
      print(
        7,
        '$sex${LoreBattText.espMetabolism}${LoreBattText.espMetabolismRest}',
      );
      final e = enemy[battle[person][3] - 1];
      if (rnd(100) < e.resistance) return;
      if (rnd(40) > me.accEsp) return;
      e.isPoisoned = true;
    } else if (k >= 15 && k <= 17) {
      print(7, '$sex${LoreBattText.espHeart}');
      final j = battle[person][3];
      final e = enemy[j - 1];
      if (rnd(40) < e.resistance) {
        e.resistance = e.resistance < 5 ? 0 : e.resistance - 5;
        return;
      }
      if (rnd(80) > me.accEsp) {
        if (e.hp < 10) {
          e.hp = 0;
          e.isUnconscious = true;
        } else {
          e.hp = e.hp - 5;
        }
        return;
      }
      e.isUnconscious = true;
    } else {
      print(7, '$sex${LoreBattText.espIllusion}');
      final j = battle[person][3];
      final e = enemy[j - 1];
      if (rnd(40) < e.resistance) {
        e.agility = e.agility < 5 ? 0 : e.agility - 5;
        return;
      }
      if (rnd(30) > me.accEsp) return;
      if (e.accArms > 0) e.accArms = e.accArms - 1;
      if (e.accMagic > 0) e.accMagic = e.accMagic - 1;
    }
  }

  /// `RunAway`.
  bool runAway() {
    if (rnd(50) > p(person).agility) {
      print(7, LoreBattText.runFailed);
      return false;
    }
    print(11, LoreBattText.runSuccess);
    return true;
  }

  // ------------------------------------------------------------------
  // 적 행동
  // ------------------------------------------------------------------

  /// 현재 `person`(적 번호)이 가리키는 적.
  Monster get _foe => enemy[person - 1];

  int _pickLivingPartyMember() {
    var k = 0;
    for (var i = 1; i <= 6; i++) {
      if (exist(i)) k++;
    }
    final h = rnd(k) + 1;
    k = 0;
    var j = 0;
    for (var i = 1; i <= 6; i++) {
      if (exist(i)) {
        k++;
        if (k == h) j = i;
      }
    }
    if (j == 0) j = rnd(6) + 1;
    if (p(j).name == '') j = rnd(5) + 1;
    return j;
  }

  void weaponAttack() {
    final e = _foe;
    if (rnd(20) >= e.accArms) {
      print(7, '${e.name}${LoreBattText.partyMissed}');
      return;
    }
    final j = _pickLivingPartyMember();
    var i = e.strength * e.level * (rnd(10) + 1) ~/ 10;
    final target = p(j);
    if (exist(j)) {
      if (rnd(50) < target.resistance) {
        print(
          13,
          '${e.name}${LoreBattText.enemyAttacked}${target.name}${LoreBattText.enemyAttackedRest}',
        );
        print(
          7,
          '${LoreBattText.partyResisted}${target.name}${LoreBattText.partyResistedRest}',
        );
        return;
      }
    }
    if (exist(j)) {
      i = i - (target.ac * target.battleLevel * (rnd(10) + 1) ~/ 10);
    }
    if (i <= 0) {
      print(
        13,
        '${e.name}${LoreBattText.enemyAttacked}${target.name}${LoreBattText.enemyAttackedRest}',
      );
      print(
        7,
        '${LoreBattText.partyResisted}${target.name}${LoreBattText.partyBlockedRest}',
      );
      return;
    }
    if (target.dead > 0) target.dead = target.dead + i;
    if (target.unconscious > 0 && target.dead == 0) {
      target.unconscious = target.unconscious + i;
    }
    if (target.hp > 0) target.hp = target.hp - i;
    print(
      13,
      '${target.name}${LoreBattText.partyWasAttacked}${e.name}${LoreBattText.partyWasAttackedRest}',
    );
    print(
      13,
      '${target.name}${LoreBattText.partyDamaged}$i${LoreBattText.partyDamagedRest}',
    );
  }

  void castAttackSub(int power, int num) {
    final e = _foe;
    if (rnd(20) >= e.accMagic) {
      print(7, '${e.name}${LoreBattText.enemyMagicMissed}');
      return;
    }
    final t = p(num);
    if (exist(num)) {
      if (rnd(50) < t.resistance) {
        print(
          7,
          '${LoreBattText.partyResistedEnemyMagic}${t.name}${LoreBattText.partyResistedEnemyMagicRest}',
        );
        return;
      }
    }
    power = power - rnd(power ~/ 2);
    if (exist(num)) {
      power = power - (t.ac * t.battleLevel * (rnd(10) + 1) ~/ 10);
    }
    if (power <= 0) {
      print(
        7,
        '${LoreBattText.partyResistedEnemyMagic}${t.name}${LoreBattText.partyBlockedEnemyMagicRest}',
      );
      return;
    }
    if (t.dead > 0) t.dead = t.dead + power;
    if (t.unconscious > 0 && t.dead == 0) t.unconscious = t.unconscious + power;
    if (t.hp > 0) t.hp = t.hp - power;
    print(
      13,
      '${t.name}${LoreBattText.partyDamaged}$power${LoreBattText.partyDamagedRest}',
    );
  }

  void castAttackOne(int num) {
    final e = _foe;
    String s;
    int k;
    final m = e.mentality;
    if (m >= 1 && m <= 3) {
      s = '충격';
      k = 1;
    } else if (m >= 4 && m <= 8) {
      s = '냉기';
      k = 2;
    } else if (m >= 9 && m <= 10) {
      s = '고통';
      k = 4;
    } else if (m >= 11 && m <= 14) {
      s = '혹한';
      k = 6;
    } else if (m >= 15 && m <= 18) {
      s = '화염';
      k = 7;
    } else {
      s = '번개';
      k = 10;
    }
    final i = k * e.level;
    print(
      13,
      '${e.name}${LoreBattText.enemyMagicUsed}${p(num).name}'
      '${LoreBattText.enemyMagicUsedRest}$s${LoreBattText.enemyMagicUsedTail}',
    );
    castAttackSub(i, num);
  }

  void castAttackAll() {
    final e = _foe;
    String method;
    int k;
    final m = e.mentality;
    if (m >= 1 && m <= 6) {
      method = '열파';
      k = 1;
    } else if (m >= 7 && m <= 12) {
      method = '에너지';
      k = 2;
    } else if (m >= 13 && m <= 16) {
      method = '초음파';
      k = 3;
    } else if (m >= 17 && m <= 20) {
      method = '혹한기';
      k = 5;
    } else {
      method = '화염폭풍';
      k = 8;
    }
    final i = k * e.level;
    print(13, "${e.name}는 일행 모두에게 '$method'마법을 사용했다");
    for (var j = 1; j <= 6; j++) {
      castAttackSub(i, j);
    }
  }

  void enemyCure(int num, int plus) {
    final target = enemy[num - 1];
    if (person == num) {
      print(13, '${_foe.name}는 자신을 치료했다');
    } else {
      print(13, '${_foe.name}는 ${target.name}를 치료했다');
    }
    if (target.isDead) {
      target.isDead = false;
    } else if (target.isUnconscious) {
      target.isUnconscious = false;
      if (target.hp <= 0) target.hp = 1;
    } else {
      target.hp = target.hp + plus;
      if (target.hp > target.endurance * target.level) {
        target.hp = target.endurance * target.level;
      }
    }
  }

  int _livingCount() {
    var k = 0;
    for (var i = 1; i <= 6; i++) {
      if (exist(i)) k++;
    }
    return k;
  }

  int _weakestLiving() {
    var j = 1;
    for (var i = 6; i >= 1; i--) {
      if (exist(i)) j = i;
    }
    for (var i = 2; i <= 6; i++) {
      if (exist(i) && p(i).hp < p(j).hp) j = i;
    }
    return j;
  }

  void castAttack() {
    final e = _foe;
    switch (e.castLevel) {
      case 1:
        final k = p(6).name == '' ? 5 : 6;
        var j = rnd(k) + 1;
        if (!exist(j)) j = rnd(k) + 1;
        castAttackOne(j);
      case 2:
        castAttackOne(_pickLivingPartyMember());
      case 3:
        if (rnd(_livingCount()) < 2) {
          castAttackOne(_pickLivingPartyMember());
        } else {
          castAttackAll();
        }
      case 4:
        if (e.hp < e.endurance * e.level ~/ 3 && rnd(2) == 0) {
          enemyCure(person, e.level * e.mentality ~/ 4);
        } else {
          if (rnd(_livingCount()) < 2) {
            castAttackOne(_pickLivingPartyMember());
          } else {
            castAttackAll();
          }
        }
      case 5:
        if (e.hp < e.endurance * e.level ~/ 3 && rnd(3) == 0) {
          enemyCure(person, e.level * e.mentality ~/ 4);
        } else {
          if (rnd(_livingCount()) < 2) {
            var j = 0;
            var k = 0;
            for (var i = 1; i <= enemynumber; i++) {
              j = j + enemy[i - 1].hp;
            }
            for (var i = 1; i <= enemynumber; i++) {
              k = k + enemy[i - 1].endurance * enemy[i - 1].level;
            }
            k = k ~/ 3;
            if (enemynumber > 2 && j < k && rnd(2) == 0) {
              for (var i = 1; i <= enemynumber; i++) {
                enemyCure(i, e.level * e.mentality ~/ 6);
              }
            } else {
              castAttackOne(_weakestLiving());
            }
          } else {
            castAttackAll();
          }
        }
      case 6:
        if (e.hp < e.endurance * e.level ~/ 3 && rnd(3) == 0) {
          enemyCure(person, e.level * e.mentality ~/ 4);
          return;
        }
        var j = 0;
        var k = 0;
        for (var i = 1; i <= 6; i++) {
          if (p(i).name != '') {
            j++;
            k = k + p(i).ac;
          }
        }
        k = j == 0 ? 0 : k ~/ j;
        if (k > 4 && rnd(5) == 0) {
          for (var i = 1; i <= 6; i++) {
            if (p(i).name != '') {
              print(13, '${e.name}는 ${p(i).name}의 갑옷파괴를 시도했다');
              if (p(i).luck > rnd(21)) {
                print(7, '그러나, ${e.name}는 성공하지 못했다');
              } else {
                print(5, '${p(i).name}의 갑옷은 파괴되었다');
                if (p(i).ac > 0) p(i).ac = p(i).ac - 1;
              }
            }
          }
        } else {
          j = 0;
          k = 0;
          for (var i = 1; i <= enemynumber; i++) {
            j = j + enemy[i - 1].hp;
          }
          for (var i = 1; i <= enemynumber; i++) {
            k = k + enemy[i - 1].endurance * enemy[i - 1].level;
          }
          k = k ~/ 3;
          if (enemynumber > 2 && j < k && rnd(3) != 0) {
            for (var i = 1; i <= enemynumber; i++) {
              enemyCure(i, e.level * e.mentality ~/ 6);
            }
          } else {
            if (rnd(_livingCount()) < 2) {
              castAttackOne(_weakestLiving());
            } else {
              castAttackAll();
            }
          }
        }
    }
  }

  int _pickBy(bool Function(PartyMember) test) {
    var k = 0;
    for (var i = 1; i <= 6; i++) {
      if (test(p(i))) k++;
    }
    final h = rnd(k) + 1;
    k = 0;
    var j = 0;
    for (var i = 1; i <= 6; i++) {
      if (test(p(i))) {
        k++;
        if (k == h) j = i;
      }
    }
    if (j == 0) j = rnd(6) + 1;
    if (p(j).name == '') j = rnd(5) + 1;
    return j;
  }

  void specialAttack() {
    final e = _foe;
    switch (e.special) {
      case 1:
        final j = _pickBy((q) => q.poison == 0);
        final t = p(j);
        print(13, '${e.name}는 ${t.name}에게 독 공격을 시도했다');
        if (rnd(40) > e.agility) {
          print(7, '독 공격은 실패했다');
          return;
        }
        if (rnd(20) < t.luck) {
          print(7, '그러나, ${t.name}는 독 공격을 피했다');
          return;
        }
        print(4, '${t.name}는 중독 되었다 !!');
        if (t.poison == 0) t.poison = 1;
      case 2:
        final j = _pickBy((q) => q.unconscious == 0);
        final t = p(j);
        print(13, '${e.name}는 ${t.name}에게 치명적 공격을 시도했다');
        if (rnd(50) > e.agility) {
          print(7, '치명적 공격은 실패했다');
          return;
        }
        if (rnd(20) < t.luck) {
          print(7, '그러나, ${t.name}는 치명적 공격을 피했다');
          return;
        }
        print(4, '${t.name}는 의식불명이 되었다 !!');
        if (t.unconscious == 0) {
          t.unconscious = 1;
          if (t.hp > 0) t.hp = 0;
        }
      case 3:
        final j = _pickBy((q) => q.dead == 0);
        final t = p(j);
        print(13, '${e.name}는 ${t.name}에게 죽음의 공격을 시도했다');
        if (rnd(60) > e.agility) {
          print(7, '죽음의 공격은 실패했다');
          return;
        }
        if (rnd(20) < t.luck) {
          print(7, '그러나, ${t.name}는 죽음의 공격을 피했다');
          return;
        }
        print(4, '${t.name}는 죽었다 !!');
        if (t.dead == 0) {
          t.dead = 1;
          if (t.hp > 0) t.hp = 0;
        }
    }
  }

  void specialCastAttack() {
    final e = _foe;
    if (e.eNumber == 1) return;
    var j = 0;
    var k = enemynumber;
    for (var i = enemynumber; i >= 1; i--) {
      if (!enemy[i - 1].isDead) {
        j++;
      } else {
        k = i;
      }
    }
    if (j < rnd(3) + 2 && rnd(3) == 0) {
      var appended = false;
      if (enemynumber < 7) {
        appended = true;
        // inc(enemynumber): 새 칸이 생긴다.
        enemy.add(Monster.create(1));
        k = enemynumber;
      }
      final summoned = e.eNumber + rnd(4) - 20;
      if (_validEnemyId(summoned)) {
        _joinEnemy(k, summoned);
        print(13, '${e.name}는 ${enemy[k - 1].name}를 생성시켰다');
      } else if (appended) {
        // 원본은 범위 밖 `enemydata` 를 읽는다(미확인). 새 칸은 죽은 상태로 둔다.
        enemy[k - 1].isDead = true;
      }
    }
    if (e.specialCastLevel > 1) {
      j = 0;
      k = enemynumber;
      for (var i = enemynumber; i >= 1; i--) {
        if (!enemy[i - 1].isDead) {
          j++;
        } else {
          k = i;
        }
      }
      if (p(6).name != '' && j < 7 && rnd(5) == 0) {
        if (enemynumber < 7) {
          enemy.add(Monster.create(1));
          k = enemynumber;
        }
        _turnMind(k, 6);
        p(6).name = '';
        print(13, '${e.name}가 독심술을 사용하여 ${enemy[k - 1].name}을 자기편으로 끌어들였다');
      }
    }
    if (e.specialCastLevel > 2) {
      if (e.special == 0) return;
      if (rnd(5) == 0) {
        for (var kk = 1; kk <= 6; kk++) {
          final t = p(kk);
          if (t.dead == 0 && t.name != '') {
            print(13, '${e.name}는 ${t.name}에게 죽음의 공격을 시도했다');
            if (rnd(60) > e.agility) {
              print(7, '죽음의 공격은 실패했다');
            } else if (rnd(20) < t.luck) {
              print(7, '그러나, ${t.name}는 죽음의 공격을 피했다');
            } else {
              print(4, '${t.name}는 죽었다 !!');
              if (t.dead == 0) {
                t.dead = 1;
                if (t.hp > 0) t.hp = 0;
              }
            }
          }
        }
      }
    }
  }

  bool _validEnemyId(int j) {
    final id = j & 0xFF;
    return id >= 1 && id <= Monster.monsterTemplates.length;
  }

  /// `joinenemy(num, j)`.
  void _joinEnemy(int num, int j) {
    if (!_validEnemyId(j)) return;
    enemy[num - 1] = Monster.create(j & 0xFF);
  }

  /// `turn_mind(j, enemy_num)`: 파티원 j 를 적 enemy_num 으로 바꾼다.
  void _turnMind(int enemyNum, int j) {
    final q = p(j);
    final level = q.battleLevel;
    enemy[enemyNum - 1] = Monster(
      eNumber: 1,
      name: q.name,
      strength: q.strength,
      mentality: q.mentality,
      endurance: q.endurance,
      resistance: q.resistance,
      agility: q.agility,
      accArms: q.accArms,
      accMagic: q.accMagic,
      ac: q.ac,
      special: q.playerClass.id == 7 ? 2 : 0,
      castLevel: q.magicLevel ~/ 4,
      specialCastLevel: 0,
      level: level,
      hp: q.endurance * level,
    );
  }

  /// `EnemyAttack` (현재 `person` = 적 번호).
  void enemyAttack() {
    final e = _foe;
    if (e.specialCastLevel > 0) specialCastAttack();
    var i = e.agility;
    if (i > 20) i = 20;
    if (e.special > 0 && rnd(50) < i) {
      var j = 0;
      for (var n = 1; n <= enemynumber; n++) {
        final x = enemy[n - 1];
        if (!(x.isUnconscious || x.isDead)) j++;
      }
      if (j > 3) {
        specialAttack();
        return;
      }
    }
    final a = rnd(e.accArms * 1000);
    final b = rnd(e.accMagic * 1000);
    if (a > b && e.strength > 0) {
      weaponAttack();
    } else {
      castAttack();
    }
  }

  // ------------------------------------------------------------------
  // BattleMode 의 조각
  // ------------------------------------------------------------------

  /// `k = 8` 의 자동 선택(직업별).
  void autoSelect(int who) {
    person = who;
    final me = p(who);
    final cls = me.playerClass.id;
    if (cls == 2 || cls == 9) {
      battle[who][1] = 2;
      int i;
      final l = me.magicLevel;
      if (l <= 1) {
        i = 1;
      } else if (l <= 3) {
        i = 2;
      } else if (l <= 7) {
        i = 3;
      } else if (l <= 11) {
        i = 4;
      } else if (l <= 15) {
        i = 5;
      } else {
        i = 6;
      }
      i = pround(i / 2);
      if (i == 0) i = 1;
      battle[who][2] = i;
      battle[who][3] = 1;
    } else if (cls == 3) {
      battle[who][1] = 6;
      battle[who][2] = 5;
      var j = 1;
      for (var i = 1; i <= enemynumber; i++) {
        if (!(enemy[i - 1].isUnconscious || enemy[i - 1].isDead)) j = i;
      }
      battle[who][3] = j;
    } else {
      battle[who][1] = 1;
      battle[who][2] = me.weapon;
      battle[who][3] = 1;
    }
  }

  /// 실행 루프의 한 사람 분(`for person := 1 to 6 ... if exist(person)`).
  /// 도주에 성공하면 true (이때 호출자는 etc[6] := 2 로 전투를 끝낸다).
  bool executePerson(int who) {
    person = who;
    if (!exist(who)) return false;
    final how = battle[who][1];
    // `ReturnMessage` 는 how 가 0, 4, 6..8 일 때만 여기서 출력된다.
    if (how == 0 || how == 4 || (how >= 6 && how <= 8)) {
      print(15, returnMessage(who, how, battle[who][2], battle[who][3]));
    }
    switch (how) {
      case 1:
        attackOne();
      case 2:
        castOne();
      case 3:
        castAll();
      case 4:
        castSpecial();
      case 6:
        battleESP();
      case 7:
        if (runAway()) return true;
    }
    return false;
  }

  /// 적 단계: 독 피해 후 행동 (`loop:` 이후).
  void enemyPhase() {
    // Pascal 의 `for` 상한은 시작 때 한 번만 계산되어, 이 단계에 소환된 적은
    // 다음 단계부터 행동한다.
    final count = enemynumber;
    for (var n = 1; n <= count; n++) {
      person = n;
      final e = enemy[n - 1];
      if (e.isPoisoned) {
        if (e.isUnconscious) {
          e.isDead = true;
        } else {
          e.hp = e.hp - 1;
          if (e.hp <= 0) e.isUnconscious = true;
        }
      }
      if (!(e.isDead || e.isUnconscious)) enemyAttack();
    }
  }

  /// `EndBattle`: 0 = 승리, 1 = 패배, null = 계속.
  int? endBattle() {
    var i = 0;
    var j = 0;
    for (var n = 1; n <= 6; n++) {
      if (p(n).name != '') {
        i++;
        if (!exist(n)) j++;
      }
    }
    if (i == j) return 1;
    i = 0;
    j = 0;
    for (var n = 1; n <= enemynumber; n++) {
      i++;
      if (enemy[n - 1].isDead || enemy[n - 1].isUnconscious) j++;
    }
    if (i == j) return 0;
    return null;
  }
}
