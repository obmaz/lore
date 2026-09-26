import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';

import '../theme/retro_theme.dart';
import '../services/audio_manager.dart';
import '../game/lore_game.dart';
import '../game/lore_world_manager.dart';
import '../logic/field_hotkeys.dart';
import '../logic/lore_sub_text.dart';
import '../logic/lore_field_logic.dart';
import '../logic/lore_join.dart';
import '../models/party_member.dart';
import '../models/monster.dart';
import '../data/lore_data.dart';
import '../data/lore_script.dart';
import '../widgets/viewport_view.dart';
import '../widgets/party_status_view.dart';
import '../widgets/message_log_view.dart';
import '../widgets/dpad_widget.dart';
import '../widgets/battle_viewport_view.dart';
import '../widgets/town_dialog.dart';
import '../widgets/town_facilities_dialog.dart';
import '../widgets/field_menu_dialog.dart';
import '../widgets/quick_view_dialog.dart';
import '../widgets/esp_dialog.dart';
import '../game/lore_map_manager.dart';
import '../services/save_manager.dart';
import '../game/lore_dialogue_manager.dart';
import '../game/lore_dungeon_event_manager.dart';
import '../widgets/lore_guide_dialog.dart';

enum GameScreenMode { field, battle, gameOver }

/// 4:3 레트로 콘솔 레이아웃 통합 메인 게임 화면
class MainGameScreen extends StatefulWidget {
  final List<PartyMember>? initialParty;
  final SaveData? initialSaveData;

  const MainGameScreen({super.key, this.initialParty, this.initialSaveData});

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  GameScreenMode _currentMode = GameScreenMode.field;
  late List<PartyMember> _party;
  late LoreGame _game;
  final List<String> _logs = [];
  int _partyGold = 2000;
  int _partyFood = 20; // 원작 LORECRET.PAS `Last`: food := 20;

  // 원작 LOREMAIN.PAS: 환경 효과 및 보조 마법 지속 걸음수
  int _torchSteps = 0; // etc[1]: 마법의 횃불
  int _waterWalkSteps = 0; // etc[2]: 물위를 걸음
  int _swampWalkSteps = 0; // etc[3]: 늪위를 걸음
  int _levitateSteps = 0; // etc[4]: 공중 부상

  /// 카메라 연출(원작 scroll(FALSE)) 한 장면을 보여주는 시간.
  /// 원작의 `PressAnyKey` 를 현대적으로 대체한 것이다.
  static const Duration _peekHold = Duration(milliseconds: 1600);
  int _mindReadCount = 0; // etc[5]: 독심술

  /// 스크립트 전투 승리 시 설정할 플래그 (원작 `party.etc[6] = 0` 처리).
  final List<String> _pendingVictoryFlags = [];

  // 전투 모드 상태
  List<Monster> _battleEnemies = [];
  String? _currentBossName;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initParty();
    _initGame();
    // 화면 진입 직후 키보드 포커스를 게임으로 가져온다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reclaimFocus());
  }

  /// 버튼/대화상자 조작 뒤 키보드 입력이 게임으로 돌아오게 한다.
  void _reclaimFocus() {
    if (mounted && !_focusNode.hasFocus) _focusNode.requestFocus();
  }

  void _initParty() {
    if (widget.initialSaveData != null) {
      _party = List.from(widget.initialSaveData!.party);
      _partyGold = widget.initialSaveData!.gold;
      _partyFood = widget.initialSaveData!.food;
      LoreDialogueManager.instance.loadFlags(widget.initialSaveData!.flags);
      final etc = widget.initialSaveData!.etc;
      _torchSteps = etc['torchSteps'] ?? 0;
      _waterWalkSteps = etc['waterWalkSteps'] ?? 0;
      _swampWalkSteps = etc['swampWalkSteps'] ?? 0;
      _levitateSteps = etc['levitateSteps'] ?? 0;
      _mindReadCount = etc['mindReadCount'] ?? 0;
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
      // 원작 LORECRET.PAS:715 `Last` - food := 20; gold := 2000;
      _partyGold = 2000;
      _partyFood = 20;
      _torchSteps = 0;
      _waterWalkSteps = 0;
      _swampWalkSteps = 0;
      _levitateSteps = 0;
      _mindReadCount = 0;
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
        if (_mindReadCount > 0) {
          setState(() => _mindReadCount--);
          _addLog('[$name]: "$talk"');
          _addLog(
            '🧠 [독심술 간파]: $name의 마음에 악의는 느껴지지 않습니다. (독심술 잔여: $_mindReadCount회)',
          );
        } else {
          _addLog('[$name]: "$talk"');
        }
      },
      canWalkOnWater: () => _waterWalkSteps > 0,
      onHazardTile: (cat) => _handleHazardTile(cat),
      onStepTaken: () => _handleStepTaken(),
      partyProvider: () => _party,
      mindReadCountProvider: () => _mindReadCount,
      scriptContextProvider: _scriptContext,
      onScriptTalk: (run) => _driveScript(run),
      onPortalRequested: (portal, tx, ty) =>
          _confirmPortalEntry(portal, tx, ty),
      onRecruitRequested: (recruit) => _requestJoinSlot(recruit),
    );
  }

  /// 원작 `LORESUB.PAS:986 wantenter` / `:999 wantexit`
  /// 성문·동굴 입구 진입 여부를 확인한 뒤 이동한다.
  Future<void> _confirmPortalEntry(PortalInfo? portal, int tx, int ty) async {
    final leavingTown =
        portal == null && _game.currentMapName.startsWith('TOWN');
    final prompt = portal != null
        ? LoreFieldLogic.enterPrompt(portal.name)
        : (leavingTown
              ? LoreFieldLogic.exitPrompt
              : LoreFieldLogic.enterPrompt('이 곳'));

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.black,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          prompt,
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RetroTheme.blue),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              LoreFieldLogic.confirmYes,
              style: RetroTheme.dosFont.copyWith(fontSize: 11),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RetroTheme.darkGray,
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              LoreFieldLogic.confirmNo,
              style: RetroTheme.dosFont.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 원작 LOREENT.PAS - 진입 전 연출(수문장 전투/대사/라바 게이트 판정).
      final enterScriptId = portal?.scriptId;
      if (enterScriptId != null) {
        final pre = LoreScriptEngine.instance.startById(
          enterScriptId,
          _scriptContext(),
        );
        if (pre != null) await _applyScriptOutcome(pre);
        if (!mounted) return;
        // 원작 `exit` - 진행을 취소하는 판정(라바 게이트 등).
        if (pre != null && pre.outcome.blockMove) return;
      }
      _game.enterPortal(portal, tx, ty);
      setState(() {});
      // 원작 entermode - 맵 진입 후 타일/연출 처리.
      final enter = LoreScriptEngine.instance.startEnter(
        _game.currentMapId,
        _scriptContext(),
      );
      if (enter != null) await _applyScriptOutcome(enter);
    } else if (confirmed == false) {
      _addLog(LoreFieldLogic.asYouWish);
    }
  }

  // =========================================================================
  // JSON 스크립트 실행 (assets/data/scripts.json)
  // =========================================================================

  /// 현재 파티/플래그/독심술 상태를 스크립트 엔진에 전달한다.
  ScriptContext _scriptContext() {
    var maxEsp = 0;
    for (final p in _party) {
      if (p.espLevel > maxEsp) maxEsp = p.espLevel;
    }
    final flags = LoreDialogueManager.instance
        .getFlagsCopy()
        .entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toSet();

    // 원작 `party.etc[3] > 0`(늪위를 걷는 마법)처럼 상황 기반 플래그도 넘긴다.
    if (_swampWalkSteps > 0) flags.add(LoreFieldLogic.scriptFlagSwampWalk);
    if (_levitateSteps > 0) flags.add(LoreFieldLogic.scriptFlagLevitate);
    if (_torchSteps > 0) flags.add(LoreFieldLogic.scriptFlagTorch);
    if (_waterWalkSteps > 0) flags.add(LoreFieldLogic.scriptFlagWaterWalk);

    return ScriptContext(
      mindReadActive: _mindReadCount > 0,
      maxEspLevel: maxEsp,
      flags: flags,
      // 원작 `party.etc[10]`/`[13]`/`[14]`/`[15]` 퀘스트 단계.
      questSteps: LoreDialogueManager.instance.questSteps,
      // 원작 `map[x,y]` 판정(숨은 통로 등)을 위해 밟은 타일을 넘긴다.
      tileAtPlayer: _game.currentMap?.getTile(_game.playerX, _game.playerY),
    );
  }

  /// 스크립트를 끝까지 진행한다(선택지가 나오면 대화상자로 물어본다).
  Future<void> _driveScript(ScriptRun run) async {
    var current = run;
    while (true) {
      await _applyScriptOutcome(current);
      final options = current.pendingChoice;
      if (options == null) return;
      if (!mounted) return;

      final chosen = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: RetroTheme.black,
          shape: Border.all(color: RetroTheme.lightCyan, width: 2),
          title: Text(
            current.choicePrompt ?? '어떻게 하시겠습니까 ?',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.yellow,
              fontSize: 12,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < options.length; i++)
                ListTile(
                  dense: true,
                  title: Text(
                    options[i],
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.white,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop(i),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(-1),
              child: Text(
                '취소 (ESC)',
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.lightRed,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
      if (chosen == null || chosen < 0) return;
      current = current.choose(chosen);
    }
  }

  /// 스크립트 결과(메시지/보상/플래그/동료/장비/전투)를 게임 상태에 반영한다.
  Future<void> _applyScriptOutcome(ScriptRun run) async {
    final outcome = run.outcome;

    if (outcome.events.isEmpty) {
      for (final m in outcome.messages) {
        _addLog(m);
      }
    } else {
      // 대사와 카메라 연출(원작 scroll(FALSE))을 원작 순서대로 재생한다.
      for (final event in outcome.events) {
        if (event.kind == 'peek') {
          _game.peekAt(event.x!, event.y!);
          _addLog('▶ 시야를 (${event.x}, ${event.y}) 부근으로 옮깁니다.');
          setState(() {});
          await Future<void>.delayed(_peekHold);
          if (!mounted) return;
        } else {
          _addLog(event.text!);
        }
      }
      _game.clearPeek();
      setState(() {});
    }

    for (final equip in outcome.equips) {
      await _applyScriptEquip(equip);
    }

    if (outcome.goldDelta != 0) {
      setState(() => _partyGold += outcome.goldDelta);
      if (outcome.goldDelta > 0) {
        _addLog('💰 금화 +${outcome.goldDelta} (보유: $_partyGold)');
      }
    }

    if (outcome.foodDelta != 0) {
      setState(
        () => _partyFood = (_partyFood + outcome.foodDelta).clamp(0, 255),
      );
      _addLog(
        '🍞 식량 ${outcome.foodDelta > 0 ? '+' : ''}${outcome.foodDelta} (보유: $_partyFood)',
      );
    }

    for (final flag in outcome.setFlags) {
      LoreDialogueManager.instance.setFlag(flag);
    }

    // 퀘스트 단계 변화 (원작 `inc(party.etc[n])` / `party.etc[n] := 값`)
    for (final quest in outcome.questChanges) {
      LoreDialogueManager.instance.applyQuestStep(
        quest.name,
        set: quest.set,
        inc: quest.inc,
      );
    }

    // 경험치 보상 (원작 `for i := 1 to 6 do if player[i].name <> '' then
    // player[i].experience := player[i].experience + n`)
    if (outcome.expDelta != 0) {
      for (final member in _party) {
        if (member.name.isEmpty) continue;
        member.experience += outcome.expDelta;
      }
      setState(() {});
      _addLog('⭐ 경험치 ${outcome.expDelta > 0 ? '+' : ''}${outcome.expDelta}');
    }

    for (final recruit in outcome.recruits) {
      final member = LoreJoin.byKey(recruit.key);
      if (member == null) continue;
      _requestJoinSlot(PendingRecruit(member, forcedSlotOption: recruit.slot));
    }

    // 지형 변형 (원작 `map[x,y] := 값`)
    for (final change in outcome.tileChanges) {
      final map = _game.currentMap;
      if (map == null) continue;
      if (change.map != null && change.map != _game.currentMapId) continue;
      if (change.x < 1 ||
          change.x > map.xmax ||
          change.y < 1 ||
          change.y > map.ymax) {
        continue;
      }
      map.grid[change.y - 1][change.x - 1] = _resolveTile(
        map.grid[change.y - 1][change.x - 1],
        change.tile,
        change.ifZero,
      );
      setState(() {});
    }

    // 영역 지형 변형 (원작 `for j := .. do map[i,j] := 값`)
    for (final area in outcome.tileAreas) {
      final map = _game.currentMap;
      if (map == null) continue;
      if (area.map != null && area.map != _game.currentMapId) continue;
      // 원작 `map[x,i] := 값`: x는 플레이어가 선 열이다.
      final xMin = area.atPlayerX ? _game.playerX : area.xMin;
      final xMax = area.atPlayerX ? _game.playerX : area.xMax;
      for (var y = area.yMin; y <= area.yMax; y++) {
        if (y < 1 || y > map.ymax) continue;
        for (var x = xMin; x <= xMax; x++) {
          if (x < 1 || x > map.xmax) continue;
          map.grid[y - 1][x - 1] = _resolveTile(
            map.grid[y - 1][x - 1],
            area.tile,
            area.ifZero,
          );
        }
      }
      setState(() {});
    }

    // 플레이어가 밟고 있는 칸의 지형 변형 (원작 `map[x,y] := 값`)
    for (final playerTile in outcome.playerTiles) {
      final map = _game.currentMap;
      if (map == null) continue;
      final px = _game.playerX;
      final py = _game.playerY;
      if (px < 1 || px > map.xmax || py < 1 || py > map.ymax) continue;
      map.grid[py - 1][px - 1] = _resolveTile(
        map.grid[py - 1][px - 1],
        playerTile.tile,
        playerTile.ifZero,
      );
      setState(() {});
    }

    // 밀어내기 (원작 `inc(y)` / `dec(y)`)
    for (final nudge in outcome.nudges) {
      _game.tryMove(nudge.dx, nudge.dy);
      setState(() {});
    }

    // 강제 이동 (원작 `x := ..; y := ..` / `map 변경`)
    if (outcome.teleportX != null && outcome.teleportY != null) {
      final targetMap = outcome.teleportMap ?? _game.currentMapId;
      _game.loadMapById(
        targetMap,
        startX: outcome.teleportKeepX ? _game.playerX : outcome.teleportX!,
        startY: outcome.teleportKeepY ? _game.playerY : outcome.teleportY!,
      );
      setState(() {});
      _addLog('▶ (${outcome.teleportX}, ${outcome.teleportY}) 위치로 이동했습니다.');
    }

    // 마법의 횃불 (원작 `party.etc[1] := 1`)
    if (outcome.torchLit && _torchSteps <= 0) {
      setState(() => _torchSteps = 40);
      _addLog('🔥 마법의 횃불이 어둠을 밝힙니다.');
    }

    if (outcome.battleMonsters.isNotEmpty) {
      _pendingVictoryFlags
        ..clear()
        ..addAll(outcome.battleVictoryFlags);
      final enemies = outcome.battleMonsters
          .map((id) => LoreData.instance.monster(id))
          .toList();
      _startBossBattle(enemies);
    }
  }

  /// 원작 `if map[x,y] = 0 then map[x,y] := A else map[x,y] := B` 규칙을 적용한다.
  int _resolveTile(int current, int tile, int? ifZero) {
    if (ifZero != null && current == 0) return ifZero;
    return tile;
  }

  /// 원작 `choosewhom` + 장비 지급 (`weapon := 3; wea_power := 12`).
  ///
  /// `prompt`가 참이면 원작과 같이 누가 장착할지 물어보고, 거절하면
  /// `asyouwish`("당신이 바란다면 ...") 를 남긴다.
  Future<void> _applyScriptEquip(
    ({String kind, int index, int power, bool prompt, bool onlyUnarmed}) equip,
  ) async {
    final targets = <int>[];

    if (equip.prompt) {
      final chosen = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: RetroTheme.black,
          shape: Border.all(color: RetroTheme.lightCyan, width: 2),
          title: Text(
            '누가 이 장비를 장착하겠습니까 ?',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.yellow,
              fontSize: 12,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _party.length; i++)
                if (_party[i].name.isNotEmpty)
                  ListTile(
                    dense: true,
                    title: Text(
                      '${i + 1}번 ${_party[i].name} (${_party[i].playerClass.koreanName})',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.white,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => Navigator.of(ctx).pop(i),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(-1),
              child: Text(
                '취소 (ESC)',
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.lightRed,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
      if (chosen == null || chosen < 0) {
        _addLog(LoreFieldLogic.asYouWish);
        return;
      }
      targets.add(chosen);
    } else {
      for (var i = 0; i < _party.length; i++) {
        final m = _party[i];
        if (m.name.isEmpty) continue;
        // 원작 맵 6: 무기가 없는 대원만 기본 무장을 한다.
        if (equip.kind == 'weapon' && equip.onlyUnarmed && m.weapon != 0) {
          continue;
        }
        targets.add(i);
      }
    }

    if (targets.isEmpty) {
      _addLog(LoreFieldLogic.asYouWish);
      return;
    }

    for (final index in targets) {
      final member = _party[index];
      setState(() {
        switch (equip.kind) {
          case 'weapon':
            member.equipWeaponRaw(equip.index, equip.power);
            break;
          case 'shield':
            member.equipShieldRaw(equip.index, equip.power);
            break;
          case 'armor':
            member.equipArmorRaw(equip.index, equip.power);
            break;
        }
      });
      final itemName = switch (equip.kind) {
        'weapon' => member.weaponName,
        'shield' => member.shieldName,
        _ => member.armorName,
      };
      _addLog('${member.name} 이(가) $itemName 을(를) 장착했다.');
    }
  }

  /// 원작 `LORESUB.PAS:1144 ReturnJoinMember` - 합류시킬 파티 슬롯(2~6번) 선택
  Future<void> _requestJoinSlot(PendingRecruit pending) async {
    final recruit = pending.member;

    // 원작이 슬롯을 고정한 경우(예: Mad Joe = 6번)에는 선택 없이 바로 합류시킨다.
    if (pending.forcedSlotOption != null) {
      final option = pending.forcedSlotOption!;
      final replaced = option + 1 < _party.length
          ? _party[option + 1].name
          : null;
      setState(() => LoreJoin.applyJoin(_party, recruit, option));
      _addLog(
        '★ ${recruit.name} (${recruit.playerClass.koreanName} Lv.${recruit.battleLevel})이(가) ${option + 2}번 슬롯으로 일행에 합류했습니다!',
      );
      if (replaced != null) {
        _addLog('$replaced은(는) 전장에서 물러났습니다.');
      }
      return;
    }

    final labels = LoreJoin.joinMenuLabels(_party);
    final option = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.black,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          LoreJoin.joinMenuPrompt,
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              ListTile(
                dense: true,
                title: Text(
                  '${i + 2}번 ${labels[i]}',
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.white,
                    fontSize: 12,
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(i),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(-1),
            child: Text(
              '취소 (ESC)',
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.lightRed,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );

    if (option == null || option < 0) {
      _addLog(LoreJoin.joinCancelled);
      return;
    }

    final slotNumber = option + 2; // 2~6번 슬롯
    final replaced = option + 1 < _party.length
        ? _party[option + 1].name
        : null;
    setState(() => LoreJoin.applyJoin(_party, recruit, option));
    _addLog(
      '★ ${recruit.name} (${recruit.playerClass.koreanName} Lv.${recruit.battleLevel})이(가) $slotNumber번 슬롯으로 일행에 합류했습니다!',
    );
    if (replaced != null) {
      _addLog('$replaced은(는) 전장에서 물러났습니다.');
    }
  }

  void _handleHazardTile(TileCategory cat) {
    if (cat == TileCategory.water) {
      if (_waterWalkSteps > 0) {
        setState(() => _waterWalkSteps--);
        _addLog('🌊 [물위를 걸음] 깊은 물 위를 걸어갑니다. (남은 걸음: $_waterWalkSteps)');
      }
    } else if (cat == TileCategory.swamp) {
      if (_swampWalkSteps > 0) {
        setState(() => _swampWalkSteps--);
        _addLog('🌿 [늪위를 걸음] 독성 늪지를 안전하게 통과했습니다. (남은 걸음: $_swampWalkSteps)');
      } else {
        // 원작 LOREMAIN.PAS:60 `일행은 독이 있는 늪에 들어갔다 !!!`
        _addLog('☣ 일행은 독이 있는 늪에 들어갔다 !!!');
        final rnd = Random();
        for (final p in _party) {
          if (p.name.isEmpty) continue;
          if (rnd.nextInt(20) + 1 >= p.luck) {
            // 원작 LOREMAIN.PAS:64 `{name}는 중독 되었다.`
            _addLog('☠ ${p.name}는 중독 되었다.');
            if (p.poison == 0) setState(() => p.poison = 1);
          }
        }
      }
    } else if (cat == TileCategory.lava) {
      if (_levitateSteps > 0) {
        setState(() => _levitateSteps--);
        _addLog('✨ [공중 부상] 용암 위를 안전하게 비행 중입니다. (남은 걸음: $_levitateSteps)');
      } else {
        // 원작 LOREMAIN.PAS:90 `일행은 용암지대로 들어섰다 !!!`
        _addLog('🔥 일행은 용암지대로 들어섰다 !!!');
        final rnd = Random();
        // 원작은 피해량을 한 번 굴려 `{name}는 {n}의 피해를 입었다 !` 로 출력하고
        // 같은 값으로 HP/상태를 갱신한다.
        final damages = <({PartyMember member, int dmg})>[];
        for (final p in _party) {
          if (p.name.isEmpty) continue;
          final luckRoll = p.luck > 0 ? rnd.nextInt(p.luck) : 0;
          damages.add((member: p, dmg: rnd.nextInt(40) + 40 - 2 * luckRoll));
        }
        for (final d in damages) {
          _addLog('💥 ${d.member.name}는 ${d.dmg}의 피해를 입었다 !');
        }
        for (final d in damages) {
          final p = d.member;
          final dmg = d.dmg;
          setState(() {
            if (p.hp > 0 && p.unconscious == 0) {
              p.hp -= dmg;
              if (p.hp <= 0) p.unconscious = 1;
            } else if (p.hp > 0 && p.unconscious > 0) {
              p.hp -= dmg;
            } else if (p.unconscious > 0 && p.dead == 0) {
              p.unconscious += dmg;
              if (p.unconscious > p.endurance * p.battleLevel) p.dead = 1;
            } else if (p.dead > 0) {
              p.dead = (p.dead + dmg > 30000) ? 30000 : p.dead + dmg;
            }
          });
        }
      }
    }
  }

  void _handleStepTaken() {
    if (_torchSteps > 0) _torchSteps--;
    // 원작 LOREMAIN.PAS:31 `Move_Mode` - 독은 걸을 때마다 진행되고 10 을 넘으면
    // 발병하여 상태(dead/unconscious/hp)에 따라 피해를 준다.
    var poisonProgressed = false;
    for (final p in _party) {
      if (p.name.isEmpty || p.poison <= 0) continue;
      poisonProgressed = true;
      setState(() {
        p.poison++;
        if (p.poison > 10) {
          p.poison = 1;
          if (p.dead > 0 && p.dead < 100) {
            p.dead++;
          } else if (p.unconscious > 0) {
            p.unconscious++;
            if (p.unconscious > p.endurance * p.battleLevel) p.dead = 1;
          } else {
            p.hp--;
            if (p.hp <= 0) p.unconscious = 1;
          }
        }
      });
    }
    if (poisonProgressed) _addLog('☠ 독이 온몸에 퍼져나갑니다.');

    // JSON 스크립트(step 트리거)를 우선 실행하고, 없으면 기존 이벤트 로직을 쓴다.
    final scriptRun = LoreScriptEngine.instance.startStep(
      _game.currentMapId,
      _game.playerX,
      _game.playerY,
      _scriptContext(),
    );
    if (scriptRun != null) {
      unawaited(_applyScriptOutcome(scriptRun));
      return;
    }

    // 던전 및 필드 특수 이벤트 감지 (LORESPEC.PAS)
    final dEvent = LoreDungeonEventManager.instance.checkEvent(
      _game.currentMapId,
      _game.playerX,
      _game.playerY,
      _party,
    );
    if (dEvent != null) {
      _addLog('★ [이벤트: ${dEvent.title}] ★');
      _addLog(dEvent.message);
      if (dEvent.foodGained > 0) {
        setState(() => _partyFood += dEvent.foodGained);
      }
      if (dEvent.goldGained > 0) {
        setState(() => _partyGold += dEvent.goldGained);
      }
      if (dEvent.bossEnemies != null && dEvent.bossEnemies!.isNotEmpty) {
        _startBossBattle(dEvent.bossEnemies!);
      }
    }
  }

  void _openQuickViewDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QuickViewDialog(party: _party),
    );
  }

  void _openEspDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EspDialog(
        party: _party,
        onLog: (msg) => _addLog(msg),
        onMindReadActivated: (count) {
          setState(() => _mindReadCount = count);
        },
      ),
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

  void _openFieldMenuDialog({FieldMenuTab initialTab = FieldMenuTab.main}) {
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
        initialTab: initialTab,
        etc: {
          'torchSteps': _torchSteps,
          'waterWalkSteps': _waterWalkSteps,
          'swampWalkSteps': _swampWalkSteps,
          'levitateSteps': _levitateSteps,
          'mindReadCount': _mindReadCount,
        },
        onFoodChanged: (newFood) => setState(() => _partyFood = newFood),
        onSpellEffect: ({int? torch, int? water, int? swamp, int? levitate}) {
          setState(() {
            if (torch != null) _torchSteps = torch;
            if (water != null) _waterWalkSteps = water;
            if (swamp != null) _swampWalkSteps = swamp;
            if (levitate != null) _levitateSteps = levitate;
          });
        },
        // 원작 PhenominaSpell의 기화 이동/지형 변화/공간 이동용 지도 접근.
        mapSize: _game.currentMap == null
            ? null
            : (_game.currentMap!.xmax, _game.currentMap!.ymax),
        tileAt: (x, y) => _game.currentMap?.getTile(x, y) ?? 0,
        onMoveTo: (x, y) {
          setState(() {
            _game.playerX = x;
            _game.playerY = y;
          });
        },
        onTerrainChange: (x, y, tile) {
          final map = _game.currentMap;
          if (map == null) return;
          if (x < 1 || x > map.xmax || y < 1 || y > map.ymax) return;
          setState(() => map.grid[y - 1][x - 1] = tile);
        },
        onMindReadActivated: (count) {
          setState(() => _mindReadCount = count);
        },
        onSaveDataLoaded: (save) {
          setState(() {
            _party = List.from(save.party);
            _partyGold = save.gold;
            _partyFood = save.food;
            _torchSteps = save.etc['torchSteps'] ?? 0;
            _waterWalkSteps = save.etc['waterWalkSteps'] ?? 0;
            _swampWalkSteps = save.etc['swampWalkSteps'] ?? 0;
            _levitateSteps = save.etc['levitateSteps'] ?? 0;
            _mindReadCount = save.etc['mindReadCount'] ?? 0;
            _game.loadMapById(
              save.mapId,
              startX: save.playerX,
              startY: save.playerY,
            );
            _addLog(
              '💾 [슬롯 ${save.slot}: ${save.slotName}] 데이터를 성공적으로 불러왔습니다.',
            );
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
        food: _partyFood,
        mapId: _game.currentMapId,
        onGoldChanged: (newGold) => setState(() => _partyGold = newGold),
        onFoodChanged: (newFood) => setState(() => _partyFood = newFood),
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
        return LoreData.instance.monster(id);
      });

      _addLog('=== 몬스터 무리가 나타났다! ===');
      for (final e in _battleEnemies) {
        _addLog('${e.name} (Lv.${e.level}, HP:${e.hp}) 등장!');
      }
    });
  }

  /// 보스전 시작
  void _startBossBattle(List<Monster> bossEnemies) {
    setState(() {
      _currentMode = GameScreenMode.battle;
      _currentBossName = bossEnemies.first.name;
      _battleEnemies = bossEnemies;

      _addLog('⚔⚔⚔ 강력한 보스 출현! ⚔⚔⚔');
      for (final e in _battleEnemies) {
        _addLog('▶ ${e.name} (Lv.${e.level}, HP:${e.hp}) 결전 시작!');
      }
    });
  }

  /// 전투 승리 -> 필드로 복귀
  void _onBattleVictory(int goldEarned) {
    setState(() {
      _partyGold += goldEarned;
      _currentMode = GameScreenMode.field;
      _addLog('전투 종료. 일행은 필드로 복귀합니다. 보유 금화: $_partyGold');

      // 원작 `if party.etc[6] = 0 then party.etc[..] or bit` - 승리 시 플래그.
      for (final flag in _pendingVictoryFlags) {
        LoreDialogueManager.instance.setFlag(flag);
      }
      _pendingVictoryFlags.clear();

      // 보스 격퇴 플래그 갱신
      if (_currentBossName != null) {
        if (_currentBossName == 'Major Mummy') {
          LoreDialogueManager.instance.bossMajorMummyDefeated = true;
          _addLog('★ Major Mummy를 물리쳤습니다! LASTDITCH 성주에게 승전보를 전하십시오!');
        } else if (_currentBossName == 'ArchiGagoyle') {
          LoreDialogueManager.instance.bossArchiGagoyleDefeated = true;
          _addLog('★ ArchiGagoyle을 물리쳤습니다! GAIA TERRA 성주에게 승전보를 전하십시오!');
        } else if (_currentBossName?.startsWith('Hidra') ?? false) {
          LoreDialogueManager.instance.bossHidraDefeated = true;
          _addLog('★ 삼두룡 Hidra를 물리쳤습니다! WATER FIELD 성주에게 승전보를 전하십시오!');
        } else if (_currentBossName == 'Huge Dragon') {
          LoreDialogueManager.instance.bossHugeDragonDefeated = true;
          _addLog('★ Huge Dragon을 물리쳤습니다! WATER FIELD 성주에게 승전보를 전하십시오!');
        }
        _currentBossName = null;
      }
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
            // 좌측 하단 [메뉴(Space)], [Q] 상태, [E] 초감각 버튼들
            Positioned(
              bottom: 6,
              left: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _openFieldMenuDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: RetroTheme.blue.withValues(alpha: 0.8),
                        border: Border.all(color: RetroTheme.cyan, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.menu,
                            size: 13,
                            color: RetroTheme.yellow,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '메뉴(Space)',
                            style: RetroTheme.dosFont.copyWith(
                              fontSize: 10,
                              color: RetroTheme.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _openQuickViewDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: RetroTheme.darkBlue.withValues(alpha: 0.8),
                        border: Border.all(
                          color: RetroTheme.lightGreen,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '[Q] 상태',
                        style: RetroTheme.dosFont.copyWith(
                          fontSize: 10,
                          color: RetroTheme.lightGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _openEspDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: RetroTheme.darkBlue.withValues(alpha: 0.8),
                        border: Border.all(
                          color: RetroTheme.lightMagenta,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '[E] 초감각',
                        style: RetroTheme.dosFont.copyWith(
                          fontSize: 10,
                          color: RetroTheme.lightMagenta,
                        ),
                      ),
                    ),
                  ),
                ],
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
                  _reclaimFocus();
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
              const SizedBox(height: 4),
              // 원작 LORESUB.PAS:480 전투 패배 시 선택
              Text(
                LoreSubText.battleLost,
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.lightRed,
                  fontSize: 13,
                ),
              ),
              Text(
                LoreSubText.battleLostAsk,
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.yellow,
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
                child: Text(
                  LoreSubText.resumeGame,
                  style: RetroTheme.dosFont,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: RetroTheme.lightRed),
                  foregroundColor: RetroTheme.lightRed,
                ),
                onPressed: () => SystemNavigator.pop(),
                child: Text(
                  LoreSubText.endGame,
                  style: RetroTheme.dosFont,
                ),
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
            // 원작 LOREMAIN.PAS 핫키: P/V/Q/C/E/R/G + Space
            switch (FieldHotkeys.resolve(event.logicalKey)) {
              case FieldAction.openMenu:
                _openFieldMenuDialog();
                return;
              case FieldAction.viewParty:
                _openFieldMenuDialog(initialTab: FieldMenuTab.partyView);
                return;
              case FieldAction.viewCharacter:
                _openFieldMenuDialog(initialTab: FieldMenuTab.characterView);
                return;
              case FieldAction.castSpell:
                _openFieldMenuDialog(initialTab: FieldMenuTab.castSpell);
                return;
              case FieldAction.rest:
                _openFieldMenuDialog(initialTab: FieldMenuTab.rest);
                return;
              case FieldAction.gameOption:
                _openFieldMenuDialog(initialTab: FieldMenuTab.gameOption);
                return;
              case FieldAction.quickView:
                _openQuickViewDialog();
                return;
              case FieldAction.extrasense:
                _openEspDialog();
                return;
              case FieldAction.guide:
                showDialog(
                  context: context,
                  builder: (ctx) => const LoreGuideDialog(),
                );
                return;
              case FieldAction.none:
                break;
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
