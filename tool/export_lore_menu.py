#!/usr/bin/env python3
"""원작 `LOREMENU.PAS` 의 문구를 `lib/logic/lore_menu_text.dart` 로 옮긴다.

표시/선택창 문구는 전부 원문 그대로 쓰고, 포트 코드는 이 상수를 참조한다.
"""
from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_lore_quest_talk import decode  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'repo_source', 'LORE_1993_src', 'LOREMENU.PAS')
OUT = os.path.join(ROOT, 'lib', 'logic', 'lore_menu_text.dart')

STR = re.compile(r"'((?:[^']|'')*)'")

# 이름 → 원작 문구(정확히 일치해야 한다)
NAMES: dict[str, str] = {
    # SelectMode (LOREMENU.PAS:1033)
    'selectModePrompt': '당신의 명령을 고르시오 ===>',
    'selectModeParty': '일행의 상황을 본다',
    'selectModeCharacter': '개인의 상황을 본다',
    'selectModeQuick': '일행의 건강 상태를 본다',
    'selectModeCast': '마법을 사용한다',
    'selectModeEsp': '초능력을 사용한다',
    'selectModeRest': '여기서 쉰다',
    'selectModeOption': '게임 선택 상황',
    # ViewParty (LOREMENU.PAS:499)
    'viewPartyXAxis': 'X 축 = ',
    'viewPartyYAxis': 'Y 축 = ',
    'viewPartyFood': '남은 식량 = ',
    'viewPartyGold': '남은 황금 = ',
    'viewPartyTorch': '마법의 횃불 :',
    'viewPartyLevitate': '공중 부상   :',
    'viewPartyWater': '물위를 걸음 :',
    'viewPartySwamp': '늪위를 걸음 :',
    'viewPartyAvailable': ' 가능',
    'viewPartyUnavailable': ' 불가',
    # ViewCharacter (LOREMENU.PAS:526)
    'viewCharWho': '능력을 보고싶은 인물을 선택하시오',
    'viewCharName': '# 이름 : ',
    'viewCharSex': '# 성별 : ',
    'viewCharClass': '# 계급 : ',
    'viewCharStrength': '체력   : ',
    'viewCharMentality': '정신력 : ',
    'viewCharConcentration': '집중력 : ',
    'viewCharEndurance': '인내력 : ',
    'viewCharResistance': '저항력 : ',
    'viewCharAgility': '민첩성 : ',
    'viewCharLuck': '행운   : ',
    'viewCharPressKey': '아무키나 누르십시오 ...',
    'viewCharAccArms': '무기의 정확성   : ',
    'viewCharAccMagic': '정신력의 정확성 : ',
    'viewCharAccEsp': '초감각의 정확성 : ',
    'viewCharBattleLevel': '전투 레벨   : ',
    'viewCharMagicLevel': '마법 레벨   : ',
    'viewCharEspLevel': '초감각 레벨 : ',
    'viewCharExp': '## 경험치   : ',
    'viewCharWeapon': '사용 무기 - ',
    'viewCharShield': '방패 - ',
    'viewCharArmor': '갑옷 - ',
    'viewCharShieldSuffix': ' 방패',
    'viewCharArmorSuffix': ' 갑옷',
    # QuickView (LOREMENU.PAS:592)
    'quickViewName': '이름',
    'quickViewHeader': ' 중독 의식불명 죽음',
    # CastSpell (LOREMENU.PAS:622)
    'castSpellKind': '사용할 마법의 종류 ===>',
    'castSpellAttack': '공격 마법',
    'castSpellCure': '치료 마법',
    'castSpellPhenomina': '변화 마법',
    'castSpellNotReady': '는 마법을 사용할수있는 상태가 아닙니다',
    # Extrasense (LOREMENU.PAS:700)
    'espNotEnough': 'ESP 지수가 충분하지 않습니다.',
    'espNotReady': '는 초감각을 사용할수있는 상태가 아닙니다',
    'espNoAbility': '당신에게는 아직 능력이 없습니다.',
    'espBattleOnly': '은 전투 모드에서만 사용됩니다.',
    'espSeeThrough': '일행은 주위를 투시하고 있다.',
    'espMindRead': '당신은 잠시동안 다른 사람의 마음을 읽을수 있다.',
    'espDirection': '<<<  방향을 선택하시오  >>>',
    'espClairvoyanceUse': '으로 천리안을 사용',
    'espClairvoyanceBusy': '천리안의 사용중 ...',
    'espPressKey': '아무키나 누르시오 ...',
    'espKind': '사용할 초감각의 종류 ===>',
    'espEvilPower': ' 이 동굴의 악의 힘이 이 마법을 방해합니다.',
    # PhenominaSpell (LOREMENU.PAS:232)
    'phenominaSelect': '선택',
    'phenominaVaporize': '으로 기화 이동',
    'phenominaTerrain': '에 지형 변화',
    'phenominaSpaceMove': '으로 공간이동',
    'phenominaRejected': '알수없는 힘이 당신의 마법을 배척합니다.',
    'phenominaTorch': '일행은 마법의 횃불을 밝혔습니다.',
    'phenominaLevitate': '일행은 공중부상중 입니다.',
    'phenominaWater': '일행은 물위를 걸을수 있습니다.',
    'phenominaSwamp': '일행은 늪위를 걸을수 있습니다.',
    'phenominaVaporizeFail': '기화 이동이 통하지 않습니다.',
    'phenominaVaporizeDone': '기화 이동을 마쳤습니다.',
    'phenominaTerrainDone': '지형 변화에 성공했습니다.',
    'phenominaPowerPrompt': '당신의 공간 이동력을 지정',
    'phenominaXAxis': 'X 축 = ',
    'phenominaYAxis': 'Y 축 = ',
    # GameOption (LOREMENU.PAS:914)
    'optionTitle': '게임 선택 상황',
    'optionDifficulty': '난이도 조절',
    'optionOrder': '정식 일행의 순서 정렬',
    'optionRemove': '일행에서 제외 시킴',
    'optionResume': '이전의 게임을 재개',
    'optionSave': '현재의 게임을 저장',
    'optionQuit': '게임을 마침',
    'optionMaxEnemy1': '한번에 출현하는 적들의',
    'optionMaxEnemy2': '최대치를 기입하십시오',
    'optionEnemySuffix': ' 명의 적들',
    'optionEncounterPrompt': '일행들의 지금 성격은 어떻습니까 ?',
    'optionEncounter1': '일부러 전투를 피하고 싶다',
    'optionEncounter2': '너무 잦은 전투는 원하지 않는다',
    'optionEncounter3': '마주친 적과는 전투를 하겠다',
    'optionEncounter4': '보이는 적들과는 모두 전투하겠다',
    'optionEncounter5': '그들은 피에 굶주려 있다',
    'optionOrderPrompt': '현재의 일원의 전투 순서를 정렬 하십시오.',
    'optionOrderWho': '순서를 바꿀 일원',
    'optionRemovePrompt': '일행에서 제외 시키고 싶은 사람을 고르십시오.',
    'optionLoadPrompt': '게임의 저장 장소를 선택하십시오.',
    'optionSaving': '현재의 게임을 저장합니다',
    'optionSaveDone': '성공했습니다',
    'optionReserved': 'Reserved',
    # Rest (LOREMENU.PAS:869)
    'restNoFood': '일행은 식량이 바닥났다',
    'restPressKey': '아무키나 누르시오 ...',
}


def literals(text: str) -> list[str]:
    return [m.group(1).replace("''", "'") for m in STR.finditer(text)]


def dart_str(text: str) -> str:
    return "'" + text.replace('\\', '\\\\').replace("'", "\\'") + "'"


def main() -> int:
    with open(SRC, 'rb') as fh:
        source = decode(fh.read())
    pool = literals(source)
    missing = [k for k, v in NAMES.items() if v not in pool]
    if missing:
        for k in missing:
            print(f'원작에서 찾지 못함: {k} = {NAMES[k]!r}')
        return 1

    lines = [
        '// GENERATED by tool/export_lore_menu.py -- 원작 LOREMENU.PAS 문구',
        '// 표시/선택창 문구를 원문 그대로 쓰기 위한 상수 모음.',
        '',
        '/// 원작 `LOREMENU.PAS` 의 화면 문구(원문).',
        'class LoreMenuText {',
        '  const LoreMenuText._();',
        '',
    ]
    for name, text in NAMES.items():
        lines.append(f'  static const String {name} = {dart_str(text)};')
    lines.append('')
    lines.append('  /// 원작 `ReturnMagic` 이름(41..45 = 초감각 5종).')
    lines.append('  static const List<String> espNames = [')
    by_id = {}
    for m in re.finditer(r"(\d+)\s*:\s*ReturnMagic\s*:=\s*'([^']*)'", source):
        by_id[int(m.group(1))] = m.group(2).replace("''", "'")
    for i in range(41, 46):
        lines.append(f'    {dart_str(by_id.get(i, ""))},')
    lines.append('  ];')
    lines.append('')
    lines.append('  /// 원작 `ReturnMagic` 이름(33..40 = 변화 마법 8종).')
    lines.append('  static const List<String> phenominaNames = [')
    for i in range(33, 41):
        lines.append(f'    {dart_str(by_id.get(i, ""))},')
    lines.append('  ];')
    lines.append('}')
    lines.append('')
    with open(OUT, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines))
    print(f'문구 {len(NAMES)}개 + 초감각/변화 마법 이름 생성')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
