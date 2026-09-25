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
  final void Function({int? torch, int? water, int? swamp, int? levitate})?
  onSpellEffect;
  final void Function(int count)? onMindReadActivated;
  final Map<String, int>? etc;
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
    this.onSpellEffect,
    this.onMindReadActivated,
    this.etc,
    required this.onLog,
  });

  @override
  State<FieldMenuDialog> createState() => _FieldMenuDialogState();
}

enum FieldMenuTab {
  main,
  partyView,
  characterView,
  quickView,
  castSpell,
  esp,
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
    if (_currentTab == FieldMenuTab.partyView) {
      title = '1. 일행의 상황 (VIEW PARTY)';
    } else if (_currentTab == FieldMenuTab.characterView) {
      title = '2. 개인의 상황 (VIEW CHARACTER)';
    } else if (_currentTab == FieldMenuTab.quickView) {
      title = '3. 간이 일행 상황 (QUICK VIEW)';
    } else if (_currentTab == FieldMenuTab.castSpell) {
      title = '4. 비전투 마법 시전 (CAST SPELL)';
    } else if (_currentTab == FieldMenuTab.esp) {
      title = '5. 초감각 기술 (EXTRASENSE / ESP)';
    } else if (_currentTab == FieldMenuTab.rest) {
      title = '6. 야외 캠프 휴식 (REST)';
    } else if (_currentTab == FieldMenuTab.gameOption) {
      title = '7. 게임 저장 및 불러오기 (GAME OPTION)';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: RetroTheme.headerFont.copyWith(
            color: RetroTheme.lightMagenta,
            fontSize: 12,
          ),
        ),
        Text(
          '식량: $_currentFood | 금화: ${widget.gold}',
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
      case FieldMenuTab.main:
        return _buildMainMenu();
      case FieldMenuTab.partyView:
        return _buildPartyView();
      case FieldMenuTab.characterView:
        return _buildCharacterView();
      case FieldMenuTab.quickView:
        return _buildQuickView();
      case FieldMenuTab.castSpell:
        return _buildCastSpell();
      case FieldMenuTab.esp:
        return _buildEspView();
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
            child: Text(
              '◀ 메뉴 목록',
              style: RetroTheme.dosFont.copyWith(fontSize: 11),
            ),
          )
        else
          const SizedBox.shrink(),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: RetroTheme.darkGray,
            foregroundColor: RetroTheme.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '닫기 (ESC)',
            style: RetroTheme.dosFont.copyWith(fontSize: 11),
          ),
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
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        _menuBtn('[P] 일행의 상황을 본다 (View Party)', FieldMenuTab.partyView),
        _menuBtn('[V] 개인의 상황을 본다 (View Character)', FieldMenuTab.characterView),
        _menuBtn('[Q] 간이 일행 상황을 본다 (Quick View)', FieldMenuTab.quickView),
        _menuBtn('[C] 마법을 사용한다 (Cast Spell)', FieldMenuTab.castSpell),
        _menuBtn('[E] 초감각 기술을 쓴다 (Extrasense / ESP)', FieldMenuTab.esp),
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
                      '무기: ${p.weaponName}\n방어: ${p.armorName}/${p.shieldName}',
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
                    Text(
                      '【 기본 능력치 】',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.yellow,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '근력(STR): ${p.strength}',
                      style: RetroTheme.dosFont.copyWith(fontSize: 10),
                    ),
                    Text(
                      '지능(INT): ${p.mentality}',
                      style: RetroTheme.dosFont.copyWith(fontSize: 10),
                    ),
                    Text(
                      '인내(CON): ${p.endurance}',
                      style: RetroTheme.dosFont.copyWith(fontSize: 10),
                    ),
                    Text(
                      '민첩(AGI): ${p.agility}',
                      style: RetroTheme.dosFont.copyWith(fontSize: 10),
                    ),
                    Text(
                      '저항(RES): ${p.resistance}',
                      style: RetroTheme.dosFont.copyWith(fontSize: 10),
                    ),
                    Text(
                      '행운(LUK): ${p.luck}',
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
                    Text(
                      '【 전투 장비 】',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.yellow,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '무기: ${p.weaponName} (+${p.weaPower})',
                      style: RetroTheme.dosFont.copyWith(fontSize: 10),
                    ),
                    Text(
                      '방패: ${p.shieldName} (+${p.shiPower})',
                      style: RetroTheme.dosFont.copyWith(fontSize: 10),
                    ),
                    Text(
                      '갑옷: ${p.armorName} (+${p.armPower})',
                      style: RetroTheme.dosFont.copyWith(fontSize: 10),
                    ),
                    Text(
                      '방어 등급(AC): ${p.ac}',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.lightGreen,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '경험치: ${p.experience}',
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
                    '이름',
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
                    '중독',
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.lightRed,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '기절',
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.lightRed,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '사망',
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
  // 4. 비전투 마법 시전 (CastSpell)
  // =========================================================================
  Widget _buildCastSpell() {
    final mages = widget.party.where((p) => p.maxSp > 0).toList();
    if (mages.isEmpty) {
      return Center(
        child: Text(
          '일행 중에 마법을 다룰 수 있는 동료가 없습니다.',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightRed,
            fontSize: 12,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            '【 1. 필드 회복 마법 】 (LOREMENU.PAS: CureSpell)',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.yellow,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          for (final caster in mages)
            Card(
              color: RetroTheme.black,
              margin: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${caster.name} (SP: ${caster.sp}/${caster.maxSp})',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.white,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: caster.sp >= 5
                                ? RetroTheme.green
                                : RetroTheme.darkGray,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(80, 26),
                          ),
                          onPressed: caster.sp >= 5
                              ? () => _chooseTargetForHeal(
                                  caster,
                                  isCurePoison: false,
                                )
                              : null,
                          child: Text(
                            '한명 치료 (5 SP)',
                            style: RetroTheme.dosFont.copyWith(fontSize: 9),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: caster.sp >= 8
                                ? RetroTheme.green
                                : RetroTheme.darkGray,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(80, 26),
                          ),
                          onPressed: caster.sp >= 8
                              ? () => _chooseTargetForHeal(
                                  caster,
                                  isCurePoison: true,
                                )
                              : null,
                          child: Text(
                            '한명 독제거 (8 SP)',
                            style: RetroTheme.dosFont.copyWith(fontSize: 9),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: caster.sp >= 20
                                ? RetroTheme.green
                                : RetroTheme.darkGray,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(80, 26),
                          ),
                          onPressed: caster.sp >= 20
                              ? () {
                                  setState(() {
                                    caster.sp -= 20;
                                    for (final p in widget.party) {
                                      if (!p.isDead) {
                                        p.hp = (p.hp + 30).clamp(0, p.maxHp);
                                        p.poison = 0;
                                      }
                                    }
                                  });
                                  widget.onLog(
                                    '✨ ${caster.name}의 전체 치료 마법으로 파티 전원의 체력이 회복되고 독이 정화되었습니다!',
                                  );
                                }
                              : null,
                          child: Text(
                            '전체 치료 (20 SP)',
                            style: RetroTheme.dosFont.copyWith(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),
          Text(
            '【 2. 현상계 보조 마법 】 (LOREMENU.PAS: PhenominaSpell)',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.lightCyan,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          for (final caster in mages)
            Card(
              color: RetroTheme.black,
              margin: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: caster.sp >= 1
                            ? RetroTheme.blue
                            : RetroTheme.darkGray,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(84, 26),
                      ),
                      onPressed: caster.sp >= 1
                          ? () {
                              setState(() => caster.sp -= 1);
                              widget.onSpellEffect?.call(torch: 255);
                              widget.onLog(
                                '🔥 ${caster.name}이(가) [마법의 횃불]을 밝혔습니다. 던전 시야가 확장됩니다.',
                              );
                            }
                          : null,
                      child: Text(
                        '마법 횃불 (1 SP)',
                        style: RetroTheme.dosFont.copyWith(fontSize: 9),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: caster.sp >= 5
                            ? RetroTheme.blue
                            : RetroTheme.darkGray,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(84, 26),
                      ),
                      onPressed: caster.sp >= 5
                          ? () {
                              setState(() => caster.sp -= 5);
                              widget.onSpellEffect?.call(levitate: 255);
                              widget.onLog(
                                '✨ ${caster.name}이(가) [공중 부상] 마법을 시전했습니다. 용암 위를 안전하게 이동합니다.',
                              );
                            }
                          : null,
                      child: Text(
                        '공중 부상 (5 SP)',
                        style: RetroTheme.dosFont.copyWith(fontSize: 9),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: caster.sp >= 10
                            ? RetroTheme.blue
                            : RetroTheme.darkGray,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(84, 26),
                      ),
                      onPressed: caster.sp >= 10
                          ? () {
                              setState(() => caster.sp -= 10);
                              widget.onSpellEffect?.call(water: 255);
                              widget.onLog(
                                '🌊 ${caster.name}이(가) [물위를 걸음] 마법을 시전했습니다. 깊은 물 위를 걸을 수 있습니다.',
                              );
                            }
                          : null,
                      child: Text(
                        '물위 걸음 (10 SP)',
                        style: RetroTheme.dosFont.copyWith(fontSize: 9),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: caster.sp >= 10
                            ? RetroTheme.blue
                            : RetroTheme.darkGray,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(84, 26),
                      ),
                      onPressed: caster.sp >= 10
                          ? () {
                              setState(() => caster.sp -= 10);
                              widget.onSpellEffect?.call(swamp: 255);
                              widget.onLog(
                                '🌿 ${caster.name}이(가) [늪위를 걸음] 마법을 시전했습니다. 독 늪지대 피해가 면제됩니다.',
                              );
                            }
                          : null,
                      child: Text(
                        '늪위 걸음 (10 SP)',
                        style: RetroTheme.dosFont.copyWith(fontSize: 9),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: caster.sp >= 15
                            ? RetroTheme.blue
                            : RetroTheme.darkGray,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(84, 26),
                      ),
                      onPressed: caster.sp >= 15
                          ? () {
                              setState(() {
                                caster.sp -= 15;
                                _currentFood = (_currentFood + 50).clamp(
                                  0,
                                  255,
                                );
                              });
                              widget.onFoodChanged?.call(_currentFood);
                              widget.onLog(
                                '🍞 ${caster.name}이(가) [식량 제조] 마법으로 50인분의 식량을 생성했습니다! (현재: $_currentFood)',
                              );
                            }
                          : null,
                      child: Text(
                        '식량 제조 (15 SP)',
                        style: RetroTheme.dosFont.copyWith(fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _chooseTargetForHeal(PartyMember caster, {required bool isCurePoison}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.black,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          isCurePoison ? '누구의 독을 정화하시겠습니까?' : '누구의 상처를 치료하시겠습니까?',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.party.map((target) {
            return ListTile(
              dense: true,
              title: Text(
                '${target.name} (HP: ${target.hp}/${target.maxHp}, ${target.isPoisoned ? "중독" : "정상"})',
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.white,
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  if (isCurePoison) {
                    caster.sp -= 8;
                    target.poison = 0;
                  } else {
                    caster.sp -= 5;
                    target.hp = (target.hp + 25).clamp(0, target.maxHp);
                  }
                });
                widget.onLog(
                  isCurePoison
                      ? '🌿 ${caster.name}의 해독 마법으로 ${target.name}의 몸에서 독이 완전히 정화되었습니다!'
                      : '✨ ${caster.name}의 치유 마법으로 ${target.name}의 체력이 25 회복되었습니다!',
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // =========================================================================
  // 5. 초감각 기술 (LOREMENU.PAS: Extrasense / ESP)
  // =========================================================================
  int _espMemberIdx = 0;
  String? _espResultText;

  Widget _buildEspView() {
    final member = widget.party[_espMemberIdx];
    final hasEsp =
        member.esp > 0 ||
        member.playerClass == PlayerClass.mage ||
        member.playerClass == PlayerClass.monk ||
        member.playerClass == PlayerClass.esper ||
        member.playerClass == PlayerClass.vagrant;

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView(
        shrinkWrap: true,
        children: [
          Row(
            children: widget.party.asMap().entries.map((e) {
              final isSel = e.key == _espMemberIdx;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(
                    '${e.value.name} (ESP:${e.value.esp})',
                    style: RetroTheme.dosFont.copyWith(
                      fontSize: 10,
                      color: isSel ? RetroTheme.black : RetroTheme.white,
                    ),
                  ),
                  selected: isSel,
                  selectedColor: RetroTheme.yellow,
                  backgroundColor: RetroTheme.darkBlue,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _espMemberIdx = e.key;
                        _espResultText = null;
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          if (!hasEsp)
            Text(
              '${member.name}에게는 아직 초감각 능력이 없습니다.',
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.lightRed,
                fontSize: 11,
              ),
            )
          else ...[
            _espActionBtn(
              '[1] 투시 (Clairvoyance) - 10 ESP',
              member.esp >= 10,
              () {
                setState(() {
                  member.esp -= 10;
                  _espResultText = '✨ 일행은 마법의 혜안으로 주변 지형과 숨겨진 통로를 꿰뚫어 보고 있습니다.';
                });
                widget.onLog('👁 [투시] ${member.name}이(가) 초감각으로 주변 지형을 투시했습니다.');
              },
            ),
            _espActionBtn('[2] 미래 예언 (Prophecy) - 5 ESP', member.esp >= 5, () {
              final prop = LoreDialogueManager.instance.getProphecy();
              setState(() {
                member.esp -= 5;
                _espResultText = '🔮 당신은 당신의 미래를 예언한다 ...\n\n"$prop"';
              });
              widget.onLog('🔮 [예언] $prop');
            }),
            _espActionBtn('[3] 독심술 (Telepathy) - 20 ESP', member.esp >= 20, () {
              setState(() {
                member.esp -= 20;
                _espResultText = '🧠 다른 사람의 숨겨진 마음을 읽을 수 있는 영적 능력이 3회 부여되었습니다.';
              });
              widget.onMindReadActivated?.call(3);
              widget.onLog(
                '🧠 [독심술] ${member.name}이(가) 타인의 마음을 읽는 능력을 활성화했습니다.',
              );
            }),
            _espActionBtn('[4] 천리안 (Scrying) - 10 ESP', member.esp >= 10, () {
              setState(() {
                member.esp -= 10;
                _espResultText = '🔭 천리안의 눈으로 전방 원거리 지형을 정찰했습니다.';
              });
              widget.onLog('🔭 [천리안] ${member.name}이(가) 전방 지형을 정찰했습니다.');
            }),
          ],
          if (_espResultText != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              color: RetroTheme.darkBlue,
              child: Text(
                _espResultText!,
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.yellow,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _espActionBtn(String title, bool enabled, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? RetroTheme.blue : RetroTheme.darkGray,
          foregroundColor: RetroTheme.white,
          minimumSize: const Size.fromHeight(30),
        ),
        onPressed: enabled ? onTap : null,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: RetroTheme.dosFont.copyWith(fontSize: 10)),
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
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightCyan,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '휴식 소모량: 식량 ${widget.party.length * 2} 인분 (현재 보유: $_currentFood 인분)',
          style: RetroTheme.dosFont.copyWith(
            color: _currentFood >= widget.party.length * 2
                ? RetroTheme.lightGreen
                : RetroTheme.lightRed,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentFood >= widget.party.length * 2
                ? RetroTheme.blue
                : RetroTheme.darkGray,
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
                  widget.onLog(
                    '⛺ 일행은 야외 캠프에서 편안한 휴식을 취하고 모든 체력과 마력을 완전히 회복했습니다.',
                  );
                  Navigator.of(context).pop();
                }
              : null,
          child: Text(
            '지금 휴식하기',
            style: RetroTheme.dosFont.copyWith(fontSize: 12),
          ),
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
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
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
                color: slotData != null
                    ? RetroTheme.lightCyan
                    : RetroTheme.darkGray,
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
                          color: slotData != null
                              ? RetroTheme.yellow
                              : RetroTheme.lightGray,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 26),
                      ),
                      onPressed: () async {
                        final mapTitle =
                            LoreWorldManager
                                .mapRegistry[widget.currentMapId]
                                ?.title ??
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
                          etc: widget.etc ?? {},
                        );
                        await SaveManager.instance.saveGame(newSave);
                        widget.onLog(
                          '💾 [슬롯 $slotNum: $slotTitle] 에 현재 모험 데이터를 저장했습니다.',
                        );
                        await _loadSlots();
                      },
                      child: Text(
                        '저장',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: slotData != null
                            ? RetroTheme.green
                            : RetroTheme.darkGray,
                        foregroundColor: RetroTheme.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 26),
                      ),
                      onPressed: slotData == null
                          ? null
                          : () {
                              LoreDialogueManager.instance.loadFlags(
                                slotData.flags,
                              );
                              widget.onSaveDataLoaded?.call(slotData);
                              Navigator.of(context).pop();
                            },
                      child: Text(
                        '불러오기',
                        style: RetroTheme.dosFont.copyWith(fontSize: 10),
                      ),
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
