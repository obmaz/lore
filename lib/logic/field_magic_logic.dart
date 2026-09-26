/// 원작 `LOREMENU.PAS`의 비전투 마법 시전 이식.
///
/// 대응 원작 코드:
/// - `LOREMENU.PAS  AttackSpell`        전투 중이 아닐 때 공격 마법 사용 금지
/// - `LOREMENU.PAS  SPnotEnough`        마법 지수 부족 문구
/// - `LOREMENU.PAS  HealOne/CureOne/ConsciousOne/RevitalizeOne`
/// - `LOREMENU.PAS  HealAll/CureAll/ConscoisAll/RevitalizeAll`
/// - `LOREMENU.PAS  CureSpell`          개인(19~25)/전체(26~32) 치료 마법 선택
/// - `LOREMENU.PAS  PhenominaSpell`     현상계 보조 마법 8종(33~40)
///
/// 원작은 SP 비용을 **시전자/대상 상태로 계산**한다(고정값 아님):
/// - `HealOne`        : `i := 2 * level[2]` 소모, `hp += i * 3 div 2`
/// - `CureOne`        : 15 소모
/// - `ConsciousOne`   : `10 * unconscious` 소모
/// - `RevitalizeOne`  : `30 * dead` 소모
library;

import 'dart:math';

import '../models/party_member.dart';

/// 마법 시전 결과 1건(로그 문구 + 소모 SP + 성공 여부).
class MagicCastResult {
  final List<String> messages;
  final int spSpent;
  final bool success;

  const MagicCastResult({
    this.messages = const [],
    this.spSpent = 0,
    this.success = false,
  });
}

/// 비전투(필드) 마법 규칙 - 원작 `LOREMENU.PAS` 그대로.
class FieldMagicLogic {
  FieldMagicLogic._();

  /// 원작 `AttackSpell` 문구.
  static const String attackSpellMessage = '전투 모드가 아닐때는 공격 마법을 사용할 수 없습니다.';

  /// 원작 `SPnotEnough` 문구.
  static const String spNotEnoughMessage = '그러나, 마법 지수가 충분하지 않습니다.';

  /// 원작 `CureSpell` 개인 마법(19~25) 선택지 이름.
  static const List<String> cureSpellNames = [
    '한명 치료', // 19
    '한명 독 제거', // 20
    '한명 치료와 독제거', // 21
    '한명 의식 돌림', // 22
    '한명 부활', // 23
    '한명 치료와 독제거와 의식돌림', // 24
    '한명 복합 치료', // 25
  ];

  /// 원작 `CureSpell` 전체 마법(26~32) 선택지 이름.
  static const List<String> cureAllSpellNames = [
    '모두 치료', // 26
    '모두 독 제거', // 27
    '모두 치료와 독제거', // 28
    '모두 의식 돌림', // 29
    '모두 치료와 독제거와 의식돌림', // 30
    '모두 부활', // 31
    '모두 복합 치료', // 32
  ];

  /// 원작 `PhenominaSpell` 보조 마법(33~40) 선택지 이름.
  static const List<String> phenominaSpellNames = [
    '마법의 햇불', // 33
    '공중 부상', // 34
    '물위를 걸음', // 35
    '늪위를 걸음', // 36
    '기화 이동', // 37
    '지형 변화', // 38
    '공간 이동', // 39
    '식량 제조', // 40
  ];

  /// 원작 `PhenominaSpell`의 SP 비용(스펠 33~40 순서).
  static const List<int> phenominaSpCosts = [1, 5, 10, 20, 25, 30, 50, 30];

  /// 원작 `PhenominaSpell`의 슬롯 제한: `level[2] div 2 + 1` (최소 1, 최대 8).
  static int phenominaSlots(int magicLevel) =>
      (magicLevel > 1 ? magicLevel ~/ 2 + 1 : 1).clamp(1, 8);

  /// 원작 `CureSpell` 개인 마법 슬롯: `level[2] div 2 + 1` (최대 7).
  static int personalCureSlots(int magicLevel) =>
      (magicLevel ~/ 2 + 1).clamp(1, 7);

  /// 원작 `CureSpell` 전체 마법 슬롯: `level[2] div 2 - 3` (0 이하면 사용 불가).
  static int groupCureSlots(int magicLevel) => magicLevel ~/ 2 - 3;

  /// 전체 치료 마법을 아직 쓸 수 없을 때의 문구 (원작 `Print`).
  static String strongCureNotReady(String casterName) =>
      '$casterName는 강한 치료 마법은 아직 불가능 합니다.';

  /// 원작 `HealOne`의 SP 비용: `2 * level[2]`.
  static int healSpCost(int magicLevel) => 2 * magicLevel;

  /// 원작 `HealOne`의 회복량: `i * 3 div 2` (i = 2 * level[2]).
  static int healAmount(int magicLevel) => (2 * magicLevel) * 3 ~/ 2;

  /// 원작 `CureOne`의 SP 비용.
  static const int cureSpCost = 15;

  /// 원작 `ConsciousOne`의 SP 비용: `10 * unconscious`.
  static int consciousSpCost(int unconscious) => 10 * unconscious;

  /// 원작 `RevitalizeOne`의 SP 비용: `30 * dead`.
  static int revitalizeSpCost(int dead) => 30 * dead;

  // ------------------------------------------------------------------
  // 개인 치료 마법 (원작 HealOne / CureOne / ConsciousOne / RevitalizeOne)
  // ------------------------------------------------------------------

  /// 원작 `HealOne(whom)`.
  static MagicCastResult healOne(PartyMember caster, PartyMember target) {
    if (target.dead > 0 || target.unconscious > 0 || target.poison > 0) {
      return MagicCastResult(messages: ['${target.name}는 치료될 상태가 아닙니다.']);
    }
    if (target.hp >= target.endurance * target.battleLevel) {
      return MagicCastResult(messages: ['${target.name}는 치료할 필요가 없습니다.']);
    }
    final cost = healSpCost(caster.magicLevel);
    if (caster.sp < cost) {
      return const MagicCastResult(messages: [spNotEnoughMessage]);
    }
    caster.sp -= cost;
    target.hp += healAmount(caster.magicLevel);
    final maxHp = target.endurance * target.battleLevel;
    if (target.hp > maxHp) target.hp = maxHp;
    return MagicCastResult(
      messages: ['${target.name}는 치료되어 졌습니다.'],
      spSpent: cost,
      success: true,
    );
  }

  /// 원작 `CureOne(whom)`.
  static MagicCastResult cureOne(PartyMember caster, PartyMember target) {
    if (target.dead > 0 || target.unconscious > 0) {
      return MagicCastResult(messages: ['${target.name}는 독이 치료될 상태가 아닙니다.']);
    }
    if (target.poison == 0) {
      return MagicCastResult(messages: ['${target.name}는 독에 걸리지 않았습니다.']);
    }
    if (caster.sp < cureSpCost) {
      return const MagicCastResult(messages: [spNotEnoughMessage]);
    }
    caster.sp -= cureSpCost;
    target.poison = 0;
    return MagicCastResult(
      messages: ['${target.name}의 독은 제거 되었습니다.'],
      spSpent: cureSpCost,
      success: true,
    );
  }

  /// 원작 `ConsciousOne(whom)`.
  static MagicCastResult consciousOne(PartyMember caster, PartyMember target) {
    if (target.dead > 0) {
      return MagicCastResult(messages: ['${target.name}는 의식이 돌아올 상태가 아닙니다.']);
    }
    if (target.unconscious == 0) {
      return MagicCastResult(messages: ['${target.name}는 의식불명이 아닙니다.']);
    }
    final cost = consciousSpCost(target.unconscious);
    if (caster.sp < cost) {
      return const MagicCastResult(messages: [spNotEnoughMessage]);
    }
    caster.sp -= cost;
    target.unconscious = 0;
    if (target.hp <= 0) target.hp = 1;
    return MagicCastResult(
      messages: ['${target.name}는 의식을 되찾았습니다.'],
      spSpent: cost,
      success: true,
    );
  }

  /// 원작 `RevitalizeOne(whom)`.
  static MagicCastResult revitalizeOne(
    PartyMember caster,
    PartyMember target,
  ) {
    if (target.dead == 0) {
      return MagicCastResult(messages: ['${target.name}는 아직 살아 있습니다.']);
    }
    final cost = revitalizeSpCost(target.dead);
    if (caster.sp < cost) {
      return const MagicCastResult(messages: [spNotEnoughMessage]);
    }
    caster.sp -= cost;
    target.dead = 0;
    final limit = target.endurance * target.battleLevel;
    if (target.unconscious > limit) target.unconscious = limit;
    if (target.unconscious == 0) target.unconscious = 1;
    return MagicCastResult(
      messages: ['${target.name}는 다시 생명을 얻었습니다.'],
      spSpent: cost,
      success: true,
    );
  }

  /// 개인 마법 19~25 중 [index](1~7)를 대상 1명에게 시전한다(원작 `case j of`).
  static MagicCastResult castPersonalCure(
    PartyMember caster,
    PartyMember target,
    int index,
  ) {
    switch (index) {
      case 1:
        return healOne(caster, target);
      case 2:
        return cureOne(caster, target);
      case 3:
        return _merge([cureOne(caster, target), healOne(caster, target)]);
      case 4:
        return consciousOne(caster, target);
      case 5:
        return revitalizeOne(caster, target);
      case 6:
        return _merge([
          consciousOne(caster, target),
          cureOne(caster, target),
          healOne(caster, target),
        ]);
      case 7:
        return _merge([
          revitalizeOne(caster, target),
          consciousOne(caster, target),
          cureOne(caster, target),
          healOne(caster, target),
        ]);
      default:
        return const MagicCastResult();
    }
  }

  /// 전체 마법 26~32 중 [index](1~7)를 일행 전원에게 시전한다.
  ///
  /// 원작은 각 `xxxAll` 이 파티 1~6번을 돌며 개인 마법을 호출한다(SP도 각각 소모).
  static MagicCastResult castGroupCure(
    PartyMember caster,
    List<PartyMember> party,
    int index,
  ) {
    final members = party.where((p) => p.name.isNotEmpty).toList();
    switch (index) {
      case 1:
        return _mergeAll(caster, members, 'heal');
      case 2:
        return _mergeAll(caster, members, 'cure');
      case 3:
        return _mergeAll(caster, members, 'cureHeal');
      case 4:
        return _mergeAll(caster, members, 'conscious');
      case 5:
        return _mergeAll(caster, members, 'revitalize');
      case 6:
        return _mergeAll(caster, members, 'consciousCureHeal');
      case 7:
        return _mergeAll(caster, members, 'revitalizeConsciousCureHeal');
      default:
        return const MagicCastResult();
    }
  }

  static MagicCastResult _mergeAll(
    PartyMember caster,
    List<PartyMember> members,
    String kind,
  ) {
    final results = <MagicCastResult>[];
    for (final m in members) {
      switch (kind) {
        case 'heal':
          results.add(healOne(caster, m));
          break;
        case 'cure':
          results.add(cureOne(caster, m));
          break;
        case 'cureHeal':
          results.add(cureOne(caster, m));
          results.add(healOne(caster, m));
          break;
        case 'conscious':
          results.add(consciousOne(caster, m));
          break;
        case 'revitalize':
          results.add(revitalizeOne(caster, m));
          break;
        case 'consciousCureHeal':
          results.add(consciousOne(caster, m));
          results.add(cureOne(caster, m));
          results.add(healOne(caster, m));
          break;
        case 'revitalizeConsciousCureHeal':
          results.add(revitalizeOne(caster, m));
          results.add(consciousOne(caster, m));
          results.add(cureOne(caster, m));
          results.add(healOne(caster, m));
          break;
      }
    }
    return _merge(results);
  }

  static MagicCastResult _merge(List<MagicCastResult> results) {
    return MagicCastResult(
      messages: [for (final r in results) ...r.messages],
      spSpent: results.fold(0, (sum, r) => sum + r.spSpent),
      success: results.any((r) => r.success),
    );
  }

  // ------------------------------------------------------------------
  // 현상계 보조 마법 (원작 PhenominaSpell)
  // ------------------------------------------------------------------

  /// 현상계 마법이 금지된 동굴(원작 `party.map in [20,25,26]`).
  static bool isPhenominaBlocked(int mapId) =>
      mapId == 20 || mapId == 25 || mapId == 26;

  /// 현상계 마법 금지 문구 (원작 `Message(13,...)`).
  static const String phenominaBlockedMessage = ' 이 동굴의 악의 힘이 이 마법을 방해합니다.';

  /// 원작 1번: 마법의 횃불 (SP 1, `party.etc[1]` 증가, 최대 255).
  static MagicCastResult torch(PartyMember caster) {
    if (caster.sp < phenominaSpCosts[0]) {
      return const MagicCastResult(messages: [spNotEnoughMessage]);
    }
    caster.sp -= phenominaSpCosts[0];
    return MagicCastResult(
      messages: ['일행은 마법의 횃불을 밝혔습니다.'],
      spSpent: phenominaSpCosts[0],
      success: true,
    );
  }

  /// 원작 2번: 공중부상 (SP 5).
  static MagicCastResult levitate(PartyMember caster) =>
      _phenomina(caster, 1, '일행은 공중부상중 입니다.');

  /// 원작 3번: 물위를 걸음 (SP 10).
  static MagicCastResult waterWalk(PartyMember caster) =>
      _phenomina(caster, 2, '일행은 물위를 걸을수 있습니다.');

  /// 원작 4번: 늪위를 걸음 (SP 20).
  static MagicCastResult swampWalk(PartyMember caster) =>
      _phenomina(caster, 3, '일행은 늪위를 걸을수 있습니다.');

  /// 원작 8번: 식량 제조 (SP 30, 파티 인원수만큼 식량 증가, 255 상한).
  static MagicCastResult createFood(
    PartyMember caster,
    List<PartyMember> party,
    int currentFood,
  ) {
    if (caster.sp < phenominaSpCosts[7]) {
      return const MagicCastResult(messages: [spNotEnoughMessage]);
    }
    final members = party.where((p) => p.name.isNotEmpty).length;
    caster.sp -= phenominaSpCosts[7];
    final food = currentFood + members > 255 ? 255 : currentFood + members;
    return MagicCastResult(
      messages: [
        ' 식량 제조 마법은 성공적으로 수행되었습니다',
        '            $members 개의 식량이 증가됨',
        '      일행의 현재 식량은 $food 개 입니다',
      ],
      spSpent: phenominaSpCosts[7],
      success: true,
    );
  }

  static MagicCastResult _phenomina(
    PartyMember caster,
    int index,
    String message,
  ) {
    final cost = phenominaSpCosts[index];
    if (caster.sp < cost) {
      return const MagicCastResult(messages: [spNotEnoughMessage]);
    }
    caster.sp -= cost;
    return MagicCastResult(
      messages: [message],
      spSpent: cost,
      success: true,
    );
  }

  /// 원작 5번: 기화 이동 (SP 25) - 2칸 이동 가능 여부 판정.
  static const int vaporizeMoveSpCost = 25;

  /// 원작 6번: 지형 변화 (SP 30).
  static const int terrainChangeSpCost = 30;

  /// 원작 7번: 공간 이동 (SP 50).
  static const int spaceMoveSpCost = 50;

  /// 지형 변화로 놓이는 타일 (원작 `case position of town:47 ground:41 den:43 keep:43`).
  static int terrainChangeTile(String position) {
    switch (position) {
      case 'town':
        return 47;
      case 'ground':
        return 41;
      case 'den':
      case 'keep':
        return 43;
      default:
        return 43;
    }
  }

  /// 기화 이동 가능 여부 (원작 타일 범위 판정).
  static bool vaporizeTileAllowed(String position, int tile) {
    switch (position) {
      case 'town':
        return tile == 0 || (tile >= 27 && tile <= 47);
      case 'ground':
        return tile == 0 || (tile >= 24 && tile <= 47);
      case 'den':
        return tile == 0 || (tile >= 41 && tile <= 47);
      case 'keep':
        return tile == 0 || (tile >= 40 && tile <= 47);
      default:
        return false;
    }
  }

  /// 공간 이동 가능 여부 (원작 타일 범위 판정).
  static bool spaceMoveTileAllowed(String position, int tile) {
    switch (position) {
      case 'town':
        return tile >= 27 && tile <= 47;
      case 'ground':
        return tile >= 24 && tile <= 47;
      case 'den':
        return tile >= 41 && tile <= 47;
      case 'keep':
        return tile >= 27 && tile <= 47;
      default:
        return false;
    }
  }

  /// 기화 이동은 항상 2칸, 공간 이동은 1~9칸 (원작 입력 범위).
  static int clampSpaceMoveDistance(int distance) => distance.clamp(1, 9);

  /// 원작 문구 모음.
  static const String vaporizeNotAllowedMessage = '기화 이동이 통하지 않습니다.';
  static const String magicRejectedMessage = '알수없는 힘이 당신의 마법을 배척합니다.';
  static const String vaporizeDoneMessage = '기화 이동을 마쳤습니다.';
  static const String terrainChangedMessage = '지형 변화에 성공했습니다.';
  static const String spaceMoveNotAllowedMessage = '공간 이동이 통하지 않습니다.';
  static const String spaceMoveBadSpotMessage = '공간 이동 장소로 부적합 합니다.';
  static const String spaceMoveRejectedMessage = '알수없는 힘이 당신을 배척합니다.';
  static const String spaceMoveDoneMessage = '공간 이동 마법이 성공했습니다.';

  /// 원작 `x := x + 2*x1` 처럼 2칸 이동할 좌표(지도 밖이면 null).
  static (int, int)? vaporizeTarget(
    int x,
    int y,
    int dx,
    int dy,
    int xmax,
    int ymax,
  ) {
    final tx = x + 2 * dx;
    final ty = y + 2 * dy;
    if (tx < 5 || tx >= xmax - 3 || ty < 5 || ty >= ymax - 3) return null;
    return (tx, ty);
  }

  /// 원작 `x := x + k*x1` 이동 좌표(지도 밖이면 null).
  static (int, int)? spaceMoveTarget(
    int x,
    int y,
    int dx,
    int dy,
    int distance,
    int xmax,
    int ymax,
  ) {
    final k = clampSpaceMoveDistance(distance);
    final tx = x + k * dx;
    final ty = y + k * dy;
    if (tx < 5 || tx >= xmax - 3 || ty < 5 || ty >= ymax - 3) return null;
    return (tx, ty);
  }

  /// 원작 `random` 을 쓰지 않는 결정적 보조(테스트용).
  static int maxOf(int a, int b) => max(a, b);
}
