/// `LOREMENU.PAS` `ViewParty` (499-524), `ViewCharacter` (526-590) and
/// `QuickView` (592-620): the texts each one draws in the window, in drawing
/// order with their `SetColor`. Pixel columns become text columns (8 pixels
/// per half-width cell, hangul two cells).
library;

import '../models/party_member.dart';
import 'lore_menu_text.dart';
import 'lore_source_memory.dart';
import 'lore_sub_text.dart';

class LoreViewProcedures {
  const LoreViewProcedures._();

  /// `ViewParty`: position, food, gold and the four field spells
  /// (`ViewPartySub`: ' 불가' when `party.etc[i] = 0`, else ' 가능').
  static List<(int, String)> viewParty({
    required int x,
    required int y,
    required int food,
    required int gold,
    required LorePartyEtc etc,
  }) {
    String sub(int i) => etc.read(i) == 0
        ? LoreMenuText.viewPartyUnavailable
        : LoreMenuText.viewPartyAvailable;
    return [
      (7, '${LoreMenuText.viewPartyXAxis}$x'),
      (7, '${LoreMenuText.viewPartyYAxis}$y'),
      (7, '${LoreMenuText.viewPartyFood}$food'),
      (7, '${LoreMenuText.viewPartyGold}$gold'),
      (7, '${LoreMenuText.viewPartyTorch}${sub(1)}'),
      (7, '${LoreMenuText.viewPartyLevitate}${sub(4)}'),
      (7, '${LoreMenuText.viewPartyWater}${sub(2)}'),
      (7, '${LoreMenuText.viewPartySwamp}${sub(3)}'),
    ];
  }

  static String _sex(PartyMember p) => p.sex == Gender.male ? '남성' : '여성';

  static List<(int, String)> _header(PartyMember p) => [
    (11, '${LoreMenuText.viewCharName}${p.name}'),
    (11, '${LoreMenuText.viewCharSex}${_sex(p)}'),
    (
      11,
      '${LoreMenuText.viewCharClass}${LoreSubText.classLabel(p.playerClass.id)}',
    ),
  ];

  /// `ViewCharacter` before its key wait.
  static List<(int, String)> characterPage1(PartyMember p) => [
    ..._header(p),
    (3, '${LoreMenuText.viewCharStrength}${p.strength}'),
    (3, '${LoreMenuText.viewCharMentality}${p.mentality}'),
    (3, '${LoreMenuText.viewCharConcentration}${p.concentration}'),
    (3, '${LoreMenuText.viewCharEndurance}${p.endurance}'),
    (3, '${LoreMenuText.viewCharResistance}${p.resistance}'),
    (3, '${LoreMenuText.viewCharAgility}${p.agility}'),
    (3, '${LoreMenuText.viewCharLuck}${p.luck}'),
  ];

  /// `ViewCharacter` after the key (it stays in the window).
  static List<(int, String)> characterPage2(PartyMember p) => [
    ..._header(p),
    (3, '${LoreMenuText.viewCharAccArms}${p.accArms}'),
    (3, '${LoreMenuText.viewCharAccMagic}${p.accMagic}'),
    (3, '${LoreMenuText.viewCharAccEsp}${p.accEsp}'),
    (3, '${LoreMenuText.viewCharBattleLevel}${p.battleLevel}'),
    (3, '${LoreMenuText.viewCharMagicLevel}${p.magicLevel}'),
    (3, '${LoreMenuText.viewCharEspLevel}${p.espLevel}'),
    (3, '${LoreMenuText.viewCharExp}${p.experience}'),
    (2, '${LoreMenuText.viewCharWeapon}${LoreSubText.weaponLabel(p.weapon)}'),
    if (p.shield != 0)
      (
        2,
        '${LoreMenuText.viewCharShield}${LoreSubText.defenseLabel(p.shield)}'
            '${LoreMenuText.viewCharShieldSuffix}',
      ),
    if (p.armor != 0)
      (
        2,
        '${LoreMenuText.viewCharArmor}${LoreSubText.defenseLabel(p.armor)}'
            '${LoreMenuText.viewCharArmorSuffix}',
      ),
  ];

  /// Display width in half-width cells (hangul and other wide glyphs = 2).
  static int _cells(String s) =>
      s.runes.fold(0, (sum, r) => sum + (r >= 0x1100 ? 2 : 1));

  /// [text] padded to start at cell [col] after [line].
  static String _at(String line, int col, String text) {
    final pad = col - _cells(line);
    return '$line${' ' * (pad > 0 ? pad : 1)}$text';
  }

  /// `QuickView`: the header (x 280 / 400) and one row per named member with
  /// `poison`, `unconscious : 3`, `dead : 5` (x 250 / 424 / 464 / 500).
  static List<(int, String)> quickView(List<PartyMember> party) => [
    (
      15,
      _at(
        _at('', 4, LoreMenuText.quickViewName),
        19,
        LoreMenuText.quickViewHeader,
      ),
    ),
    for (final p in party.take(6))
      if (p.name.isNotEmpty)
        (
          7,
          _at(
            _at(
              _at(p.name, 22, '${p.poison}'),
              27,
              '${p.unconscious}'.padLeft(3),
            ),
            31,
            '${p.dead}'.padLeft(5),
          ),
        ),
  ];
}
