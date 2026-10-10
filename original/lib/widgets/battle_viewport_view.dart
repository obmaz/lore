import 'dart:async';
import 'dart:math';

import '../logic/lore_random.dart';

import '../logic/lore_batt_text.dart';
import '../logic/lore_sub_text.dart';
import '../logic/lore_enemy_presentation.dart';
import '../logic/lore_enemy_selection.dart';
import '../logic/lore_battle_commands.dart';
import '../logic/lore_battle_menus.dart';

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
import '../logic/lore_transient_slots.dart';
import '../game/lore_dialogue_manager.dart';

/// 1993년 원작 LOREBATT.PAS 기반 턴제 전투 뷰포트 위젯
/// - 7대 전투 커맨드 ([1]무기, [2]단일마법, [3]전체마법, [4]특수마법, [5]일행치료, [6]초능력, [7]자동전투/도망)
/// - 45종 전체 마법 체계 및 ESP 연동
/// - 몬스터 풀 AI (전체마법, 동료치료, 독/치명타/즉사 특수공격)
/// - 파티 리더의 무조건 공격 지시 (자동 전투 모드)
class BattleViewportView extends StatefulWidget {
  final List<PartyMember> partyMembers;
  final List<Monster> enemies;
  final LoreTransientSlots? slots;
  final Random? random;
  final bool enemyFirst;
  final bool espAccessGranted;
  final void Function(String message) onLog;
  final void Function(int color, String text)? onPrint;
  final VoidCallback? onClearMessageWindow;
  final void Function(int goldEarned) onVictory;
  final void Function(int eNumber) onTelepathyJoin;
  final VoidCallback onDefeat;
  final VoidCallback onRunAway;

  const BattleViewportView({
    super.key,
    required this.partyMembers,
    required this.enemies,
    this.slots,
    this.random,
    this.enemyFirst = false,
    required this.espAccessGranted,
    required this.onLog,
    this.onPrint,
    this.onClearMessageWindow,
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
  Completer<void>? _keyWait;
  bool _keyWaitPrompt = false;

  Future<void> _readKey({bool prompt = false}) {
    if (!mounted) return Future.value();
    _releaseKeyWait(rebuild: false);
    // A script dialog can restore focus to the field after creating this
    // viewport. BattleMode's pending ReadKey must receive the next key.
    _focusNode.requestFocus();
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

  int get _partyCount => min(6, widget.partyMembers.length);

  PartyMember? get activePlayer {
    for (int i = _activePlayerIndex; i < _partyCount; i++) {
      if (widget.partyMembers[i].isBattleActive) {
        _activePlayerIndex = i;
        return widget.partyMembers[i];
      }
    }
    for (int i = 0; i < _partyCount; i++) {
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
      slots: widget.slots,
      random: widget.random ?? LoreRandom.fromClock(),
      print: (color, text) {
        if (widget.onPrint case final print?) {
          print(color, text);
        } else {
          widget.onLog(text);
        }
      },
      sound: _playSound,
      onTelepathyJoin: widget.onTelepathyJoin,
      specialMagicLearned: LoreDialogueManager.instance.specialMagicLearned,
      espBit: widget.espAccessGranted,
    );
    if (widget.enemyFirst) {
      _isTurnProcessing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runOpeningEnemyTurn());
      });
    } else if (!widget.partyMembers.take(6).any((p) => p.isBattleActive)) {
      // The source FOR does not wait for a menu when every exist(person) is false.
      _isTurnProcessing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_executeRound());
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
    _battle.beginSelection();
    _autoRound = false;
    setState(() {
      _activePlayerIndex = 0;
      _isTurnProcessing = false;
    });
    final player = activePlayer;
    _selectedEnemyIndex = 0; // LORESUB SelectEnemy starts at number := 1.
    if (player == null) unawaited(_executeRound());
  }

  /// 현재 파티원의 선택을 기록하고 다음 사람으로 넘어간다.
  void _select(int how, int what, int whom) {
    final who = _activePlayerIndex + 1;
    _battle.battle[who][1] = how;
    _battle.battle[who][2] = what;
    _battle.battle[who][3] = whom;
    unawaited(_afterSelection());
  }

  void _selectSourceMenu(int how, int result) {
    final player = activePlayer;
    if (player == null || _battleEnded) return;
    final command = LoreBattleCommands.manual(
      how: how,
      result: result,
      maxsum: how == 1 ? 0 : LoreBattleMenus.maxsum(how, player.magicLevel),
      target: _selectedEnemyIndex + 1,
      weapon: player.weapon,
      targetUnavailable: currentTarget.isUnconscious || currentTarget.isDead,
    );
    _select(command[0], command[1], command[2]);
  }

  Future<void> _afterSelection() async {
    if (_battleEnded) return;
    var next = _activePlayerIndex + 1;
    while (true) {
      while (next < _partyCount && !widget.partyMembers[next].isBattleActive) {
        next++;
      }
      if (next >= _partyCount) break;
      setState(() {
        _activePlayerIndex = next;
        _selectedEnemyIndex = 0;
      });
      if (!_autoRound) return;
      _battle.autoSelect(next + 1); // `k := 8`
      next++;
    }
    await _executeRound();
  }

  Future<void> _executeRound() async {
    setState(() => _isTurnProcessing = true);
    for (var who = 1; who <= _partyCount; who++) {
      if (!_battle.exist(who)) continue;
      final escaped = _battle.executePerson(who);
      if (!mounted) return;
      setState(() {});
      if (escaped) {
        // `party.etc[6] := 2; c := ReadKey; Clear; Scroll(TRUE); exit;`
        LoreDialogueManager.instance.setBattleResult(2);
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
    final steps = _battle.enemyPhaseSteps().iterator;
    // moveNext executes the next attack: check lifetime before advancing,
    // including after every asynchronous render boundary.
    while (mounted && !_battleEnded && steps.moveNext()) {
      setState(() {});
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || _battleEnded) return;
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
    _selectSourceMenu(1, 0);
  }

  // ==========================================
  // [2] 한 명의 적에게 마법 공격 (1..6)
  // ==========================================
  void _onSingleMagicMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;
    widget.onClearMessageWindow?.call();
    final spells = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.singleAttack)
        .toList();
    _showSpellDialog(
      _modeTitle(player),
      spells,
      player,
      (result) => _selectSourceMenu(2, result),
    );
  }

  // ==========================================
  // [3] 모든 적에게 마법 공격 (7..12)
  // ==========================================
  void _onAllMagicMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;
    widget.onClearMessageWindow?.call();
    final spells = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.allAttack)
        .toList();
    _showSpellDialog(
      _modeTitle(player),
      spells,
      player,
      (result) => _selectSourceMenu(3, result),
    );
  }

  // ==========================================
  // [4] 적에게 특수 마법 공격 (13..18)
  // ==========================================
  void _onSpecialMagicMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;
    widget.onClearMessageWindow?.call();
    final spells = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.specialDebuff)
        .toList();
    _showSpellDialog(
      _modeTitle(player),
      spells,
      player,
      (result) => _selectSourceMenu(4, result),
    );
  }

  /// 메뉴에서 `없음`/취소: `battle[person,1] := 0` (`주저했다`).
  void _hesitate() {
    if (_battleEnded) return;
    widget.onClearMessageWindow?.call();
    final who = _activePlayerIndex + 1;
    _select(0, _battle.battle[who][2], _battle.battle[who][3]);
  }

  // ==========================================
  // [5] 일행을 치료 (19..32) — 원본은 선택하는 즉시 적용한다 (`5 : CureSpell`)
  // ==========================================
  void _onCureMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;
    widget.onClearMessageWindow?.call();
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
    final who = _activePlayerIndex + 1;
    _select(5, _battle.battle[who][2], _battle.battle[who][3]);
  }

  // ==========================================
  // [6] 적에게 초능력 사용 (41..45)
  // ==========================================
  void _onEspMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;
    widget.onClearMessageWindow?.call();
    final spells = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.esp)
        .toList();
    _showSpellDialog(
      _modeTitle(player),
      spells,
      player,
      (result) => _selectSourceMenu(6, result),
      includeNone: false,
    );
  }

  // ==========================================
  // [7] 도주를 시도 / 리더는 무조건 공격을 지시
  // ==========================================
  void _onAutoBattleOrRun() {
    if (_isTurnProcessing || _battleEnded) return;
    if (activePlayer == null) return;
    widget.onClearMessageWindow?.call();
    if (isLeaderActive) {
      // `k = 7, person = 1` → `k := 8; autobattle := TRUE`
      _autoRound = true;
      _battle.autoSelect(1);
      unawaited(_afterSelection());
    } else {
      final who = _activePlayerIndex + 1;
      _select(7, _battle.battle[who][2], _battle.battle[who][3]);
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
    void Function(int result) onSelected, {
    bool includeNone = true,
  }) {
    final how = switch (spells.first.category) {
      SpellCategory.singleAttack => 2,
      SpellCategory.allAttack => 3,
      SpellCategory.specialDebuff => 4,
      SpellCategory.esp => 6,
      _ => throw StateError('Not a BattleMode attack menu'),
    };
    // BattleMode's attack menus have m[1] = '없음'; ESP has five spells
    // without that entry. Select renders all rows, black beyond maxsum.
    unawaited(
      showLoreSelectDialog(
        context,
        title: title,
        items: [if (includeNone) '없음', for (final spell in spells) spell.name],
        maxsum: LoreBattleMenus.maxsum(how, player.magicLevel),
      ).then((k) {
        if (!mounted || _battleEnded) return;
        onSelected(k);
      }),
    );
  }

  /// `DisplayEnemies`: HP 구간별 색, 의식불명은 8, 죽으면 0(보이지 않음).
  Color _getEnemyHpColor(Monster e) {
    final index = LoreEnemyPresentation.color(e);
    // Source colour 0 erases the name on its black backdrop. Keep the modern
    // viewport's existing backdrop adapter while retaining that invisibility.
    return index == 0 ? RetroTheme.viewportBg : RetroTheme.ega(index);
  }

  @override
  Widget build(BuildContext context) {
    final player = activePlayer;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (isLoreReadKeyEvent(event) && _keyWait != null) {
          _releaseKeyWait();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent && !_isTurnProcessing && !_battleEnded) {
          if (widget.enemies.isNotEmpty &&
              (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                  event.logicalKey == LogicalKeyboardKey.arrowDown ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            final cursor = LoreEnemySelection(
              widget.enemies.length,
              number: _selectedEnemyIndex + 1,
            );
            final accepted = cursor.readKey(
              event.logicalKey == LogicalKeyboardKey.enter ? 13 : 0,
              scan: event.logicalKey == LogicalKeyboardKey.arrowUp ? 72 : 80,
            );
            setState(() => _selectedEnemyIndex = cursor.number - 1);
            if (accepted) _onWeaponAttack();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _hesitate(); // command Select(0); not SelectEnemy cancellation.
            return KeyEventResult.handled;
          }
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
                        if (_keyWait != null ||
                            _isTurnProcessing ||
                            _battleEnded) {
                          return;
                        }
                        // SelectEnemy accepts every slot, including corpses.
                        // AttackOne/CastOne own any subsequent retargeting.
                        setState(() => _selectedEnemyIndex = idx);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        color: isSelected
                            ? RetroTheme.lightGray
                            : Colors.transparent,
                        child: Text(
                          enemy.name,
                          style: RetroTheme.dosFont.copyWith(
                            color: enemy.isDead
                                ? Colors.transparent
                                : _getEnemyHpColor(enemy),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            if (widget.enemies.isNotEmpty)
              Text(
                currentTarget.name,
                key: const ValueKey('battle-target-preview'),
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.ega(
                    LoreEnemySelection.color(currentTarget),
                  ),
                  fontSize: 12,
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
            Expanded(
              flex: 40,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: RetroTheme.black,
                    border: Border(
                      top: BorderSide(
                        color: RetroTheme.borderColor,
                        width: 1.5,
                      ),
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
