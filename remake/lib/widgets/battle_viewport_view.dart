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

import 'mobile_content_dialog.dart';

import '../theme/retro_theme.dart';
import '../theme/mobile_theme.dart';
import '../services/audio_manager.dart';
import '../models/monster.dart';
import '../models/party_member.dart';
import '../models/spell.dart';
import '../data/lore_data.dart';
import '../logic/lore_cast_spell.dart';
import 'lore_select_view.dart';
import 'mobile_dialog_action.dart';
import '../logic/lore_battle.dart';
import '../logic/lore_transient_slots.dart';
import '../game/lore_dialogue_manager.dart';
import '../presentation/battle_presentation.dart';
import '../presentation/battle_command_plan.dart';
import 'battle_choice_dialog.dart';
import 'mobile_field_menus.dart';
import '../presentation/battle_backdrop.dart';
import 'battle_art.dart';
import 'jrpg_battle_stage.dart';
import 'mobile_party_dialog.dart';

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

  /// Test-only adapter for replaying the DOS wait boundaries and raw UI.
  final bool sourceReplay;
  final BattleBackdrop backdrop;

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
    this.sourceReplay = false,
    this.backdrop = BattleBackdrop.meadow,
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
  final ScrollController _commandScroll = ScrollController();
  bool _isCommandPickerOpen = false;
  final List<String> _actionLines = [];
  final List<String> _battleHistory = [];
  late final BattleSnapshot _initialSnapshot;
  BattleSnapshot? _cureBefore;
  BattleActionEvent? _event;
  int _eventSerial = 0;
  int? _resultGold;
  bool _resultDefeat = false;
  bool _resultAccepted = false;
  int _speed = 1;
  final _commandPlan = BattleCommandPlan();
  Iterable<int> get _eligibleActors sync* {
    for (var i = 0; i < _partyCount; i++) {
      if (widget.partyMembers[i].isBattleActive) yield i;
    }
  }

  Duration get _effectDuration => Duration(milliseconds: 1000 ~/ _speed);

  /// `c := ReadKey` / `PressAnyKey` inside `BattleMode`: the round stops until
  /// the explicit mobile action or a keyboard key is used.
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
    if (!widget.sourceReplay) {
      return Future<void>.delayed(const Duration(milliseconds: 180));
    }
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
    if (!widget.sourceReplay && widget.enemies[_selectedEnemyIndex].isDead) {
      final living = widget.enemies.indexWhere((e) => !e.isDead);
      if (living >= 0) _selectedEnemyIndex = living;
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
    _initialSnapshot = BattleSnapshot(widget.partyMembers, widget.enemies);
    _battle = LoreBattle(
      party: widget.partyMembers,
      enemy: widget.enemies,
      slots: widget.slots,
      random: widget.random ?? LoreRandom.fromClock(),
      print: (color, text) {
        if (text.isNotEmpty) {
          _actionLines.add(text);
          _battleHistory.add(text);
        }
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
    _commandScroll.dispose();
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
      if (widget.sourceReplay) {
        widget.onDefeat();
      } else {
        setState(() => _resultDefeat = true);
      }
    } else {
      final gold = _battle.plusGold();
      if (widget.sourceReplay) {
        widget.onVictory(gold);
      } else {
        setState(() => _resultGold = gold);
      }
    }
  }

  // ======================================================================
  // BattleMode: 모든 파티원이 먼저 명령(`battle[person,1..3]`)을 고르고,
  // 그다음 번호 순서대로 실행한 뒤 적 단계가 온다.
  // ======================================================================

  /// 새 라운드의 선택을 시작한다 (`for person := 1 to 6 do battle[person,1] := 0`).
  void _startSelection() {
    _battle.beginSelection();
    _commandPlan.reset();
    _autoRound = false;
    setState(() {
      _event = null;
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
    if (!widget.sourceReplay) _commandPlan.prepare(who - 1);
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
    if (!widget.sourceReplay && !_autoRound) {
      final next = _commandPlan.nextPending(_eligibleActors);
      if (next != null) {
        setState(() {
          _activePlayerIndex = next;
          _event = null;
        });
        return;
      }
      await _executeRound();
      return;
    }
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
      final before = BattleSnapshot(widget.partyMembers, widget.enemies);
      _actionLines.clear();
      final escaped = _battle.executePerson(who);
      if (!mounted) return;
      setState(() {});
      if (!widget.sourceReplay) {
        final command = _battle.battle[who];
        await _presentAction(
          before: before,
          side: BattleSide.party,
          actor: who - 1,
          effect: switch (command[1]) {
            2 || 3 => BattleEffect.magic,
            4 => BattleEffect.status,
            5 => BattleEffect.heal,
            6 => BattleEffect.esp,
            7 => BattleEffect.escape,
            _ => BattleEffect.weapon,
          },
          title: _actionTitle(who - 1, command),
          target: command[3] > 0 ? command[3] - 1 : null,
          allTargets: command[1] == 3,
        );
        if (!mounted) return;
      }
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
      if (widget.sourceReplay) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
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
    while (mounted && !_battleEnded) {
      final before = BattleSnapshot(widget.partyMembers, widget.enemies);
      _actionLines.clear();
      if (!steps.moveNext()) break;
      setState(() {});
      if (widget.sourceReplay) {
        await WidgetsBinding.instance.endOfFrame;
      } else {
        final index = steps.current - 1;
        final lines = _actionLines.join(' ');
        await _presentAction(
          before: before,
          side: BattleSide.enemy,
          actor: index,
          effect: lines.contains('마법')
              ? BattleEffect.magic
              : lines.contains('치료')
              ? BattleEffect.heal
              : BattleEffect.enemy,
          title: '${widget.enemies[index].name}의 행동',
          target:
              widget.partyMembers.indexWhere(
                    (p) => p.name.isNotEmpty && lines.contains(p.name),
                  ) >=
                  0
              ? widget.partyMembers.indexWhere(
                  (p) => p.name.isNotEmpty && lines.contains(p.name),
                )
              : 0,
          allTargets: lines.contains('일행 모두'),
        );
      }
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
    _cureBefore = BattleSnapshot(widget.partyMembers, widget.enemies);
    setState(() => _isTurnProcessing = true);
    List<int>? choices;
    if (!widget.sourceReplay) {
      choices = await MobileFieldMenus(
        context,
        widget.partyMembers,
      ).cure(caster);
      if (!mounted || _battleEnded) return;
      if (choices == null) {
        setState(() {
          _isTurnProcessing = false;
          _event = null;
        });
        return;
      }
    }
    await LoreCastSpell.cureSpell(
      _BattleCureIo(this, choices: choices),
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
      // Prepared commands (especially immediate cure) must not be overwritten.
      if (!widget.sourceReplay &&
          _commandPlan.preparedCount(_eligibleActors) > 0) {
        for (final actor in _eligibleActors) {
          if (!_commandPlan.isPrepared(actor)) _battle.autoSelect(actor + 1);
        }
        unawaited(_executeRound());
        return;
      }
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
  String _actionTitle(int actor, List<int> command) {
    final name = widget.partyMembers[actor].name;
    final spellId = switch (command[1]) {
      2 => command[2],
      3 => command[2] + 6,
      4 => command[2] + 12,
      6 => command[2] + 40,
      _ => 0,
    };
    final spells = LoreData.instance.spells.where((s) => s.id == spellId);
    final action = spells.isNotEmpty
        ? spells.first.name
        : switch (command[1]) {
            0 => '대기',
            1 => '무기 공격',
            5 => '회복',
            7 => '도주',
            _ => '행동',
          };
    return '$name · $action';
  }

  Future<void> _presentAction({
    required BattleSnapshot before,
    required BattleSide side,
    required int actor,
    required BattleEffect effect,
    required String title,
    int? target,
    bool allTargets = false,
  }) async {
    if (!mounted) return;
    final event = BattleActionEvent.between(
      serial: ++_eventSerial,
      side: side,
      actor: actor,
      effect: effect,
      title: title,
      before: before,
      after: BattleSnapshot(widget.partyMembers, widget.enemies),
      lines: List.of(_actionLines),
      target: target,
      allTargets: allTargets,
    );
    if (event.lines.isEmpty && event.feedback.isEmpty) return;
    setState(() => _event = event);
    await Future<void>.delayed(_effectDuration);
  }

  Future<void> _showBattleHistory() => showDialog<void>(
    context: context,
    builder: (ctx) => MobileContentDialog(
      title: '이번 전투 기록',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_battleHistory.isEmpty) const Text('아직 기록이 없습니다.'),
          for (final line in _battleHistory)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line),
            ),
        ],
      ),
      footer: MobileDialogAction(
        label: '닫기',
        onPressed: () => Navigator.pop(ctx),
      ),
    ),
  );

  Future<void> _showPartyDetail(int index) async {
    if (!widget.sourceReplay &&
        widget.partyMembers[index].isBattleActive &&
        !_commandPlan.isPrepared(index)) {
      setState(() {
        _activePlayerIndex = index;
        _event = null;
      });
    }
    await showMobilePartyDialog(
      context,
      party: widget.partyMembers,
      initialIndex: index,
    );
  }

  Widget _buildModernBattle(BuildContext context) {
    final player = activePlayer;
    // Resolve a dead selection before passing its index to the stage.
    currentTarget;
    final disabled = _isTurnProcessing || _battleEnded;
    final result = _resultGold;
    final compact = MediaQuery.sizeOf(context).height < 600;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent || disabled || _isCommandPickerOpen) {
          return KeyEventResult.ignored;
        }
        final actions = [
          _onWeaponAttack,
          _onSingleMagicMenu,
          _onAllMagicMenu,
          _onSpecialMagicMenu,
          _onCureMenu,
          _onEspMenu,
          _onAutoBattleOrRun,
        ];
        final digit = int.tryParse(event.logicalKey.keyLabel);
        if (digit != null && digit >= 1 && digit <= 7) {
          actions[digit - 1]();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        color: MobileTheme.background,
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _resultDefeat
                            ? '전투 패배'
                            : result != null
                            ? '전투 승리'
                            : disabled
                            ? '행동 진행 중'
                            : '${player?.name ?? '일행'} · 행동 선택',
                        style: const TextStyle(
                          color: MobileTheme.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (result == null && player != null)
                        Text(
                          'HP ${player.hp}/${player.maxHp}  ·  SP ${player.sp}/${player.maxSp}',
                          style: const TextStyle(
                            color: MobileTheme.muted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  key: const ValueKey('battle-speed'),
                  style: TextButton.styleFrom(
                    foregroundColor: MobileTheme.mint,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () =>
                      setState(() => _speed = _speed == 4 ? 1 : _speed * 2),
                  child: Text('$_speed×'),
                ),
                IconButton(
                  tooltip: '이번 전투 기록',
                  onPressed: _showBattleHistory,
                  icon: const Icon(
                    Icons.history_rounded,
                    color: MobileTheme.ink,
                  ),
                ),
              ],
            ),
            Expanded(
              child: JrpgBattleStage(
                key: const ValueKey('jrpg-battle-stage'),
                party: widget.partyMembers,
                enemies: widget.enemies,
                activeParty: _activePlayerIndex,
                selectedEnemy: _selectedEnemyIndex,
                showSelection: !disabled,
                preparedParty: {
                  for (final i in _eligibleActors)
                    if (_commandPlan.isPrepared(i)) i,
                },
                excludeDeadTargets: true,
                event: _event,
                duration: _effectDuration,
                backdrop: widget.backdrop,
                onEnemyTap: disabled
                    ? null
                    : (i) {
                        if (!widget.enemies[i].isDead) {
                          setState(() => _selectedEnemyIndex = i);
                        }
                      },
                onPartyTap: disabled ? null : _showPartyDetail,
              ),
            ),
            const SizedBox(height: 8),
            if (result == null && !_resultDefeat) ...[
              Container(
                key: const ValueKey('battle-action-caption'),
                width: double.infinity,
                height: compact ? 52 : 60,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: MobileTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MobileTheme.line),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_event == null && !disabled)
                          Row(
                            key: const ValueKey('battle-selection-summary'),
                            children: [
                              Flexible(
                                child: Text(
                                  player?.name ?? '일행',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: MobileTheme.mint,
                                    fontSize: 14,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: MobileTheme.muted,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  currentTarget.name,
                                  key: const ValueKey(
                                    'battle-selected-target-name',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: MobileTheme.ink,
                                    fontSize: 14,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        Text(
                          _event?.title ??
                              (disabled
                                  ? '행동 진행 중'
                                  : '명령 ${_commandPlan.preparedCount(_eligibleActors)}/${_eligibleActors.length} 준비 · 일행을 눌러 선택'),
                          style: const TextStyle(
                            color: MobileTheme.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        for (final line in _event?.lines ?? <String>[])
                          Text(
                            line,
                            style: const TextStyle(
                              color: MobileTheme.ink,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _buildModernCommands(compact: compact),
            ] else if (_resultDefeat)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xffffeeea),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '전투 패배',
                      style: TextStyle(
                        color: MobileTheme.danger,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '일행이 전투 불능 상태가 되었습니다.',
                      style: TextStyle(color: MobileTheme.ink),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FantasyBattleButton(
                        buttonKey: const ValueKey('battle-defeat-continue'),
                        cell: 8,
                        label: '계속',
                        onPressed: () {
                          if (_resultAccepted) return;
                          _resultAccepted = true;
                          widget.onDefeat();
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              _buildVictoryResult(result!),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCommands({required bool compact}) {
    final disabled = _isTurnProcessing || _battleEnded;
    final labels = ['공격', '단일 마법', '전체 마법', '특수 마법', '회복', '초능력'];
    final actions = [
      _onWeaponAttack,
      _onSingleMagicMenu,
      _onAllMagicMenu,
      _onSpecialMagicMenu,
      _onCureMenu,
      _onEspMenu,
    ];
    Widget command(int i) => FantasyBattleButton(
      buttonKey: ValueKey('battle-cmd-${i + 1}'),
      cell: i == 6 ? (isLeaderActive ? 6 : 7) : i,
      label: i == 6
          ? isLeaderActive
                ? '일행 자동 공격'
                : '도주'
          : labels[i],
      onPressed: disabled
          ? null
          : i == 6
          ? _onAutoBattleOrRun
          : actions[i],
    );
    if (compact) {
      return SizedBox(
        height: 52,
        child: Scrollbar(
          controller: _commandScroll,
          thumbVisibility: true,
          thickness: 3,
          child: SingleChildScrollView(
            controller: _commandScroll,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SizedBox(width: 112, height: 48, child: command(i)),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) => Column(
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < 6; i++)
                SizedBox(
                  width: (box.maxWidth - 12) / 3,
                  height: 48,
                  child: command(i),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, height: 48, child: command(6)),
        ],
      ),
    );
  }

  Widget _buildVictoryResult(int gold) => Container(
    key: const ValueKey('battle-victory'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: MobileTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: battleGold),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: battleGold, size: 30),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '승리!',
                style: TextStyle(
                  color: MobileTheme.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '금화 +$gold',
              style: const TextStyle(
                color: MobileTheme.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < widget.partyMembers.length && i < 6; i++)
                  if (widget.partyMembers[i].name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.partyMembers[i].name,
                              style: const TextStyle(color: MobileTheme.ink),
                            ),
                          ),
                          Text(
                            'EXP ${widget.partyMembers[i].experience - _initialSnapshot.party[i].experience >= 0 ? '+' : ''}${widget.partyMembers[i].experience - _initialSnapshot.party[i].experience}',
                            style: const TextStyle(
                              color: MobileTheme.mint,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FantasyBattleButton(
            buttonKey: const ValueKey('battle-result-continue'),
            cell: 8,
            label: '탐험으로 돌아가기',
            onPressed: () {
              final earned = _resultGold;
              if (earned == null) return;
              _resultGold = null;
              widget.onVictory(earned);
            },
          ),
        ),
      ],
    ),
  );

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
    if (!widget.sourceReplay) {
      unawaited(
        _showModernSpells(how, spells, player, onSelected, includeNone),
      );
      return;
    }
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

  Future<void> _showModernSpells(
    int how,
    List<Spell> spells,
    PartyMember player,
    void Function(int) onSelected,
    bool includeNone,
  ) async {
    if (_isCommandPickerOpen) return;
    _isCommandPickerOpen = true;
    final choices = <BattleChoice>[];
    for (var i = 0; i < spells.length; i++) {
      final spell = spells[i];
      final cost = how == 2 || how == 3
          ? LoreBattle.castCost(player.magicLevel, i + 1)
          : spell.baseSp;
      String? unavailable;
      if (i + 1 + (includeNone ? 1 : 0) >
          LoreBattleMenus.maxsum(how, player.magicLevel)) {
        unavailable = '마법 레벨이 부족합니다';
      } else if (how == 4 &&
          !LoreDialogueManager.instance.specialMagicLearned) {
        unavailable = '특수 마법을 아직 배우지 않았습니다';
      } else if (how == 6 &&
          ![2, 3, 6].contains(player.playerClass.id) &&
          !widget.espAccessGranted) {
        unavailable = '초능력을 사용할 수 없는 직업입니다';
      } else if (how == 6 && spell.id != 43 && spell.id != 45) {
        unavailable = '탐험 중에 사용하는 능력입니다';
      } else if ((how == 6 ? player.esp : player.sp) < cost) {
        unavailable = how == 6 ? '초능력이 부족합니다' : 'SP가 부족합니다';
      }
      choices.add(
        BattleChoice(
          spell.name,
          detail: spell.description,
          cost: how == 6
              ? 'ESP $cost'
              : how == 3
              ? '대상당 SP $cost'
              : 'SP $cost',
          unavailable: unavailable,
        ),
      );
    }
    final selected = await showBattleChoiceDialog(
      context,
      title: switch (how) {
        2 => '단일 마법',
        3 => '전체 마법',
        4 => '특수 마법',
        _ => '초능력',
      },
      summary:
          '${player.name} · ${how == 6 ? 'ESP ${player.esp}/${player.maxEsp}' : 'SP ${player.sp}/${player.maxSp}'}',
      choices: choices,
    );
    _isCommandPickerOpen = false;
    if (!mounted || _battleEnded || selected == null) return;
    onSelected(selected + 1 + (includeNone ? 1 : 0));
  }

  /// `DisplayEnemies`: HP 구간별 색, 의식불명은 8, 죽으면 0(보이지 않음).
  Color _getEnemyHpColor(Monster e) {
    final index = LoreEnemyPresentation.color(e);
    // Colour 0 erases the name in the native adapter.
    return index == 0 ? Colors.transparent : RetroTheme.ega(index);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.sourceReplay) return _buildModernBattle(context);
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
            if (_keyWait != null)
              MobileDialogAction(
                key: const ValueKey('battle-continue'),
                label: '계속',
                onPressed: _releaseKeyWait,
              ),
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
  _BattleCureIo(this._view, {List<int>? choices})
    : _choices = choices == null ? null : List.of(choices);

  final _BattleViewportViewState _view;
  final List<int>? _choices;

  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    List<(int, String)> lines = const [],
  }) async {
    if (!_view.mounted) return 0;
    if (_choices != null) return _choices.removeAt(0);
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
    if (!_view.widget.sourceReplay) {
      _view._actionLines
        ..clear()
        ..addAll(lines.map((line) => line.$2).where((text) => text.isNotEmpty));
      _view._battleHistory.addAll(_view._actionLines);
      await _view._presentAction(
        before:
            _view._cureBefore ??
            BattleSnapshot(_view.widget.partyMembers, _view.widget.enemies),
        side: BattleSide.party,
        actor: _view._activePlayerIndex,
        effect: BattleEffect.heal,
        title:
            '${_view.widget.partyMembers[_view._activePlayerIndex].name} · 회복',
      );
      _view._cureBefore = BattleSnapshot(
        _view.widget.partyMembers,
        _view.widget.enemies,
      );
      return;
    }
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
