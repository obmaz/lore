#!/usr/bin/env python3
"""원작 `LOREBATT.PAS` 의 전투 로그/메뉴 문구를 `lib/logic/lore_batt_text.dart` 로.

전투 로그는 원작에서 `Print(...)` 조각을 이어붙여 만든다. 포트에서도 같은 문장이
나오도록 조각을 상수/헬퍼로 옮긴다.
"""
from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_lore_quest_talk import decode  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'repo_source', 'LORE_1993_src', 'LOREBATT.PAS')
OUT = os.path.join(ROOT, 'lib', 'logic', 'lore_batt_text.dart')

STR = re.compile(r"'((?:[^']|'')*)'")


def dart_str(text: str) -> str:
    """작은따옴표가 있으면 큰따옴표로 감싼다(원문 그대로 소스에 남기기 위해)."""
    if "'" in text:
        return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'
    return "'" + text.replace('\\', '\\\\') + "'"

# 상수 이름 → (원작 조각, 앞뒤 연결 플레이스홀더 사용 여부)
PLAIN: dict[str, str] = {
    'expGainedMsg': '만큼 경험치를 얻었다 !',
    'goldGained': '개의 금을 얻었다.',
    'killWeapon': '의 무기가 ',
    'killHeart': '의 심장을 꿰뚫었다',
    'killHead': '의 머리는 ',
    'killHeadRest': '의 공격으로 산산조각이 났다',  # 원작은 '났다' 로 끝난다
    'killBlood': '적의 피가 사방에 뿌려졌다',
    'killTorn': '적은 비명과 함께 찢겨 나갔다',
    'attackMissed': '의 공격은 빗나갔다 ....',
    'enemyResisted': '적은 ',
    'enemyResistedRest': '의 공격을 저지했다',
    'enemyBlocked': '그러나, 적은 ',
    'enemyBlockedRest': '의 공격을 막았다',
    'enemyKnockedOut': '적은 ',
    'enemyKnockedOutRest': '의 공격으로 의식불명이 되었다',
    'enemyDamaged': '적은 ',
    'enemyDamagedRest': '만큼의 피해를 입었다',
    'magicOnCorpse': '의 마법은 적의 시체 위에서 작열했다',
    'spNotEnough': '마법 지수가 부족했다',
    'magicMissed': '그러나, ',
    'magicMissedRest': '를 빗나갔다',
    'enemyResistedMagic': '는 ',
    'enemyResistedMagicRest': '의 마법을 저지했다',
    'enemyBlockedMagic': '그러나, ',
    'enemyBlockedMagicRest': '는 ',
    'enemyBlockedMagicTail': '의 마법 공격을 막았다',
    'magicKnockedOut': '는 ',
    'magicKnockedOutRest': '의 마법에 의해 의식불능이 되었다',
    'magicDamaged': '는 ',
    'magicDamagedRest': '만큼의 피해를 입었다',
    'noAbility': '당신에게는 아직 능력이 없다.',
    'poisonResisted': '적은 독 공격을 저지 했다',
    'poisonMissed': '독 공격은 빗나갔다',
    'poisoned': '는 중독 되었다',
    'techResisted': '기술 무력화 공격은 저지 당했다',
    'techMissed': '기술 무력화 공격은 빗나갔다',
    'techRemoved': '의 특수 공격 능력이 제거되었다',
    'defenseResisted': '방어 무력화 공격은 저지 당했다',
    'defenseMissed': '방어 무력화 공격은 빗나갔다',
    'defenseLowered': '의 방어 능력이 저하되었다',
    'powerResisted': '능력 저하 공격은 저지 당했다',
    'powerMissed': '능력 저하 공격은 빗나갔다',
    'powerLowered': '의 전체적인 능력이 저하되었다',
    'magicBanResisted': '마법 불능 공격은 저지 당했다',
    'magicBanMissed': '마법 불능 공격은 빗나갔다',
    'magicLowered': '의 마법 능력이 저하되었다',
    'magicRemoved': '의 마법 능력은 사라졌다',
    'espBanResisted': '탈 초인화 공격은 저지 당했다',
    'espBanMissed': '탈 초인화 공격은 빗나갔다',
    'espLowered': '의 초자연적 능력이 저하되었다',
    'espRemoved': '의 초자연적 능력은 사라졌다',
    'espBattleOnly': '는 전투모드에서는 사용할 수가 없습니다.',
    'espNotEnough': '초감각 지수가 부족했다',
    'mindReadFailed': '독심술은 전혀 통하지 않았다',
    'mindReadWeak': '적의 마음을 끌어들이기에는 아직 능력이 부족했다',
    'mindReadResisted': '적의 마음은 흔들리지 않았다',
    'mindReadJoined': '적은 우리의 편이 되었다',
    'espRocks': '주위의 돌들이 떠올라 ',
    'espRocksRest': '를 공격하기 시작한다',
    'espGerms': ' 주위의 세균이 그에게 침투하여 해를 입히기 시작한다',
    'espWeapon': '의 무기가 갑자기 ',
    'espWeaponRest': '에게 달려들기 시작한다',
    'espFission': '갑자기 땅속의 우라늄이 핵분열을 일으켜 고온',
    'espFissionRest': '의 열기가 적의 주위를 감싸기 시작한다',
    'espFusion': '공기중의 수소가 돌연히 핵융합을 일으켜 질량',
    'espFusionRest': '결손의 에너지를 적들에게 방출하기 시작한다',
    'espFear': '는 적에게 공포심을 불어 넣었다',
    'espFled': '는 겁을 먹고는 도망 가버렸다',
    'espMetabolism': '는 적의 신진 대사를 조절하여 적의 ',
    'espMetabolismRest': '체력을 점차 약화 시키려 한다',
    'espHeart': '는 염력으로 적의 심장을 멈추려 한다',
    'espIllusion': '는 적을 환상속에 빠지게 하려한다',
    'runFailed': '그러나, 일행은 성공하지 못했다',
    'runSuccess': '성공적으로 도망을 갔다',
    'partyMissed': '는 빗맞추었다',
    'enemyAttacked': '는 ',
    'enemyAttackedRest': '를 공격했다',
    'partyResisted': '그러나, ',
    'partyResistedRest': '는 적의 공격을 저지했다',
    'partyBlockedRest': '는 적의 공격을 방어했다',
    'partyWasAttacked': '는 ',
    'partyWasAttackedRest': '에게 공격 받았다',
    'partyDamaged': '는 ',
    'partyDamagedRest': '만큼의 피해를 입었다',
    'enemyMagicMissed': '의 마법공격은 빗나갔다',
    'partyResistedEnemyMagic': '그러나, ',
    'partyResistedEnemyMagicRest': '는 적의 마법을 저지했다',
    'partyBlockedEnemyMagicRest': '는 적의 마법을 막아냈다',
    'enemyMagicUsed': '는 ',
    'enemyMagicUsedRest': '에게 \'',
    'enemyMagicUsedTail': '\'마법을 사용했다',
    'enemyMagicAll': '는 일행 모두에게 \'',
    'enemyMagicAllTail': '\'마법을 사용했다',
    'enemyHealSelf': '는 자신을 치료했다',
    'enemyHealOther': '는 ',
    'enemyHealOtherRest': '를 치료했다',
    'armorBreakTry': '는 ',
    'armorBreakTryRest': '의 갑옷파괴를 시도했다',
    'armorBreakFail': '그러나, ',
    'armorBreakFailRest': '는 성공하지 못했다',
    'armorBroken': '의 갑옷은 파괴되었다',
    'poisonTry': '는 ',
    'poisonTryRest': '에게 독 공격을 시도했다',
    'poisonFail': '독 공격은 실패했다',
    'poisonAvoid': '그러나, ',
    'poisonAvoidRest': '는 독 공격을 피했다',
    'poisonedBang': '는 중독 되었다 !!',
    'fatalTry': '는 ',
    'fatalTryRest': '에게 치명적 공격을 시도했다',
    'fatalFail': '치명적 공격은 실패했다',
    'fatalAvoid': '그러나, ',
    'fatalAvoidRest': '는 치명적 공격을 피했다',
    'fatalDone': '는 의식불명이 되었다 !!',
    'deathTry': '는 ',
    'deathTryRest': '에게 죽음의 공격을 시도했다',
    'deathFail': '죽음의 공격은 실패했다',
    'deathAvoid': '그러나, ',
    'deathAvoidRest': '는 죽음의 공격을 피했다',
    'deathDone': '는 죽었다 !!',
    'summonTry': '는 ',
    'summonTryRest': '를 생성시켰다',
    'mindReadEnemy': '가 독심술을 사용하여 ',
    'mindReadEnemyRest': '을 자기편으로 끌어들였다',
    'battleMode': '의 전투 모드 ===>',
    'menuAttackOne': '한 명의 적을 ',
    'menuAttackOneRest': '로 공격',
    'menuMagicOne': '한 명의 적에게 마법 공격',
    'menuMagicAll': '모든 적에게 마법 공격',
    'menuSpecial': '적에게 특수 마법 공격',
    'menuHealParty': '일행을 치료',
    'menuEsp': '적에게 초능력 사용',
    'menuRun': '도망을 시도함',
    'menuCommandAll': '일행에게 무조건 공격 할 것을 지시',
    'menuNone': '없음',
    'encounter': '적이 출현했다 !!!',
    'enemyAgility': '적의 평균 민첩성',
    'engage': '적과 교전한다',
    'flee': '도망간다',
}


def main() -> int:
    with open(SRC, 'rb') as fh:
        source = decode(fh.read())
    pool = [m.group(1).replace("''", "'") for m in STR.finditer(source)]
    # 원작 문자열을 그대로 쓰기 위해 공백 무시 대조로 실제 조각을 찾아 쓴다.
    norm = lambda t: re.sub(r'\s+', '', t)
    by_norm = {norm(x): x for x in pool}
    resolved: dict[str, str] = {}
    missing = []
    for k, v in PLAIN.items():
        exact = by_norm.get(norm(v))
        if exact is None:
            missing.append(k)
        else:
            resolved[k] = exact
    if missing:
        for k in missing:
            print(f'원작에서 찾지 못함: {k} = {PLAIN[k]!r}')
        return 1
    PLAIN.update(resolved)

    lines = [
        '// GENERATED by tool/export_lore_batt.py -- 원작 LOREBATT.PAS 전투 문구',
        '',
        '/// 원작 `LOREBATT.PAS` 의 전투 로그 조각(원문).',
        '///',
        '/// 원작은 조각을 이어붙여 문장을 만든다. 포트도 같은 문장이 나오도록',
        '/// 아래 헬퍼를 통해 조합한다.',
        'class LoreBattText {',
        '  const LoreBattText._();',
        '',
    ]
    for name, text in PLAIN.items():
        lines.append(f'  static const String {name} = {dart_str(text)};')
    lines.append('')
    lines.append('  /// 원작 `ReturnSexData` - 성별에 따른 호칭.')
    lines.append("  static String sexData(bool female) => female ? '그녀' : '그';")
    lines.append('')
    lines.append('  /// 원작 `AttackOne` 1) 무기로 적 처치(4종 연출 중 1종).')
    lines.append('  static String weaponKill(String sex, String target, int roll) {')
    lines.append('    switch (roll % 4) {')
    lines.append('      case 0:')
    lines.append('        return \'$sex$killWeapon$target$killHeart\';')
    lines.append('      case 1:')
    lines.append('        return \'$target$killHead$sex$killHeadRest\';')
    lines.append('      case 2:')
    lines.append('        return killBlood;')
    lines.append('      default:')
    lines.append('        return killTorn;')
    lines.append('    }')
    lines.append('  }')
    lines.append('')
    lines.append('  /// 원작 `{actor}는 {amount}만큼 경험치를 얻었다 !`.')
    lines.append('  static String expGained(String actor, String amount) =>')
    lines.append("      '$actor는 $amount$expGainedMsg';")
    lines.append('')
    lines.append('  /// 원작 `일행은 {n}개의 금을 얻었다.`')
    lines.append('  static String goldFound(String amount) =>')
    lines.append("      '일행은 $amount$goldGained';")
    lines.append('}')
    lines.append('')
    with open(OUT, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(lines))
    print(f'전투 문구 {len(PLAIN)}개 생성')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
