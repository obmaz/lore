import 'package:flutter/material.dart';
import '../theme/retro_theme.dart';
import '../services/audio_manager.dart';
import '../models/monster.dart';
import '../models/party_member.dart';
import '../logic/battle_engine.dart';

/// 1993년 원작 LOREBATT.PAS 기반 턴제 전투 뷰포트 위젯
class BattleViewportView extends StatefulWidget {
  final List<PartyMember> partyMembers;
  final List<Monster> enemies;
  final void Function(String message) onLog;
  final void Function(int goldEarned) onVictory;
  final VoidCallback onDefeat;
  final VoidCallback onRunAway;

  const BattleViewportView({
    super.key,
    required this.partyMembers,
    required this.enemies,
    required this.onLog,
    required this.onVictory,
    required this.onDefeat,
    required this.onRunAway,
  });

  @override
  State<BattleViewportView> createState() => _BattleViewportViewState();
}

class _BattleViewportViewState extends State<BattleViewportView> {
  final BattleEngine _engine = BattleEngine();
  int _selectedEnemyIndex = 0;
  bool _isTurnProcessing = false;
  bool _battleEnded = false;

  Monster get currentTarget => widget.enemies[_selectedEnemyIndex];

  PartyMember? get activePlayer {
    for (final member in widget.partyMembers) {
      if (member.canAct) return member;
    }
    return null;
  }

  void _checkBattleEnd() {
    // 1. 모든 적 퇴치 확인
    final allEnemiesDefeated = widget.enemies.every((e) => e.isDead || e.isUnconscious);
    if (allEnemiesDefeated) {
      _battleEnded = true;
      final gold = _engine.calculateGold(widget.enemies);
      widget.onLog('★ 전투에서 승리했습니다! ★');
      widget.onLog('일행은 금화 $gold 개를 획득했습니다.');
      widget.onVictory(gold);
      return;
    }

    // 2. 파티원 전멸 확인
    final allPartyDefeated = widget.partyMembers.every((p) => !p.canAct);
    if (allPartyDefeated) {
      _battleEnded = true;
      widget.onLog('† 일행은 모험중에 모두 목숨을 잃었다... GAME OVER †');
      widget.onDefeat();
      return;
    }
  }

  /// 적의 반격 턴 (Enemy Turn)
  Future<void> _enemyTurn() async {
    setState(() => _isTurnProcessing = true);
    await Future.delayed(const Duration(milliseconds: 350));

    for (final enemy in widget.enemies) {
      if (enemy.isDead || enemy.isUnconscious) continue;

      // 생존한 파티원 중 무작위 1명 대상 선택
      final livingMembers = widget.partyMembers.where((p) => p.isAlive).toList();
      if (livingMembers.isEmpty) break;

      final target = livingMembers[DateTime.now().millisecondsSinceEpoch % livingMembers.length];
      final res = _engine.executeEnemyWeaponAttack(enemy, target);
      widget.onLog(res.message);

      if (res.outcome == AttackOutcome.hit) {
        AudioManager.instance.playHit();
      } else if (res.outcome == AttackOutcome.killed) {
        AudioManager.instance.playScream2();
      } else if (res.outcome == AttackOutcome.unconscious) {
        AudioManager.instance.playScream1();
      }

      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (mounted) {
      setState(() => _isTurnProcessing = false);
      _checkBattleEnd();
    }
  }

  /// 플레이어 무기 공격 실행
  void _onAttack() async {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;

    setState(() => _isTurnProcessing = true);

    widget.onLog('${player.name}의 일반 무기 공격 시작!');
    final res = _engine.executePlayerWeaponAttack(player, currentTarget);
    widget.onLog(res.message);

    if (res.outcome == AttackOutcome.hit) {
      AudioManager.instance.playHit();
    } else if (res.outcome == AttackOutcome.killed) {
      AudioManager.instance.playHit();
      Future.delayed(const Duration(milliseconds: 150), () => AudioManager.instance.playScream2());
    } else if (res.outcome == AttackOutcome.unconscious) {
      AudioManager.instance.playHit();
      Future.delayed(const Duration(milliseconds: 150), () => AudioManager.instance.playScream1());
    }

    // 타겟이 쓰러졌으면 다음 생존한 적으로 자동 타겟 변경
    if (currentTarget.isDead || currentTarget.isUnconscious) {
      for (int i = 0; i < widget.enemies.length; i++) {
        if (!widget.enemies[i].isDead && !widget.enemies[i].isUnconscious) {
          _selectedEnemyIndex = i;
          break;
        }
      }
    }

    _checkBattleEnd();
    if (!_battleEnded) {
      await _enemyTurn();
    } else {
      setState(() => _isTurnProcessing = false);
    }
  }

  /// 플레이어 마법 공격 실행 (1번 마법 시전)
  void _onMagic() async {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer;
    if (player == null) return;

    setState(() => _isTurnProcessing = true);

    widget.onLog('${player.name}의 마법 화살(Magic Arrow) 시전!');
    final res = _engine.executePlayerMagicAttack(player, currentTarget, 1);
    widget.onLog(res.message);

    if (res.outcome == AttackOutcome.hit) {
      AudioManager.instance.playHit();
    } else if (res.outcome == AttackOutcome.killed) {
      AudioManager.instance.playHit();
      Future.delayed(const Duration(milliseconds: 150), () => AudioManager.instance.playScream2());
    }

    if (res.outcome != AttackOutcome.outOfSp) {
      _checkBattleEnd();
      if (!_battleEnded) {
        await _enemyTurn();
      } else {
        setState(() => _isTurnProcessing = false);
      }
    } else {
      setState(() => _isTurnProcessing = false);
    }
  }

  /// 도구 사용
  void _onItem() {
    if (_isTurnProcessing || _battleEnded) return;
    widget.onLog('소지품을 확인했습니다. 현재 사용할 수 있는 전투 도구가 없습니다.');
  }

  /// 도망 시도
  void _onRunAway() async {
    if (_isTurnProcessing || _battleEnded) return;
    final player = activePlayer ?? widget.partyMembers.first;

    setState(() => _isTurnProcessing = true);
    widget.onLog('${player.name}이(가) 도망을 시도합니다...');

    final success = _engine.checkRunAway(player);
    await Future.delayed(const Duration(milliseconds: 250));

    if (success) {
      widget.onLog('일행은 성공적으로 도망쳤습니다!');
      widget.onRunAway();
    } else {
      widget.onLog('그러나 도망치지 못했습니다!');
      await _enemyTurn();
    }
    if (mounted) setState(() => _isTurnProcessing = false);
  }

  Color _getEnemyHpColor(Monster e) {
    if (e.isDead) return RetroTheme.darkGray;
    if (e.isUnconscious) return RetroTheme.yellow;
    final ratio = e.hp / e.maxHp;
    if (ratio <= 0.25) return RetroTheme.lightRed;
    if (ratio <= 0.6) return RetroTheme.yellow;
    return RetroTheme.lightGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. 전투 장면 (몬스터 표시 영역)
        Expanded(
          flex: 65,
          child: Container(
            color: RetroTheme.viewportBg,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // 왼쪽: 몬스터 목록 선택
                Expanded(
                  flex: 5,
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? RetroTheme.blue.withValues(alpha: 0.6)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? RetroTheme.yellow : Colors.transparent,
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
                                      : (isSelected ? RetroTheme.yellow : RetroTheme.white),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                enemy.isDead
                                    ? '[사망]'
                                    : (enemy.isUnconscious ? '[기절]' : '${enemy.hp}/${enemy.maxHp}'),
                                style: RetroTheme.dosFont.copyWith(
                                  color: hpColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // 오른쪽: 대상 몬스터 픽셀 그래픽/도트 아바타 박스
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: RetroTheme.borderColor, width: 1),
                      color: RetroTheme.black,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pest_control_outlined,
                            size: 44,
                            color: currentTarget.isDead
                                ? RetroTheme.darkGray
                                : (currentTarget.isUnconscious
                                    ? RetroTheme.yellow
                                    : RetroTheme.lightRed),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currentTarget.name,
                            style: RetroTheme.headerFont.copyWith(fontSize: 14),
                          ),
                          Text(
                            currentTarget.isDead
                                ? '상태: 사망'
                                : (currentTarget.isUnconscious ? '상태: 의식불명' : '상태: 전투중'),
                            style: RetroTheme.dosFont.copyWith(
                              color: _getEnemyHpColor(currentTarget),
                              fontSize: 11,
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

        // 2. 전투 커맨드 조작 버튼부
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: const BoxDecoration(
            color: RetroTheme.panelBg,
            border: Border(top: BorderSide(color: RetroTheme.borderColor, width: 1.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBattleButton('공격 [A]', RetroTheme.lightRed, _onAttack),
              _buildBattleButton('마법 [M]', RetroTheme.lightBlue, _onMagic),
              _buildBattleButton('도구 [I]', RetroTheme.lightGreen, _onItem),
              _buildBattleButton('도망 [R]', RetroTheme.yellow, _onRunAway),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBattleButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: RetroTheme.background,
        foregroundColor: color,
        side: BorderSide(color: color, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      onPressed: _isTurnProcessing || _battleEnded ? null : onPressed,
      child: Text(
        label,
        style: RetroTheme.dosFont.copyWith(
          color: _isTurnProcessing || _battleEnded ? RetroTheme.darkGray : color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
