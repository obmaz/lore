import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';

import '../theme/retro_theme.dart';
import '../services/audio_manager.dart';
import '../game/lore_game.dart';
import '../models/party_member.dart';
import '../models/monster.dart';
import '../widgets/viewport_view.dart';
import '../widgets/party_status_view.dart';
import '../widgets/message_log_view.dart';
import '../widgets/dpad_widget.dart';
import '../widgets/battle_viewport_view.dart';
import '../widgets/town_dialog.dart';
import '../widgets/town_facilities_dialog.dart';
import '../widgets/field_menu_dialog.dart';
import '../services/save_manager.dart';
import '../game/lore_dialogue_manager.dart';

enum GameScreenMode { field, battle, gameOver }

/// 4:3 레트로 콘솔 레이아웃 통합 메인 게임 화면
class MainGameScreen extends StatefulWidget {
  final List<PartyMember>? initialParty;
  final SaveData? initialSaveData;

  const MainGameScreen({
    super.key,
    this.initialParty,
    this.initialSaveData,
  });

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  GameScreenMode _currentMode = GameScreenMode.field;
  late List<PartyMember> _party;
  late LoreGame _game;
  final List<String> _logs = [];
  int _partyGold = 2000;
  int _partyFood = 100;

  // 전투 모드 상태
  List<Monster> _battleEnemies = [];

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initParty();
    _initGame();
  }

  void _initParty() {
    if (widget.initialSaveData != null) {
      _party = List.from(widget.initialSaveData!.party);
      _partyGold = widget.initialSaveData!.gold;
      _partyFood = widget.initialSaveData!.food;
      LoreDialogueManager.instance.loadFlags(widget.initialSaveData!.flags);
    } else {
      _party =
          widget.initialParty ??
          [
            PartyMember.createPreset(1), // Hercules (기사)
            PartyMember.createPreset(3), // Merlin (마법사)
            PartyMember.createPreset(5), // Genius Kie (전사)
            PartyMember.createPreset(6), // Bellatrix (전사)
            PartyMember.createPreset(7), // Regulus (전투승)
          ];
      _partyGold = 2000;
      _partyFood = 100;
    }
  }

  void _initGame() {
    _logs.clear();
    _addLog('또 다른 지식의 성전 제 1 부 (1993 - 2026 Flutter Engine)');
    if (widget.initialSaveData != null) {
      final save = widget.initialSaveData!;
      _addLog('💾 저장된 모험 [${save.slotName}] 을(를) 성공적으로 이어합니다.');
      _addLog('현재 위치: ${save.mapTitle} (${save.playerX}, ${save.playerY})');
    } else {
      _addLog('성전 마을 CASTLE LORE 성내 광장 (51, 31)에 도착했습니다.');
    }
    _addLog('키보드 방향키 또는 화면 우측 하단의 D-Pad로 이동하십시오.');
    _addLog('단단한 성벽은 통과할 수 없으며, 주민(NPC)과 대화하거나 상점을 이용할 수 있습니다.');

    final initialMapId = widget.initialSaveData?.mapId ?? 6;
    final startX = widget.initialSaveData?.playerX ?? 51;
    final startY = widget.initialSaveData?.playerY ?? 31;

    _game = LoreGame(
      initialMapId: initialMapId,
      initialPlayerX: startX,
      initialPlayerY: startY,
      onLog: (msg) => _addLog(msg),
      onEncounter: () => _startBattle(),
      onTownEntered: () => _openTownDialog(),
      onFacilityEntered: (type) {
        TownFacilityType fType;
        switch (type) {
          case 1:
            fType = TownFacilityType.weaponShop;
            break;
          case 2:
            fType = TownFacilityType.hospital;
            break;
          case 3:
            fType = TownFacilityType.trainCenter;
            break;
          case 4:
          default:
            fType = TownFacilityType.grocery;
            break;
        }
        _openTownFacilityDialog(fType);
      },
      onNpcTalk: (name, talk) {
        _addLog('[$name]: "$talk"');
      },
    );
  }

  void _openTownFacilityDialog(TownFacilityType type) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TownFacilitiesDialog(
        facilityType: type,
        party: _party,
        gold: _partyGold,
        food: _partyFood,
        onGoldChanged: (newGold) => setState(() => _partyGold = newGold),
        onFoodChanged: (newFood) => setState(() => _partyFood = newFood),
        onLog: (msg) => _addLog(msg),
      ),
    );
  }

  void _openFieldMenuDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FieldMenuDialog(
        party: _party,
        gold: _partyGold,
        food: _partyFood,
        currentMapId: _game.currentMapId,
        playerX: _game.playerX,
        playerY: _game.playerY,
        onFoodChanged: (newFood) => setState(() => _partyFood = newFood),
        onSaveDataLoaded: (save) {
          setState(() {
            _party = List.from(save.party);
            _partyGold = save.gold;
            _partyFood = save.food;
            _game.loadMapById(save.mapId, startX: save.playerX, startY: save.playerY);
            _addLog('💾 [슬롯 ${save.slot}: ${save.slotName}] 데이터를 성공적으로 불러왔습니다.');
          });
        },
        onLog: (msg) => _addLog(msg),
      ),
    );
  }

  void _openTownDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TownDialog(
        party: _party,
        gold: _partyGold,
        onGoldChanged: (newGold) => setState(() => _partyGold = newGold),
        onLog: (msg) => _addLog(msg),
      ),
    );
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.add(msg);
      if (_logs.length > 80) {
        _logs.removeAt(0);
      }
    });
  }

  /// 필드 인카운터 -> 전투 모드로 전환
  void _startBattle() {
    setState(() {
      _currentMode = GameScreenMode.battle;
      final rnd = Random();
      final count = rnd.nextInt(3) + 1; // 1~3마리
      int minId = 1;
      int maxId = 12;

      // 맵 난이도에 따른 몬스터 ID 풀
      if (_game.currentMapId >= 11 && _game.currentMapId <= 20) {
        minId = 13;
        maxId = 45; // 동굴 던전 몬스터
      } else if (_game.currentMapId >= 21) {
        minId = 40;
        maxId = 72; // 요새/심연 몬스터
      }

      _battleEnemies = List.generate(count, (_) {
        final id = minId + rnd.nextInt(maxId - minId + 1);
        return Monster.create(id);
      });

      _addLog('=== 몬스터 무리가 나타났다! ===');
      for (final e in _battleEnemies) {
        _addLog('${e.name} (Lv.${e.level}, HP:${e.hp}) 등장!');
      }
    });
  }

  /// 전투 승리 -> 필드로 복귀
  void _onBattleVictory(int goldEarned) {
    setState(() {
      _partyGold += goldEarned;
      _currentMode = GameScreenMode.field;
      _addLog('전투 종료. 일행은 필드로 복귀합니다. 보유 금화: $_partyGold');
    });
    _focusNode.requestFocus();
  }

  /// 전투 도망 -> 필드로 복귀
  void _onBattleRunAway() {
    setState(() {
      _currentMode = GameScreenMode.field;
      _addLog('안전한 곳으로 도망쳐 필드로 복귀했습니다.');
    });
    _focusNode.requestFocus();
  }

  /// 전투 패배 -> 게임 오버
  void _onBattleDefeat() {
    AudioManager.instance.stopBgm();
    setState(() {
      _currentMode = GameScreenMode.gameOver;
    });
  }

  void _restartGame() {
    setState(() {
      _initParty();
      _initGame();
      _currentMode = GameScreenMode.field;
    });
    AudioManager.instance.playBgm(BgmTrack.town);
    _focusNode.requestFocus();
  }

  List<PartyMemberStatus> _mapPartyStatus() {
    return _party.map((p) {
      return PartyMemberStatus(
        name: p.name,
        hp: p.hp,
        maxHp: p.maxHp,
        sp: p.sp,
        maxSp: p.maxSp,
        level: p.battleLevel,
        condition: p.condition,
      );
    }).toList();
  }

  Widget _buildViewportContent() {
    switch (_currentMode) {
      case GameScreenMode.field:
        return Stack(
          children: [
            // Flame 2D 타일맵 게임 위젯
            Positioned.fill(child: GameWidget(game: _game)),
            // 좌측 상단 좌표 표시
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: RetroTheme.black.withValues(alpha: 0.7),
                child: Text(
                  '좌표: (${_game.playerX}, ${_game.playerY})',
                  style: RetroTheme.dosFont.copyWith(
                    fontSize: 11,
                    color: RetroTheme.lightCyan,
                  ),
                ),
              ),
            ),
            // 우측 상단 골드 및 오디오 토글 표시
            Positioned(
              top: 6,
              right: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    color: RetroTheme.black.withValues(alpha: 0.7),
                    child: Text(
                      '금화: $_partyGold 개',
                      style: RetroTheme.dosFont.copyWith(
                        fontSize: 11,
                        color: RetroTheme.yellow,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        AudioManager.instance.toggleMute();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      color: RetroTheme.black.withValues(alpha: 0.7),
                      child: Icon(
                        AudioManager.instance.isMuted
                            ? Icons.volume_off
                            : Icons.volume_up,
                        size: 14,
                        color: AudioManager.instance.isMuted
                            ? RetroTheme.lightRed
                            : RetroTheme.lightGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 좌측 하단 [메뉴 (Space)] 버튼
            Positioned(
              bottom: 6,
              left: 6,
              child: GestureDetector(
                onTap: _openFieldMenuDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: RetroTheme.blue.withValues(alpha: 0.8),
                    border: Border.all(color: RetroTheme.cyan, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu, size: 14, color: RetroTheme.yellow),
                      const SizedBox(width: 4),
                      Text(
                        '메뉴 (Space)',
                        style: RetroTheme.dosFont.copyWith(
                          fontSize: 11,
                          color: RetroTheme.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 우측 하단 D-Pad 컨트롤러
            Positioned(
              bottom: 6,
              right: 6,
              child: DPadWidget(
                onDirectionPressed: (dx, dy) {
                  _game.tryMove(dx, dy);
                  setState(() {});
                },
              ),
            ),
          ],
        );

      case GameScreenMode.battle:
        return BattleViewportView(
          partyMembers: _party,
          enemies: _battleEnemies,
          onLog: (msg) => _addLog(msg),
          onVictory: _onBattleVictory,
          onDefeat: _onBattleDefeat,
          onRunAway: _onBattleRunAway,
        );

      case GameScreenMode.gameOver:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.dangerous_outlined,
                size: 54,
                color: RetroTheme.lightRed,
              ),
              const SizedBox(height: 12),
              Text(
                'G A M E   O V E R',
                style: RetroTheme.headerFont.copyWith(
                  color: RetroTheme.lightRed,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '일행은 모험중에 모두 목숨을 잃었다.',
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.white,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RetroTheme.blue,
                  foregroundColor: RetroTheme.white,
                ),
                onPressed: _restartGame,
                child: Text('처음부터 다시 시작', style: RetroTheme.dosFont),
              ),
            ],
          ),
        );
    }
  }

  String _getViewportTitle() {
    switch (_currentMode) {
      case GameScreenMode.field:
        return '◆ 필드 탐험 모드 (FIELD VIEW 10x10) ◆';
      case GameScreenMode.battle:
        return '⚔ 턴제 전투 모드 (BATTLE ARENA) ⚔';
      case GameScreenMode.gameOver:
        return '† 게임 오버 (GAME OVER) †';
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (_currentMode == GameScreenMode.field) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.keyP ||
                event.logicalKey == LogicalKeyboardKey.keyV ||
                event.logicalKey == LogicalKeyboardKey.keyC ||
                event.logicalKey == LogicalKeyboardKey.keyR) {
              _openFieldMenuDialog();
              return;
            }
          }
          _game.handleKeyEvent(event);
          setState(() {});
        }
      },
      child: Scaffold(
        backgroundColor: RetroTheme.black,
        body: SafeArea(
          child: Center(
            child: AspectRatio(
              aspectRatio: 4 / 3, // 4:3 고정 종횡비 레트로 콘솔 스타일
              child: Container(
                margin: const EdgeInsets.all(6.0),
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: RetroTheme.background,
                  border: Border.all(color: RetroTheme.darkGray, width: 3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    // 상단 영역 (메인 뷰포트 + 파티 상태창)
                    Expanded(
                      flex: 68,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 왼쪽 상단: 메인 뷰포트
                          Expanded(
                            flex: 62,
                            child: ViewportView(
                              title: _getViewportTitle(),
                              content: _buildViewportContent(),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 오른쪽 상단: 파티원 상태창
                          Expanded(
                            flex: 38,
                            child: PartyStatusView(members: _mapPartyStatus()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 하단 영역: 3~4줄 분량 메시지 로그 스크롤 영역
                    Expanded(flex: 32, child: MessageLogView(logs: _logs)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
