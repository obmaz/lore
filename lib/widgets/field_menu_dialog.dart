import 'package:flutter/material.dart';

import '../logic/lore_menu_text.dart';
import 'esp_panel.dart';
import '../theme/retro_theme.dart';
import '../models/party_member.dart';

/// 1993년 원작 LOREMENU.PAS 기반 스페이스바 필드 시스템 메뉴 (SelectMode)
class FieldMenuDialog extends StatefulWidget {
  final List<PartyMember> party;
  final int gold;
  final int food;
  final int currentMapId;
  final int playerX;
  final int playerY;
  final void Function(int count)? onMindReadActivated;
  final Map<String, int>? etc;
  final void Function(String message) onLog;

  /// SelectMode 항목이나 원작 핫키(P/V/Q/E)로 고른 절차.
  final FieldMenuTab initialTab;

  const FieldMenuDialog({
    super.key,
    required this.party,
    required this.gold,
    required this.food,
    this.currentMapId = 6,
    this.playerX = 51,
    this.playerY = 31,
    this.onMindReadActivated,
    this.etc,
    required this.initialTab,
    required this.onLog,
  });

  @override
  State<FieldMenuDialog> createState() => _FieldMenuDialogState();
}

/// The LOREMENU procedure this dialog shows (SelectMode itself is a Select
/// on the game screen).
enum FieldMenuTab { partyView, characterView, quickView, esp }

class _FieldMenuDialogState extends State<FieldMenuDialog> {
  late final FieldMenuTab _currentTab = widget.initialTab;
  int _selectedMemberIndex = 0;
  late int _currentFood;

  @override
  void initState() {
    super.initState();
    _currentFood = widget.food;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: RetroTheme.black,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.lightMagenta, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 10),
            _buildBody(),
            const SizedBox(height: 12),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = '';
    if (_currentTab == FieldMenuTab.partyView) {
      title = LoreMenuText.selectModeParty;
    } else if (_currentTab == FieldMenuTab.characterView) {
      // 원작 LOREMENU.PAS:528 - `능력을 보고싶은 인물을 선택하시오`
      title = LoreMenuText.viewCharWho;
    } else if (_currentTab == FieldMenuTab.quickView) {
      title = LoreMenuText.selectModeQuick;
    } else if (_currentTab == FieldMenuTab.esp) {
      title = LoreMenuText.selectModeEsp;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: RetroTheme.headerFont.copyWith(
              color: RetroTheme.lightMagenta,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${LoreMenuText.viewPartyFood}$_currentFood  ${LoreMenuText.viewPartyGold}${widget.gold}',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case FieldMenuTab.partyView:
        return _buildPartyView();
      case FieldMenuTab.characterView:
        return _buildCharacterView();
      case FieldMenuTab.quickView:
        return _buildQuickView();
      case FieldMenuTab.esp:
        return _buildEspView();
    }
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox.shrink(),
        IconButton(
          key: const ValueKey('field-menu-close'),
          style: IconButton.styleFrom(
            backgroundColor: RetroTheme.darkGray,
            foregroundColor: RetroTheme.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, size: 16),
        ),
      ],
    );
  }

  // =========================================================================
  // 1. 일행의 상황 (ViewParty)
  // =========================================================================
  Widget _buildPartyView() {
    final etc = widget.etc ?? const <String, int>{};
    String availability(int value) => value > 0
        ? LoreMenuText.viewPartyAvailable
        : LoreMenuText.viewPartyUnavailable;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 원작 LOREMENU.PAS:504 `ViewParty` - 세계 상태 요약
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${LoreMenuText.viewPartyXAxis}${widget.playerX}   '
                      '${LoreMenuText.viewPartyYAxis}${widget.playerY}',
                      style: RetroTheme.dosFont.copyWith(fontSize: 10),
                    ),
                    Text(
                      '${LoreMenuText.viewPartyFood}${widget.food}   '
                      '${LoreMenuText.viewPartyGold}${widget.gold}',
                      style: RetroTheme.dosFont.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${LoreMenuText.viewPartyTorch}${availability(etc['torchSteps'] ?? 0)}'
                      '  ${LoreMenuText.viewPartyLevitate}${availability(etc['levitateSteps'] ?? 0)}',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.lightCyan,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '${LoreMenuText.viewPartyWater}${availability(etc['waterWalkSteps'] ?? 0)}'
                      '  ${LoreMenuText.viewPartySwamp}${availability(etc['swampWalkSteps'] ?? 0)}',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.lightCyan,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 86,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: RetroTheme.darkGray),
              color: RetroTheme.background,
            ),
            child: ListView.builder(
              itemCount: widget.party.length,
              itemBuilder: (context, idx) {
                final p = widget.party[idx];
                return Card(
                  color: RetroTheme.black,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${idx + 1}. ${p.name}\n(${p.playerClass.koreanName}, Lv.${p.battleLevel})',
                            style: RetroTheme.dosFont.copyWith(
                              color: RetroTheme.yellow,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'HP: ${p.hp}/${p.maxHp}\nSP: ${p.sp}/${p.maxSp}',
                            style: RetroTheme.dosFont.copyWith(
                              color: RetroTheme.lightGreen,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            '${LoreMenuText.viewCharWeapon}${p.weaponName}\n${LoreMenuText.viewCharShield}${p.shieldName}\n${LoreMenuText.viewCharArmor}${p.armorName}',
                            style: RetroTheme.dosFont.copyWith(
                              color: RetroTheme.lightCyan,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 2. 개인의 상황 (ViewCharacter)
  // =========================================================================
  Widget _buildCharacterView() {
    final p = widget.party[_selectedMemberIndex];
    return Column(
      children: [
        // 멤버 선택 탭 (인원이 많아도 넘치지 않도록 가로 스크롤)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.party.asMap().entries.map((e) {
              final isSel = e.key == _selectedMemberIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Text(
                    e.value.name,
                    style: RetroTheme.dosFont.copyWith(fontSize: 10),
                  ),
                  selected: isSel,
                  selectedColor: RetroTheme.yellow,
                  backgroundColor: RetroTheme.darkGray,
                  onSelected: (val) {
                    if (val) setState(() => _selectedMemberIndex = e.key);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 168,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: RetroTheme.darkGray),
            color: RetroTheme.background,
          ),
          child: SingleChildScrollView(
            child: Row(
              children: [
                // 기본 스탯
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      // 원작 LOREMENU.PAS:526 `ViewCharacter` 표기
                      Text(
                        '${LoreMenuText.viewCharStrength}${p.strength}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharMentality}${p.mentality}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharConcentration}${p.concentration}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharEndurance}${p.endurance}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharResistance}${p.resistance}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharAgility}${p.agility}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharLuck}${p.luck}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                // 장비 및 전투력
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '${LoreMenuText.viewCharWeapon}${p.weaponName}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharShield}${p.shieldName}${LoreMenuText.viewCharShieldSuffix}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharArmor}${p.armorName}${LoreMenuText.viewCharArmorSuffix}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharAccArms}${p.accArms}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharAccMagic}${p.accMagic}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharAccEsp}${p.accEsp}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharBattleLevel}${p.battleLevel}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharMagicLevel}${p.magicLevel}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharEspLevel}${p.espLevel}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${LoreMenuText.viewCharExp}${p.experience}',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 3. 간이 일행 상황 (LOREMENU.PAS: QuickView)
  // =========================================================================
  Widget _buildQuickView() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      child: Column(
        children: [
          Container(
            color: RetroTheme.darkBlue,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    LoreMenuText.quickViewName,
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.white,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'HP',
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.lightGreen,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SP',
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.lightCyan,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ESP',
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.yellow,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    // 원작 QuickView: ` 중독 의식불명 죽음`
                    LoreMenuText.quickViewHeader,
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.lightRed,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '',
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.lightRed,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '',
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.lightRed,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: widget.party.length,
              itemBuilder: (context, idx) {
                final p = widget.party[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: RetroTheme.background,
                    border: Border.all(color: RetroTheme.darkGray, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${idx + 1}. ${p.name}',
                          style: RetroTheme.dosFont.copyWith(
                            color: p.isDead
                                ? RetroTheme.darkGray
                                : (p.isUnconscious
                                      ? RetroTheme.lightRed
                                      : RetroTheme.yellow),
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${p.hp}/${p.maxHp}',
                          style: RetroTheme.dosFont.copyWith(
                            color: RetroTheme.lightGreen,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${p.sp}/${p.maxSp}',
                          style: RetroTheme.dosFont.copyWith(
                            color: RetroTheme.lightCyan,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${p.esp}/${p.maxEsp}',
                          style: RetroTheme.dosFont.copyWith(
                            color: RetroTheme.yellow,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          p.poison > 0 ? '${p.poison}' : '-',
                          style: RetroTheme.dosFont.copyWith(
                            color: p.poison > 0
                                ? RetroTheme.lightRed
                                : RetroTheme.lightGray,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          p.unconscious > 0 ? '${p.unconscious}' : '-',
                          style: RetroTheme.dosFont.copyWith(
                            color: p.unconscious > 0
                                ? RetroTheme.lightRed
                                : RetroTheme.lightGray,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          p.dead > 0 ? '${p.dead}' : '-',
                          style: RetroTheme.dosFont.copyWith(
                            color: p.dead > 0
                                ? RetroTheme.lightRed
                                : RetroTheme.lightGray,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. 초감각 기술 (LOREMENU.PAS: Extrasense / ESP)
  // =========================================================================
  Widget _buildEspView() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      child: SingleChildScrollView(
        child: EspPanel(
          party: widget.party,
          onLog: widget.onLog,
          onMindReadActivated: widget.onMindReadActivated,
        ),
      ),
    );
  }
}
