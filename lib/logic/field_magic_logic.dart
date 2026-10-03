/// 원작 `LOREMENU.PAS`의 비전투 마법 시전 이식.
///
/// 대응 원작 코드:
/// - `LOREMENU.PAS  AttackSpell`        전투 중이 아닐 때 공격 마법 사용 금지
/// - `LOREMENU.PAS  SPnotEnough`        마법 지수 부족 문구
/// - `LOREMENU.PAS  HealOne/CureOne/ConsciousOne/RevitalizeOne`
/// - `LOREMENU.PAS  HealAll/CureAll/ConscoisAll/RevitalizeAll`
/// - `LOREMENU.PAS  CureSpell`          개인(19~25)/전체(26~32) 치료 마법 선택
/// - `LOREMENU.PAS  PhenominaSpell`     마법 이름(33~40); 절차는 `lore_cast_spell.dart`
///
/// 원작은 SP 비용을 **시전자/대상 상태로 계산**한다(고정값 아님):
/// - `HealOne`        : `i := 2 * level[2]` 소모, `hp += i * 3 div 2`
/// - `CureOne`        : 15 소모
/// - `ConsciousOne`   : `10 * unconscious` 소모
/// - `RevitalizeOne`  : `30 * dead` 소모
library;

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

  /// 원작 `CureSpell` 전체 마법 슬롯: `level[2] div 2 - 3` (음수면 거절).
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

  /// 전투 중(`party.etc[6] <> 0`)에는 거절 문구를 출력하지 않는다.
  static MagicCastResult _refusal(String message, bool inBattle) =>
      MagicCastResult(messages: inBattle ? const [] : [message]);

  /// 원작 `HealOne(whom)`.
  static MagicCastResult healOne(
    PartyMember caster,
    PartyMember target, {
    bool inBattle = false,
  }) {
    if (target.dead > 0 || target.unconscious > 0 || target.poison > 0) {
      return _refusal('${target.name}는 치료될 상태가 아닙니다.', inBattle);
    }
    if (target.hp >= target.endurance * target.battleLevel) {
      return _refusal('${target.name}는 치료할 필요가 없습니다.', inBattle);
    }
    final cost = healSpCost(caster.magicLevel);
    if (caster.sp < cost) {
      return _refusal(spNotEnoughMessage, inBattle);
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
  static MagicCastResult cureOne(
    PartyMember caster,
    PartyMember target, {
    bool inBattle = false,
  }) {
    if (target.dead > 0 || target.unconscious > 0) {
      return _refusal('${target.name}는 독이 치료될 상태가 아닙니다.', inBattle);
    }
    if (target.poison == 0) {
      return _refusal('${target.name}는 독에 걸리지 않았습니다.', inBattle);
    }
    if (caster.sp < cureSpCost) {
      return _refusal(spNotEnoughMessage, inBattle);
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
  static MagicCastResult consciousOne(
    PartyMember caster,
    PartyMember target, {
    bool inBattle = false,
  }) {
    if (target.dead > 0) {
      return _refusal('${target.name}는 의식이 돌아올 상태가 아닙니다.', inBattle);
    }
    if (target.unconscious == 0) {
      return _refusal('${target.name}는 의식불명이 아닙니다.', inBattle);
    }
    final cost = consciousSpCost(target.unconscious);
    if (caster.sp < cost) {
      return _refusal(spNotEnoughMessage, inBattle);
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
    PartyMember target, {
    bool inBattle = false,
  }) {
    if (target.dead == 0) {
      return _refusal('${target.name}는 아직 살아 있습니다.', inBattle);
    }
    final cost = revitalizeSpCost(target.dead);
    if (caster.sp < cost) {
      return _refusal(spNotEnoughMessage, inBattle);
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
  /// [each] 는 개인 마법 한 번마다 그 결과를 받는다(출력 순서·색, `SPnotEnough`).
  static MagicCastResult castPersonalCure(
    PartyMember caster,
    PartyMember target,
    int index, {
    bool inBattle = false,
    void Function(MagicCastResult result)? each,
  }) {
    const kinds = <int, List<String>>{
      1: ['heal'],
      2: ['cure'],
      3: ['cure', 'heal'],
      4: ['conscious'],
      5: ['revitalize'],
      6: ['conscious', 'cure', 'heal'],
      7: ['revitalize', 'conscious', 'cure', 'heal'],
    };
    return _merge([
      for (final kind in kinds[index] ?? const <String>[])
        _cast(kind, caster, target, inBattle, each),
    ]);
  }

  /// 전체 마법 26~32 중 [index](1~7)를 일행 전원에게 시전한다.
  ///
  /// LOREMENU `CureSpell` 의 `case j of`: 각 `xxxAll` 은 파티 1~6번을 한 번씩 돌며
  /// 개인 마법을 호출하고(SP도 각각 소모), 복합 마법은 단계별로 `xxxAll` 을 차례로
  /// 부른다. 원작의 5·6번은 개인 마법(5=부활, 6=복합)과 달리 `5 : ConscoisAll;
  /// CureAll;HealAll`, `6 : RevitalizeAll` 이다.
  static MagicCastResult castGroupCure(
    PartyMember caster,
    List<PartyMember> party,
    int index, {
    bool inBattle = false,
    void Function(MagicCastResult result)? each,
  }) {
    final members = party.where((p) => p.name.isNotEmpty).toList();
    const phases = <int, List<String>>{
      1: ['heal'],
      2: ['cure'],
      3: ['cure', 'heal'],
      4: ['conscious'],
      5: ['conscious', 'cure', 'heal'],
      6: ['revitalize'],
      7: ['revitalize', 'conscious', 'cure', 'heal'],
    };
    return _merge([
      for (final kind in phases[index] ?? const <String>[])
        for (final m in members) _cast(kind, caster, m, inBattle, each),
    ]);
  }

  static MagicCastResult _cast(
    String kind,
    PartyMember caster,
    PartyMember target,
    bool inBattle,
    void Function(MagicCastResult result)? each,
  ) {
    final result = switch (kind) {
      'heal' => healOne(caster, target, inBattle: inBattle),
      'cure' => cureOne(caster, target, inBattle: inBattle),
      'conscious' => consciousOne(caster, target, inBattle: inBattle),
      _ => revitalizeOne(caster, target, inBattle: inBattle),
    };
    each?.call(result);
    return result;
  }

  static MagicCastResult _merge(List<MagicCastResult> results) {
    return MagicCastResult(
      messages: [for (final r in results) ...r.messages],
      spSpent: results.fold(0, (sum, r) => sum + r.spSpent),
      success: results.any((r) => r.success),
    );
  }

  /// PhenominaSpell 7 (공간 이동) 문구 (`LoreCastSpell`).
  static const String spaceMoveNotAllowedMessage = '공간 이동이 통하지 않습니다.';
  static const String spaceMoveBadSpotMessage = '공간 이동 장소로 부적합 합니다.';
  static const String spaceMoveRejectedMessage = '알수없는 힘이 당신을 배척합니다.';
  static const String spaceMoveDoneMessage = '공간 이동 마법이 성공했습니다.';
}
