import 'dart:math';

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
  AttackResult executePlayerWeaponAttack(PartyMember attacker, Monster target) {
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
      attacker.experience += exp;
      return AttackResult(
        outcome: AttackOutcome.killed,
        expGained: exp,
        message:
            '${attacker.name}의 치명적인 일격! ${target.name}의 숨통을 완전히 끊었다! (EXP +$exp)',
      );
    }

    // 2. 명중 판정 (random(20) > accuracy[1] 이면 빗나감)
    if (_rand(20) > attacker.accArms) {
      return AttackResult(
        outcome: AttackOutcome.miss,
        message: '${attacker.name}의 공격은 빗나갔다 ....',
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
      return AttackResult(
        outcome: AttackOutcome.resisted,
        message: '${target.name}은(는) ${attacker.name}의 공격을 저지했다!',
      );
    }

    // 5. 적 방어력(AC) 감쇄: ac * level * (random(10)+1) / 10
    final defReduce = (target.ac * target.level * (_rand(10) + 1) / 10).round();
    final finalDmg = baseDmg - defReduce;

    if (finalDmg <= 0) {
      return AttackResult(
        outcome: AttackOutcome.blocked,
        message: '그러나, ${target.name}은(는) ${attacker.name}의 공격을 막아냈다!',
      );
    }

    // 6. 피해 적용 및 기절 판정
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
        message: '${target.name}은(는) $finalDmg의 피해를 입고 의식불명이 되었다! (EXP +$exp)',
      );
    }

    return AttackResult(
      outcome: AttackOutcome.hit,
      damage: finalDmg,
      message: '${target.name}은(는) $finalDmg만큼의 피해를 입었다.',
    );
  }

  // ==========================================
  // 2. 플레이어 단일 마법 공격 (CastOne - LOREBATT.PAS:172)
  // 마법 1..6: 마법 화살, 마법 화구, 마법 단창, 독 바늘, 맥동 광선, 직격 뇌전
  // ==========================================
  AttackResult executePlayerMagicAttack(
    PartyMember attacker,
    Monster target,
    int magicIndex, // 1 ~ 6
  ) => executePlayerSingleMagicAttack(attacker, target, magicIndex);

  AttackResult executePlayerSingleMagicAttack(
    PartyMember attacker,
    Monster target,
    int magicIndex, // 1 ~ 6
  ) {
    if (target.isDead) {
      return const AttackResult(
        outcome: AttackOutcome.miss,
        message: '공격 대상이 이미 사망했습니다.',
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

    // 기절 상태 대상: 마법 작열로 즉사
    if (target.isUnconscious) {
      target.hp = 0;
      target.isDead = true;
      final exp = calculateExperience(target);
      attacker.experience += exp;
      return AttackResult(
        outcome: AttackOutcome.killed,
        expGained: exp,
        message:
            '${attacker.name}의 마법은 ${target.name}의 시체 위에서 작열하여 소멸시켰다! (EXP +$exp)',
      );
    }

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
    int magicIndex, // 7 ~ 12
  ) {
    final spell = LoreData.instance.spell(magicIndex);
    final reqSp = spell.calculateSpCost(attacker.magicLevel);

    if (attacker.sp < reqSp) {
      return [
        const AttackResult(
          outcome: AttackOutcome.outOfSp,
          message: '마법 지수(SP)가 부족합니다!',
        ),
      ];
    }
    attacker.sp -= reqSp;

    final results = <AttackResult>[];
    final j = magicIndex - 6; // 1..6 등급

    for (final target in enemies) {
      if (target.isDead) continue;

      if (target.isUnconscious) {
        target.hp = 0;
        target.isDead = true;
        final exp = calculateExperience(target);
        attacker.experience += exp;
        results.add(
          AttackResult(
            outcome: AttackOutcome.killed,
            expGained: exp,
            message:
                '${target.name}의 시체 위에서 \'${spell.name}\'이 작열했다! (EXP +$exp)',
          ),
        );
        continue;
      }

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
    List<PartyMember> party,
  ) {
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
      if (_rand(60) > (caster.espLevel - target.level) * 2 + caster.accEsp) {
        return AttackResult(
          outcome: AttackOutcome.failed,
          message: '${target.name}의 마음은 흔들리지 않았다.',
        );
      }
      target.hp = 0;
      target.isDead = true;
      target.isUnconscious = true;
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
      if (target.hp <= 0) {
        target.isUnconscious = true;
        return AttackResult(
          outcome: AttackOutcome.unconscious,
          damage: dmg,
          message: '주위의 돌들이 날아올라 ${target.name}을(를) 강타했다! ($dmg 피해, 기절)',
        );
      }
      return AttackResult(
        outcome: AttackOutcome.hit,
        damage: dmg,
        message: '주위의 물체들이 날아올라 ${target.name}에게 $dmg의 염력 피해를 입혔다!',
      );
    } else if (k <= 10) {
      // 핵분열/핵융합 고열 에너지 방출
      final dmg = k * 5;
      target.hp = max(0, target.hp - dmg);
      if (target.hp <= 0) target.isUnconscious = true;
      return AttackResult(
        outcome: AttackOutcome.hit,
        damage: dmg,
        message: '대기 중의 원자가 염력에 의해 핵반응을 일으키며 ${target.name}에게 $dmg 피해를 주었다!',
      );
    } else if (k <= 12) {
      // 공포심 주입 -> 도망/즉사
      if (_rand(40) < target.resistance) {
        target.resistance = max(0, target.resistance - 5);
        return AttackResult(
          outcome: AttackOutcome.resisted,
          message: '${target.name}은(는) 공포를 견뎌냈다.',
        );
      }
      target.isDead = true;
      target.hp = 0;
      return AttackResult(
        outcome: AttackOutcome.killed,
        message: '★ ${target.name}은(는) 극심한 공포를 견디지 못하고 전장에서 도망쳐버렸다!',
      );
    } else if (k <= 14) {
      // 신진대사 교란 (중독)
      target.isPoisoned = true;
      return AttackResult(
        outcome: AttackOutcome.debuffed,
        message: '★ 신진대사를 조절하여 ${target.name}의 체내에 맹독을 발생시켰다!',
      );
    } else if (k <= 17) {
      // 심장 정지 (기절)
      target.hp = 0;
      target.isUnconscious = true;
      return AttackResult(
        outcome: AttackOutcome.unconscious,
        message: '★ 염력으로 ${target.name}의 심장을 직접 멈추어 의식불명으로 만들었다!',
      );
    } else {
      // 환상 (명중 저하)
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

    final livingParty = party.where((p) => p.isAlive).toList();
    if (livingParty.isEmpty) return results;

    // 2. 특수 소환/세뇌 공격 (SpecialCastAttack - LOREBATT.PAS:896)
    if (monster.specialCastLevel > 2 && _rand(5) == 0 && monster.special > 0) {
      // 전체 즉사 공격 시도
      for (final p in livingParty) {
        if (_rand(60) <= monster.agility && _rand(20) >= p.luck) {
          p.dead = 1;
          p.hp = 0;
          results.add(
            AttackResult(
              outcome: AttackOutcome.killed,
              message: '☠ ${monster.name}의 죽음의 저주! ${p.name}은(는) 목숨을 잃었다!',
            ),
          );
        }
      }
      if (results.isNotEmpty) return results;
    }

    // 3. 특수 공격 (SpecialAttack - LOREBATT.PAS:814)
    final agiCap = min(20, monster.agility);
    if (monster.special > 0 && _rand(50) < agiCap) {
      final target = livingParty[_rand(livingParty.length)];
      if (monster.special == 1) {
        // 독 공격
        if (_rand(40) <= monster.agility && _rand(20) >= target.luck) {
          target.poison = 1;
          results.add(
            AttackResult(
              outcome: AttackOutcome.debuffed,
              message: '☠ ${monster.name}의 독 공격! ${target.name}은(는) 중독되었다!!',
            ),
          );
          return results;
        }
      } else if (monster.special == 2) {
        // 치명타 기절 공격
        if (_rand(50) <= monster.agility && _rand(20) >= target.luck) {
          target.unconscious = 1;
          target.hp = 0;
          results.add(
            AttackResult(
              outcome: AttackOutcome.unconscious,
              message:
                  '💥 ${monster.name}의 치명타! ${target.name}은(는) 쓰러져 의식불명이 되었다!!',
            ),
          );
          return results;
        }
      } else if (monster.special == 3) {
        // 즉사 공격
        if (_rand(60) <= monster.agility && _rand(20) >= target.luck) {
          target.dead = 1;
          target.hp = 0;
          results.add(
            AttackResult(
              outcome: AttackOutcome.killed,
              message:
                  '☠ ${monster.name}의 죽음의 일격! ${target.name}은(는) 숨을 거두었다!!',
            ),
          );
          return results;
        }
      }
    }

    // 4. 마법 vs 물리 공격 판정 (LOREBATT.PAS:968)
    final useMagic =
        monster.castLevel > 0 &&
        (_rand(monster.accArms * 1000 + 1) <=
            _rand(monster.accMagic * 1000 + 1));

    if (useMagic) {
      // 아군 회복 마법 (castlevel 4..5 & 체력 저하 시)
      if (monster.castLevel >= 4 &&
          (monster.hp < monster.maxHp ~/ 3) &&
          _rand(2) == 0) {
        final heal = monster.level * monster.mentality ~/ 6 + 5;
        monster.hp = min(monster.maxHp, monster.hp + heal);
        results.add(
          AttackResult(
            outcome: AttackOutcome.cured,
            message: '${monster.name}은(는) 치유 마법으로 자신의 체력을 $heal 회복했다!',
          ),
        );
        return results;
      }

      // 전체 마법 공격 (castlevel >= 3 이고 50% 확률)
      if (monster.castLevel >= 3 && _rand(2) == 0) {
        const magicNames = ['열파', '에너지', '초음파', '혹한기', '화염폭풍'];
        final mIdx = min(magicNames.length - 1, monster.mentality ~/ 4);
        final spellName = magicNames[mIdx];
        final pwr = (mIdx + 1) * monster.level;

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
      const singleNames = ['충격', '냉기', '고통', '혹한', '화염', '번개'];
      final mIdx = min(singleNames.length - 1, monster.mentality ~/ 3);
      final spellName = singleNames[mIdx];
      final pwr = (mIdx + 1) * monster.level;
      final target = livingParty[_rand(livingParty.length)];

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

  int calculateGold(List<Monster> defeatedEnemies) {
    int totalGold = 0;
    for (final e in defeatedEnemies) {
      final acVal = e.ac <= 0 ? 1 : e.ac;
      final plus = (e.level * e.level * e.level) * acVal;
      totalGold += plus;
    }
    return totalGold;
  }
}
