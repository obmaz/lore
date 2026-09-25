import 'package:flutter/material.dart';
import '../theme/retro_theme.dart';
import '../models/party_member.dart';
import '../services/save_manager.dart';
import '../game/lore_world_manager.dart';
import '../game/lore_dialogue_manager.dart';

/// 1993년 원작 LOREMENU.PAS 기반 스페이스바 필드 시스템 메뉴 (SelectMode)
class FieldMenuDialog extends StatefulWidget {
  final List<PartyMember> party;
  final int gold;
  final int food;
  final int currentMapId;
  final int playerX;
  final int playerY;
  final void Function(int newFood)? onFoodChanged;
  final void Function(SaveData loadedData)? onSaveDataLoaded;
  final void Function(String message) onLog;

  const FieldMenuDialog({
    super.key,
    required this.party,
    required this.gold,
    required this.food,
    this.currentMapId = 6,
    this.playerX = 51,
    this.playerY = 31,
    this.onFoodChanged,
    this.onSaveDataLoaded,
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
  gameOption,
}

class _FieldMenuDialogState extends State<FieldMenuDialog> {
  FieldMenuTab _currentTab = FieldMenuTab.main;
  int _selectedMemberIndex = 0;
  late int _currentFood;
  List<SaveData?>? _slots;
  bool _isLoadingSlots = false;

  @override
  void initState() {
    super.initState();
    _currentFood = widget.food;
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() => _isLoadingSlots = true);
    try {
      final slots = await SaveManager.instance.getAllSlots();
      if (mounted) {
        setState(() {
          _slots = slots;
          _isLoadingSlots = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSlots = false);
      }
    }
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
    if (_currentTab == FieldMenuTab.gameOption) title = '5. 게임 저장 및 불러오기 (GAME OPTION)';

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
      case FieldMenuTab.gameOption:
        return _buildGameOption();
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
        _menuBtn('[G] 게임 저장 / 불러오기 (Game Option)', FieldMenuTab.gameOption),
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

  // =========================================================================
  // 5. 게임 저장 및 불러오기 (LOREMENU.PAS: GameOption)
  // =========================================================================
  Widget _buildGameOption() {
    if (_isLoadingSlots || _slots == null) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        child: Text(
          '슬롯 정보를 확인하는 중입니다...',
          style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow, fontSize: 12),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: 4,
        itemBuilder: (context, index) {
          final slotNum = index + 1;
          final slotData = _slots![index];
          final slotTitle = SaveManager.slotNames[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                color: slotData != null ? RetroTheme.lightCyan : RetroTheme.darkGray,
                width: 1,
              ),
              color: RetroTheme.background,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '슬롯 $slotNum. $slotTitle',
                        style: RetroTheme.headerFont.copyWith(
                          color: slotData != null ? RetroTheme.yellow : RetroTheme.lightGray,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (slotData == null)
                        Text(
                          '-- [ 비어 있는 슬롯 (EMPTY) ] --',
                          style: RetroTheme.dosFont.copyWith(
                            color: RetroTheme.darkGray,
                            fontSize: 10,
                          ),
                        )
                      else ...[
                        Text(
                          '위치: ${slotData.mapTitle} (${slotData.playerX}, ${slotData.playerY})',
                          style: RetroTheme.dosFont.copyWith(
                            color: RetroTheme.lightGreen,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '일시: ${slotData.timestamp.toLocal().toString().substring(0, 16)} | 금화: ${slotData.gold} | 식량: ${slotData.food}',
                          style: RetroTheme.dosFont.copyWith(
                            color: RetroTheme.lightCyan,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          '일행: ${slotData.party.map((p) => p.name).join(', ')}',
                          style: RetroTheme.dosFont.copyWith(
                            color: RetroTheme.white,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RetroTheme.blue,
                        foregroundColor: RetroTheme.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(60, 26),
                      ),
                      onPressed: () async {
                        final mapTitle = LoreWorldManager.mapRegistry[widget.currentMapId]?.title ??
                            '지도 ${widget.currentMapId}';
                        final newSave = SaveData(
                          slot: slotNum,
                          slotName: slotTitle,
                          timestamp: DateTime.now(),
                          mapId: widget.currentMapId,
                          mapTitle: mapTitle,
                          playerX: widget.playerX,
                          playerY: widget.playerY,
                          gold: widget.gold,
                          food: _currentFood,
                          party: widget.party,
                          flags: LoreDialogueManager.instance.getFlagsCopy(),
                        );
                        await SaveManager.instance.saveGame(newSave);
                        widget.onLog('💾 [슬롯 $slotNum: $slotTitle] 에 현재 모험 데이터를 저장했습니다.');
                        await _loadSlots();
                      },
                      child: Text('저장', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: slotData != null ? RetroTheme.green : RetroTheme.darkGray,
                        foregroundColor: RetroTheme.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(60, 26),
                      ),
                      onPressed: slotData == null
                          ? null
                          : () {
                              LoreDialogueManager.instance.loadFlags(slotData.flags);
                              widget.onSaveDataLoaded?.call(slotData);
                              Navigator.of(context).pop();
                            },
                      child: Text('불러오기', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
