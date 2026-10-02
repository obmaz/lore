import 'package:flutter/material.dart';

import '../logic/lore_menu_text.dart';
import 'quick_view_dialog.dart';
import '../theme/retro_theme.dart';
import '../models/party_member.dart';
import '../services/save_manager.dart';
import '../game/lore_world_manager.dart';
import '../game/lore_dialogue_manager.dart';
import '../logic/field_magic_logic.dart';
import '../logic/town_logic.dart';
import '../data/lore_script.dart';

/// 1993년 원작 LOREMENU.PAS 기반 스페이스바 필드 시스템 메뉴 (SelectMode)
class FieldMenuDialog extends StatefulWidget {
  final List<PartyMember> party;
  final int gold;
  final int food;
  final int currentMapId;
  final int playerX;
  final int playerY;
  final void Function(int newFood)? onFoodChanged;
  final Future<void> Function(SaveData loadedData)? onSaveDataLoaded;
  final void Function({int? torch, int? water, int? swamp, int? levitate})?
  onSpellEffect;

  /// 현재 맵의 크기 (원작 `xmax`,`ymax`) - 기화/공간 이동 판정용.
  final (int, int)? mapSize;

  /// (x, y)의 타일 값 (원작 `map[x,y]`).
  final int? Function(int x, int y)? tileAt;

  /// 파티를 (x, y)로 이동시킨다 (원작 `x := ..; y := ..`).
  final void Function(int x, int y)? onMoveTo;

  /// (x, y) 타일을 바꾼다 (원작 `map[x+dx,y+dy] := k`).
  final void Function(int x, int y, int tile)? onTerrainChange;
  final void Function(int count)? onMindReadActivated;
  final void Function(int frequency, int maxEnemies)?
  onEncounterSettingsChanged;
  final List<int> Function()? mapTilesProvider;
  final List<String> Function()? consumedScriptsProvider;
  final Map<String, int>? etc;
  final Map<String, int> Function()? etcProvider;
  final void Function(String message) onLog;

  /// 원작 핫키(P/V/C/R/G)로 진입할 때 바로 열 탭.
  final FieldMenuTab initialTab;

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
    this.mapSize,
    this.tileAt,
    this.onMoveTo,
    this.onTerrainChange,
    this.onMindReadActivated,
    this.onEncounterSettingsChanged,
    this.mapTilesProvider,
    this.consumedScriptsProvider,
    this.etc,
    this.etcProvider,
    this.initialTab = FieldMenuTab.main,
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
  late int _encounterFrequency;
  late int _maxEnemies;
  List<SaveData?>? _slots;
  bool _isLoadingSlots = false;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _currentFood = widget.food;
    _encounterFrequency = widget.etc?['encounterFrequency'] ?? 2;
    _maxEnemies = widget.etc?['maxEnemies'] ?? 5;
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
      backgroundColor: RetroTheme.panelBg,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.borderColor, width: 2),
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
    final title = switch (_currentTab) {
      FieldMenuTab.main => LoreMenuText.selectModePrompt,
      FieldMenuTab.partyView => LoreMenuText.selectModeParty,
      FieldMenuTab.characterView => LoreMenuText.viewCharWho,
      FieldMenuTab.quickView => LoreMenuText.selectModeQuick,
      FieldMenuTab.castSpell => LoreMenuText.castSpellKind,
      FieldMenuTab.esp => LoreMenuText.espKind,
      FieldMenuTab.rest => LoreMenuText.selectModeRest,
      FieldMenuTab.gameOption => LoreMenuText.optionTitle,
    };
    if (_currentTab == FieldMenuTab.main ||
        _currentTab == FieldMenuTab.castSpell) {
      return const SizedBox.shrink();
    }
    return Text(
      title,
      style: RetroTheme.dosFont.copyWith(color: RetroTheme.white, fontSize: 12),
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
            child: Text('메뉴', style: RetroTheme.dosFont.copyWith(fontSize: 11)),
          )
        else
          const SizedBox.shrink(),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: RetroTheme.darkGray,
            foregroundColor: RetroTheme.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('닫기', style: RetroTheme.dosFont.copyWith(fontSize: 11)),
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
          LoreMenuText.selectModePrompt,
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        // 원작 LOREMENU.PAS:1033 SelectMode 의 7개 항목
        _menuBtn(LoreMenuText.selectModeParty, FieldMenuTab.partyView),
        _menuBtn(LoreMenuText.selectModeCharacter, FieldMenuTab.characterView),
        _menuBtn(LoreMenuText.selectModeQuick, FieldMenuTab.quickView),
        _menuBtn(LoreMenuText.selectModeCast, FieldMenuTab.castSpell),
        _menuBtn(LoreMenuText.selectModeEsp, FieldMenuTab.esp),
        _menuBtn(LoreMenuText.selectModeRest, FieldMenuTab.rest),
        _menuBtn(LoreMenuText.selectModeOption, FieldMenuTab.gameOption),
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
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => setState(() => _currentTab = tab),
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: RetroTheme.dosFont.copyWith(fontSize: 12),
        ),
      ),
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
        ),
      ],
    );
  }

  // =========================================================================
  // 3. 간이 일행 상황 (LOREMENU.PAS: QuickView)
  // =========================================================================
  Widget _buildQuickView() =>
      SizedBox(height: 260, child: QuickStatusTable(party: widget.party));

  // =========================================================================
  // =========================================================================
  // 4. 비전투 마법 시전 (LOREMENU.PAS: CastSpell / CureSpell / PhenominaSpell)
  // =========================================================================
  Widget _buildCastSpell() {
    final mages = widget.party
        .where((p) => p.name.isNotEmpty && p.maxSp > 0)
        .toList();
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
            LoreMenuText.castSpellKind,
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
                      caster.name,
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
                        _spellBtn(
                          '1. 공격 마법',
                          RetroTheme.darkGray,
                          () =>
                              widget.onLog(FieldMagicLogic.attackSpellMessage),
                        ),
                        _spellBtn(
                          '2. 치료 마법',
                          RetroTheme.green,
                          () => _castCureSpell(caster),
                        ),
                        _spellBtn(
                          '3. 변화 마법',
                          RetroTheme.blue,
                          () => _castPhenominaSpell(caster),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _spellBtn(String title, Color color, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(96, 26),
      ),
      onPressed: onTap,
      child: Text(title, style: RetroTheme.dosFont.copyWith(fontSize: 9)),
    );
  }

  /// 원작 `exist(person)` 판정 - 이름이 있고 기절/사망/HP 0이 아닌 상태.
  bool _canCast(PartyMember m) =>
      m.name.isNotEmpty && !m.isUnconscious && !m.isDead && m.hp > 0;

  /// 현재 맵의 원작 `position` 값 (town/ground/den/keep).
  String get _position {
    final cat = LoreWorldManager.mapRegistry[widget.currentMapId]?.category;
    switch (cat) {
      case MapCategory.town:
        return 'town';
      case MapCategory.ground:
        return 'ground';
      case MapCategory.den:
        return 'den';
      case MapCategory.keep:
        return 'keep';
      default:
        return 'town';
    }
  }

  int _tileAt(int x, int y) => widget.tileAt?.call(x, y) ?? 0;

  // ------------------------------------------------------------------
  // 치료 마법 (원작 CureSpell: 대상 → 개인 7종 / 전체 7종)
  // ------------------------------------------------------------------
  void _castCureSpell(PartyMember caster) {
    if (!_canCast(caster)) {
      widget.onLog(
        '${caster.sex == Gender.female ? '그녀' : '그'}는 마법을 사용할수있는 상태가 아닙니다',
      );
      return;
    }
    final members = widget.party.where((p) => p.name.isNotEmpty).toList();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.panelBg,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          '누구에게',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final target in members)
              ListTile(
                dense: true,
                title: Text(
                  '${target.name} (HP ${target.hp}/${target.maxHp} · SP ${target.sp}/${target.maxSp})',
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.white,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _choosePersonalCure(caster, target);
                },
              ),
            ListTile(
              dense: true,
              title: Text(
                '모든 사람들에게',
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.lightCyan,
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _chooseGroupCure(caster);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _choosePersonalCure(PartyMember caster, PartyMember target) {
    final slots = FieldMagicLogic.personalCureSlots(caster.magicLevel);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.panelBg,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          '선택',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < slots; i++)
              ListTile(
                dense: true,
                title: Text(
                  FieldMagicLogic.cureSpellNames[i],
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.white,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  final result = FieldMagicLogic.castPersonalCure(
                    caster,
                    target,
                    i + 1,
                  );
                  setState(() {});
                  for (final msg in result.messages) {
                    widget.onLog(msg);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _chooseGroupCure(PartyMember caster) {
    final slots = FieldMagicLogic.groupCureSlots(caster.magicLevel);
    if (slots <= 0) {
      widget.onLog(FieldMagicLogic.strongCureNotReady(caster.name));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.panelBg,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          '선택',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < slots; i++)
              ListTile(
                dense: true,
                title: Text(
                  FieldMagicLogic.cureAllSpellNames[i],
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.white,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  final result = FieldMagicLogic.castGroupCure(
                    caster,
                    widget.party,
                    i + 1,
                  );
                  setState(() {});
                  for (final msg in result.messages) {
                    widget.onLog(msg);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 변화 마법 (원작 PhenominaSpell 8종)
  // ------------------------------------------------------------------
  void _castPhenominaSpell(PartyMember caster) {
    if (!_canCast(caster)) {
      widget.onLog(
        '${caster.sex == Gender.female ? '그녀' : '그'}는 마법을 사용할수있는 상태가 아닙니다',
      );
      return;
    }
    if (FieldMagicLogic.isPhenominaBlocked(widget.currentMapId)) {
      widget.onLog(FieldMagicLogic.phenominaBlockedMessage);
      return;
    }
    final slots = FieldMagicLogic.phenominaSlots(caster.magicLevel);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.panelBg,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          '선택',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < slots; i++)
              ListTile(
                dense: true,
                title: Text(
                  '${FieldMagicLogic.phenominaSpellNames[i]} (${FieldMagicLogic.phenominaSpCosts[i]} SP)',
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.white,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _applyPhenomina(caster, i + 1);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _applyPhenomina(PartyMember caster, int index) {
    MagicCastResult result;
    switch (index) {
      case 1:
        result = FieldMagicLogic.torch(caster);
        if (result.success) widget.onSpellEffect?.call(torch: 255);
        break;
      case 2:
        result = FieldMagicLogic.levitate(caster);
        if (result.success) widget.onSpellEffect?.call(levitate: 255);
        break;
      case 3:
        result = FieldMagicLogic.waterWalk(caster);
        if (result.success) widget.onSpellEffect?.call(water: 255);
        break;
      case 4:
        result = FieldMagicLogic.swampWalk(caster);
        if (result.success) widget.onSpellEffect?.call(swamp: 255);
        break;
      case 5:
        _chooseDirection('기화 이동', (dx, dy, label) {
          final moved = _applyVaporize(caster, dx, dy);
          if (moved == null) {
            widget.onLog(FieldMagicLogic.vaporizeNotAllowedMessage);
          }
        });
        return;
      case 6:
        _chooseDirection('지형 변화', (dx, dy, label) {
          _applyTerrainChange(caster, dx, dy);
        });
        return;
      case 7:
        _chooseDirection('공간 이동', (dx, dy, label) {
          _chooseDistance(caster, dx, dy);
        });
        return;
      case 8:
        result = FieldMagicLogic.createFood(caster, widget.party, _currentFood);
        if (result.success) {
          final members = widget.party.where((p) => p.name.isNotEmpty).length;
          _currentFood = (_currentFood + members).clamp(0, 255);
          widget.onFoodChanged?.call(_currentFood);
        }
        break;
      default:
        return;
    }
    setState(() {});
    for (final msg in result.messages) {
      widget.onLog(msg);
    }
  }

  /// 원작 방향 선택(`m[1..4]` = 북/남/동/서).
  void _chooseDirection(
    String label,
    void Function(int dx, int dy, String label) onPicked,
  ) {
    const dirs = [('북쪽', 0, -1), ('남쪽', 0, 1), ('동쪽', 1, 0), ('서쪽', -1, 0)];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.panelBg,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          LoreMenuText.espDirection,
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (name, dx, dy) in dirs)
              ListTile(
                dense: true,
                title: Text(
                  name,
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.white,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onPicked(dx, dy, name);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 원작 공간 이동은 1~9칸 거리를 입력받는다.
  void _chooseDistance(PartyMember caster, int dx, int dy) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.panelBg,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          LoreMenuText.phenominaPowerPrompt,
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var k = 1; k <= 9; k++)
              ListTile(
                dense: true,
                title: Text(
                  '$k 칸',
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.white,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _applySpaceMove(caster, dx, dy, k);
                },
              ),
          ],
        ),
      ),
    );
  }

  (int, int)? _applyVaporize(PartyMember caster, int dx, int dy) {
    if (!_canCast(caster)) return null;
    final map = widget.mapSize;
    if (map == null) return null;
    final target = FieldMagicLogic.vaporizeTarget(
      widget.playerX,
      widget.playerY,
      dx,
      dy,
      map.$1,
      map.$2,
    );
    if (target == null) return null;
    if (caster.sp < FieldMagicLogic.vaporizeMoveSpCost) {
      widget.onLog(FieldMagicLogic.spNotEnoughMessage);
      return null;
    }
    final (tx, ty) = target;
    if (!FieldMagicLogic.vaporizeTileAllowed(_position, _tileAt(tx, ty))) {
      widget.onLog(FieldMagicLogic.vaporizeNotAllowedMessage);
      return null;
    }
    caster.sp -= FieldMagicLogic.vaporizeMoveSpCost;
    // 원작: 도착 지점 뒤 타일이 0이거나 던전 벽(52)이면 마법이 배척된다.
    final behind = _tileAt(widget.playerX + dx, widget.playerY + dy);
    if (behind == 0 || (['den', 'keep'].contains(_position) && behind == 52)) {
      widget.onLog(FieldMagicLogic.magicRejectedMessage);
      return null;
    }
    widget.onMoveTo?.call(tx, ty);
    setState(() {});
    widget.onLog(FieldMagicLogic.vaporizeDoneMessage);
    return (tx, ty);
  }

  void _applyTerrainChange(PartyMember caster, int dx, int dy) {
    if (!_canCast(caster)) return;
    if (!['town', 'ground', 'den', 'keep'].contains(_position)) return;
    if (caster.sp < FieldMagicLogic.terrainChangeSpCost) {
      widget.onLog(FieldMagicLogic.spNotEnoughMessage);
      return;
    }
    final tx = widget.playerX + dx;
    final ty = widget.playerY + dy;
    final tile = _tileAt(tx, ty);
    if (tile == 0 || (['den', 'keep'].contains(_position) && tile == 52)) {
      widget.onLog(FieldMagicLogic.magicRejectedMessage);
      return;
    }
    caster.sp -= FieldMagicLogic.terrainChangeSpCost;
    final newTile = FieldMagicLogic.terrainChangeTile(_position);
    widget.onTerrainChange?.call(tx, ty, newTile);
    setState(() {});
    widget.onLog(FieldMagicLogic.terrainChangedMessage);
  }

  void _applySpaceMove(PartyMember caster, int dx, int dy, int distance) {
    if (!_canCast(caster)) return;
    final map = widget.mapSize;
    if (map == null) return;
    final target = FieldMagicLogic.spaceMoveTarget(
      widget.playerX,
      widget.playerY,
      dx,
      dy,
      distance,
      map.$1,
      map.$2,
    );
    if (target == null) {
      widget.onLog(FieldMagicLogic.spaceMoveNotAllowedMessage);
      return;
    }
    if (caster.sp < FieldMagicLogic.spaceMoveSpCost) {
      widget.onLog(FieldMagicLogic.spNotEnoughMessage);
      return;
    }
    final (tx, ty) = target;
    if (!FieldMagicLogic.spaceMoveTileAllowed(_position, _tileAt(tx, ty))) {
      widget.onLog(FieldMagicLogic.spaceMoveBadSpotMessage);
      return;
    }
    caster.sp -= FieldMagicLogic.spaceMoveSpCost;
    final ahead = _tileAt(tx + dx, ty + dy);
    if (ahead == 0 || (['den', 'keep'].contains(_position) && ahead == 52)) {
      widget.onLog(FieldMagicLogic.spaceMoveRejectedMessage);
      return;
    }
    widget.onMoveTo?.call(tx, ty);
    setState(() {});
    widget.onLog(FieldMagicLogic.spaceMoveDoneMessage);
  }

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
                    e.value.name,
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
              LoreMenuText.espNoAbility,
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.lightRed,
                fontSize: 11,
              ),
            )
          else ...[
            _espActionBtn('투시', member.esp >= 10, () {
              setState(() {
                member.esp -= 10;
                _espResultText = LoreMenuText.espSeeThrough;
              });
              widget.onLog(LoreMenuText.espSeeThrough);
            }),
            _espActionBtn('예언', member.esp >= 5, () {
              final prop = LoreDialogueManager.instance.getProphecy();
              setState(() {
                member.esp -= 5;
                _espResultText = prop;
              });
              widget.onLog(prop);
            }),
            _espActionBtn('독심', member.esp >= 20, () {
              setState(() {
                member.esp -= 20;
                _espResultText = LoreMenuText.espMindRead;
              });
              widget.onMindReadActivated?.call(3);
              widget.onLog(LoreMenuText.espMindRead);
            }),
            _espActionBtn('천리안', member.esp >= 10, () {
              setState(() {
                member.esp -= 10;
                _espResultText = LoreMenuText.espClairvoyanceBusy;
              });
              widget.onLog(LoreMenuText.espClairvoyanceBusy);
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
  // 4. 여기서 쉰다 (원작 LOREMENU.PAS:869 Rest)
  // =========================================================================
  Widget _buildRest() {
    final torchSteps = widget.etc?['torchSteps'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: RetroTheme.blue,
            foregroundColor: RetroTheme.white,
            minimumSize: const Size.fromHeight(36),
          ),
          onPressed: () {
            final outcome = TownLogic.rest(
              widget.party,
              _currentFood,
              torchSteps: torchSteps,
            );
            setState(() => _currentFood = outcome.food);
            widget.onFoodChanged?.call(_currentFood);
            // 현상계 지속 마법 해제 (원작 party.etc[1..4] 처리)
            widget.onSpellEffect?.call(
              torch: outcome.torchSteps,
              water: 0,
              swamp: 0,
              levitate: 0,
            );
            for (final l in outcome.logs) {
              widget.onLog(l);
            }
            Navigator.of(context).pop();
          },
          child: Text(
            LoreMenuText.selectModeRest,
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
          '',
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
        itemCount: 5,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 18,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '일행들의 지금 성격은 어떻습니까 ?',
                    style: RetroTheme.dosFont.copyWith(fontSize: 11),
                  ),
                  DropdownButton<int>(
                    value: _encounterFrequency,
                    dropdownColor: RetroTheme.background,
                    items: const [1, 2, 3]
                        .map(
                          (n) => DropdownMenuItem(value: n, child: Text('$n')),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _encounterFrequency = value);
                      widget.onEncounterSettingsChanged?.call(
                        value,
                        _maxEnemies,
                      );
                    },
                  ),
                  Text(
                    '한번에 출현하는 적들의 최대치를 기입하십시오',
                    style: RetroTheme.dosFont.copyWith(fontSize: 11),
                  ),
                  DropdownButton<int>(
                    value: _maxEnemies,
                    dropdownColor: RetroTheme.background,
                    items: const [3, 4, 5, 6, 7]
                        .map(
                          (n) => DropdownMenuItem(value: n, child: Text('$n')),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _maxEnemies = value);
                      widget.onEncounterSettingsChanged?.call(
                        _encounterFrequency,
                        value,
                      );
                    },
                  ),
                ],
              ),
            );
          }
          final slotNum = index;
          final slotData = _slots![index - 1];
          final slotTitle = SaveManager.slotNames[index - 1];

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
                        slotTitle.replaceAll(' (Main)', ''),
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
                          '없습니다',
                          style: RetroTheme.dosFont.copyWith(
                            color: RetroTheme.darkGray,
                            fontSize: 10,
                          ),
                        ),
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
                          flags: LoreDialogueManager.instance.getSaveFlags(),
                          etc: widget.etcProvider?.call() ?? widget.etc ?? {},
                          mapTiles: widget.mapTilesProvider?.call() ?? const [],
                          consumedScripts:
                              widget.consumedScriptsProvider?.call() ??
                              LoreScriptEngine.instance.consumedScripts
                                  .toList(),
                        );
                        await SaveManager.instance.saveGame(newSave);
                        widget.onLog('현재의 게임을 저장합니다');
                        await _loadSlots();
                      },
                      child: Text(
                        LoreMenuText.optionSave,
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
                          : () async {
                              LoreDialogueManager.instance.loadFlags(
                                slotData.flags,
                                fieldCounters: slotData.etc,
                              );
                              await widget.onSaveDataLoaded?.call(slotData);
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            },
                      child: Text(
                        LoreMenuText.optionResume,
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
