import 'dart:math';

import '../logic/lore_batt_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/retro_theme.dart';
import '../services/audio_manager.dart';
import '../models/monster.dart';
import '../models/party_member.dart';
import '../models/spell.dart';
import '../data/lore_data.dart';
import '../logic/battle_engine.dart';
import '../game/lore_dialogue_manager.dart';

/// 1993년 원작 LOREBATT.PAS 기반 턴제 전투 뷰포트 위젯
/// - 7대 전투 커맨드 ([1]무기, [2]단일마법, [3]전체마법, [4]특수마법, [5]일행치료, [6]초능력, [7]자동전투/도망)
/// - 45종 전체 마법 체계 및 ESP 연동
/// - 몬스터 풀 AI (전체마법, 동료치료, 독/치명타/즉사 특수공격)
/// - 파티 리더의 무조건 공격 지시 (자동 전투 모드)
class BattleViewportView extends StatefulWidget {
  final List<PartyMember> partyMembers;
  final List<Monster> enemies;
  final BattleEngine? battleEngine;
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
    this.battleEngine,
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
  late final BattleEngine _engine;
  int _selectedEnemyIndex = 0;
  int _activePlayerIndex = 0;
  bool _isTurnProcessing = false;
  bool _battleEnded = false;
  bool _isAutoBattle = false;

  final FocusNode _focusNode = FocusNode();

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
    _engine = widget.battleEngine ?? BattleEngine();
    _selectFirstAliveTarget();
  }

  @override
  void dispose() {
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

  void _checkBattleEnd() {
    if (_battleEnded) return;

    // 1. 모든 적 퇴치 확인
    final allEnemiesDefeated = widget.enemies.every(
      (e) => e.isDead || e.isUnconscious,
    );
    if (allEnemiesDefeated) {
      _battleEnded = true;
      _isAutoBattle = false;
      final gold = _engine.calculateGold(widget.enemies);
      widget.onLog('★ 전투에서 승리했습니다! ★');
      widget.onLog('일행은 금화 $gold 개를 획득했습니다.');
      widget.onVictory(gold);
      return;
    }

    // 2. 파티원 전멸 확인
    final allPartyDefeated = widget.partyMembers.every(
      (p) => !p.isBattleActive,
    );
    if (allPartyDefeated) {
      _battleEnded = true;
      _isAutoBattle = false;
      widget.onLog('† 일행은 모험중에 모두 목숨을 잃었다... GAME OVER †');
      widget.onDefeat();
      return;
    }
  }

  /// 다음 행동 가능한 파티원으로 순환하거나 몬스터 턴 진행
  Future<void> _advanceTurn() async {
    _checkBattleEnd();
    if (_battleEnded) {
      setState(() => _isTurnProcessing = false);
      return;
    }

    int nextIdx = _activePlayerIndex + 1;
    while (nextIdx < widget.partyMembers.length &&
        !widget.partyMembers[nextIdx].isBattleActive) {
      nextIdx++;
    }

    if (nextIdx < widget.partyMembers.length) {
      // 다음 파티원 행동
      setState(() {
        _activePlayerIndex = nextIdx;
        _isTurnProcessing = false;
      });
      if (_isAutoBattle) {
        await Future.delayed(const Duration(milliseconds: 200));
        _executeAutoAction();
      }
    } else {
      // 파티원 턴 종료 -> 몬스터 반격 턴 시작
      _activePlayerIndex = 0;
      await _enemyTurn();

      if (!_battleEnded) {
        // 첫 번째 행동 가능 파티원 찾기
        for (int i = 0; i < widget.partyMembers.length; i++) {
          if (widget.partyMembers[i].isBattleActive) {
            _activePlayerIndex = i;
            break;
          }
        }
        if (mounted) {
          setState(() => _isTurnProcessing = false);
          if (_isAutoBattle) {
            await Future.delayed(const Duration(milliseconds: 200));
            _executeAutoAction();
          }
        }
      }
    }
  }

  /// 적의 반격 턴 (Enemy Turn)
  Future<void> _enemyTurn() async {
    setState(() => _isTurnProcessing = true);
    await Future.delayed(const Duration(milliseconds: 300));

    // 원본의 `for person := 1 to enemynumber`는 턴 시작 시의 상한을 쓴다.
    // 행동 중 소환된 적은 다음 턴부터 행동하며 리스트 변경도 안전하게 처리한다.
    final enemyTurnCount = widget.enemies.length;
    for (var index = 0; index < enemyTurnCount; index++) {
      final enemy = widget.enemies[index];
      if (enemy.isDead || enemy.isUnconscious) continue;
      if (widget.partyMembers.every((p) => !p.isBattleActive)) break;

      final results = _engine.executeMonsterTurn(
        enemy,
        widget.partyMembers,
        widget.enemies,
      );
      for (final res in results) {
        widget.onLog(res.message);
        if (res.outcome == AttackOutcome.hit) {
          AudioManager.instance.playHit();
        } else if (res.outcome == AttackOutcome.killed) {
          AudioManager.instance.playScream2();
        } else if (res.outcome == AttackOutcome.unconscious) {
          AudioManager.instance.playScream1();
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    _checkBattleEnd();
  }

  // ==========================================
  // [1] 무기 공격
  // ==========================================
  void _onWeaponAttack() async {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;

    setState(() => _isTurnProcessing = true);

    widget.onLog('${player.name}의 무기 공격!');
    final res = _engine.executePlayerWeaponAttack(
      player,
      currentTarget,
      party: widget.partyMembers,
    );
    widget.onLog(res.message);

    _playAttackSound(res);
    _reTargetIfDead();

    await _advanceTurn();
  }

  // ==========================================
  // [2] 단일 마법 공격 (1..6)
  // ==========================================
  void _onSingleMagicMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;

    final singleSpells = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.singleAttack)
        .toList();
    _showSpellDialog('단일 마법 공격', singleSpells, player, (spell) {
      _executeSingleMagic(player, spell);
    });
  }

  void _executeSingleMagic(PartyMember player, Spell spell) async {
    setState(() => _isTurnProcessing = true);

    widget.onLog('${player.name}의 \'${spell.name}\' 시전!');
    final res = _engine.executePlayerSingleMagicAttack(
      player,
      currentTarget,
      spell.id,
      party: widget.partyMembers,
    );
    widget.onLog(res.message);

    _playAttackSound(res);
    _reTargetIfDead();

    await _advanceTurn();
  }

  // ==========================================
  // [3] 모든 적 마법 공격 (7..12)
  // ==========================================
  void _onAllMagicMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;

    final allSpells = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.allAttack)
        .toList();
    _showSpellDialog('전체 마법 공격', allSpells, player, (spell) {
      _executeAllMagic(player, spell);
    });
  }

  void _executeAllMagic(PartyMember player, Spell spell) async {
    setState(() => _isTurnProcessing = true);

    widget.onLog('${player.name}의 전체 마법 \'${spell.name}\' 작열!');
    final results = _engine.executePlayerAllMagicAttack(
      player,
      widget.enemies,
      spell.id,
      party: widget.partyMembers,
    );

    for (final res in results) {
      widget.onLog(res.message);
      _playAttackSound(res);
      await Future.delayed(const Duration(milliseconds: 150));
    }
    _reTargetIfDead();

    await _advanceTurn();
  }

  // ==========================================
  // [4] 적 특수 마법 공격 (13..18)
  // ==========================================
  void _onSpecialMagicMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;

    final specialSpells = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.specialDebuff)
        .toList();
    _showSpellDialog('적 특수 디버프 마법', specialSpells, player, (spell) {
      _executeSpecialMagic(player, spell);
    });
  }

  void _executeSpecialMagic(PartyMember player, Spell spell) async {
    // 원작 LOREBATT.PAS:245 CastSpecial -
    // Red Antares에게 "간접 공격"을 배우기 전에는 특수 마법을 쓸 수 없다.
    if (!LoreDialogueManager.instance.specialMagicLearned) {
      widget.onLog(
        '${player.name}: ${LoreDialogueManager.specialMagicLockedMessage}',
      );
      widget.onLog('(NOTICE 동굴 (75,52)의 Red Antares를 만나 특수 마법을 배워야 합니다)');
      return;
    }

    setState(() => _isTurnProcessing = true);

    widget.onLog(
      '${player.name}이(가) ${currentTarget.name}에게 \'${spell.name}\' 시전!',
    );
    final res = _engine.executePlayerSpecialDebuff(
      player,
      currentTarget,
      spell.id,
    );
    widget.onLog(res.message);

    if (res.outcome == AttackOutcome.debuffed) {
      AudioManager.instance.playHit();
    }

    await _advanceTurn();
  }

  // ==========================================
  // [5] 일행 치료 (19..32)
  // ==========================================
  void _onCureMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;

    // 아군 대상 선택 다이얼로그
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.black,
        shape: Border.all(color: RetroTheme.lightGreen, width: 2),
        title: Text(
          '치료 대상 선택',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 13,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...widget.partyMembers.map((m) {
              return ListTile(
                dense: true,
                title: Text(
                  '${m.name} (HP: ${m.hp}/${m.maxHp})',
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.white,
                    fontSize: 11,
                  ),
                ),
                subtitle: Text(
                  m.isDead
                      ? '[사망]'
                      : (m.isUnconscious
                            ? '[기절]'
                            : (m.poison > 0 ? '[독]' : '[정상]')),
                  style: RetroTheme.dosFont.copyWith(
                    color: m.isDead
                        ? RetroTheme.lightRed
                        : RetroTheme.lightCyan,
                    fontSize: 10,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSingleCureSpells(player, m);
                },
              );
            }),
            const Divider(color: RetroTheme.lightGray),
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.group,
                color: RetroTheme.yellow,
                size: 20,
              ),
              title: Text(
                '모든 사람들에게 (전체 치료)',
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.yellow,
                  fontSize: 11,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showAllCureSpells(player);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSingleCureSpells(PartyMember caster, PartyMember target) {
    final singleCure = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.singleCure)
        .toList();
    _showSpellDialog('${target.name}에게 치료 시전', singleCure, caster, (spell) {
      _executeCure(caster, target, spell);
    });
  }

  void _showAllCureSpells(PartyMember caster) {
    final allCure = LoreData.instance.spells
        .where((s) => s.category == SpellCategory.allCure)
        .toList();
    _showSpellDialog('일행 전체 치료 시전', allCure, caster, (spell) {
      _executeCureAll(caster, spell);
    });
  }

  void _executeCure(PartyMember caster, PartyMember target, Spell spell) async {
    setState(() => _isTurnProcessing = true);

    widget.onLog('${caster.name}이(가) ${target.name}에게 \'${spell.name}\' 사용!');
    final res = _engine.executePlayerCure(caster, target, spell.id);
    widget.onLog(res.message);

    await _advanceTurn();
  }

  void _executeCureAll(PartyMember caster, Spell spell) async {
    setState(() => _isTurnProcessing = true);

    widget.onLog('${caster.name}의 전체 치료 \'${spell.name}\' 시전!');
    for (final member in widget.partyMembers) {
      final res = _engine.executePlayerCure(caster, member, spell.id);
      widget.onLog(res.message);
    }

    await _advanceTurn();
  }

  // ==========================================
  // [6] 초능력 사용 (ESP: 43 독심술, 45 염력)
  // ==========================================
  void _onEspMenu() {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;

    final battleEsp = LoreData.instance.spells
        .where((s) => s.id == 43 || s.id == 45)
        .toList();
    _showSpellDialog('초능력 (ESP) 시전', battleEsp, player, (spell) {
      _executeEsp(player, spell);
    });
  }

  void _executeEsp(PartyMember player, Spell spell) async {
    setState(() => _isTurnProcessing = true);

    widget.onLog('${player.name}의 초능력 \'${spell.name}\' 발동!');
    final target = currentTarget;
    final res = _engine.executePlayerESP(
      player,
      target,
      spell.id,
      widget.partyMembers,
      enemies: widget.enemies,
      espAccessGranted: widget.espAccessGranted,
    );
    widget.onLog(res.message);
    if (res.outcome == AttackOutcome.joined) {
      widget.onTelepathyJoin(target.eNumber);
    }

    _playAttackSound(res);
    _reTargetIfDead();

    await _advanceTurn();
  }

  // ==========================================
  // [7] 자동 전투 / 도망
  // ==========================================
  void _onAutoBattleOrRun() {
    if (_isTurnProcessing || _battleEnded) return;

    if (isLeaderActive) {
      // 파티 리더: 자동 전투 토글
      setState(() {
        _isAutoBattle = !_isAutoBattle;
      });
      if (_isAutoBattle) {
        // 원작 LOREBATT.PAS:1228 - `{이름}의 전투 모드 ===>` / `일행에게 무조건
        // 공격 할 것을 지시`
        widget.onLog(
          '${widget.partyMembers.first.name}'
          '${LoreBattText.battleMode}'
          '${LoreBattText.menuCommandAll}',
        );
        _executeAutoAction();
      } else {
        widget.onLog('⚔ 자동 전투를 중지하고 일반 전투 모드로 전환합니다.');
      }
    } else {
      // 일반 파티원: 도망 시도
      _attemptRunAway();
    }
  }

  void _attemptRunAway() async {
    final player = activePlayer ?? widget.partyMembers.first;
    setState(() => _isTurnProcessing = true);

    // 원작 LOREBATT.PAS:79-88 - `{이름}은 도망간다` / 실패 시 `그러나,
    // 일행은 성공하지 못했다`
    widget.onLog('${player.name}${LoreBattText.flee}');
    final success = _engine.checkRunAway(player);
    await Future.delayed(const Duration(milliseconds: 250));

    if (success) {
      widget.onRunAway();
    } else {
      widget.onLog(LoreBattText.runFailed);
      await _advanceTurn();
    }
  }

  /// 원작 LOREBATT.PAS 1037-1066행 기반 자동 전투 액션
  void _executeAutoAction() async {
    if (!_isAutoBattle || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;

    _reTargetIfDead();

    // 직업별 자동 행동:
    // 전사 계열: 무기 공격
    // 마법사 계열(SP 충분 시): 단일 마법 공격
    // 초능력자(ESP 충분 시): 염력 공격
    if ((player.playerClass == PlayerClass.mage ||
            player.playerClass == PlayerClass.ghost) &&
        player.sp >= 4) {
      int spellId = min(6, max(1, player.magicLevel ~/ 2));
      _executeSingleMagic(player, LoreData.instance.spell(spellId));
    } else if (player.playerClass == PlayerClass.esper && player.esp >= 20) {
      _executeEsp(player, LoreData.instance.spell(45)); // 염력
    } else {
      _onWeaponAttack();
    }
  }

  // ==========================================
  // 헬퍼 및 UI 다이얼로그
  // ==========================================
  void _showSpellDialog(
    String title,
    List<Spell> spells,
    PartyMember player,
    void Function(Spell spell) onSelected,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.black,
        shape: Border.all(color: RetroTheme.lightMagenta, width: 2),
        title: Text(
          '$title (SP: ${player.sp} / ESP: ${player.esp})',
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
              final cost = sp.calculateSpCost(
                sp.category == SpellCategory.esp
                    ? player.espLevel
                    : player.magicLevel,
              );
              final isAvailable = sp.isAvailableForLevel(
                player.magicLevel,
                player.espLevel,
              );
              final executionIsFree = switch (sp.category) {
                SpellCategory.singleAttack => currentTarget.isUnconscious,
                SpellCategory.allAttack => widget.enemies.every(
                  (enemy) => enemy.isDead || enemy.isUnconscious,
                ),
                _ => false,
              };
              final canAfford = sp.category == SpellCategory.esp
                  ? player.esp >= cost
                  : executionIsFree || player.sp >= cost;
              final canCast = isAvailable && canAfford;

              return ListTile(
                dense: true,
                title: Text(
                  sp.name,
                  style: RetroTheme.dosFont.copyWith(
                    color: canCast ? RetroTheme.white : RetroTheme.darkGray,
                    fontSize: 11,
                  ),
                ),
                subtitle: Text(
                  sp.description,
                  style: RetroTheme.dosFont.copyWith(
                    color: canCast ? RetroTheme.lightGray : RetroTheme.darkGray,
                    fontSize: 9,
                  ),
                ),
                trailing: Text(
                  !isAvailable
                      ? 'Lv부족'
                      : (sp.category == SpellCategory.esp
                            ? 'ESP $cost'
                            : executionIsFree
                            ? 'SP 0'
                            : sp.category == SpellCategory.allAttack
                            ? 'SP $cost/적'
                            : 'SP $cost'),
                  style: RetroTheme.dosFont.copyWith(
                    color: canCast ? RetroTheme.lightCyan : RetroTheme.lightRed,
                    fontSize: 10,
                  ),
                ),
                onTap: canCast
                    ? () {
                        Navigator.of(ctx).pop();
                        onSelected(sp);
                      }
                    : null,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _playAttackSound(AttackResult res) {
    if (res.outcome == AttackOutcome.hit) {
      AudioManager.instance.playHit();
    } else if (res.outcome == AttackOutcome.killed) {
      AudioManager.instance.playHit();
      Future.delayed(
        const Duration(milliseconds: 150),
        () => AudioManager.instance.playScream2(),
      );
    } else if (res.outcome == AttackOutcome.unconscious) {
      AudioManager.instance.playHit();
      Future.delayed(
        const Duration(milliseconds: 150),
        () => AudioManager.instance.playScream1(),
      );
    }
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

  Color _getEnemyHpColor(Monster e) {
    if (e.isDead) return RetroTheme.darkGray;
    if (e.isUnconscious) return RetroTheme.yellow;
    final ratio = e.hp / (e.maxHp <= 0 ? 1 : e.maxHp);
    if (ratio <= 0.25) return RetroTheme.lightRed;
    if (ratio <= 0.6) return RetroTheme.yellow;
    return RetroTheme.lightGreen;
  }

  @override
  Widget build(BuildContext context) {
    final player = activePlayer;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
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
      child: Column(
        children: [
          // 자동 전투 실행 중 안내 배너
          if (_isAutoBattle)
            InkWell(
              onTap: () => setState(() => _isAutoBattle = false),
              child: Container(
                width: double.infinity,
                color: RetroTheme.lightRed,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '⚔ 자동 전투 진행 중... [터치하여 수동 모드로 복귀]',
                  textAlign: TextAlign.center,
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // 1. 전투 장면 (몬스터 목록 및 타겟 상세 박스)
          Expanded(
            flex: 60,
            child: Container(
              color: RetroTheme.viewportBg,
              padding: const EdgeInsets.all(6.0),
              child: Row(
                children: [
                  // 왼쪽: 몬스터 목록
                  Expanded(
                    flex: 6,
                    child: ListView.builder(
                      itemCount: widget.enemies.length,
                      itemBuilder: (context, idx) {
                        final enemy = widget.enemies[idx];
                        final isSelected = idx == _selectedEnemyIndex;
                        final hpColor = _getEnemyHpColor(enemy);

                        return GestureDetector(
                          onTap: () {
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
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? RetroTheme.blue.withValues(alpha: 0.6)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? RetroTheme.yellow
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${isSelected ? '▶ ' : '   '}${enemy.name} Lv.${enemy.level}',
                                  style: RetroTheme.dosFont.copyWith(
                                    color: enemy.isDead
                                        ? RetroTheme.darkGray
                                        : (isSelected
                                              ? RetroTheme.yellow
                                              : RetroTheme.white),
                                    fontSize: 11,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (enemy.isPoisoned)
                                      Text(
                                        '[독] ',
                                        style: RetroTheme.dosFont.copyWith(
                                          color: RetroTheme.green,
                                          fontSize: 10,
                                        ),
                                      ),
                                    Text(
                                      enemy.isDead
                                          ? '[사망]'
                                          : (enemy.isUnconscious
                                                ? '[기절]'
                                                : '${enemy.hp}/${enemy.maxHp}'),
                                      style: RetroTheme.dosFont.copyWith(
                                        color: hpColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 오른쪽: 타겟 몬스터 상세
                  Expanded(
                    flex: 4,
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: RetroTheme.borderColor,
                          width: 1,
                        ),
                        color: RetroTheme.black,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pest_control_outlined,
                              size: 40,
                              color: currentTarget.isDead
                                  ? RetroTheme.darkGray
                                  : (currentTarget.isUnconscious
                                        ? RetroTheme.yellow
                                        : RetroTheme.lightRed),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentTarget.name,
                              style: RetroTheme.headerFont.copyWith(
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              currentTarget.isDead
                                  ? '상태: 사망'
                                  : (currentTarget.isUnconscious
                                        ? '상태: 의식불명'
                                        : 'HP: ${currentTarget.hp}/${currentTarget.maxHp}'),
                              style: RetroTheme.dosFont.copyWith(
                                color: _getEnemyHpColor(currentTarget),
                                fontSize: 10,
                              ),
                            ),
                            if (currentTarget.isPoisoned)
                              Text(
                                '중독 상태',
                                style: RetroTheme.dosFont.copyWith(
                                  color: RetroTheme.green,
                                  fontSize: 9,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. 현재 행동 파티원 상태 배너
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: RetroTheme.panelBg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  player != null ? '▶ [${player.name}] 의 전투 턴' : '행동 대기 중...',
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.yellow,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (player != null)
                  Text(
                    'HP: ${player.hp}/${player.maxHp} | SP: ${player.sp}/${player.maxSp} | ESP: ${player.esp}/${player.maxEsp}',
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.lightCyan,
                      fontSize: 10,
                    ),
                  ),
              ],
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
                _buildCmdButton('1.무기공격', RetroTheme.lightRed, _onWeaponAttack),
                _buildCmdButton(
                  '2.단일마법',
                  RetroTheme.lightBlue,
                  _onSingleMagicMenu,
                ),
                _buildCmdButton(
                  '3.전체마법',
                  RetroTheme.lightCyan,
                  _onAllMagicMenu,
                ),
                _buildCmdButton(
                  '4.특수마법',
                  RetroTheme.lightMagenta,
                  _onSpecialMagicMenu,
                ),
                _buildCmdButton('5.일행치료', RetroTheme.lightGreen, _onCureMenu),
                _buildCmdButton('6.초능력', RetroTheme.yellow, _onEspMenu),
                _buildCmdButton(
                  isLeaderActive
                      ? (_isAutoBattle ? '7.자동중지' : '7.자동전투')
                      : '7.도망시도',
                  _isAutoBattle ? RetroTheme.lightRed : RetroTheme.white,
                  _onAutoBattleOrRun,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCmdButton(String label, Color color, VoidCallback onPressed) {
    final disabled = _isTurnProcessing || _battleEnded;
    return ElevatedButton(
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
