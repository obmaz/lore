/// 1993년 원작 LORE `LOREMENU.PAS:869 Rest`(야외 캠프 휴식)의 순수 Dart 계산.
/// 마을 시설(Grocery, Weapon_Shop, Train_Center, Hospital)은
/// `lore_town_shops.dart` 가 원본 흐름 그대로 옮긴다.
///
/// 모든 수치와 대사는 원본 소스를 Johab(CP1361) 디코딩하여 그대로 옮긴 것이다.
/// (도구: `tool/decode_johab.py`)
library;

import '../models/party_member.dart';

/// 야외 캠프 휴식(LOREMENU.PAS:869 Rest) 1회 실행 결과.
class RestOutcome {
  /// 휴식 후 남은 식량 (원작 `party.food`).
  final int food;

  /// 휴식 후 마법의 횃불 잔여 스텝 (원작 `party.etc[1]`, 매 휴식마다 1 감소).
  final int torchSteps;

  /// 원작 `Print(color, s)` 순서 그대로의 (색, 문구).
  final List<(int, String)> lines;

  /// [lines] 의 문구만.
  List<String> get logs => [for (final (_, text) in lines) text];

  const RestOutcome({
    required this.food,
    required this.torchSteps,
    required this.lines,
  });

  /// 실제로 체력/의식이 회복된 파티원 수 (테스트 편의용).
  int get healedCount =>
      logs.where((l) => l.contains('회복되었다') || l.contains('치료되었다')).length;
}

/// 원작 마을 시설/휴식의 순수 계산 및 상태 변경 규칙 모음.
class TownLogic {
  TownLogic._();

  static const int maxFood = 255;

  /// 성별에 따른 원작 대명사 (`his`/`her`).
  static String possessive(Gender sex) => sex == Gender.male ? '그의' : '그녀의';

  // ==========================================================================
  // 5. 야외 캠프 휴식 (LOREMENU.PAS:869 Rest)
  // ==========================================================================

  /// 원작 Rest 프로시저를 1:1로 재현한다.
  ///
  /// 1) 파티원 1~6번 순서로:
  ///    - 식량이 0이면 "일행은 식량이 바닥났다"만 출력
  ///    - 사망자는 제외
  ///    - 의식불명(독 아님): `unconscious -= (레벨1+레벨2+레벨3)`,
  ///      깨어나면 식량 1 소모 & `hp<=0`이면 1로 보정
  ///    - 의식불명 + 중독: 독 때문에 의식 회복 실패
  ///    - 중독: 독 때문에 건강 회복 실패
  ///    - 정상: `hp += (레벨1+레벨2+레벨3)*2` (최대치 제한),
  ///      이미 만복이었다면 식량 1개를 되돌려받아 순 소모 0
  /// 2) `party.etc[1]`(마법의 횃불) 1 감소, `etc[2..4]`(물위걸음/늪위걸음/공중부상) 초기화
  /// 3) 살아있는 파티원 전원의 `sp = mentality*level[2]`, `esp = concentration*level[3]` 완전 회복
  static RestOutcome rest(
    List<PartyMember> party,
    int food, {
    int torchSteps = 0,
  }) {
    final logs = <(int, String)>[];
    var currentFood = food;

    for (final p in party.take(6)) {
      if (p.name.isEmpty) continue;

      if (currentFood <= 0) {
        logs.add((4, '일행은 식량이 바닥났다'));
        continue;
      }
      if (p.dead > 0) {
        logs.add((7, '${p.name}는 죽었다'));
        continue;
      }
      if (p.unconscious > 0 && p.poison == 0) {
        p.unconscious -= p.battleLevel + p.magicLevel + p.espLevel;
        if (p.unconscious <= 0) {
          p.unconscious = 0;
          if (p.hp <= 0) p.hp = 1;
          currentFood--;
          logs.add((15, '${p.name}는 의식이 회복되었다'));
        } else {
          logs.add((15, '${p.name}는 여전히 의식 불명이다'));
        }
      } else if (p.unconscious > 0 && p.poison > 0) {
        logs.add((7, '독때문에, ${p.name} ${possessive(p.sex)} 의식은 회복되지 않았다'));
      } else if (p.poison > 0) {
        logs.add((7, '독때문에, ${p.name} ${possessive(p.sex)} 건강은 회복되지 않았다'));
      } else {
        final heal = (p.battleLevel + p.magicLevel + p.espLevel) * 2;
        // 원작: 이미 만복이면 식량을 1개 돌려받은 뒤 다시 1개 소모한다(순 소모 0).
        if (p.hp >= p.maxHp && currentFood < maxFood) currentFood++;
        p.hp += heal;
        if (p.hp >= p.maxHp) {
          p.hp = p.maxHp;
          logs.add((15, '${p.name}는 모든 건강이 회복되었다'));
        } else {
          logs.add((15, '${p.name}는 치료되었다'));
        }
        currentFood--;
      }
    }

    // 현상계 지속 마법 해제 (원작 party.etc[1..4]).
    var torch = torchSteps;
    if (torch > 0) torch--;

    // 마력/초능력 완전 회복 (원작은 사망자 포함 이름이 있는 파티원 전원에게 적용).
    for (final p in party.take(6)) {
      if (p.name.isEmpty) continue;
      p.sp = p.maxSp;
      p.esp = p.maxEsp;
    }

    return RestOutcome(food: currentFood, torchSteps: torch, lines: logs);
  }
}
