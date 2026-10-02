import 'dart:async';
import 'dart:math';

import '../logic/lore_batt_text.dart';

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
import '../logic/lore_encounter_logic.dart';
import '../logic/lore_special_event_dispatcher.dart';
import '../logic/lore_portal_session.dart';
import '../logic/lore_battle_progress.dart';
import '../logic/battle_engine.dart';
import '../logic/lore_mirror_enemy.dart';
import '../logic/lore_rigel_blessing.dart';
import '../logic/script_battle_session.dart';
import '../logic/script_equip_reducer.dart';
import '../logic/script_party_reducer.dart';
import '../logic/script_world_reducer.dart';
import '../logic/lore_join.dart';
import '../logic/lore_main_procedures.dart';
import '../logic/lore_source_memory.dart';
import '../logic/lore_ent_procedures.dart';
import '../models/party_member.dart';
import '../models/monster.dart';
import '../data/lore_data.dart';
import '../data/lore_script.dart';
import '../widgets/viewport_view.dart';
import '../widgets/game_screen_layout.dart';
import '../widgets/party_status_view.dart';
import '../widgets/message_log_view.dart';
import '../widgets/dpad_widget.dart';
import '../widgets/battle_viewport_view.dart';
import '../widgets/encounter_viewport_view.dart';
import '../widgets/town_dialog.dart';
import '../widgets/town_facilities_dialog.dart';
import '../widgets/field_menu_dialog.dart';
import '../widgets/script_scene_dialog.dart';
import '../widgets/quick_view_dialog.dart';
import '../widgets/esp_dialog.dart';
import '../game/lore_map_manager.dart';
import '../services/save_manager.dart';
import '../game/lore_dialogue_manager.dart';
import '../game/lore_dungeon_event_manager.dart';
import '../widgets/lore_guide_dialog.dart';
import '../logic/lore_menu_text.dart';
import '../widgets/ending_view.dart';

enum GameScreenMode { field, encounter, battle, gameOver, ending }

/// 화면 비율에 맞춰 정사각형 맵과 상태·대화 패널을 배치한다.
class MainGameScreen extends StatefulWidget {
  final List<PartyMember>? initialParty;
  final SaveData? initialSaveData;

  /// 필드·위험 지형·몬스터 편성·전투가 공유하는 난수원.
  final Random? encounterRandom;

  const MainGameScreen({
    super.key,
    this.initialParty,
    this.initialSaveData,
    this.encounterRandom,
  });

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  late final Random _sessionRandom;
  late final LoreScriptEngine _scripts;
  GameScreenMode _currentMode = GameScreenMode.field;
  late List<PartyMember> _party;
  late LoreGame _game;
  final List<String> _logs = [];
  int _logRevision = 0;
  int _partyGold = 2000;
  int _partyFood = 20; // 원작 LORECRET.PAS `Last`: food := 20;

  // 원작 LOREMAIN.PAS: 환경 효과 및 보조 마법 지속 걸음수
  LorePartyEtc get _sourceEtc => LoreDialogueManager.instance.partyEtc;
  int get _torchSteps => _sourceEtc.read(1);
  set _torchSteps(int value) => _sourceEtc[1] = value;
  int get _waterWalkSteps => _sourceEtc.read(2);
  set _waterWalkSteps(int value) => _sourceEtc[2] = value;
  int get _swampWalkSteps => _sourceEtc.read(3);
  set _swampWalkSteps(int value) => _sourceEtc[3] = value;
  int get _levitateSteps => _sourceEtc.read(4);
  set _levitateSteps(int value) => _sourceEtc[4] = value;

  /// 카메라 연출(원작 scroll(FALSE)) 한 장면을 보여주는 시간.
  /// 원작의 `PressAnyKey` 를 현대적으로 대체한 것이다.
  static const Duration _peekHold = Duration(milliseconds: 1600);
  int get _mindReadCount => _sourceEtc.read(5);
  set _mindReadCount(int value) => _sourceEtc[5] = value;
  int get _encounterFrequency => _sourceEtc.read(7);
  set _encounterFrequency(int value) => _sourceEtc[7] = value;
  int get _maxEnemies => _sourceEtc.read(8);
  set _maxEnemies(int value) => _sourceEtc[8] = value;

  /// 스크립트 전투 승리 시 설정할 플래그 (원작 `party.etc[6] = 0` 처리).
  final List<String> _pendingVictoryFlags = [];
  bool _battleEnemyFirst = false;

  /// 연속 전투도 서로 다른 전투 화면 상태로 시작한다.
  int _battleSerial = 0;
  ScriptRun? _pendingScriptBattle;
  int? _pendingScriptTargetX;
  int? _pendingScriptTargetY;
  ({PortalInfo portal, int tx, int ty})? _pendingPortalTransition;
  bool _entryAnimationActive = false;

  // 전투 모드 상태
  List<Monster> _battleEnemies = [];

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _sessionRandom = widget.encounterRandom ?? Random();
    _scripts = LoreScriptEngine.instance.fork(random: _sessionRandom);
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
      LoreDialogueManager.instance.loadFlags(
        widget.initialSaveData!.flags,
        fieldCounters: widget.initialSaveData!.etc,
      );
      _scripts.consumedScripts
        ..clear()
        ..addAll(widget.initialSaveData!.consumedScripts);
    } else {
      LoreDialogueManager.instance.loadFlags({});
      _scripts.consumedScripts.clear();
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
      _encounterFrequency = 2;
      _maxEnemies = 5;
    }
  }

  void _initGame() {
    _logs.clear();

    final initialMapId = widget.initialSaveData?.mapId ?? 6;
    final startX = widget.initialSaveData?.playerX ?? 51;
    final startY = widget.initialSaveData?.playerY ?? 31;

    _game = LoreGame(
      initialMapId: initialMapId,
      initialPlayerX: startX,
      initialPlayerY: startY,
      initialMapTiles: widget.initialSaveData?.mapTiles,
      random: _sessionRandom,
      onLog: (msg) => _addLog(msg),
      onEncounter: () => _startBattle(),
      encounterFrequencyProvider: () => _encounterFrequency,
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
        } else {
          _addLog('[$name]: "$talk"');
        }
      },
      canWalkOnWater: () => _waterWalkSteps > 0,
      waterWalkStepsProvider: () => _waterWalkSteps,
      onWaterWalkStepsChanged: (steps) {
        setState(() => _waterWalkSteps = steps);
      },
      onHazardTile: (cat) => _handleHazardTile(cat),
      onPoisonTick: _advancePoison,
      onMoveMode: () {
        LoreMainProcedures.moveMode(
          party: _party,
          scrollToParty: _game.clearPeek,
          displayHealthAndCondition: () {
            setState(() {});
          },
          gameOver: () =>
              setState(() => _currentMode = GameScreenMode.gameOver),
          mindReadSteps: () => _mindReadCount,
          setMindReadSteps: (steps) => setState(() => _mindReadCount = steps),
          encounterFrequency: _encounterFrequency,
          random: _sessionRandom.nextInt,
          encounterEnemy: () {
            if (LoreEncounterLogic.pools.containsKey(_game.currentMapId)) {
              _startBattle();
            }
          },
        );
      },
      onMindReadTick: () {
        if (_mindReadCount > 0) setState(() => _mindReadCount--);
      },
      onStepTaken: () => _handleStepTaken(),
      partyProvider: () => _party,
      mindReadCountProvider: () => _mindReadCount,
      scriptContextProvider: _scriptContext,
      scriptEngine: _scripts,
      onScriptTalk: (run, tx, ty) =>
          _driveScript(run, talkTargetX: tx, talkTargetY: ty),
      onPortalRequested: (portal, tx, ty) =>
          _confirmPortalEntry(portal, tx, ty),
      onRecruitRequested: (recruit) => _requestJoinSlot(recruit),
    );
  }

  /// 원작 `LORESUB.PAS:986 wantenter` / `:999 wantexit`
  /// 성문·동굴 입구 진입 여부를 확인한 뒤 이동한다.
  Future<void> _confirmPortalEntry(PortalInfo portal, int tx, int ty) async {
    final sourceRejectY = LoreWorldManager.sourceExitRejectY(
      _game.currentMapId,
      ty,
      x: tx,
    );
    final sourceDungeonExit =
        sourceRejectY != null &&
        !LoreWorldManager.sourceAsksEnter(_game.currentMapId, tx, ty);
    final leavingTown =
        sourceDungeonExit ||
        _game.currentMapName.startsWith('TOWN') &&
            LoreWorldManager.mapRegistry[portal.targetMapId]?.category ==
                MapCategory.ground;
    final prompt = leavingTown
        ? LoreFieldLogic.exitPrompt
        : LoreFieldLogic.enterPrompt(portal.name);

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

    final plan = LorePortalSession.begin(
      confirmed: confirmed == true,
      portal: portal,
      context: _scriptContext(),
      scripts: _scripts,
      x: tx,
      y: ty,
    );
    if (plan.action == LorePortalAction.cancelled) {
      if (confirmed == false) _addLog(LoreFieldLogic.asYouWish);
      if (sourceRejectY != null) {
        _game.playerX = tx;
        _game.playerY = sourceRejectY;
        setState(() {});
      }
      _game.clearPeek();
      return;
    }
    // 원작 LOREENT.PAS - 진입 전 연출(수문장 전투/대사/라바 게이트 판정).
    if (plan.preScript case final pre?) {
      if (portal.scriptId == 'portal-25-26-chamber') {
        // LOREENT.entermode turns on the torch, then consumes ten pairs of
        // animation rolls before the Necromancer battle begins.
        setState(() => _torchSteps = 1);
        await _playChamberEntryAnimation();
        if (!mounted) return;
      }
      if (pre.awaitingBattle) {
        var alreadyApplied = const ScriptOutcome();
        if (portal.scriptId == 'portal-23-25-dungeon') {
          for (final message in pre.outcome.messages) {
            _addLog(message);
          }
          if (_party.length >= 6 && _party[5].name == 'Draconian') {
            for (final message in const [
              ' ArchiDraconian은 마지막에 있는 Draconian',
              '을 발견했다.',
              ' 아니 너는 누구냐! 감히 Draconian 족이면',
              '서 Necromancer님에게 반기를 들다니... 그',
              '것은 바로 죽음이다. 받아랏!!',
            ]) {
              _addLog(message);
            }
            LoreEntProcedures.strikeDraconianBeforeDungeon(_party);
            setState(() {});
          }
          alreadyApplied = ScriptOutcome(
            messages: pre.outcome.messages,
            events: pre.outcome.events,
          );
        }
        _pendingPortalTransition = (portal: portal, tx: tx, ty: ty);
        final completed = await _driveScript(
          pre,
          alreadyApplied: alreadyApplied,
        );
        final action = LorePortalSession.afterPreScript(
          completed: completed,
          waitingForBattle: _pendingScriptBattle != null,
          blockMove: pre.outcome.blockMove,
        );
        if (action != LorePortalAction.waitForBattle) {
          _pendingPortalTransition = null;
        }
        if (action != LorePortalAction.loadMap) return;
      } else {
        _pendingPortalTransition = (portal: portal, tx: tx, ty: ty);
        final completed = await _driveScript(pre);
        if (!mounted) return;
        final action = LorePortalSession.afterPreScript(
          completed: completed,
          waitingForBattle: _pendingScriptBattle != null,
          blockMove: pre.outcome.blockMove,
        );
        if (action != LorePortalAction.waitForBattle) {
          _pendingPortalTransition = null;
        }
        if (action != LorePortalAction.loadMap) return;
      }
    }
    await _finishPortalEntry(portal, tx, ty);
  }

  Future<void> _finishPortalEntry(PortalInfo portal, int tx, int ty) async {
    final enteredFromMap = _game.currentMapId;
    // LOREENT map 21 shows Ancient Evil before the destination `load`.
    final speech = LoreEntProcedures.ancientEvilBeforeLoad(
      fromMap: enteredFromMap,
      toMap: portal.targetMapId,
      flags: _scriptContext().flags,
    );
    if (speech != null) {
      await _driveScript(_scripts.startProcedure(speech, _scriptContext()));
      if (!mounted) return;
    }
    await _game.enterPortal(portal, tx, ty, deferPostLoadEffects: true);
    if (!mounted) return;
    if (enteredFromMap == 25 && _game.currentMapId == 26) {
      // `scroll(FALSE)` draws the new map without the party until the descent.
      _game.peekAt(_game.playerX, _game.playerY);
    }
    setState(() {});
    if (enteredFromMap == 25 && _game.currentMapId == 26) {
      await _playChamberDescent();
      if (!mounted) return;
    }
    final context = _scriptContext(enteredFromMap: enteredFromMap);
    _game.applyEntrancePostLoadTiles(
      fromMap: enteredFromMap,
      partyNames: context.partyNames,
      flags: context.flags,
      questSteps: context.questSteps,
    );
    if (!mounted) return;
    _game.finishEntrance();
    setState(() {});
  }

  Future<void> _playChamberEntryAnimation() async {
    final frames = LoreEntProcedures.chamberEntryFrames(_sessionRandom);
    _entryAnimationActive = true;
    try {
      for (final frame in frames) {
        if (!mounted) return;
        setState(() => _game.showChamberEntryFrame(frame.$1, frame.$2));
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    } finally {
      _game.clearChamberEntryFrame();
      _entryAnimationActive = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _playChamberDescent() async {
    _entryAnimationActive = true;
    try {
      for (final row in LoreEntProcedures.chamberDescentRows) {
        if (!mounted) return;
        setState(() => _game.showChamberDescentRow(row));
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    } finally {
      _game.clearChamberDescentRow();
      _entryAnimationActive = false;
      if (mounted) setState(() {});
    }
  }

  // =========================================================================
  // JSON 스크립트 실행 (assets/data/scripts.json)
  // =========================================================================

  /// 현재 파티/플래그/독심술 상태를 스크립트 엔진에 전달한다.
  ScriptContext _scriptContext({int? enteredFromMap}) {
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
    // 생성된 전투 스크립트의 etc6 조건은 원작에서 *이번* 전투 직후에 평가된다.
    // 이전 전투의 도망/패배 결과로 다음 보스전의 승리 분기가 바뀌지 않게 한다.
    flags.remove('etc6');

    // 원작 `party.etc[3] > 0`(늪위를 걷는 마법)처럼 상황 기반 플래그도 넘긴다.
    // 기계적으로 옮긴 스크립트는 원작 조건을 `etcN` 으로 적으므로 두 이름을 모두
    // 넘긴다(예: `etc5` = 독심술 활성).
    if (_swampWalkSteps > 0) {
      flags
        ..add(LoreFieldLogic.scriptFlagSwampWalk)
        ..add(LoreFieldLogic.etcSwampWalk);
    }
    if (_levitateSteps > 0) {
      flags
        ..add(LoreFieldLogic.scriptFlagLevitate)
        ..add(LoreFieldLogic.etcLevitate);
    }
    if (_torchSteps > 0) {
      flags
        ..add(LoreFieldLogic.scriptFlagTorch)
        ..add(LoreFieldLogic.etcTorch);
    }
    if (_waterWalkSteps > 0) {
      flags
        ..add(LoreFieldLogic.scriptFlagWaterWalk)
        ..add(LoreFieldLogic.etcWaterWalk);
    }
    if (_mindReadCount > 0) flags.add(LoreFieldLogic.etcMindRead);

    return ScriptContext(
      mindReadActive: _mindReadCount > 0,
      maxEspLevel: maxEsp,
      flags: flags,
      partyNames: {for (final member in _party) member.name},
      enteredFromMap: enteredFromMap,
      // 원작 `party.etc[10]`/`[13]`/`[14]`/`[15]` 퀘스트 단계.
      questSteps: LoreDialogueManager.instance.questSteps,
      sourceEtc: LoreDialogueManager.instance.partyEtc.snapshot(),
      // 원작 `map[x,y]` 판정(숨은 통로 등)을 위해 밟은 타일을 넘긴다.
      tileAtPlayer: _game.currentMap?.getTile(_game.playerX, _game.playerY),
      moveDy: switch (_game.playerDirection) {
        0 => 1,
        1 => -1,
        _ => 0,
      },
    );
  }

  /// 스크립트를 끝까지 진행한다(선택지가 나오면 대화상자로 물어본다).
  ///
  /// [talkTargetX]/[talkTargetY]는 NPC 대화일 때 대화 상대(앞 칸)의 좌표다.
  /// 원작 `map[x+x1,y+y1] := 값` 스텝(`setTileAtTarget`)에 쓰인다.
  Future<bool> _driveScript(
    ScriptRun run, {
    ScriptOutcome alreadyApplied = const ScriptOutcome(),
    int? talkTargetX,
    int? talkTargetY,
  }) async {
    var current = run;
    var applied = alreadyApplied;
    while (true) {
      final appliedSuccessfully = await _applyScriptOutcome(
        current,
        since: applied,
        talkTargetX: talkTargetX,
        talkTargetY: talkTargetY,
      );
      if (!appliedSuccessfully) return false;
      applied = current.outcome;
      if (current.awaitingBattle) {
        _pendingScriptBattle = current;
        _pendingScriptTargetX = talkTargetX;
        _pendingScriptTargetY = talkTargetY;
        return false;
      }
      if (current.pendingScene case final scene?) {
        if (!mounted) return false;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ScriptSceneDialog(
            scene: scene.withPartyNames([
              for (final member in _party) member.name,
            ]),
            actors: [for (final id in scene.actors) Monster.create(id)],
          ),
        );
        if (!mounted) return false;
        current = current.acknowledgeScene();
        continue;
      }
      final options = current.pendingChoice;
      if (options == null) return true;
      if (!mounted) return false;

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
            IconButton(
              key: const ValueKey('dialog-cancel'),
              onPressed: () => Navigator.of(ctx).pop(-1),
              icon: const Icon(
                Icons.close,
                size: 16,
                color: RetroTheme.lightRed,
              ),
            ),
          ],
        ),
      );
      final selected = chosen == null || chosen < 0
          ? current.cancelOptionIndex
          : chosen;
      if (selected == null) {
        if (!current.hasCancelSteps) return false;
        current = current.cancel();
        continue;
      }
      current = current.choose(selected);
    }
  }

  /// 스크립트 결과(메시지/보상/플래그/동료/장비/전투)를 게임 상태에 반영한다.
  Future<bool> _applyScriptOutcome(
    ScriptRun run, {
    ScriptOutcome? since,
    int? talkTargetX,
    int? talkTargetY,
  }) async {
    final outcome = since == null ? run.outcome : run.outcome.since(since);
    final sourceScene = run.pendingScene;
    final renderedScene = sourceScene?.withPartyNames([
      for (final member in _party) member.name,
    ]);
    String presented(String message) {
      final line = sourceScene?.appendPartyNameLine;
      if (line != null && message == sourceScene!.lines[line]) {
        return renderedScene!.lines[line];
      }
      return message;
    }

    if (outcome.events.isEmpty) {
      for (final m in outcome.messages) {
        _addLog(presented(m));
      }
    } else {
      // 대사와 카메라 연출(원작 scroll(FALSE))을 원작 순서대로 재생한다.
      for (final event in outcome.events) {
        if (event.kind == 'peek') {
          _game.peekAt(event.x!, event.y!);
          setState(() {});
          await Future<void>.delayed(_peekHold);
          if (!mounted) return false;
        } else if (event.kind == 'sourceFace') {
          _game.applySourceFace(event.face!);
        } else if (event.kind == 'message') {
          _addLog(presented(event.text!));
        }
      }
      _game.clearPeek();
      setState(() {});
    }

    for (final equip in outcome.equips) {
      if (!await _applyScriptEquip(equip)) return false;
    }
    run.completeEquipment();

    if (outcome.goldDelta != 0 || outcome.foodDelta != 0) {
      final resources = ScriptWorldReducer.applyResources(
        ScriptResources(gold: _partyGold, food: _partyFood),
        outcome,
      );
      setState(() {
        _partyGold = resources.gold;
        _partyFood = resources.food;
      });
    }
    const recruitFlagByKey = {
      'mad_joe': 'madJoeJoined',
      'rigel': 'rigelJoined',
      'red_antares': 'redAntaresJoined',
      'spica': 'spicaJoined',
      'polaris': 'polarisJoined',
      'lore_hunter': 'loreHunterJoined',
    };
    final deferredRecruitFlags = {
      for (final recruit in outcome.recruits)
        if (recruitFlagByKey[recruit.key] case final String flag)
          if (outcome.setFlags.contains(flag)) flag,
      // LORESPEC.PAS: Red Antares의 완료 비트는 슬롯 선택에 성공한 뒤에만 기록한다.
      if (outcome.recruits.any((recruit) => recruit.key == 'red_antares') &&
          outcome.setFlags.contains('etc38_bit2'))
        'etc38_bit2',
      // Rigel도 ReturnJoinMember 취소 시 완료 비트를 세우지 않는다.
      if (outcome.recruits.any((recruit) => recruit.key == 'rigel') &&
          outcome.setFlags.contains('etc31_bit2'))
        'etc31_bit2',
    };
    final dialogue = LoreDialogueManager.instance;
    final progressBefore = ScriptProgressState(
      flags: dialogue.getFlagsCopy(),
      quests: dialogue.questSteps,
      sourceEtc: dialogue.partyEtc.snapshot(),
    );
    final progressAfter = ScriptWorldReducer.applyProgress(
      progressBefore,
      outcome,
      deferredFlags: deferredRecruitFlags,
    );
    for (final flag in progressAfter.flags.entries) {
      if (flag.value && progressBefore.flags[flag.key] != true) {
        dialogue.setFlag(flag.key);
      }
    }
    for (final quest in progressAfter.quests.entries) {
      if (progressBefore.quests[quest.key] != quest.value) {
        dialogue.applyQuestStep(quest.key, set: quest.value);
      }
    }
    for (final write in outcome.sourceEtcWrites) {
      dialogue.partyEtc[write.index] = progressAfter.sourceEtc[write.index]!;
    }

    if (outcome.rigelBlessing) {
      applyRigelBlessing(_party, _sessionRandom);
      setState(() {});
    }

    if (outcome.partyClassId != null || outcome.expDelta != 0) {
      setState(() {
        _party = ScriptPartyReducer.applyProgress(_party, outcome);
      });
    }
    if (outcome.expDelta != 0) {
      _addLog('⭐ 경험치 ${outcome.expDelta > 0 ? '+' : ''}${outcome.expDelta}');
    }

    for (final recruit in outcome.recruits) {
      final member = LoreJoin.byKey(recruit.key);
      if (member == null) continue;
      final joined = await _requestJoinSlot(
        PendingRecruit(member, forcedSlotOption: recruit.slot),
      );
      if (!joined) return false;
      final flag = recruitFlagByKey[recruit.key];
      if (flag != null && deferredRecruitFlags.contains(flag)) {
        LoreDialogueManager.instance.setFlag(flag);
      }
      if (recruit.key == 'red_antares' &&
          deferredRecruitFlags.contains('etc38_bit2')) {
        LoreDialogueManager.instance.setFlag('etc38_bit2');
      }
      if (recruit.key == 'rigel' &&
          deferredRecruitFlags.contains('etc31_bit2')) {
        LoreDialogueManager.instance.setFlag('etc31_bit2');
      }
    }

    // 지도와 좌표 변화는 화면 밖의 순수 상태 전이 함수에서 계산한다.
    final hasMapEffect =
        outcome.tileAtTarget != null ||
        outcome.tileChanges.isNotEmpty ||
        outcome.tileAreas.isNotEmpty ||
        outcome.playerTiles.isNotEmpty ||
        outcome.nudges.isNotEmpty ||
        outcome.stepBack ||
        (outcome.teleportX != null && outcome.teleportY != null);
    if (hasMapEffect) {
      final map = _game.currentMap;
      if (map != null) {
        final result = ScriptWorldReducer.applyMap(
          ScriptMapState(
            mapId: _game.currentMapId,
            x: _game.playerX,
            y: _game.playerY,
            direction: _game.playerDirection,
            grid: map.grid,
          ),
          outcome,
          talkTargetX: talkTargetX,
          talkTargetY: talkTargetY,
        );
        final originalMapId = _game.currentMapId;
        setState(() {
          map.grid.setAll(0, result.grid);
          if (result.mapId == originalMapId) {
            _game.playerX = result.x;
            _game.playerY = result.y;
          }
        });
        if (result.mapId != originalMapId) {
          await _game.loadMapById(
            result.mapId,
            startX: result.x,
            startY: result.y,
          );
          if (!mounted) return false;
          setState(() {});
        }
        if (outcome.teleportX != null && outcome.teleportY != null) {}
      } else if (outcome.teleportX != null && outcome.teleportY != null) {
        // 지도가 아직 준비되지 않은 진입 스크립트도 목적지 이동은 수행한다.
        final x = outcome.teleportKeepX ? _game.playerX : outcome.teleportX!;
        final y = outcome.teleportKeepY ? _game.playerY : outcome.teleportY!;
        await _game.loadMapById(
          outcome.teleportMap ?? _game.currentMapId,
          startX: x,
          startY: y,
        );
        if (!mounted) return false;
        setState(() {});
      }
    }

    // 마법의 횃불 (원작 `party.etc[1] := 1`)
    if (outcome.torchLit && _torchSteps <= 0) {
      setState(() => _torchSteps = 1);
    }

    if (outcome.events.any((event) => event.kind == 'endDemo')) {
      if (!mounted) return false;
      setState(() => _currentMode = GameScreenMode.ending);
      return false;
    }

    if (outcome.setFlags.contains('bossNecromancerDefeated')) {
      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          backgroundColor: RetroTheme.black,
          title: const SizedBox.shrink(),
          content: Text(
            outcome.messages.join('\n'),
            style: RetroTheme.dosFont.copyWith(fontSize: 11),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                LoreMenuText.viewCharPressKey,
                style: RetroTheme.dosFont,
              ),
            ),
          ],
        ),
      );
      if (!mounted) return false;
      setState(() => _currentMode = GameScreenMode.ending);
      return false;
    }

    if (outcome.battleMonsters.isNotEmpty) {
      if ((run.script.id == 'prison-battle-first' ||
              run.script.id == 'prison-battle-return') &&
          LoreJoin.removeMadJoeAtPrison(_party)) {
        setState(() {});
      }
      _pendingVictoryFlags
        ..clear()
        ..addAll(outcome.battleVictoryFlags);
      final enemies = outcome.battleReuseExisting
          ? _battleEnemies
          : outcome.battleMirrorParty
          ? createMindMirrorEnemies(_party)
          : outcome.battleMonsters
                .map((id) => LoreData.instance.monster(id))
                .toList();
      if (!outcome.battleReuseExisting) {
        _applyBattleOverrides(enemies, outcome.battleOverrides);
      }
      _startBossBattle(
        enemies,
        title: outcome.battleTitle,
        enemyFirst: outcome.battleEnemyFirst,
      );
    }
    return true;
  }

  /// 원작 `with enemy[i] do begin name := 'Sphinx'; level := 4; ac := 1; end`.
  ///
  /// 적 번호는 1부터이며 `monsters` 목록 순서와 같다.
  void _applyBattleOverrides(
    List<Monster> enemies,
    List<Map<String, Object?>> overrides,
  ) {
    for (final o in overrides) {
      final index = (o['index'] as num?)?.toInt();
      if (index == null || index < 1 || index > enemies.length) continue;
      final i = index - 1;
      enemies[i] = enemies[i].withOverrides(
        name: o['name'] as String?,
        ac: (o['ac'] as num?)?.toInt(),
        special: (o['special'] as num?)?.toInt(),
        castLevel: (o['castLevel'] as num?)?.toInt(),
        specialCastLevel: (o['specialCastLevel'] as num?)?.toInt(),
        level: (o['level'] as num?)?.toInt(),
        eNumber: (o['eNumber'] as num?)?.toInt(),
        hp: (o['hp'] as num?)?.toInt(),
      );
    }
  }

  /// 원작 `choosewhom` + 장비 지급 (`weapon := 3; wea_power := 12`).
  ///
  /// `prompt`가 참이면 원작과 같이 누가 장착할지 물어보고, 거절하면
  /// `asyouwish`("당신이 바란다면 ...") 를 남긴다.
  Future<bool> _applyScriptEquip(
    ({String kind, int index, int power, bool prompt, bool onlyUnarmed}) equip,
  ) async {
    int? chosen;
    if (equip.prompt) {
      chosen = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: RetroTheme.black,
          shape: Border.all(color: RetroTheme.lightCyan, width: 2),
          title: Text(
            '',
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
            IconButton(
              key: const ValueKey('dialog-cancel'),
              onPressed: () => Navigator.of(ctx).pop(-1),
              icon: const Icon(
                Icons.close,
                size: 16,
                color: RetroTheme.lightRed,
              ),
            ),
          ],
        ),
      );
      if (!mounted) return false;
    }
    final result = ScriptEquipReducer.apply(
      _party,
      equip,
      selectedIndex: chosen,
    );
    if (!result.accepted) {
      _addLog(
        result.rejectedMonk ? '전투승은 이 무기가 필요없습니다.' : LoreFieldLogic.asYouWish,
      );
      return false;
    }
    if (result.equippedIndexes.isNotEmpty) {
      setState(() => _party = result.party);
    }
    for (final index in result.equippedIndexes) {
      final member = _party[index];
      _addLog(ScriptEquipReducer.completionMessage(member, equip));
    }
    return true;
  }

  /// 원작 `LORESUB.PAS:1144 ReturnJoinMember` - 합류시킬 파티 슬롯(2~6번) 선택
  Future<bool> _requestJoinSlot(PendingRecruit pending) async {
    final recruit = pending.member;

    // 원작이 슬롯을 고정한 경우(예: Mad Joe = 6번)에는 선택 없이 바로 합류시킨다.
    if (pending.forcedSlotOption != null) {
      final option = pending.forcedSlotOption!;
      setState(() => LoreJoin.applyJoin(_party, recruit, option));
      return true;
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
          IconButton(
            key: const ValueKey('dialog-cancel'),
            onPressed: () => Navigator.of(ctx).pop(-1),
            icon: const Icon(Icons.close, size: 16, color: RetroTheme.lightRed),
          ),
        ],
      ),
    );

    if (option == null || option < 0) {
      _addLog(LoreJoin.joinCancelled);
      return false;
    }

    setState(() => LoreJoin.applyJoin(_party, recruit, option));
    return true;
  }

  void _handleHazardTile(TileCategory cat) {
    if (cat == TileCategory.swamp) {
      LoreMainProcedures.enterSwamp(
        party: _party,
        scrollToParty: _game.clearPeek,
        swampWalkSteps: () => _swampWalkSteps,
        setSwampWalkSteps: (steps) {
          setState(() => _swampWalkSteps = steps);
        },
        random: _sessionRandom,
        showSwampWarning: () => _addLog('일행은 독이 있는 늪에 들어갔다 !!!'),
        showPoisonMessage: (member) {
          _addLog('${member.name}는 중독 되었다.');
        },
        displayCondition: () => setState(() {}),
        displayHealthAndCondition: () {
          setState(() {});
        },
        gameOver: () => setState(() => _currentMode = GameScreenMode.gameOver),
      );
    } else if (cat == TileCategory.lava) {
      LoreMainProcedures.enterLava(
        party: _party,
        random: _sessionRandom,
        scrollToParty: _game.clearPeek,
        showLavaWarning: () => _addLog('일행은 용암지대로 들어섰다 !!!'),
        showDamage: (member, damage) =>
            _addLog('${member.name}는 $damage의 피해를 입었다 !'),
        displayCondition: () => setState(() {}),
        gameOver: () => setState(() => _currentMode = GameScreenMode.gameOver),
      );
    }
  }

  bool _handleStepTaken() {
    if (_torchSteps > 0 &&
        LoreFieldLogic.consumesTorch(
          _game.currentMapId,
          _game.playerX,
          _game.playerY,
        )) {
      _torchSteps--;
    }
    // 원본의 특수 타일 사건은 일반 이동 상태 효과와 별도로 실행한다.
    final map = _game.currentMap;
    if (map == null ||
        map.getCategory(map.getTile(_game.playerX, _game.playerY)) !=
            TileCategory.special) {
      return false;
    }

    final selected = LoreSpecialEventDispatcher.resolve(
      action: map.actionForTile(map.getTile(_game.playerX, _game.playerY)),
      mapId: _game.currentMapId,
      x: _game.playerX,
      y: _game.playerY,
      context: _scriptContext(),
      party: _party,
      scripts: _scripts,
      legacy: LoreDungeonEventManager.instance,
    );
    if (selected.script case final scriptRun?) {
      unawaited(_driveScript(scriptRun));
      return true;
    }

    if (selected.legacy case final dEvent?) {
      _addLog(dEvent.message);
      if (dEvent.foodGained > 0) {
        setState(() => _partyFood += dEvent.foodGained);
      }
      if (dEvent.goldGained > 0) {
        setState(() => _partyGold += dEvent.goldGained);
      }
      if (dEvent.bossEnemies != null && dEvent.bossEnemies!.isNotEmpty) {
        _startBossBattle(dEvent.bossEnemies!, title: dEvent.title);
      }
      return true;
    }
    return false;
  }

  void _advancePoison() {
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
  }

  Future<void> _openQuickViewDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QuickViewDialog(party: _party),
    );
  }

  Future<void> _openEspDialog() async {
    await showDialog<void>(
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

  Future<void> _openFieldMenuDialog({
    FieldMenuTab initialTab = FieldMenuTab.main,
  }) async {
    await showDialog<void>(
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
        etc: _sourceEtc.fieldCounters(),
        etcProvider: () => _sourceEtc.fieldCounters(),
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
          setState(() => map.setTile(x, y, tile));
        },
        onMindReadActivated: (count) {
          setState(() => _mindReadCount = count);
        },
        onEncounterSettingsChanged: (frequency, maxEnemies) {
          setState(() {
            _encounterFrequency = frequency;
            _maxEnemies = maxEnemies;
          });
        },
        mapTilesProvider: () => _game.currentMap?.tileSnapshot() ?? [],
        consumedScriptsProvider: () => _scripts.consumedScripts.toList(),
        onSaveDataLoaded: (save) async {
          setState(() {
            _scripts.consumedScripts
              ..clear()
              ..addAll(save.consumedScripts);
            _party = List.from(save.party);
            _partyGold = save.gold;
            _partyFood = save.food;
          });
          await _game.loadMapById(
            save.mapId,
            startX: save.playerX,
            startY: save.playerY,
            mapTiles: save.mapTiles,
          );
          if (!mounted) return;
          setState(() {});
        },
        onLog: (msg) => _addLog(msg),
      ),
    );
  }

  void _redispatchCurrentTileAfter(FieldAction action) {
    if (!mounted ||
        _currentMode != GameScreenMode.field ||
        !LoreMainProcedures.mainRedispatchesCurrentTile(action)) {
      return;
    }
    _game.tryMove(0, 0);
    setState(() {});
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
      _logRevision++;
      if (_logs.length > 80) {
        _logs.removeAt(0);
      }
    });
  }

  /// LOREBATT.PAS:396 `join(E_number, 6)` — 독심술로 설득한 적을
  /// 도감 원본 능력치로 6번 슬롯에 즉시 편입한다.
  void _onBattleTelepathyJoin(int eNumber) {
    final recruit = LoreJoin.telepathyRecruit(eNumber);
    setState(() {
      LoreJoin.applyJoin(_party, recruit, LoreJoin.forcedSixthSlotOption);
    });
  }

  /// 필드 인카운터 -> 전투 전 교전·도주 선택.
  void _startBattle() {
    final monsterIds = LoreEncounterLogic.rollMonsters(
      _game.currentMapId,
      _sessionRandom,
      maxEnemies: _maxEnemies,
    );
    if (monsterIds.isEmpty) return;
    setState(() {
      _currentMode = GameScreenMode.encounter;
      _battleEnemies = monsterIds.map(LoreData.instance.monster).toList();

      // 원작 LOREBATT.PAS:1228-1240 - 조우 화면: `적이 출현했다 !!!` /
      // `적의 평균 민첩성 : n` / `적과 교전한다` / `도망간다`
      _addLog(LoreBattText.encounter);
      for (final e in _battleEnemies) {
        _addLog('${e.name} (Lv.${e.level}, HP:${e.hp})');
      }
      _addLog(
        '${LoreBattText.enemyAgility} : ${LoreEncounterLogic.averageEnemyAgility(_battleEnemies)}',
      );
    });
  }

  void _engageEncounter() {
    if (_currentMode != GameScreenMode.encounter) return;
    _addLog(LoreBattText.engage);
    final decision = LoreEncounterLogic.decide(
      EncounterChoice.engage,
      _party,
      _battleEnemies,
    );
    _beginEncounterBattle(enemyFirst: decision.enemyFirst);
  }

  void _fleeEncounter() {
    if (_currentMode != GameScreenMode.encounter) return;
    _addLog(LoreBattText.flee);
    final decision = LoreEncounterLogic.decide(
      EncounterChoice.flee,
      _party,
      _battleEnemies,
    );
    if (decision.escaped) {
      setState(() {
        _battleEnemies = [];
        _currentMode = GameScreenMode.field;
      });
      _reclaimFocus();
      return;
    }
    _addLog(LoreBattText.runFailed);
    _beginEncounterBattle(enemyFirst: decision.enemyFirst);
  }

  void _beginEncounterBattle({required bool enemyFirst}) {
    setState(() {
      // LOREBATT.PAS:1005, also required when re-entering BattleMode.
      LoreDialogueManager.instance.setBattleResult(1);
      _battleEnemyFirst = enemyFirst;
      _battleSerial++;
      _currentMode = GameScreenMode.battle;
    });
  }

  /// 보스전 시작
  void _startBossBattle(
    List<Monster> bossEnemies, {
    String? title,
    bool enemyFirst = false,
  }) {
    setState(() {
      LoreDialogueManager.instance.setBattleResult(1); // LOREBATT.PAS:1005.
      _currentMode = GameScreenMode.battle;
      _battleEnemies = bossEnemies;
      _battleEnemyFirst = enemyFirst;
      _battleSerial++;
    });
  }

  /// 전투 승리 -> 필드로 복귀
  void _onBattleVictory(int goldEarned) {
    final pendingScript = _pendingScriptBattle;
    final targetX = _pendingScriptTargetX;
    final targetY = _pendingScriptTargetY;
    final session = ScriptBattleSession.resolve(
      before: _battleProgressState(),
      end: LoreBattleEnd.victory,
      enemies: _battleEnemies,
      pendingScript: pendingScript,
      goldEarned: goldEarned,
      victoryFlags: _pendingVictoryFlags,
    );
    _pendingScriptBattle = null;
    _pendingScriptTargetX = null;
    _pendingScriptTargetY = null;
    _pendingVictoryFlags.clear();
    setState(() {
      _applyBattleProgress(session.progress);
      _currentMode = GameScreenMode.field;
    });
    if (session.progress.bossMessage case final message?) _addLog(message);
    _focusNode.requestFocus();
    if (session.continuation case final continuation?) {
      unawaited(
        _resumeScriptAfterBattle(
          continuation,
          session.appliedOutcome!,
          session.delta,
          talkTargetX: targetX,
          talkTargetY: targetY,
        ),
      );
    }
  }

  /// 전투 도망 -> 필드로 복귀
  void _onBattleRunAway() {
    final pendingScript = _pendingScriptBattle;
    final targetX = _pendingScriptTargetX;
    final targetY = _pendingScriptTargetY;
    final session = ScriptBattleSession.resolve(
      before: _battleProgressState(),
      end: LoreBattleEnd.runAway,
      enemies: _battleEnemies,
      pendingScript: pendingScript,
    );
    _pendingScriptBattle = null;
    _pendingScriptTargetX = null;
    _pendingScriptTargetY = null;
    _pendingVictoryFlags.clear();
    setState(() {
      _applyBattleProgress(session.progress);
      _currentMode = GameScreenMode.field;
    });
    if (session.progress.bossMessage case final message?) _addLog(message);
    _focusNode.requestFocus();
    if (session.continuation case final continuation?) {
      unawaited(
        _resumeScriptAfterBattle(
          continuation,
          session.appliedOutcome!,
          session.delta,
          talkTargetX: targetX,
          talkTargetY: targetY,
        ),
      );
    }
  }

  Future<void> _resumeScriptAfterBattle(
    ScriptRun run,
    ScriptOutcome applied,
    ScriptOutcome delta, {
    int? talkTargetX,
    int? talkTargetY,
  }) async {
    final blocked = delta.blockMove;
    final completed = await _driveScript(
      run,
      alreadyApplied: applied,
      talkTargetX: talkTargetX,
      talkTargetY: talkTargetY,
    );
    final portal = _pendingPortalTransition;
    if (!mounted) return;
    if (portal == null) return;
    final action = LorePortalSession.afterPreScript(
      completed: completed,
      waitingForBattle: _pendingScriptBattle != null,
      blockMove: blocked,
    );
    if (action == LorePortalAction.waitForBattle) return;
    _pendingPortalTransition = null;
    if (action != LorePortalAction.loadMap) return;
    await _finishPortalEntry(portal.portal, portal.tx, portal.ty);
  }

  LoreBattleProgressState _battleProgressState() {
    final dialogue = LoreDialogueManager.instance;
    return LoreBattleProgressState(
      gold: _partyGold,
      lastBattleResult: dialogue.lastBattleResult,
      flags: dialogue.getFlagsCopy(),
    );
  }

  void _applyBattleProgress(LoreBattleProgressResult result) {
    final dialogue = LoreDialogueManager.instance;
    _partyGold = result.state.gold;
    dialogue.setBattleResult(result.state.lastBattleResult);
    for (final flag in result.newlySetFlags) {
      dialogue.setFlag(flag);
    }
  }

  /// 전투 패배 -> 게임 오버
  Future<void> _onBattleDefeat() async {
    final session = ScriptBattleSession.resolve(
      before: _battleProgressState(),
      end: LoreBattleEnd.defeat,
      enemies: _battleEnemies,
      pendingScript: _pendingScriptBattle,
    );
    _pendingScriptBattle = null;
    _pendingScriptTargetX = null;
    _pendingScriptTargetY = null;
    _pendingVictoryFlags.clear();
    _pendingPortalTransition = null;
    _applyBattleProgress(session.progress);
    if (session.continuation case final continuation?) {
      await _applyScriptOutcome(continuation, since: session.appliedOutcome);
      if (!mounted) return;
    }
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
            // 우측 상단 오디오 토글
            Positioned(
              top: 6,
              right: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    onTap: () async {
                      if (_entryAnimationActive) return;
                      LoreDialogueManager.instance.setBattleResult(0);
                      await _openFieldMenuDialog();
                      _redispatchCurrentTileAfter(FieldAction.openMenu);
                    },
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
                            '명령(Space)',
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
                    onTap: () async {
                      if (_entryAnimationActive) return;
                      await _openQuickViewDialog();
                      _redispatchCurrentTileAfter(FieldAction.quickView);
                    },
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
                        '[Q] 건강 상태',
                        style: RetroTheme.dosFont.copyWith(
                          fontSize: 10,
                          color: RetroTheme.lightGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () async {
                      if (_entryAnimationActive) return;
                      await _openEspDialog();
                      _redispatchCurrentTileAfter(FieldAction.extrasense);
                    },
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
                        '[E] 초능력',
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
          ],
        );

      case GameScreenMode.battle:
        return BattleViewportView(
          key: ValueKey(_battleSerial),
          battleEngine: BattleEngine(random: _sessionRandom),
          partyMembers: _party,
          enemies: _battleEnemies,
          enemyFirst: _battleEnemyFirst,
          espAccessGranted:
              LoreDialogueManager.instance.getFlagsCopy()['etc39_bit1'] == true,
          onLog: (msg) => _addLog(msg),
          onVictory: _onBattleVictory,
          onTelepathyJoin: _onBattleTelepathyJoin,
          onDefeat: _onBattleDefeat,
          onRunAway: _onBattleRunAway,
        );

      case GameScreenMode.encounter:
        return EncounterViewportView(
          enemies: _battleEnemies,
          onEngage: _engageEncounter,
          onFlee: _fleeEncounter,
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
                child: Text(LoreSubText.resumeGame, style: RetroTheme.dosFont),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: RetroTheme.lightRed),
                  foregroundColor: RetroTheme.lightRed,
                ),
                onPressed: () => SystemNavigator.pop(),
                child: Text(LoreSubText.endGame, style: RetroTheme.dosFont),
              ),
            ],
          ),
        );
      case GameScreenMode.ending:
        return const SizedBox.shrink();
    }
  }

  String _getViewportTitle() {
    switch (_currentMode) {
      case GameScreenMode.field:
        return '';
      case GameScreenMode.battle:
        return '';
      case GameScreenMode.encounter:
        return '';
      case GameScreenMode.gameOver:
        return '';
      case GameScreenMode.ending:
        return '';
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMode == GameScreenMode.ending) {
      return Scaffold(
        backgroundColor: RetroTheme.black,
        body: EndingView(heroName: _party.first.name, onFinish: _restartGame),
      );
    }
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) async {
        if (_entryAnimationActive) return;
        if (_currentMode == GameScreenMode.encounter && event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.digit1 ||
              event.logicalKey == LogicalKeyboardKey.numpad1) {
            _engageEncounter();
          } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
              event.logicalKey == LogicalKeyboardKey.numpad2) {
            _fleeEncounter();
          }
          return;
        }
        if (_currentMode == GameScreenMode.field) {
          if (event is KeyDownEvent) {
            // 원작 LOREMAIN.PAS 핫키: P/V/Q/C/E/R/G + Space
            final action = FieldHotkeys.resolve(event.logicalKey);
            switch (action) {
              case FieldAction.openMenu:
                // LOREMAIN.Main clears party.etc[6] before SelectMode.
                LoreDialogueManager.instance.setBattleResult(0);
                await _openFieldMenuDialog();
              case FieldAction.viewParty:
                await _openFieldMenuDialog(initialTab: FieldMenuTab.partyView);
              case FieldAction.viewCharacter:
                await _openFieldMenuDialog(
                  initialTab: FieldMenuTab.characterView,
                );
              case FieldAction.castSpell:
                await _openFieldMenuDialog(initialTab: FieldMenuTab.castSpell);
              case FieldAction.rest:
                await _openFieldMenuDialog(initialTab: FieldMenuTab.rest);
              case FieldAction.gameOption:
                await _openFieldMenuDialog(initialTab: FieldMenuTab.gameOption);
              case FieldAction.toggleSound:
                setState(() => AudioManager.instance.toggleMute());
              case FieldAction.quickView:
                await _openQuickViewDialog();
              case FieldAction.extrasense:
                await _openEspDialog();
              case FieldAction.guide:
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => const LoreGuideDialog(),
                );
              case FieldAction.none:
                break;
            }
            if (action != FieldAction.none) {
              _redispatchCurrentTileAfter(action);
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
          child: GameScreenLayout(
            viewport: ViewportView(
              title: _getViewportTitle(),
              overlayTitle: true,
              content: _buildViewportContent(),
            ),
            party: PartyStatusView(members: _mapPartyStatus()),
            messages: MessageLogView(logs: _logs, revision: _logRevision),
            controls: _currentMode == GameScreenMode.field
                ? Opacity(
                    opacity: .6,
                    child: DPadWidget(
                      onDirectionPressed: (dx, dy) {
                        if (_entryAnimationActive ||
                            _currentMode != GameScreenMode.field) {
                          return;
                        }
                        _game.tryMove(dx, dy);
                        setState(() {});
                        _reclaimFocus();
                      },
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
