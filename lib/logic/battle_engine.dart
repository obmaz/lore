import 'dart:math';

import 'lore_batt_text.dart';

import '../models/party_member.dart';
import '../models/monster.dart';
import '../data/lore_data.dart';

enum AttackOutcome {
  hit,
  miss,
  resisted,
  blocked,
  unconscious,
  killed,
  outOfSp,
  cured,
  debuffed,
  joined,
  summoned,
  converted,
  failed,
}

class AttackResult {
  final AttackOutcome outcome;
  final int damage;
  final int expGained;
  final String message;

  const AttackResult({
    required this.outcome,
    this.damage = 0,
    this.expGained = 0,
    required this.message,
  });
}

/// 1993년 원작 LOREBATT.PAS 및 LOREMENU.PAS 기반 풀 스펙 전투 공식 엔진
class BattleEngine {
  final Random _random;

  BattleEngine({Random? random}) : _random = random ?? Random();

  /// 파스칼의 random(n)과 동일: 0 이상 n 미만의 정수 반환
  int _rand(int n) => n <= 0 ? 0 : _random.nextInt(n);

  // ==========================================
  // 1. 플레이어 일반 무기 공격 (AttackOne - LOREBATT.PAS:527)
  // ==========================================
  AttackResult executePlayerWeaponAttack(
    PartyMember attacker,
    Monster target, {
    List<PartyMember>? party,
  }) {
    if (target.isDead) {
      return const AttackResult(
        outcome: AttackOutcome.miss,
        message: '공격 대상이 이미 쓰러져 있습니다.',
      );
    }

    // 1. 적이 기절(의식불명) 상태인 경우: 무조건 즉사 처형
    if (target.isUnconscious && !target.isDead) {
      target.hp = 0;
      target.isDead = true;
      final exp = calculateExperience(target);
      _awardExecutionExperience(attacker, exp, party);
      return AttackResult(
        outcome: AttackOutcome.killed,
        expGained: exp,
        message:
            '${LoreBattText.weaponKill(LoreBattText.sexData(attacker.sex == Gender.female), target.name, _rand(4))}'
            ' (${_executionExperienceMessage(attacker, exp, party)})',
      );
    }

    // 2. 명중 판정 (random(20) > accuracy[1] 이면 빗나감)
    if (_rand(20) > attacker.accArms) {
      // 원작 LOREBATT.PAS:138 - `{sexdata}의 공격은 빗나갔다 ....`
      return AttackResult(
        outcome: AttackOutcome.miss,
        message:
            '${LoreBattText.sexData(attacker.sex == Gender.female)}'
            '${LoreBattText.attackMissed}',
      );
    }

    // 3. 기초 대미지 계산 및 50% 난수 변동
    // i := round(strength * wea_power * level[1] div 20);
    int baseDmg =
        (attacker.strength * attacker.weaPower * attacker.battleLevel) ~/ 20;
    // i := i - i * random(50) div 100;
    baseDmg = baseDmg - (baseDmg * _rand(50)) ~/ 100;

    // 4. 적 저항 판정 (random(100) < resistance)
    if (_rand(100) < target.resistance) {
      // 원작 LOREBATT.PAS:144 - `적은 {sexdata}의 공격을 저지했다`
      final sex = LoreBattText.sexData(attacker.sex == Gender.female);
      return AttackResult(
        outcome: AttackOutcome.resisted,
        message:
            '${LoreBattText.enemyResisted}$sex'
            '${LoreBattText.enemyResistedRest}',
      );
    }

    // 5. 적 방어력(AC) 감쇄: ac * level * (random(10)+1) / 10
    final defReduce = (target.ac * target.level * (_rand(10) + 1) / 10).round();
    final finalDmg = baseDmg - defReduce;

    if (finalDmg <= 0) {
      // 원작 LOREBATT.PAS:150 - `그러나, 적은 {sexdata}의 공격을 막았다`
      final sex = LoreBattText.sexData(attacker.sex == Gender.female);
      return AttackResult(
        outcome: AttackOutcome.blocked,
        message:
            '${LoreBattText.enemyBlocked}$sex'
            '${LoreBattText.enemyBlockedRest}',
      );
    }

    // 6. 피해 적용 및 기절 판정
    target.hp -= finalDmg;
    if (target.hp <= 0) {
      target.hp = 0;
      target.isUnconscious = true;
      final exp = calculateExperience(target);
      attacker.experience += exp;
      // 원작 LOREBATT.PAS:159 - `적은 {sexdata}의 공격으로 의식불명이 되었다`
      final sex = LoreBattText.sexData(attacker.sex == Gender.female);
      return AttackResult(
        outcome: AttackOutcome.unconscious,
        damage: finalDmg,
        expGained: exp,
        message:
            '${LoreBattText.enemyKnockedOut}$sex'
            '${LoreBattText.enemyKnockedOutRest}'
            ' (${LoreBattText.expGained(attacker.name, '$exp')})',
      );
    }

    // 원작 LOREBATT.PAS:165 - `적은 {n}만큼의 피해를 입었다`
    return AttackResult(
      outcome: AttackOutcome.hit,
      damage: finalDmg,
      message:
          '${LoreBattText.enemyDamaged}$finalDmg'
          '${LoreBattText.enemyDamagedRest}',
    );
  }

  // ==========================================
  // 2. 플레이어 단일 마법 공격 (CastOne - LOREBATT.PAS:172)
  // 마법 1..6: 마법 화살, 마법 화구, 마법 단창, 독 바늘, 맥동 광선, 직격 뇌전
  // ==========================================
  AttackResult executePlayerMagicAttack(
    PartyMember attacker,
    Monster target,
    int magicIndex, {
    List<PartyMember>? party,
  }) => executePlayerSingleMagicAttack(
    attacker,
    target,
    magicIndex,
    party: party,
  );

  AttackResult executePlayerSingleMagicAttack(
    PartyMember attacker,
    Monster target,
    int magicIndex, {
    List<PartyMember>? party,
  }) {
    if (target.isDead) {
      return const AttackResult(
        outcome: AttackOutcome.miss,
        message: '공격 대상이 이미 사망했습니다.',
      );
    }

    // 원본 CastOne은 의식불명 처형을 SP 검사·소모보다 먼저 실행한다.
    if (target.isUnconscious) {
      target.hp = 0;
      target.isDead = true;
      final exp = calculateExperience(target);
      _awardExecutionExperience(attacker, exp, party);
      return AttackResult(
        outcome: AttackOutcome.killed,
        expGained: exp,
        message:
            '${attacker.name}의 마법은 ${target.name}의 시체 위에서 작열하여 소멸시켰다! (${_executionExperienceMessage(attacker, exp, party)})',
      );
    }

    final spell = LoreData.instance.spell(magicIndex);
    final reqSp = spell.calculateSpCost(attacker.magicLevel);

    if (attacker.sp < reqSp) {
      return const AttackResult(
        outcome: AttackOutcome.outOfSp,
        message: '마법 지수(SP)가 부족합니다!',
      );
    }
    attacker.sp -= reqSp;

    // 명중 판정 (random(20) >= accuracy[2])
    if (_rand(20) >= attacker.accMagic) {
      return AttackResult(
        outcome: AttackOutcome.miss,
        message: '그러나, \'${spell.name}\' 마법은 ${target.name}을(를) 빗나갔다.',
      );
    }

    // 위력: round(j * j * level[2] * 2)
    final baseDmg = magicIndex * magicIndex * attacker.magicLevel * 2;

    // 적 마법 저항 판정 (random(100) < resistance)
    if (_rand(100) < target.resistance) {
      return AttackResult(
        outcome: AttackOutcome.resisted,
        message: '${target.name}은(는) \'${spell.name}\' 마법을 저지했다!',
      );
    }

    // 적 방어력 감쇄
    final defReduce = (target.ac * target.level * (_rand(10) + 1) / 10).round();
    final finalDmg = baseDmg - defReduce;

    if (finalDmg <= 0) {
      return AttackResult(
        outcome: AttackOutcome.blocked,
        message: '그러나, ${target.name}은(는) 마법 공격을 막았다!',
      );
    }

    target.hp -= finalDmg;
    if (target.hp <= 0) {
      target.hp = 0;
      target.isUnconscious = true;
      final exp = calculateExperience(target);
      attacker.experience += exp;
      return AttackResult(
        outcome: AttackOutcome.unconscious,
        damage: finalDmg,
        expGained: exp,
        message:
            '${target.name}은(는) \'${spell.name}\'에 의해 의식불명이 되었다! (EXP +$exp)',
      );
    }

    return AttackResult(
      outcome: AttackOutcome.hit,
      damage: finalDmg,
      message: '${target.name}은(는) \'${spell.name}\'으로 $finalDmg만큼의 피해를 입었다.',
    );
  }

  // ==========================================
  // 3. 플레이어 전체 마법 공격 (CastAll - LOREBATT.PAS:236)
  // 마법 7..12: 공기 폭풍, 열선 파동, 초음파, 초냉기, 인공 지진, 차원 이탈
  // ==========================================
  List<AttackResult> executePlayerAllMagicAttack(
    PartyMember attacker,
    List<Monster> enemies,
    int magicIndex, {
    List<PartyMember>? party,
  }) {
    final spell = LoreData.instance.spell(magicIndex);
    final reqSp = spell.calculateSpCost(attacker.magicLevel);

    final results = <AttackResult>[];
    final j = magicIndex - 6; // 1..6 등급

    for (final target in enemies) {
      if (target.isDead) continue;

      if (target.isUnconscious) {
        target.hp = 0;
        target.isDead = true;
        final exp = calculateExperience(target);
        _awardExecutionExperience(attacker, exp, party);
        results.add(
          AttackResult(
            outcome: AttackOutcome.killed,
            expGained: exp,
            message:
                '${target.name}의 시체 위에서 \'${spell.name}\'이 작열했다! (${_executionExperienceMessage(attacker, exp, party)})',
          ),
        );
        continue;
      }

      if (attacker.sp < reqSp) {
        results.add(
          const AttackResult(
            outcome: AttackOutcome.outOfSp,
            message: '마법 지수(SP)가 부족합니다!',
          ),
        );
        continue;
      }
      attacker.sp -= reqSp;

      // 명중 판정
      if (_rand(20) >= attacker.accMagic) {
        results.add(
          AttackResult(
            outcome: AttackOutcome.miss,
            message: '${target.name}에게는 마법이 빗나갔다.',
          ),
        );
        continue;
      }

      // 저항 판정
      if (_rand(100) < target.resistance) {
        results.add(
          AttackResult(
            outcome: AttackOutcome.resisted,
            message: '${target.name}은(는) 마법을 저지했다!',
          ),
        );
        continue;
      }

      final baseDmg = j * j * attacker.magicLevel * 2;
      final defReduce = (target.ac * target.level * (_rand(10) + 1) / 10)
          .round();
      final finalDmg = baseDmg - defReduce;

      if (finalDmg <= 0) {
        results.add(
          AttackResult(
            outcome: AttackOutcome.blocked,
            message: '${target.name}은(는) 마법을 막아냈다!',
          ),
        );
        continue;
      }

      target.hp -= finalDmg;
      if (target.hp <= 0) {
        target.hp = 0;
        target.isUnconscious = true;
        final exp = calculateExperience(target);
        attacker.experience += exp;
        results.add(
          AttackResult(
            outcome: AttackOutcome.unconscious,
            damage: finalDmg,
            expGained: exp,
            message: '${target.name}은(는) $finalDmg의 피해를 입고 쓰러졌다! (EXP +$exp)',
          ),
        );
      } else {
        results.add(
          AttackResult(
            outcome: AttackOutcome.hit,
            damage: finalDmg,
            message: '${target.name}은(는) $finalDmg의 피해를 입었다.',
          ),
        );
      }
    }

    return results;
  }

  // ==========================================
  // 4. 플레이어 특수 디버프 마법 (CastSpecial - LOREBATT.PAS:245)
  // 마법 13..18: 독, 기술 무력화, 방어 무력화, 능력 저하, 마법 불능, 탈 초인화
  // ==========================================
  AttackResult executePlayerSpecialDebuff(
    PartyMember attacker,
    Monster target,
    int debuffIndex, // 13 ~ 18
  ) {
    if (target.isDead || target.isUnconscious) {
      return const AttackResult(
        outcome: AttackOutcome.miss,
        message: '행동 불능 상태인 적에게는 시전할 수 없습니다.',
      );
    }

    final spell = LoreData.instance.spell(debuffIndex);
    final reqSp = spell.calculateSpCost(attacker.magicLevel);

    if (attacker.sp < reqSp) {
      return const AttackResult(
        outcome: AttackOutcome.outOfSp,
        message: '마법 지수(SP)가 부족합니다!',
      );
    }
    attacker.sp -= reqSp;

    switch (debuffIndex) {
      case 13: // 독 (SP 10)
        if (_rand(100) < target.resistance) {
          return AttackResult(
            outcome: AttackOutcome.resisted,
            message: '${target.name}은(는) 독 공격을 저지했다!',
          );
        }
        if (_rand(40) > attacker.accMagic) {
          return AttackResult(
            outcome: AttackOutcome.miss,
            message: '독 공격은 빗나갔다.',
          );
        }
        target.isPoisoned = true;
        return AttackResult(
          outcome: AttackOutcome.debuffed,
          message: '★ ${target.name}은(는) 중독되었다!',
        );

      case 14: // 기술 무력화 (SP 30)
        if (_rand(100) < target.resistance) {
          return AttackResult(
            outcome: AttackOutcome.resisted,
            message: '기술 무력화 공격은 저지당했다!',
          );
        }
        if (_rand(60) > attacker.accMagic) {
          return AttackResult(
            outcome: AttackOutcome.miss,
            message: '기술 무력화 공격은 빗나갔다.',
          );
        }
        target.special = 0;
        return AttackResult(
          outcome: AttackOutcome.debuffed,
          message: '★ ${target.name}의 특수 공격 능력이 완전히 제거되었다!',
        );

      case 15: // 방어 무력화 (SP 15)
        if (_rand(100) < target.resistance) {
          return AttackResult(
            outcome: AttackOutcome.resisted,
            message: '방어 무력화 공격은 저지당했다!',
          );
        }
        final check = target.ac < 5 ? 40 : 25;
        if (_rand(check) > attacker.accMagic) {
          return AttackResult(
            outcome: AttackOutcome.miss,
            message: '방어 무력화 공격은 빗나갔다.',
          );
        }
        if (target.resistance < 31 || _rand(2) == 0) {
          if (target.ac > 0) target.ac--;
        } else {
          target.resistance = max(0, target.resistance - 10);
        }
        return AttackResult(
          outcome: AttackOutcome.debuffed,
          message: '★ ${target.name}의 방어 능력이 저하되었다!',
        );

      case 16: // 능력 저하 (SP 20)
        if (_rand(200) < target.resistance) {
          return AttackResult(
            outcome: AttackOutcome.resisted,
            message: '능력 저하 공격은 저지당했다!',
          );
        }
        if (_rand(30) > attacker.accMagic) {
          return AttackResult(
            outcome: AttackOutcome.miss,
            message: '능력 저하 공격은 빗나갔다.',
          );
        }
        if (target.level > 1) target.level--;
        target.resistance = max(0, target.resistance - 10);
        return AttackResult(
          outcome: AttackOutcome.debuffed,
          message: '★ ${target.name}의 전체적인 능력(Lv/저항)이 저하되었다!',
        );

      case 17: // 마법 불능 (SP 15)
        if (_rand(100) < target.resistance) {
          return AttackResult(
            outcome: AttackOutcome.resisted,
            message: '마법 불능 공격은 저지당했다!',
          );
        }
        if (_rand(100) > attacker.accMagic) {
          return AttackResult(
            outcome: AttackOutcome.miss,
            message: '마법 불능 공격은 빗나갔다.',
          );
        }
        if (target.castLevel > 0) target.castLevel--;
        return AttackResult(
          outcome: AttackOutcome.debuffed,
          message: target.castLevel > 0
              ? '★ ${target.name}의 마법 능력이 저하되었다!'
              : '★ ${target.name}의 마법 시전 능력이 완전히 봉인되었다!',
        );

      case 18: // 탈 초인화 (SP 20)
        if (_rand(100) < target.resistance) {
          return AttackResult(
            outcome: AttackOutcome.resisted,
            message: '탈 초인화 공격은 저지당했다!',
          );
        }
        if (_rand(100) > attacker.accMagic) {
          return AttackResult(
            outcome: AttackOutcome.miss,
            message: '탈 초인화 공격은 빗나갔다.',
          );
        }
        if (target.specialCastLevel > 0) target.specialCastLevel--;
        return AttackResult(
          outcome: AttackOutcome.debuffed,
          message: target.specialCastLevel > 0
              ? '★ ${target.name}의 초자연적 능력이 저하되었다!'
              : '★ ${target.name}의 초자연적 능력이 완전히 사라졌다!',
        );

      default:
        return const AttackResult(
          outcome: AttackOutcome.failed,
          message: '알 수 없는 특수 마법입니다.',
        );
    }
  }

  // ==========================================
  // 5. 플레이어 일행 치료 마법 (CureSpell - LOREMENU.PAS:43..230)
  // 단일: 19..25, 전체: 26..32
  // ==========================================
  AttackResult executePlayerCure(
    PartyMember caster,
    PartyMember target,
    int spellId,
  ) {
    final spell = LoreData.instance.spell(spellId);
    final reqSp = spell.calculateSpCost(caster.magicLevel);

    if (caster.sp < reqSp) {
      return const AttackResult(
        outcome: AttackOutcome.outOfSp,
        message: '마법 지수(SP)가 부족합니다!',
      );
    }
    caster.sp -= reqSp;

    final logs = <String>[];

    // 부활 처리 (23, 25, 31, 32)
    if (spellId == 23 || spellId == 25 || spellId == 31 || spellId == 32) {
      if (target.isDead) {
        target.dead = 0;
        target.unconscious = 1;
        target.hp = 1;
        logs.add('${target.name}은(는) 다시 생명을 얻었습니다!');
      }
    }

    // 의식 돌림 처리 (22, 24, 25, 29, 30, 32)
    if (spellId == 22 ||
        spellId == 24 ||
        spellId == 25 ||
        spellId == 29 ||
        spellId == 30 ||
        spellId == 32) {
      if (target.isUnconscious && !target.isDead) {
        target.unconscious = 0;
        if (target.hp <= 0) target.hp = 1;
        logs.add('${target.name}은(는) 의식을 되찾았습니다!');
      }
    }

    // 독 제거 처리 (20, 21, 24, 25, 27, 28, 30, 32)
    if (spellId == 20 ||
        spellId == 21 ||
        spellId == 24 ||
        spellId == 25 ||
        spellId == 27 ||
        spellId == 28 ||
        spellId == 30 ||
        spellId == 32) {
      if (target.poison > 0) {
        target.poison = 0;
        logs.add('${target.name}의 독이 깨끗이 제거되었습니다!');
      }
    }

    // HP 회복 처리 (19, 21, 24, 25, 26, 28, 30, 32)
    if (spellId == 19 ||
        spellId == 21 ||
        spellId == 24 ||
        spellId == 25 ||
        spellId == 26 ||
        spellId == 28 ||
        spellId == 30 ||
        spellId == 32) {
      if (!target.isDead && !target.isUnconscious) {
        final healAmount = 3 * caster.magicLevel;
        target.hp = min(target.maxHp, target.hp + healAmount);
        logs.add('${target.name}의 체력이 $healAmount 회복되었습니다.');
      }
    }

    if (logs.isEmpty) {
      return AttackResult(
        outcome: AttackOutcome.cured,
        message: '${target.name}에게 \'${spell.name}\'을(를) 사용했으나 특별한 변화가 없었습니다.',
      );
    }

    return AttackResult(outcome: AttackOutcome.cured, message: logs.join(' '));
  }

  // ==========================================
  // 6. 플레이어 초능력 ESP (BattleESP - LOREBATT.PAS:364)
  // 43: 독심술, 45: 염력
  // ==========================================
  AttackResult executePlayerESP(
    PartyMember caster,
    Monster target,
    int espId,
    List<PartyMember> party, {
    required List<Monster> enemies,
    bool espAccessGranted = false,
  }) {
    // LOREBATT.PAS:366-369 — 직업 2/3/6 또는 party.etc[39] bit1.
    if (caster.playerClass != PlayerClass.mage &&
        caster.playerClass != PlayerClass.esper &&
        caster.playerClass != PlayerClass.ninja &&
        !espAccessGranted) {
      return const AttackResult(
        outcome: AttackOutcome.failed,
        message: '초능력을 사용할 수 없는 직업입니다.',
      );
    }
    final spell = LoreData.instance.spell(espId);
    final reqEsp = spell.calculateSpCost(caster.espLevel);

    if (caster.esp < reqEsp) {
      return const AttackResult(
        outcome: AttackOutcome.outOfSp,
        message: '초감각 지수(ESP)가 부족합니다!',
      );
    }
    caster.esp -= reqEsp;

    // 43: 독심술 (적 동료화)
    if (espId == 43) {
      // 원작 포섭 가능 몬스터 E_number: 6, 10, 20, 24, 27, 29, 33, 35, 40, 47, 53, 62
      const recruitable = [6, 10, 20, 24, 27, 29, 33, 35, 40, 47, 53, 62];
      if (!recruitable.contains(target.eNumber)) {
        return AttackResult(
          outcome: AttackOutcome.failed,
          message: '${target.name}에게 독심술은 전혀 통하지 않았다.',
        );
      }
      // LOREBATT.PAS:385-390 — 높은 레벨의 적은 먼저 50% 확률로 거부한다.
      // 62번은 전투 레벨 대신 고정 레벨 17로 비교한다.
      final resistanceLevel = target.eNumber == 62 ? 17 : target.level;
      if (resistanceLevel > caster.espLevel && _rand(2) == 0) {
        return AttackResult(
          outcome: AttackOutcome.failed,
          message: '${target.name}의 마음은 너무 강해 독심술을 거부했다.',
        );
      }
      if (_rand(60) > (caster.espLevel - resistanceLevel) * 2 + caster.accEsp) {
        return AttackResult(
          outcome: AttackOutcome.failed,
          message: '${target.name}의 마음은 흔들리지 않았다.',
        );
      }
      target.hp = 0;
      target.isDead = true;
      target.isUnconscious = true;
      target.level = 0;
      return AttackResult(
        outcome: AttackOutcome.joined,
        message: '★ 독심술 성공! ${target.name}은(는) 감화되어 전투를 멈추고 우리 편이 되었다!',
      );
    }

    // 45: 염력 (ESP 레벨에 따른 위력 분기 - LOREBATT.PAS:408)
    final k = _rand(caster.espLevel > 0 ? caster.espLevel : 1) + 1;

    if (k <= 6) {
      // 돌, 세균, 무기 염력 공격
      final dmg = k * 10;
      target.hp = max(0, target.hp - dmg);
      if (target.isUnconscious && !target.isDead) {
        target.isDead = true;
        final exp = calculateExperience(target);
        _awardExecutionExperience(caster, exp, party);
        return AttackResult(
          outcome: AttackOutcome.killed,
          damage: dmg,
          expGained: exp,
          message:
              '${target.name}을(를) 염력으로 처형했다! '
              '(${_executionExperienceMessage(caster, exp, party)})',
        );
      }
      if (target.hp == 0 && !target.isUnconscious) {
        target.isUnconscious = true;
        final exp = calculateExperience(target);
        caster.experience += exp;
        return AttackResult(
          outcome: AttackOutcome.unconscious,
          damage: dmg,
          expGained: exp,
          message:
              '주위의 돌들이 날아올라 ${target.name}을(를) 강타했다! '
              '($dmg 피해, 기절, 경험치 +$exp)',
        );
      }
      return AttackResult(
        outcome: AttackOutcome.hit,
        damage: dmg,
        message: '주위의 물체들이 날아올라 ${target.name}에게 $dmg의 염력 피해를 입혔다!',
      );
    } else if (k <= 10) {
      // LOREBATT.PAS:442-453 — 핵분열/핵융합은 전투 중인 모든 적에게 적용.
      final dmg = k * 5;
      var expGained = 0;
      var knockedOut = false;
      var executed = false;
      final affected = enemies;
      for (final monster in affected) {
        monster.hp = max(0, monster.hp - dmg);
        if (monster.isUnconscious && !monster.isDead) {
          monster.isDead = true;
          // 원본은 여기서 현재 반복 중인 적이 아닌 선택한 적의 번호로
          // PlusExperience를 호출한다. 경험치 종류와 분배도 선택한 적 기준이다.
          final exp = calculateExperience(target);
          if (target.isUnconscious) {
            _awardExecutionExperience(caster, exp, party);
          } else {
            caster.experience += exp;
          }
          expGained += exp;
          executed = true;
        }
        if (monster.hp == 0 && !monster.isUnconscious) {
          monster.isUnconscious = true;
          final exp = calculateExperience(monster);
          caster.experience += exp;
          expGained += exp;
          knockedOut = true;
        }
      }
      return AttackResult(
        outcome: executed
            ? AttackOutcome.killed
            : knockedOut
            ? AttackOutcome.unconscious
            : AttackOutcome.hit,
        damage: dmg * affected.length,
        expGained: expGained,
        message:
            '대기 중의 원자가 염력에 의해 핵반응을 일으켜 적 ${affected.length}명에게 '
            '각각 $dmg 피해를 주었다! (경험치 +$expGained)',
      );
    } else if (k <= 12) {
      // LOREBATT.PAS:456-470 — 저항은 저항력, 명중 실패는 인내력을 낮춘다.
      if (_rand(40) < target.resistance) {
        target.resistance = max(0, target.resistance - 5);
        return AttackResult(
          outcome: AttackOutcome.resisted,
          message: '${target.name}은(는) 공포를 견뎌냈다.',
        );
      }
      if (_rand(60) > caster.accEsp) {
        target.endurance = max(0, target.endurance - 5);
        return AttackResult(
          outcome: AttackOutcome.miss,
          message: '${target.name}은(는) 공포를 떨쳤지만 인내력이 5 떨어졌다.',
        );
      }
      target.isDead = true;
      return AttackResult(
        outcome: AttackOutcome.killed,
        message: '★ ${target.name}은(는) 극심한 공포를 견디지 못하고 전장에서 도망쳐버렸다!',
      );
    } else if (k <= 14) {
      // LOREBATT.PAS:472-478 — 저항 후 ESP 명중 판정을 통과해야 중독된다.
      if (_rand(100) < target.resistance) {
        return AttackResult(
          outcome: AttackOutcome.resisted,
          message: '${target.name}은(는) 염력 중독을 견뎌냈다.',
        );
      }
      if (_rand(40) > caster.accEsp) {
        return AttackResult(
          outcome: AttackOutcome.miss,
          message: '${caster.name}의 염력 중독이 빗나갔다.',
        );
      }
      target.isPoisoned = true;
      return AttackResult(
        outcome: AttackOutcome.debuffed,
        message: '★ 신진대사를 조절하여 ${target.name}의 체내에 맹독을 발생시켰다!',
      );
    } else if (k <= 17) {
      // LOREBATT.PAS:479-496 — 저항하면 저항력이 약해지고,
      // ESP 명중 실패도 HP 5 피해 또는 저체력 기절을 남긴다.
      if (_rand(40) < target.resistance) {
        target.resistance = max(0, target.resistance - 5);
        return AttackResult(
          outcome: AttackOutcome.resisted,
          message: '${target.name}은(는) 심장 정지 염력을 견뎠다.',
        );
      }
      if (_rand(80) > caster.accEsp) {
        if (target.hp < 10) {
          target.hp = 0;
          target.isUnconscious = true;
          return AttackResult(
            outcome: AttackOutcome.unconscious,
            message: '${target.name}은(는) 염력 충격으로 의식을 잃었다!',
          );
        }
        target.hp -= 5;
        return AttackResult(
          outcome: AttackOutcome.hit,
          damage: 5,
          message: '${target.name}은(는) 빗나간 염력에도 HP 5를 잃었다.',
        );
      }
      target.isUnconscious = true;
      return AttackResult(
        outcome: AttackOutcome.unconscious,
        message: '★ 염력으로 ${target.name}의 심장을 직접 멈추어 의식불명으로 만들었다!',
      );
    } else {
      // LOREBATT.PAS:497-509 — 저항 시 민첩 감소, 명중 시 두 정확도 감소.
      if (_rand(40) < target.resistance) {
        target.agility = max(0, target.agility - 5);
        return AttackResult(
          outcome: AttackOutcome.resisted,
          message: '${target.name}은(는) 환상을 견뎠지만 민첩이 5 떨어졌다.',
        );
      }
      if (_rand(30) > caster.accEsp) {
        return AttackResult(
          outcome: AttackOutcome.miss,
          message: '${caster.name}의 환상 염력이 빗나갔다.',
        );
      }
      if (target.accArms > 0) target.accArms--;
      if (target.accMagic > 0) target.accMagic--;
      return AttackResult(
        outcome: AttackOutcome.debuffed,
        message: '★ ${target.name}은(는) 강력한 환상에 빠져 공격 감각을 상실했다!',
      );
    }
  }

  // ==========================================
  // 7. 몬스터 턴 풀 AI (EnemyAttack - LOREBATT.PAS:599..970)
  // 마법 공격, 전체 마법, 동료 회복, 특수 공격(독/치명타/즉사), 일반 공격
  // ==========================================
  List<AttackResult> executeMonsterTurn(
    Monster monster,
    List<PartyMember> party,
    List<Monster> allEnemies,
  ) {
    final results = <AttackResult>[];

    // 1. 독 피해 판정 (LOREBATT.PAS:1162)
    if (monster.isPoisoned) {
      if (monster.isUnconscious) {
        monster.isDead = true;
        results.add(
          AttackResult(
            outcome: AttackOutcome.killed,
            message: '${monster.name}은(는) 체내의 독에 의해 완전히 숨을 거두었다.',
          ),
        );
        return results;
      } else {
        monster.hp--;
        if (monster.hp <= 0) {
          monster.hp = 0;
          monster.isUnconscious = true;
          results.add(
            AttackResult(
              outcome: AttackOutcome.unconscious,
              message: '${monster.name}은(는) 독의 고통을 버티지 못하고 의식불명이 되었다!',
            ),
          );
          return results;
        }
      }
    }

    if (monster.isDead || monster.isUnconscious) return results;

    if (!party.any((member) => member.isBattleActive)) return results;

    // 2. SpecialCastAttack: 소환은 일반 공격보다 먼저 일어나며 턴을 끝내지 않는다.
    if (monster.specialCastLevel > 0 && monster.eNumber != 1) {
      final presentEnemies = allEnemies.where((enemy) => !enemy.isDead).length;
      if (presentEnemies < _rand(3) + 2 && _rand(3) == 0) {
        final summoned = Monster.create(monster.eNumber + _rand(4) - 20);
        if (allEnemies.length < 7) {
          allEnemies.add(summoned);
        } else {
          // 원본의 7칸 상한: 사망 슬롯을 뒤에서 훑어 가장 앞의 슬롯을 교체.
          final deadSlot = allEnemies.indexWhere((enemy) => enemy.isDead);
          if (deadSlot >= 0) allEnemies[deadSlot] = summoned;
        }
        results.add(
          AttackResult(
            outcome: AttackOutcome.summoned,
            message: '${monster.name}은(는) ${summoned.name}을(를) 소환했다!',
          ),
        );
      }
    }

    // 원본의 turn_mind(k,6)은 선언된 인자 순서와 반대다. 의도한 6번 동료를
    // 선택된 적 슬롯으로 변환한다. 원본 호출을 그대로 실행하면 7번 파티원 참조 가능.
    if (monster.specialCastLevel > 1 &&
        monster.eNumber != 1 &&
        party.length >= 6 &&
        party[5].name.isNotEmpty &&
        allEnemies.where((enemy) => !enemy.isDead).length < 7 &&
        _rand(5) == 0) {
      final formerAlly = party[5];
      final convertedEnemy = _turnedMind(formerAlly);
      if (allEnemies.length < 7) {
        allEnemies.add(convertedEnemy);
      } else {
        final deadSlot = allEnemies.indexWhere((enemy) => enemy.isDead);
        if (deadSlot >= 0) allEnemies[deadSlot] = convertedEnemy;
      }
      formerAlly.name = '';
      results.add(
        AttackResult(
          outcome: AttackOutcome.converted,
          message:
              '${monster.name}은(는) ${convertedEnemy.name}의 마음을 돌려 적으로 만들었다!',
        ),
      );
    }

    // LOREBATT.PAS:931-949 — 전체 즉사 저주 뒤에도 기본 행동을 계속한다.
    if (monster.eNumber != 1 &&
        monster.specialCastLevel > 2 &&
        monster.special > 0 &&
        _rand(5) == 0) {
      for (final p in party.where(
        (member) => member.name.isNotEmpty && !member.isDead,
      )) {
        if (_rand(60) > monster.agility) {
          results.add(
            AttackResult(
              outcome: AttackOutcome.miss,
              message: '${p.name}에게 향한 ${monster.name}의 죽음의 저주가 빗나갔다.',
            ),
          );
        } else if (_rand(20) < p.luck) {
          results.add(
            AttackResult(
              outcome: AttackOutcome.resisted,
              message: '${p.name}은(는) ${monster.name}의 죽음의 저주를 피했다.',
            ),
          );
        } else {
          p.dead = 1;
          if (p.hp > 0) p.hp = 0;
          results.add(
            AttackResult(
              outcome: AttackOutcome.killed,
              message: '☠ ${monster.name}의 죽음의 저주! ${p.name}은(는) 목숨을 잃었다!',
            ),
          );
        }
      }
    }

    // 변환·저주 이후의 상태로 기본 공격 대상을 다시 고른다.
    final livingParty = party
        .where((member) => member.name.isNotEmpty && member.isAlive)
        .toList();
    final activeParty = party.where((member) => member.isBattleActive).toList();
    if (activeParty.isEmpty) return results;

    // 3. 특수 공격 (SpecialAttack - LOREBATT.PAS:814)
    final agiCap = min(20, monster.agility);
    if (monster.special > 0 &&
        _rand(50) < agiCap &&
        allEnemies
                .where((enemy) => !enemy.isDead && !enemy.isUnconscious)
                .length >
            3) {
      final eligibleTargets = livingParty.where((member) {
        return switch (monster.special) {
          1 => member.poison == 0,
          2 => member.unconscious == 0,
          3 => member.dead == 0,
          _ => false,
        };
      }).toList();
      if (eligibleTargets.isEmpty) {
        results.add(
          AttackResult(
            outcome: AttackOutcome.failed,
            message: '${monster.name}의 특수 공격 대상이 없다.',
          ),
        );
        return results;
      }
      final target = eligibleTargets[_rand(eligibleTargets.length)];
      final accuracyRoll = switch (monster.special) {
        1 => 40,
        2 => 50,
        3 => 60,
        _ => 0,
      };
      if (accuracyRoll > 0) {
        if (_rand(accuracyRoll) > monster.agility) {
          results.add(
            AttackResult(
              outcome: AttackOutcome.miss,
              message: '${monster.name}의 특수 공격은 빗나갔다.',
            ),
          );
        } else if (_rand(20) < target.luck) {
          results.add(
            AttackResult(
              outcome: AttackOutcome.resisted,
              message: '${target.name}은(는) ${monster.name}의 특수 공격을 피했다.',
            ),
          );
        } else if (monster.special == 1) {
          target.poison = 1;
          results.add(
            AttackResult(
              outcome: AttackOutcome.debuffed,
              message: '☠ ${monster.name}의 독 공격! ${target.name}은(는) 중독되었다!!',
            ),
          );
        } else if (monster.special == 2) {
          target.unconscious = 1;
          if (target.hp > 0) target.hp = 0;
          results.add(
            AttackResult(
              outcome: AttackOutcome.unconscious,
              message:
                  '💥 ${monster.name}의 치명타! ${target.name}은(는) 쓰러져 의식불명이 되었다!!',
            ),
          );
        } else {
          target.dead = 1;
          if (target.hp > 0) target.hp = 0;
          results.add(
            AttackResult(
              outcome: AttackOutcome.killed,
              message:
                  '☠ ${monster.name}의 죽음의 일격! ${target.name}은(는) 숨을 거두었다!!',
            ),
          );
        }
        return results;
      }
    }

    // 4. 마법 vs 물리 공격 판정 (LOREBATT.PAS:968)
    final useMagic =
        monster.castLevel > 0 &&
        (_rand(monster.accArms * 1000 + 1) <=
            _rand(monster.accMagic * 1000 + 1));

    if (useMagic) {
      // LOREBATT.PAS:724-748,769-773 — 레벨 4는 1/2, 5·6은 1/3.
      if (monster.castLevel >= 4 &&
          monster.castLevel <= 6 &&
          (monster.hp < monster.maxHp ~/ 3) &&
          _rand(monster.castLevel == 4 ? 2 : 3) == 0) {
        final heal = monster.level * monster.mentality ~/ 4;
        results.add(executeEnemyCure(monster, monster, heal));
        return results;
      }

      // 5단계는 대상 선택이 먼저다. 전체 공격을 고르면 전체 치료를 시도하지 않는다.
      final castAllAtLevelFive = monster.castLevel == 5
          ? _rand(activeParty.length) >= 2
          : null;

      // LOREBATT.PAS:774-791 — 6단계 시전자는 방어도 높은 파티를 먼저 약화.
      if (monster.castLevel == 6) {
        final namedParty = party
            .where((member) => member.name.isNotEmpty)
            .toList();
        if (namedParty.isNotEmpty) {
          final totalAc = namedParty.fold<int>(
            0,
            (sum, member) => sum + member.ac,
          );
          if (totalAc ~/ namedParty.length > 4 && _rand(5) == 0) {
            for (final member in namedParty) {
              if (member.luck > _rand(21)) {
                results.add(
                  AttackResult(
                    outcome: AttackOutcome.resisted,
                    message:
                        '${member.name}은(는) ${monster.name}의 방어 약화 마법을 피했다.',
                  ),
                );
              } else {
                if (member.ac > 0) member.ac--;
                results.add(
                  AttackResult(
                    outcome: AttackOutcome.debuffed,
                    message: '${member.name}의 방어도가 낮아졌다.',
                  ),
                );
              }
            }
            return results;
          }
        }
      }

      // LOREBATT.PAS:751-759,792-798 — 적이 셋 이상이고 합산 HP가 낮으면 전체 치료.
      if ((monster.castLevel == 5 && !castAllAtLevelFive!) ||
          monster.castLevel == 6) {
        final totalHp = allEnemies.fold<int>(0, (sum, enemy) => sum + enemy.hp);
        final maxHp = allEnemies.fold<int>(
          0,
          (sum, enemy) => sum + enemy.endurance * enemy.level,
        );
        if (allEnemies.length > 2 && totalHp < maxHp ~/ 3) {
          final roll = _rand(monster.castLevel == 5 ? 2 : 3);
          if ((monster.castLevel == 5 && roll == 0) ||
              (monster.castLevel == 6 && roll != 0)) {
            final heal = monster.level * monster.mentality ~/ 6;
            for (final enemy in allEnemies) {
              results.add(executeEnemyCure(monster, enemy, heal));
            }
            return results;
          }
        }
      }

      // 5·6단계는 행동 가능한 파티원 수를 기준으로 공격 범위를 정한다.
      final castAll = switch (monster.castLevel) {
        5 => castAllAtLevelFive!,
        6 => _rand(activeParty.length) >= 2,
        _ => monster.castLevel >= 3 && _rand(2) == 0,
      };
      if (castAll) {
        final spell = _enemyAllMagic(monster.mentality);
        final spellName = spell.name;
        final pwr = spell.multiplier * monster.level;

        results.add(
          AttackResult(
            outcome: AttackOutcome.hit,
            message: '${monster.name}은(는) 일행 모두에게 \'$spellName\' 마법을 작열시켰다!',
          ),
        );

        for (final p in livingParty) {
          final res = _applyEnemyMagicDamage(monster, p, spellName, pwr);
          results.add(res);
        }
        return results;
      }

      // 단일 마법 공격 (castattackone)
      final spell = _enemySingleMagic(monster.mentality);
      final spellName = spell.name;
      final pwr = spell.multiplier * monster.level;
      final target = monster.castLevel >= 5
          ? activeParty.reduce(
              (lowest, member) => member.hp < lowest.hp ? member : lowest,
            )
          : livingParty[_rand(livingParty.length)];

      results.add(
        AttackResult(
          outcome: AttackOutcome.hit,
          message:
              '${monster.name}은(는) ${target.name}에게 \'$spellName\' 마법을 시전했다!',
        ),
      );
      results.add(_applyEnemyMagicDamage(monster, target, spellName, pwr));
      return results;
    }

    // 5. 일반 물리 공격 (WeaponAttack - LOREBATT.PAS:527)
    final target = livingParty[_rand(livingParty.length)];
    results.add(executeEnemyWeaponAttack(monster, target));
    return results;
  }

  Monster _turnedMind(PartyMember member) => Monster(
    eNumber: 1,
    name: member.name,
    strength: member.strength,
    mentality: member.mentality,
    endurance: member.endurance,
    resistance: member.resistance,
    agility: member.agility,
    accArms: member.accArms,
    accMagic: member.accMagic,
    ac: member.ac,
    special: member.playerClass == PlayerClass.hunter ? 2 : 0,
    castLevel: member.magicLevel ~/ 4,
    specialCastLevel: 0,
    level: member.battleLevel,
  );

  /// LOREBATT.PAS:602-628 `castattackone`의 정신력별 기본 위력.
  ({String name, int multiplier}) _enemySingleMagic(int mentality) {
    if (mentality <= 0) return (name: '번개', multiplier: 10);
    if (mentality >= 1 && mentality <= 3) return (name: '충격', multiplier: 1);
    if (mentality <= 8) return (name: '냉기', multiplier: 2);
    if (mentality <= 10) return (name: '고통', multiplier: 4);
    if (mentality <= 14) return (name: '혹한', multiplier: 6);
    if (mentality <= 18) return (name: '화염', multiplier: 7);
    return (name: '번개', multiplier: 10);
  }

  /// LOREBATT.PAS:639-663 `castattackall`의 정신력별 기본 위력.
  ({String name, int multiplier}) _enemyAllMagic(int mentality) {
    if (mentality <= 0) return (name: '화염폭풍', multiplier: 8);
    if (mentality >= 1 && mentality <= 6) return (name: '열파', multiplier: 1);
    if (mentality <= 12) return (name: '에너지', multiplier: 2);
    if (mentality <= 16) return (name: '초음파', multiplier: 3);
    if (mentality <= 20) return (name: '혹한기', multiplier: 5);
    return (name: '화염폭풍', multiplier: 8);
  }

  /// LOREBATT.PAS:666-680 `enemycure`: 사망·기절·HP 회복의 순서와 효과.
  AttackResult executeEnemyCure(Monster caster, Monster target, int amount) {
    if (target.isDead) {
      target.isDead = false;
    } else if (target.isUnconscious) {
      target.isUnconscious = false;
      if (target.hp <= 0) target.hp = 1;
    } else {
      target.hp = min(target.endurance * target.level, target.hp + amount);
    }
    return AttackResult(
      outcome: AttackOutcome.cured,
      message: '${caster.name}은(는) ${target.name}을(를) 치료했다.',
    );
  }

  AttackResult _applyEnemyMagicDamage(
    Monster attacker,
    PartyMember target,
    String spellName,
    int basePower,
  ) {
    if (_rand(20) >= attacker.accMagic) {
      return AttackResult(
        outcome: AttackOutcome.miss,
        message: '${target.name}에게 마법이 빗나갔다.',
      );
    }
    if (_rand(50) < target.resistance) {
      return AttackResult(
        outcome: AttackOutcome.resisted,
        message: '${target.name}은(는) 마법을 저지했다!',
      );
    }
    int power = basePower - _rand(max(1, basePower ~/ 2));
    final defReduce = (target.ac * target.battleLevel * (_rand(10) + 1)) ~/ 10;
    power -= defReduce;

    if (power <= 0) {
      return AttackResult(
        outcome: AttackOutcome.blocked,
        message: '${target.name}은(는) 마법을 방어했다!',
      );
    }

    target.hp -= power;
    if (target.hp <= 0) {
      target.hp = 0;
      target.unconscious = 1;
      return AttackResult(
        outcome: AttackOutcome.unconscious,
        damage: power,
        message: '${target.name}은(는) $power의 마법 피해를 입고 쓰러졌다!',
      );
    }
    return AttackResult(
      outcome: AttackOutcome.hit,
      damage: power,
      message: '${target.name}은(는) $power의 마법 피해를 입었다.',
    );
  }

  // ==========================================
  // 8. 적 일반 물리 공격 (WeaponAttack)
  // ==========================================
  AttackResult executeEnemyWeaponAttack(Monster attacker, PartyMember target) {
    if (_rand(20) >= attacker.accArms) {
      return AttackResult(
        outcome: AttackOutcome.miss,
        message: '${attacker.name}의 공격은 빗맞았다.',
      );
    }

    final baseDmg =
        (attacker.strength * attacker.level * (_rand(10) + 1)) ~/ 10;

    if (_rand(50) < target.resistance) {
      return AttackResult(
        outcome: AttackOutcome.resisted,
        message: '${target.name}은(는) 적의 공격을 저지했다!',
      );
    }

    final defReduce = (target.ac * target.battleLevel * (_rand(10) + 1)) ~/ 10;
    final finalDmg = baseDmg - defReduce;

    if (finalDmg <= 0) {
      return AttackResult(
        outcome: AttackOutcome.blocked,
        message: '그러나, ${target.name}은(는) 적의 공격을 완벽히 방어했다!',
      );
    }

    if (target.isDead) {
      target.dead += finalDmg;
    } else if (target.isUnconscious) {
      target.unconscious += finalDmg;
      if (target.unconscious > target.endurance * target.battleLevel) {
        target.dead = 1;
        return AttackResult(
          outcome: AttackOutcome.killed,
          damage: finalDmg,
          message: '기절해 있던 ${target.name}은(는) 추가 피해를 버티지 못하고 숨을 거두었다...',
        );
      }
    } else {
      target.hp -= finalDmg;
      if (target.hp <= 0) {
        target.hp = 0;
        target.unconscious = 1;
        return AttackResult(
          outcome: AttackOutcome.unconscious,
          damage: finalDmg,
          message: '${target.name}은(는) $finalDmg의 피해를 입고 쓰러져 의식불명이 되었다!',
        );
      }
    }

    return AttackResult(
      outcome: AttackOutcome.hit,
      damage: finalDmg,
      message: '${target.name}은(는) ${attacker.name}에게 $finalDmg의 피해를 입었다!',
    );
  }

  // ==========================================
  // 9. 도망 판정 (RunAway)
  // ==========================================
  bool checkRunAway(PartyMember member) {
    return _rand(50) <= member.agility;
  }

  // ==========================================
  // 10. 경험치 및 골드 보상 공식
  // ==========================================
  int calculateExperience(Monster monster) {
    final n = monster.eNumber;
    int exp = (n * n * n) ~/ 8;
    return exp <= 0 ? 1 : exp;
  }

  /// LOREBATT.PAS:43-50 — 의식불명 적의 처형 경험치는 `exist(i)`인 일행 전원.
  void _awardExecutionExperience(
    PartyMember attacker,
    int exp,
    List<PartyMember>? party,
  ) {
    if (party == null) {
      attacker.experience += exp;
      return;
    }
    for (final member in party) {
      if (member.name.isNotEmpty && member.canAct && member.hp > 0) {
        member.experience += exp;
      }
    }
  }

  String _executionExperienceMessage(
    PartyMember attacker,
    int exp,
    List<PartyMember>? party,
  ) => party == null
      ? LoreBattText.expGained(attacker.name, '$exp')
      : '행동 가능한 일행 모두 경험치 +$exp';

  int calculateGold(List<Monster> defeatedEnemies) {
    int totalGold = 0;
    for (final e in defeatedEnemies) {
      // LOREBATT.PAS:60-69 PlusGold는 전투 인스턴스 enemy[i]에서
      // E_number만 읽고, 레벨과 AC는 원본 enemydata[E_number]에서 읽는다.
      final template = LoreData.instance.monster(e.eNumber);
      final acVal = template.ac == 0 ? 1 : template.ac;
      final plus = (template.level * template.level * template.level) * acVal;
      totalGold += plus;
    }
    return totalGold;
  }
}
