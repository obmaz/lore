/// 1993년 원작 LORE의 동료 영입(join) 이벤트 이식.
///
/// 대응 원작 코드:
/// - `LORESUB.PAS:1042  join(num, partynum)`   몬스터 템플릿 → 파티원 편입
/// - `LORESUB.PAS:1144  ReturnJoinMember`      합류시킬 파티 슬롯 선택 (2~6번)
/// - `LORETALK.PAS / LORESPEC.PAS`             6명의 영입 가능 동료별 능력치 보정
///
/// 원작은 `join(몬스터번호, 슬롯)` 으로 기본 능력치를 채운 뒤,
/// 캐릭터별로 이름/직업/장비/능력치를 덮어쓴다. 이 파일은 그 결과를 그대로 옮긴 것이다.
library;

import '../data/lore_data.dart';
import '../models/party_member.dart';

/// 영입 대기 항목 - 원작 `join(num, partynum)` 호출 1건에 대응한다.
class PendingRecruit {
  final PartyMember member;

  /// 원작이 슬롯을 고정한 경우(예: Mad Joe = 6번 슬롯)의 메뉴 옵션 인덱스(0~4).
  final int? forcedSlotOption;

  const PendingRecruit(this.member, {this.forcedSlotOption});
}

/// 원작에서 실제로 일행에 합류할 수 있는 6명의 동료.
class LoreJoin {
  LoreJoin._();

  /// LORESPEC.PAS 수감소 전투: 6번 슬롯의 Mad Joe가 탈주 직후 일행을 떠난다.
  /// 영입을 기록한 `party.etc[50]`의 bit2는 그대로 남아 병사 전투가 이어진다.
  static bool removeMadJoeAtPrison(List<PartyMember> party) {
    if (party.length < 6 || party[5].name != 'Mad Joe') return false;
    party[5].name = '';
    return true;
  }

  /// 원작 파티 슬롯은 1~6번(리더 포함)이다.
  static const int maxPartySize = 6;

  /// 원작 `LORETALK.PAS:197` - 지하 감옥의 Mad Joe (몬스터 #1 Orc 템플릿).
  /// 원작: class 8(떠돌이), 모든 장비/방어도 0.
  static PartyMember madJoe() {
    return PartyMember.fromMonsterTemplate(
        LoreData.instance.monster(1),
        name: 'Mad Joe',
      )
      ..playerClass = PlayerClass.vagrant
      ..weapon = 0
      ..shield = 0
      ..armor = 0
      ..weaPower = 0
      ..shiPower = 0
      ..armPower = 0
      ..ac = 0;
  }

  /// 원작 `LORETALK.PAS:413` - LASTDITCH의 전사 Polaris (몬스터 #9 Imp 템플릿).
  /// 원작: class 4(전사), level[2] := 3, 장검(4)/가죽 방패(1)/가죽 갑옷(1) 장착.
  static PartyMember polaris() {
    return PartyMember.fromMonsterTemplate(
        LoreData.instance.monster(9),
        name: 'Polaris',
      )
      ..playerClass = PlayerClass.warrior
      ..magicLevel = 3
      ..weapon = 4
      ..shield = 1
      ..armor = 1
      ..weaPower = 10
      ..shiPower = 1
      ..armPower = 2
      ..ac = 3;
  }

  /// 원작 `LORESPEC.PAS:620` - EVIL SEAL의 사냥꾼 Rigel (몬스터 #14 Gremlin 템플릿).
  /// 원작: class 7(사냥꾼), hp := 1 (빈사 상태로 합류).
  static PartyMember rigel() {
    return PartyMember.fromMonsterTemplate(
        LoreData.instance.monster(14),
        name: 'Rigel',
      )
      ..playerClass = PlayerClass.hunter
      ..weapon = 4
      ..shield = 1
      ..armor = 1
      ..weaPower = 10
      ..shiPower = 1
      ..armPower = 2
      ..ac = 3
      ..hp = 1;
  }

  /// 원작 `LORESPEC.PAS:1040` - Red Antares (몬스터 #55 Dark Soul 템플릿).
  /// 원작: class 9(혼령), 모든 장비 제거, hp := 0, resistance := 15, endurance := 10.
  static PartyMember redAntares() {
    return PartyMember.fromMonsterTemplate(
        LoreData.instance.monster(55),
        name: 'Red Antares',
      )
      ..playerClass = PlayerClass.ghost
      ..weapon = 0
      ..shield = 0
      ..armor = 0
      ..weaPower = 0
      ..shiPower = 0
      ..armPower = 0
      ..ac = 0
      ..hp = 0
      ..resistance = 15
      ..endurance = 10;
  }

  /// 원작 `LORESPEC.PAS:1230` - Spica (몬스터 #43 Wivern 템플릿).
  /// 원작: 여성, class 3(에스퍼), level 11/6/11, 단도(1)/가죽 방패(1)/가죽 갑옷(1).
  static PartyMember spica() {
    return PartyMember.fromMonsterTemplate(
        LoreData.instance.monster(43),
        name: 'Spica',
      )
      ..sex = Gender.female
      ..playerClass = PlayerClass.esper
      ..strength = 10
      ..mentality = 17
      ..concentration = 20
      ..endurance = 9
      ..resistance = 15
      ..agility = 7
      ..accArms = 8
      ..accMagic = 15
      ..accEsp = 20
      ..luck = 10
      ..battleLevel = 11
      ..magicLevel = 6
      ..espLevel = 11
      ..hp = 9 * 11
      ..sp = 17 * 6
      ..esp = 20 * 11
      ..ac = 3
      ..weapon = 1
      ..shield = 1
      ..armor = 1
      ..weaPower = 5
      ..shiPower = 1
      ..armPower = 2;
  }

  /// 원작 `LORETALK.PAS:623` - LORE 특공대장 Lore Hunter (몬스터 #39 Rampager 템플릿).
  /// 원작: class 7(사냥꾼), 철퇴(5)/청동 방패(2)/가죽 갑옷(1) 장착.
  static PartyMember loreHunter() {
    return PartyMember.fromMonsterTemplate(
        LoreData.instance.monster(39),
        name: 'Lore Hunter',
      )
      ..playerClass = PlayerClass.hunter
      ..weapon = 5
      ..shield = 2
      ..armor = 1
      ..weaPower = 15
      ..shiPower = 2
      ..armPower = 2
      ..ac = 4;
  }

  /// 원작 `LORESPEC.PAS:135` - 늪지 대륙 피라밋의 Draconian (몬스터 #62 템플릿).
  ///
  /// 원작은 `enemydata[62].level := 17; join(62,6); enemydata[62].level := 19;`
  /// 로 **레벨 17** 상태로 6번 슬롯에 편입시키고, 몬스터 템플릿 레벨은
  /// 19 로 되돌려 둔다(재도전 시 적 레벨 유지).
  static PartyMember draconian() {
    final base = LoreData.instance.monster(62);
    final member = PartyMember.fromMonsterTemplate(base, name: 'Draconian')
      ..battleLevel = 17
      ..experience = PartyMember.expTable[16]
      ..hp = base.endurance * 17
      ..weaPower = 17 * 2 + 10;
    return member;
  }

  /// 원작 `LORESPEC.PAS:291` - LORE 성을 떠날 때 합류하는 Skeleton (#19).
  ///
  /// 원작은 `join(19,6)` 으로 6번 슬롯을 고정한다.
  static PartyMember skeleton() {
    return PartyMember.fromMonsterTemplate(
      LoreData.instance.monster(19),
      name: 'Skeleton',
    );
  }

  /// 스크립트(JSON `{"join": "polaris"}`)에서 쓰는 키로 동료를 만든다.
  static PartyMember? byKey(String key) {
    switch (key) {
      case 'mad_joe':
        return madJoe();
      case 'polaris':
        return polaris();
      case 'rigel':
        return rigel();
      case 'red_antares':
        return redAntares();
      case 'spica':
        return spica();
      case 'lore_hunter':
        return loreHunter();
      case 'draconian':
        return draconian();
      case 'skeleton':
        return skeleton();
      default:
        return null;
    }
  }

  /// 원작이 6번 슬롯을 고정한 영입(join(num,6))의 메뉴 옵션 인덱스.
  static const int forcedSixthSlotOption = 4;

  /// 원작 `LORESUB.PAS:1144 ReturnJoinMember`의 메뉴 문구.
  static const String joinMenuPrompt = '교체 시킬 인물은 누구입니까 ?';

  /// 6번 슬롯이 비어 있을 때 표시되는 원작 문구.
  static const String reserveSlotLabel = '보조 일원으로 둠';

  /// 영입을 취소했을 때의 원작 문구 (`asyouwish`).
  static const String joinCancelled = '당신이 바란다면 ...';

  /// 원작 `ReturnJoinMember`의 선택지(m[1..5] = 파티 2~6번 슬롯) 5개.
  ///
  /// 파티가 6명 미만이면 비어 있는 슬롯 라벨은 빈 문자열이 되고,
  /// 6번 슬롯이 비어 있으면 `'보조 일원으로 둠'`으로 대체된다(원작과 동일).
  static List<String> joinMenuLabels(List<PartyMember> party) {
    final labels = <String>[];
    for (var slot = 2; slot <= maxPartySize; slot++) {
      labels.add(slot <= party.length ? party[slot - 1].name : '');
    }
    if (labels.isNotEmpty && labels.last.isEmpty) {
      labels[labels.length - 1] = reserveSlotLabel;
    }
    return labels;
  }

  /// 원작 `join(num, partynum)` 적용.
  ///
  /// [optionIndex]는 메뉴 1~5번째(0~4)로 파티 슬롯 2~6번에 대응한다.
  /// 해당 슬롯에 이미 파티원이 있으면 **교체**하고, 비어 있으면 합류시킨다.
  static void applyJoin(
    List<PartyMember> party,
    PartyMember recruit,
    int optionIndex,
  ) {
    final slotIndex = optionIndex + 1; // 파티 2번 슬롯 = index 1
    if (slotIndex < party.length) {
      party[slotIndex] = recruit;
    } else {
      party.add(recruit);
    }
  }
}
