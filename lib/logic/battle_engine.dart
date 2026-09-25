import 'dart:math';
import '../models/party_member.dart';
import '../models/monster.dart';

enum AttackOutcome {
  hit,
  miss,
  resisted,
  blocked,
  unconscious,
  killed,
  outOfSp,
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

/// 1993년 원작 LOREBATT.PAS의 전투 공식 구현 엔진
class BattleEngine {
  final Random _random;

  BattleEngine({Random? random}) : _random = random ?? Random();

  /// 파스칼의 random(n)과 동일: 0 이상 n 미만의 정수 반환
  int _rand(int n) => n <= 0 ? 0 : _random.nextInt(n);

  // ==========================================
  // 1. 플레이어 일반 무기 공격 (AttackOne)
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
        message: '${attacker.name}의 치명적인 일격! ${target.name}의 심장을 꿰뚫어 숨을 끊었다! (EXP +$exp)',
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
    int baseDmg = (attacker.strength * attacker.weaPower * attacker.battleLevel) ~/ 20;
    // i := i - i * random(50) div 100;
    baseDmg = baseDmg - (baseDmg * _rand(50)) ~/ 100;

    // 4. 적 저항 판정 (random(100) < resistance)
    if (_rand(100) < target.resistance) {
      return AttackResult(
        outcome: AttackOutcome.resisted,
        message: '${target.name}은(는) ${attacker.name}의 공격을 저지했다!',
      );
    }

    // 5. 적 방어력(AC) 감쇄
    // j := round(ac * level * (random(10)+1) / 10);
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
  // 2. 플레이어 단일 마법 공격 (CastOne)
  // ==========================================
  AttackResult executePlayerMagicAttack(
    PartyMember attacker,
    Monster target,
    int magicIndex, // 1 ~ 6 (마법 등급)
  ) {
    if (target.isDead) {
      return const AttackResult(
        outcome: AttackOutcome.miss,
        message: '공격 대상이 이미 사망했습니다.',
      );
    }

    // 소모 SP: round(level[2] * j * j / 2)
    final reqSp = (attacker.magicLevel * magicIndex * magicIndex / 2).round();
    if (attacker.sp < reqSp) {
      return const AttackResult(
        outcome: AttackOutcome.outOfSp,
        message: '마법 지수(SP)가 부족합니다!',
      );
    }
    attacker.sp -= reqSp;

    // 기절 상태 즉사 마법
    if (target.isUnconscious) {
      target.hp = 0;
      target.isDead = true;
      final exp = calculateExperience(target);
      attacker.experience += exp;
      return AttackResult(
        outcome: AttackOutcome.killed,
        expGained: exp,
        message: '${attacker.name}의 마법이 ${target.name}의 몸 위에서 작열하여 소멸시켰다! (EXP +$exp)',
      );
    }

    // 명중 판정 (random(20) >= accuracy[2] 이면 빗나감)
    if (_rand(20) >= attacker.accMagic) {
      return AttackResult(
        outcome: AttackOutcome.miss,
        message: '그러나, 마법은 ${target.name}을(를) 빗나갔다.',
      );
    }

    // 마법 위력: round(j * j * level[2] * 2)
    final baseDmg = magicIndex * magicIndex * attacker.magicLevel * 2;

    // 저항 판정
    if (_rand(100) < target.resistance) {
      return AttackResult(
        outcome: AttackOutcome.resisted,
        message: '${target.name}은(는) ${attacker.name}의 마법을 저지했다!',
      );
    }

    // 방어 차감
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
        message: '${target.name}은(는) 마법에 의해 의식불능이 되었다! (EXP +$exp)',
      );
    }

    return AttackResult(
      outcome: AttackOutcome.hit,
      damage: finalDmg,
      message: '${target.name}은(는) $finalDmg만큼의 마법 피해를 입었다.',
    );
  }

  // ==========================================
  // 3. 적 일반 물리 공격 (WeaponAttack)
  // ==========================================
  AttackResult executeEnemyWeaponAttack(Monster attacker, PartyMember target) {
    // 1. 명중 판정 (random(20) >= accuracy[1] 이면 빗맞음)
    if (_rand(20) >= attacker.accArms) {
      return AttackResult(
        outcome: AttackOutcome.miss,
        message: '${attacker.name}의 공격은 빗맞았다.',
      );
    }

    // 2. 적 기본 대미지: strength * level * (random(10)+1) div 10
    final baseDmg = (attacker.strength * attacker.level * (_rand(10) + 1)) ~/ 10;

    // 3. 플레이어 저항 판정: random(50) < resistance
    if (_rand(50) < target.resistance) {
      return AttackResult(
        outcome: AttackOutcome.resisted,
        message: '${target.name}은(는) 적의 공격을 저지했다!',
      );
    }

    // 4. 플레이어 방어력(AC) 감쇄: ac * level[1] * (random(10)+1) div 10
    final defReduce = (target.ac * target.battleLevel * (_rand(10) + 1)) ~/ 10;
    final finalDmg = baseDmg - defReduce;

    if (finalDmg <= 0) {
      return AttackResult(
        outcome: AttackOutcome.blocked,
        message: '그러나, ${target.name}은(는) 적의 공격을 완벽히 방어했다!',
      );
    }

    // 5. 피해 누적 및 기절/사망 처리
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
  // 4. 도망 판정 (RunAway)
  // ==========================================
  bool checkRunAway(PartyMember member) {
    // Random(50) <= player[person].agility
    return _rand(50) <= member.agility;
  }

  // ==========================================
  // 5. 경험치 및 골드 보상 공식
  // ==========================================
  int calculateExperience(Monster monster) {
    // plus := enemy[foe].E_number; plus := plus * plus * plus div 8;
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
