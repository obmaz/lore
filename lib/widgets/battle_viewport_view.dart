import 'dart:async';
import 'dart:math';

import '../logic/lore_batt_text.dart';
import '../logic/lore_sub_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/retro_theme.dart';
import '../services/audio_manager.dart';
import '../models/monster.dart';
import '../models/party_member.dart';
import '../models/spell.dart';
import '../data/lore_data.dart';
import '../logic/lore_cast_spell.dart';
import 'lore_select_view.dart';
import '../logic/lore_battle.dart';
import '../game/lore_dialogue_manager.dart';

/// 1993년 원작 LOREBATT.PAS 기반 턴제 전투 뷰포트 위젯
/// - 7대 전투 커맨드 ([1]무기, [2]단일마법, [3]전체마법, [4]특수마법, [5]일행치료, [6]초능력, [7]자동전투/도망)
/// - 45종 전체 마법 체계 및 ESP 연동
/// - 몬스터 풀 AI (전체마법, 동료치료, 독/치명타/즉사 특수공격)
/// - 파티 리더의 무조건 공격 지시 (자동 전투 모드)
class BattleViewportView extends StatefulWidget {
  final List<PartyMember> partyMembers;
  final List<Monster> enemies;
  final Random? random;
  final bool enemyFirst;
  final bool espAccessGranted;
  final void Function(String message) onLog;
  final void Function(int goldEarned) onVictory;
  final void Function(int eNumber) onTelepathyJoin;
  final VoidCallback onDefeat;
  final VoidCallback onRunAway;

  const BattleViewportView({
    super.key,
    required this.partyMembers,
    required this.enemies,
    this.random,
    this.enemyFirst = false,
    required this.espAccessGranted,
    required this.onLog,
    required this.onVictory,
    required this.onTelepathyJoin,
    required this.onDefeat,
    required this.onRunAway,
  });

  @override
  State<BattleViewportView> createState() => _BattleViewportViewState();
}

class _BattleViewportViewState extends State<BattleViewportView> {
  late final LoreBattle _battle;
  int _selectedEnemyIndex = 0;

  /// 지금 명령을 고르는 파티원(0부터).
  int _activePlayerIndex = 0;
  bool _isTurnProcessing = false;
  bool _battleEnded = false;

  /// `autobattle`: 리더가 `일행에게 무조건 공격 할 것을 지시`를 고른 라운드.
  bool _autoRound = false;

  final FocusNode _focusNode = FocusNode();

  /// `c := ReadKey` / `PressAnyKey` inside `BattleMode`: the round stops until
  /// any key or pointer press. [_keyWaitPrompt] is true for `PressAnyKey`,
  /// which prints its text; `ReadKey` shows nothing.
  static final Set<LogicalKeyboardKey> _modifierKeys = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.numLock,
    LogicalKeyboardKey.scrollLock,
  };

  Completer<void>? _keyWait;
  bool _keyWaitPrompt = false;

  Future<void> _readKey({bool prompt = false}) {
    if (!mounted) return Future.value();
    _releaseKeyWait(rebuild: false);
    final wait = Completer<void>();
    _keyWait = wait;
    setState(() => _keyWaitPrompt = prompt);
    return wait.future;
  }

  void _releaseKeyWait({bool rebuild = true}) {
    final wait = _keyWait;
    _keyWait = null;
    if (wait != null && !wait.isCompleted) {
      wait.complete();
      if (rebuild && mounted) setState(() => _keyWaitPrompt = false);
    }
  }

  Monster get currentTarget {
    if (_selectedEnemyIndex >= widget.enemies.length) {
      _selectedEnemyIndex = 0;
    }
    return widget.enemies[_selectedEnemyIndex];
  }

  PartyMember? get activePlayer {
    for (int i = _activePlayerIndex; i < widget.partyMembers.length; i++) {
      if (widget.partyMembers[i].isBattleActive) {
        _activePlayerIndex = i;
        return widget.partyMembers[i];
      }
    }
    for (int i = 0; i < widget.partyMembers.length; i++) {
      if (widget.partyMembers[i].isBattleActive) {
        _activePlayerIndex = i;
        return widget.partyMembers[i];
      }
    }
    return null;
  }

  bool get isLeaderActive => _activePlayerIndex == 0;

  @override
  void initState() {
    super.initState();
    _battle = LoreBattle(
      party: widget.partyMembers,
      enemy: widget.enemies,
      random: widget.random ?? Random(),
      print: (color, text) => widget.onLog(text),
      sound: _playSound,
      onTelepathyJoin: widget.onTelepathyJoin,
      specialMagicLearned: LoreDialogueManager.instance.specialMagicLearned,
      espBit: widget.espAccessGranted,
    );
    _selectFirstAliveTarget();
    if (widget.enemyFirst) {
      _isTurnProcessing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runOpeningEnemyTurn());
      });
    }
  }

  /// `BattleMode(FALSE)`: 첫 선택 전에 적 단계(`loop:`)부터 돈다.
  Future<void> _runOpeningEnemyTurn() async {
    await _enemyTurn();
    if (!mounted || _battleEnded) return;
    _startSelection();
  }

  @override
  void dispose() {
    _releaseKeyWait(rebuild: false);
    _focusNode.dispose();
    super.dispose();
  }

  void _selectFirstAliveTarget() {
    for (int i = 0; i < widget.enemies.length; i++) {
      if (!widget.enemies[i].isDead) {
        _selectedEnemyIndex = i;
        break;
      }
    }
  }

  void _playSound(String name) {
    switch (name) {
      case 'hit':
        AudioManager.instance.playHit();
      case 'scream1':
        AudioManager.instance.playScream1();
      case 'scream2':
        AudioManager.instance.playScream2();
    }
  }

  /// `EndBattle` (적 단계 끝에서만 판정한다).
  void _checkBattleEnd() {
    if (_battleEnded) return;
    final code = _battle.endBattle();
    if (code == null) return;
    _battleEnded = true;
    _autoRound = false;
    if (code == 1) {
      // `1 : begin GameOver; exit; end` — GameOver prints the defeat text.
      widget.onDefeat();
    } else {
      final gold = _battle.plusGold();
      widget.onVictory(gold);
    }
  }

  // ======================================================================
  // BattleMode: 모든 파티원이 먼저 명령(`battle[person,1..3]`)을 고르고,
  // 그다음 번호 순서대로 실행한 뒤 적 단계가 온다.
  // ======================================================================

  /// 새 라운드의 선택을 시작한다 (`for person := 1 to 6 do battle[person,1] := 0`).
  void _startSelection() {
    for (var i = 1; i <= 6; i++) {
      _battle.battle[i][1] = 0;
    }
    _autoRound = false;
    setState(() {
      _activePlayerIndex = 0;
      _isTurnProcessing = false;
    });
    activePlayer;
    _reTargetIfDead();
  }

  /// 현재 파티원의 선택을 기록하고 다음 사람으로 넘어간다.
  void _select(int how, int what, int whom) {
    final who = _activePlayerIndex + 1;
    _battle.battle[who][1] = how;
    _battle.battle[who][2] = what;
    _battle.battle[who][3] = whom;
    unawaited(_afterSelection());
  }

  Future<void> _afterSelection() async {
    if (_battleEnded) return;
    var next = _activePlayerIndex + 1;
    while (true) {
      while (next < widget.partyMembers.length &&
          !widget.partyMembers[next].isBattleActive) {
        next++;
      }
      if (next >= widget.partyMembers.length) break;
      setState(() => _activePlayerIndex = next);
      if (!_autoRound) return;
      _battle.autoSelect(next + 1); // `k := 8`
      next++;
    }
    await _executeRound();
  }

  Future<void> _executeRound() async {
    setState(() => _isTurnProcessing = true);
    for (var who = 1; who <= widget.partyMembers.length; who++) {
      if (!_battle.exist(who)) continue;
      final escaped = _battle.executePerson(who);
      if (!mounted) return;
      setState(() {});
      if (escaped) {
        // `party.etc[6] := 2; c := ReadKey; Clear; Scroll(TRUE); exit;`
        await _readKey();
        if (!mounted) return;
        _battleEnded = true;
        _autoRound = false;
        widget.onRunAway();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted || _battleEnded) return;
    }
    // `DisplayEnemies(FALSE); print(7,''); PressAnyKey;` before `loop:`.
    await _readKey(prompt: true);
    if (!mounted || _battleEnded) return;
    await _enemyTurn();
    if (!mounted || _battleEnded) return;
    _startSelection();
  }

  /// 적 단계 (`loop:` 부터 `EndBattle` 까지).
  Future<void> _enemyTurn() async {
    setState(() => _isTurnProcessing = true);
    _battle.enemyPhase();
    setState(() {});
    // `SimpleDisCond; ok := EndBattle(i); c := ReadKey;` — the key wait comes
    // before the result is used, also on a defeat.
    await _readKey();
    if (!mounted || _battleEnded) return;
    _checkBattleEnd();
  }

  // ==========================================
  // [1] 한 명의 적을 무기로 공격
  // ==========================================
  void _onWeaponAttack() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;
    _select(1, player.weapon, _selectedEnemyIndex + 1);
  }

  // ==========================================
  // [2] 한 명의 적에게 마법 공격 (1..6)
  // ==========================================
  void _onSingleMagicMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;
    final spells = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.singleAttack)
        .toList();
    _showSpellDialog(
      _modeTitle(player),
      spells,
      player,
      (spell) => _select(2, spell.id, _selectedEnemyIndex + 1),
      onCancel: _hesitate,
    );
  }

  // ==========================================
  // [3] 모든 적에게 마법 공격 (7..12)
  // ==========================================
  void _onAllMagicMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;
    final spells = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.allAttack)
        .toList();
    _showSpellDialog(
      _modeTitle(player),
      spells,
      player,
      (spell) => _select(3, spell.id - 6, 0),
      onCancel: _hesitate,
    );
  }

  // ==========================================
  // [4] 적에게 특수 마법 공격 (13..18)
  // ==========================================
  void _onSpecialMagicMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;
    final spells = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.specialDebuff)
        .toList();
    _showSpellDialog(
      _modeTitle(player),
      spells,
      player,
      (spell) => _select(4, spell.id - 12, _selectedEnemyIndex + 1),
      onCancel: _hesitate,
    );
  }

  /// 메뉴에서 `없음`/취소: `battle[person,1] := 0` (`주저했다`).
  void _hesitate() {
    if (_battleEnded) return;
    _select(0, 0, 0);
  }

  // ==========================================
  // [5] 일행을 치료 (19..32) — 원본은 선택하는 즉시 적용한다 (`5 : CureSpell`)
  // ==========================================
  void _onCureMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;
    unawaited(_runCureSpell(player));
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  /// `5 : CureSpell`: LOREMENU's procedure runs at once, while the commands
  /// are being chosen (`party.etc[6] = 1`, so refusals and `SPnotEnough` stay
  /// silent), and the turn of [caster] then holds `battle[person,1] = 5`.
  Future<void> _runCureSpell(PartyMember caster) async {
    setState(() => _isTurnProcessing = true);
    await LoreCastSpell.cureSpell(
      _BattleCureIo(this),
      widget.partyMembers,
      caster,
      quiet: true,
    );
    if (!mounted || _battleEnded) return;
    setState(() => _isTurnProcessing = false);
    _select(5, 0, 0);
  }

  // ==========================================
  // [6] 적에게 초능력 사용 (41..45)
  // ==========================================
  void _onEspMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;
    final spells = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.esp)
        .toList();
    _showSpellDialog(_modeTitle(player), spells, player, (spell) {
      final target = currentTarget;
      if (target.isUnconscious || target.isDead) {
        // `if enemy[j].unconscious or enemy[j].dead then battle[person,1] := 0`
        _hesitate();
        return;
      }
      _select(6, spell.id - 40, _selectedEnemyIndex + 1);
    }, onCancel: _hesitate);
  }

  // ==========================================
  // [7] 도주를 시도 / 리더는 무조건 공격을 지시
  // ==========================================
  void _onAutoBattleOrRun() {
    if (_isTurnProcessing || _battleEnded) return;
    if (isLeaderActive) {
      // `k = 7, person = 1` → `k := 8; autobattle := TRUE`
      _autoRound = true;
      _battle.autoSelect(1);
      unawaited(_afterSelection());
    } else {
      _select(7, 0, 0);
    }
  }

  // ==========================================
  // 헬퍼 및 UI 다이얼로그
  // ==========================================
  /// m[0] of the battle menus: `{name}의 전투 모드 ===>`.
  String _modeTitle(PartyMember player) =>
      '${player.name}${LoreBattText.battleMode}';

  void _showSpellDialog(
    String title,
    List<Spell> spells,
    PartyMember player,
    void Function(Spell spell) onSelected, {
    VoidCallback? onCancel,
  }) {
    var chosen = false;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.black,
        shape: Border.all(color: RetroTheme.lightMagenta, width: 2),
        title: Text(
          title,
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: spells.map((sp) {
              // `Select` 는 레벨로 정해진 개수만 보여 준다. 초능력은 다섯 개 모두
              // 보이고 쓸 수 없는 것은 실행할 때 문구가 나온다.
              final isAvailable = sp.category == SpellCategory.esp
                  ? true
                  : sp.isAvailableForLevel(player.magicLevel, player.espLevel);
              return ListTile(
                dense: true,
                title: Text(
                  sp.name,
                  style: RetroTheme.dosFont.copyWith(
                    color: isAvailable ? RetroTheme.white : RetroTheme.darkGray,
                    fontSize: 11,
                  ),
                ),
                onTap: isAvailable
                    ? () {
                        chosen = true;
                        Navigator.of(ctx).pop();
                        onSelected(sp);
                      }
                    : null,
              );
            }).toList(),
          ),
        ),
      ),
    ).then((_) {
      if (!chosen && mounted) onCancel?.call();
    });
  }

  void _reTargetIfDead() {
    if (currentTarget.isDead || currentTarget.isUnconscious) {
      for (int i = 0; i < widget.enemies.length; i++) {
        if (!widget.enemies[i].isDead && !widget.enemies[i].isUnconscious) {
          _selectedEnemyIndex = i;
          return;
        }
      }
      for (int i = 0; i < widget.enemies.length; i++) {
        if (!widget.enemies[i].isDead) {
          _selectedEnemyIndex = i;
          return;
        }
      }
    }
  }

  /// `DisplayEnemies`: HP 구간별 색, 의식불명은 8, 죽으면 0(보이지 않음).
  Color _getEnemyHpColor(Monster e) {
    if (e.isDead) return RetroTheme.viewportBg;
    if (e.isUnconscious) return RetroTheme.darkGray;
    final hp = e.hp;
    if (hp <= 0) return RetroTheme.darkGray; // 8
    if (hp <= 19) return RetroTheme.lightRed; // 12
    if (hp <= 49) return RetroTheme.red; // 4
    if (hp <= 99) return RetroTheme.brown; // 6
    if (hp <= 199) return RetroTheme.yellow; // 14
    if (hp <= 299) return RetroTheme.green; // 2
    return RetroTheme.lightGreen; // 10
  }

  @override
  Widget build(BuildContext context) {
    final player = activePlayer;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && _keyWait != null) {
          // DOS `ReadKey` does not return for a lone modifier key.
          if (_modifierKeys.contains(event.logicalKey)) {
            return KeyEventResult.ignored;
          }
          _releaseKeyWait();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent && !_isTurnProcessing && !_battleEnded) {
          if (event.logicalKey == LogicalKeyboardKey.digit1) {
            _onWeaponAttack();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
            _onSingleMagicMenu();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
            _onAllMagicMenu();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit4) {
            _onSpecialMagicMenu();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit5) {
            _onCureMenu();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit6) {
            _onEspMenu();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit7) {
            _onAutoBattleOrRun();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _releaseKeyWait(),
        child: Column(
          children: [
            // `PressAnyKey`: 원본이 찍는 문구(`ReadKey`는 아무것도 찍지 않는다)
            if (_keyWaitPrompt)
              Container(
                width: double.infinity,
                color: RetroTheme.panelBg,
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  LoreSubText.pressAnyKey,
                  textAlign: TextAlign.center,
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.ega(14), // setcolor(14)
                    fontSize: 11,
                  ),
                ),
              ),
            // 자동 전투 실행 중 안내 배너
            if (_autoRound)
              InkWell(
                child: Container(
                  width: double.infinity,
                  color: RetroTheme.lightRed,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    LoreBattText.menuCommandAll,
                    textAlign: TextAlign.center,
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // 1. 전투 장면: `DisplayEnemies` — 이름만, HP 구간별 색 (죽으면 지워진다)
            Expanded(
              flex: 60,
              child: Container(
                color: RetroTheme.viewportBg,
                padding: const EdgeInsets.all(6.0),
                child: ListView.builder(
                  itemCount: widget.enemies.length,
                  itemBuilder: (context, idx) {
                    final enemy = widget.enemies[idx];
                    final isSelected = idx == _selectedEnemyIndex;
                    return GestureDetector(
                      key: ValueKey('enemy-$idx'),
                      onTap: () {
                        // The press that ends a key wait must not pick a target.
                        if (_keyWait != null) return;
                        if (!enemy.isDead) {
                          setState(() => _selectedEnemyIndex = idx);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        color: isSelected && !enemy.isDead
                            ? RetroTheme.lightGray
                            : Colors.transparent,
                        child: Text(
                          enemy.name,
                          style: RetroTheme.dosFont.copyWith(
                            color: _getEnemyHpColor(enemy),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. 명령을 고르는 파티원: `m[0] := name + '의 전투 모드 ===>'`
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: RetroTheme.panelBg,
              width: double.infinity,
              child: Text(
                player != null ? _modeTitle(player) : '',
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.yellow,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // 3. 원작 7대 전투 커맨드 조작 버튼부
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: const BoxDecoration(
                color: RetroTheme.black,
                border: Border(
                  top: BorderSide(color: RetroTheme.borderColor, width: 1.5),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  _buildCmdButton(
                    1,
                    '${LoreBattText.menuAttackOne}${LoreSubText.weaponLabel(player?.weapon ?? 0)}${LoreSubText.weaponJosa(player?.weapon ?? 0)}${LoreBattText.menuAttackOneRest}',
                    RetroTheme.lightRed,
                    _onWeaponAttack,
                  ),
                  _buildCmdButton(
                    2,
                    LoreBattText.menuMagicOne,
                    RetroTheme.lightBlue,
                    _onSingleMagicMenu,
                  ),
                  _buildCmdButton(
                    3,
                    LoreBattText.menuMagicAll,
                    RetroTheme.lightCyan,
                    _onAllMagicMenu,
                  ),
                  _buildCmdButton(
                    4,
                    LoreBattText.menuSpecial,
                    RetroTheme.lightMagenta,
                    _onSpecialMagicMenu,
                  ),
                  _buildCmdButton(
                    5,
                    LoreBattText.menuHealParty,
                    RetroTheme.lightGreen,
                    _onCureMenu,
                  ),
                  _buildCmdButton(
                    6,
                    LoreBattText.menuEsp,
                    RetroTheme.yellow,
                    _onEspMenu,
                  ),
                  _buildCmdButton(
                    7,
                    isLeaderActive
                        ? LoreBattText.menuCommandAll
                        : LoreBattText.menuRun,
                    _autoRound ? RetroTheme.lightRed : RetroTheme.white,
                    _onAutoBattleOrRun,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCmdButton(
    int number,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    final disabled = _isTurnProcessing || _battleEnded;
    return ElevatedButton(
      key: ValueKey('battle-cmd-$number'),
      style: ElevatedButton.styleFrom(
        backgroundColor: RetroTheme.panelBg,
        foregroundColor: color,
        side: BorderSide(
          color: disabled ? RetroTheme.darkGray : color,
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(60, 32),
      ),
      onPressed: disabled ? null : onPressed,
      child: Text(
        label,
        style: RetroTheme.dosFont.copyWith(
          color: disabled ? RetroTheme.darkGray : color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// [LoreCureSpellIo] inside the battle: selects and `Talk` as dialogs, the
/// texts also go to the battle log, `SimpleDisCond` normalizes the party.
class _BattleCureIo implements LoreCureSpellIo {
  _BattleCureIo(this._view);

  final _BattleViewportViewState _view;

  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    List<(int, String)> lines = const [],
  }) async {
    if (!_view.mounted) return 0;
    return showLoreSelectDialog(
      _view.context,
      title: title,
      items: items,
      maxsum: maxsum,
      lines: lines,
    );
  }

  @override
  Future<void> talk(List<(int, String)> lines) async {
    if (!_view.mounted) return;
    for (final (_, text) in lines) {
      if (text.isNotEmpty) _view.widget.onLog(text);
    }
    await showLoreMessageDialog(_view.context, lines: lines);
  }

  @override
  void displayCondition() {
    PartyMember.simpleDisCond(_view.widget.partyMembers);
    _view._redraw();
  }
}
