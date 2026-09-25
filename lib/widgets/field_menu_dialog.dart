import 'package:flutter/material.dart';
import '../theme/retro_theme.dart';
import '../models/party_member.dart';

/// 1993년 원작 LOREMENU.PAS 기반 스페이스바 필드 시스템 메뉴 (SelectMode)
class FieldMenuDialog extends StatefulWidget {
  final List<PartyMember> party;
  final int gold;
  final int food;
  final void Function(int newFood)? onFoodChanged;
  final void Function(String message) onLog;

  const FieldMenuDialog({
    super.key,
    required this.party,
    required this.gold,
    required this.food,
    this.onFoodChanged,
    required this.onLog,
  });

  @override
  State<FieldMenuDialog> createState() => _FieldMenuDialogState();
}

enum FieldMenuTab {
  main,
  partyView,
  characterView,
  castSpell,
  rest,
}

class _FieldMenuDialogState extends State<FieldMenuDialog> {
  FieldMenuTab _currentTab = FieldMenuTab.main;
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
    String title = '◆ LORE 시스템 커맨드 메뉴 (SELECT MODE) ◆';
    if (_currentTab == FieldMenuTab.partyView) title = '1. 일행의 상황 (VIEW PARTY)';
    if (_currentTab == FieldMenuTab.characterView) title = '2. 개인의 상황 (VIEW CHARACTER)';
    if (_currentTab == FieldMenuTab.castSpell) title = '3. 비전투 마법 시전 (CAST SPELL)';
    if (_currentTab == FieldMenuTab.rest) title = '4. 야외 캠프 휴식 (REST)';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: RetroTheme.headerFont.copyWith(color: RetroTheme.lightMagenta, fontSize: 12),
        ),
        Text(
          '식량: $_currentFood | 금화: ${widget.gold}',
          style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case FieldMenuTab.main:
        return _buildMainMenu();
      case FieldMenuTab.partyView:
        return _buildPartyView();
      case FieldMenuTab.characterView:
        return _buildCharacterView();
      case FieldMenuTab.castSpell:
        return _buildCastSpell();
      case FieldMenuTab.rest:
        return _buildRest();
    }
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentTab != FieldMenuTab.main)
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: RetroTheme.blue,
              foregroundColor: RetroTheme.white,
            ),
            onPressed: () => setState(() => _currentTab = FieldMenuTab.main),
            child: Text('◀ 메뉴 목록', style: RetroTheme.dosFont.copyWith(fontSize: 11)),
          )
        else
          const SizedBox.shrink(),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: RetroTheme.darkGray,
            foregroundColor: RetroTheme.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('닫기 (ESC)', style: RetroTheme.dosFont.copyWith(fontSize: 11)),
        ),
      ],
    );
  }

  // =========================================================================
  // 메인 메뉴 선택 (LOREMENU.PAS: SelectMode)
  // =========================================================================
  Widget _buildMainMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '당신의 명령을 고르시오 ===>',
          style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _menuBtn('[P] 일행의 상황을 본다 (View Party)', FieldMenuTab.partyView),
        _menuBtn('[V] 개인의 상황을 본다 (View Character)', FieldMenuTab.characterView),
        _menuBtn('[C] 마법을 사용한다 (Cast Spell)', FieldMenuTab.castSpell),
        _menuBtn('[R] 여기서 쉰다 (Rest)', FieldMenuTab.rest),
      ],
    );
  }

  Widget _menuBtn(String title, FieldMenuTab tab) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: RetroTheme.blue,
          foregroundColor: RetroTheme.white,
          minimumSize: const Size.fromHeight(34),
        ),
        onPressed: () => setState(() => _currentTab = tab),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: RetroTheme.dosFont.copyWith(fontSize: 12)),
        ),
      ),
    );
  }

  // =========================================================================
  // 1. 일행의 상황 (ViewParty)
  // =========================================================================
  Widget _buildPartyView() {
    return Container(
      height: 200,
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
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${idx + 1}. ${p.name}\n(${p.playerClass.koreanName}, Lv.${p.battleLevel})',
                      style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'HP: ${p.hp}/${p.maxHp}\nSP: ${p.sp}/${p.maxSp}',
                      style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightGreen, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '무기: ${p.weaponName}\n방어: ${p.armorName}/${p.shieldName}',
                      style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // 2. 개인의 상황 (ViewCharacter)
  // =========================================================================
  Widget _buildCharacterView() {
    final p = widget.party[_selectedMemberIndex];
    return Column(
      children: [
        // 멤버 선택 탭
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.party.asMap().entries.map((e) {
            final isSel = e.key == _selectedMemberIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ChoiceChip(
                label: Text(e.value.name, style: RetroTheme.dosFont.copyWith(fontSize: 10)),
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
        const SizedBox(height: 8),
        Container(
          height: 160,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: RetroTheme.darkGray),
            color: RetroTheme.background,
          ),
          child: Row(
            children: [
              // 기본 스탯
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('【 기본 능력치 】', style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text('근력(STR): ${p.strength}', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
                    Text('지능(INT): ${p.mentality}', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
                    Text('인내(CON): ${p.endurance}', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
                    Text('민첩(AGI): ${p.agility}', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
                    Text('저항(RES): ${p.resistance}', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
                    Text('행운(LUK): ${p.luck}', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              // 장비 및 전투력
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('【 전투 장비 】', style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text('무기: ${p.weaponName} (+${p.weaPower})', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
                    Text('방패: ${p.shieldName} (+${p.shiPower})', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
                    Text('갑옷: ${p.armorName} (+${p.armPower})', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
                    Text('방어 등급(AC): ${p.ac}', style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightGreen, fontSize: 10)),
                    Text('경험치: ${p.experience}', style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 3. 비전투 마법 시전 (CastSpell)
  // =========================================================================
  Widget _buildCastSpell() {
    final mages = widget.party.where((p) => p.maxSp > 0).toList();
    if (mages.isEmpty) {
      return Center(
        child: Text(
          '일행 중에 마법을 다룰 수 있는 동료가 없습니다.',
          style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightRed, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '【 필드 회복 마법 】 (시전자 선택 후 대상을 치료합니다)',
          style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow, fontSize: 11),
        ),
        const SizedBox(height: 8),
        for (final caster in mages)
          Card(
            color: RetroTheme.black,
            child: ListTile(
              dense: true,
              title: Text(
                '${caster.name} (SP: ${caster.sp}/${caster.maxSp})',
                style: RetroTheme.dosFont.copyWith(color: RetroTheme.white, fontSize: 11),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: caster.sp >= 5 ? RetroTheme.green : RetroTheme.darkGray,
                  foregroundColor: RetroTheme.white,
                ),
                onPressed: caster.sp >= 5
                    ? () => _chooseTargetForHeal(caster)
                    : null,
                child: Text('치료 마법 (5 SP)', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
              ),
            ),
          ),
      ],
    );
  }

  void _chooseTargetForHeal(PartyMember caster) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.black,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          '누구의 상처를 치료하시겠습니까?',
          style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow, fontSize: 12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.party.map((target) {
            return ListTile(
              dense: true,
              title: Text(
                '${target.name} (HP: ${target.hp}/${target.maxHp})',
                style: RetroTheme.dosFont.copyWith(color: RetroTheme.white, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  caster.sp -= 5;
                  target.hp = (target.hp + 25).clamp(0, target.maxHp);
                  if (target.isPoisoned) target.poison = 0;
                });
                widget.onLog('✨ ${caster.name}의 치유 마법으로 ${target.name}의 체력이 25 회복되었습니다!');
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // =========================================================================
  // 4. 야외 캠프 휴식 (Rest)
  // =========================================================================
  Widget _buildRest() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '모닥불을 피우고 휴식을 취하여 일행 전원의 체력과 마력을 회복합니다.',
          style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          '휴식 소모량: 식량 ${widget.party.length * 2} 인분 (현재 보유: $_currentFood 인분)',
          style: RetroTheme.dosFont.copyWith(
            color: _currentFood >= widget.party.length * 2 ? RetroTheme.lightGreen : RetroTheme.lightRed,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentFood >= widget.party.length * 2 ? RetroTheme.blue : RetroTheme.darkGray,
            foregroundColor: RetroTheme.white,
            minimumSize: const Size.fromHeight(36),
          ),
          onPressed: _currentFood >= widget.party.length * 2
              ? () {
                  final neededFood = widget.party.length * 2;
                  setState(() {
                    _currentFood -= neededFood;
                    for (final p in widget.party) {
                      if (!p.isDead) {
                        p.hp = p.maxHp;
                        p.sp = p.maxSp;
                        p.unconscious = 0;
                      }
                    }
                  });
                  widget.onFoodChanged?.call(_currentFood);
                  widget.onLog('⛺ 일행은 야외 캠프에서 편안한 휴식을 취하고 모든 체력과 마력을 완전히 회복했습니다.');
                  Navigator.of(context).pop();
                }
              : null,
          child: Text('지금 휴식하기', style: RetroTheme.dosFont.copyWith(fontSize: 12)),
        ),
      ],
    );
  }
}
