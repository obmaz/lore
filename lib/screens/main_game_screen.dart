import 'dart:async';
import 'dart:math';

import '../logic/lore_transient_slots.dart';
import '../logic/lore_random.dart';
import '../logic/lore_main_input.dart';

import '../logic/lore_batt_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';

import '../theme/retro_theme.dart';
import '../services/audio_manager.dart';
import '../services/source_palette.dart';
import '../game/lore_game.dart';
import '../game/lore_world_manager.dart';
import '../logic/field_hotkeys.dart';
import '../logic/lore_sub_text.dart';
import '../logic/lore_field_logic.dart';
import '../logic/lore_encounter_logic.dart';
import '../logic/lore_special_event_dispatcher.dart';
import '../logic/lore_portal_session.dart';
import '../logic/lore_battle_progress.dart';
import '../logic/lore_mirror_enemy.dart';
import '../logic/lore_rigel_blessing.dart';
import '../logic/script_battle_session.dart';
import '../logic/script_equip_reducer.dart';
import '../logic/script_party_reducer.dart';
import '../logic/script_world_reducer.dart';
import '../logic/lore_join.dart';
import '../logic/town_logic.dart';
import '../logic/lore_cast_spell.dart';
import '../logic/lore_extrasense.dart';
import '../logic/lore_town_shops.dart';
import '../logic/lore_view_procedures.dart';
import '../logic/lore_game_option.dart';
import '../logic/lore_game_over.dart';
import '../logic/lore_main_procedures.dart';
import '../logic/lore_talk_dispatcher.dart';
import '../logic/lore_talk_mode.dart';
import '../logic/lore_remains_blink.dart';
import '../logic/lore_special_arrival.dart';
import '../logic/lore_water_lord.dart';
import '../logic/lore_spec_procedures.dart';
import '../logic/lore_source_memory.dart';
import '../logic/lore_save_party.dart';
import '../logic/lore_load_weather.dart';
import '../logic/lore_load_failure.dart';
import '../logic/lore_ent_procedures.dart';
import '../models/party_member.dart';
import '../models/monster.dart';
import '../data/lore_data.dart';
import '../data/lore_script.dart';
import '../widgets/viewport_view.dart';
import '../widgets/game_screen_layout.dart';
import '../widgets/party_status_view.dart';
import '../widgets/message_log_view.dart';
import '../widgets/dialogue_history_view.dart';
import '../logic/lore_dialogue_history.dart';
import '../logic/lore_source_speech.dart';
import '../widgets/dpad_widget.dart';
import '../widgets/battle_viewport_view.dart';
import '../widgets/encounter_viewport_view.dart';
import '../widgets/lore_window.dart';
import '../widgets/script_scene_dialog.dart';
import '../game/lore_map_manager.dart';
import '../services/save_manager.dart';
import '../game/lore_dialogue_manager.dart';
import '../logic/lore_menu_text.dart';
import '../widgets/ending_view.dart';
import '../widgets/game_over_view.dart';
import '../widgets/lore_select_view.dart';
import '../widgets/browser_fullscreen_button.dart';
import '../widgets/app_settings_button.dart';

enum GameScreenMode { field, encounter, battle, gameOver, ending }

/// 화면 비율에 맞춰 정사각형 맵과 상태·대화 패널을 배치한다.
class MainGameScreen extends StatefulWidget {
  final List<PartyMember>? initialParty;
  final SaveData? initialSaveData;

  /// 필드·위험 지형·몬스터 편성·전투가 공유하는 난수원.
  final Random? encounterRandom;

  /// `Halt` 뒤 호출(기본값은 `SystemNavigator.pop`; 테스트용 주입).
  final VoidCallback? onHalt;
  final LoreMapLoader? mapLoader;
  final LoreFontLoader? fontLoader;

  const MainGameScreen({
    super.key,
    this.initialParty,
    this.initialSaveData,
    this.encounterRandom,
    this.onHalt,
    this.mapLoader,
    this.fontLoader,
  });

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  late final Random _sessionRandom;
  late final LoreScriptEngine _scripts;
  GameScreenMode _currentMode = GameScreenMode.field;
  bool _lastSceneKeyWasEscape = false;
  late List<PartyMember> _party;
  late LoreGame _game;
  final LoreScrollState _sourceScroll = LoreScrollState();
  final List<String> _logs = [];
  final List<int> _logColors = [];
  int _logRevision = 0;

  /// `이전 대화` 탭: 대사 창에 보였던 NPC 대사(이번 접속 동안).
  final LoreDialogueHistory _dialogueHistory = LoreDialogueHistory();

  /// The `Print` lines that stay on screen while the `Select` of a speech is
  /// open (`select(.., clean = FALSE, ..)`): shown above its items.
  List<(int, String)> _choiceLines = const [];
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

  /// The entrance waiting on its pre-script; [fromMap] is the map whose
  /// `entermode` arm is running (it stays that arm after a GameOver reload).
  ({PortalInfo portal, int tx, int ty, int fromMap})? _pendingPortalTransition;
  bool _entryAnimationActive = false;

  // 전투 모드 상태
  List<Monster> _battleEnemies = [];
  // Pascal enemy[1..7] survives shorter encounters; saves do not store it.
  final _transientSlots = LoreTransientSlots();
  List<Monster?> get _sourceEnemySlots => _transientSlots.enemies;

  void _retainEnemySlots(List<Monster> enemies) {
    for (var i = 0; i < enemies.length && i < 7; i++) {
      _sourceEnemySlots[i] = enemies[i];
    }
  }

  Set<int> get _inactiveDeadEnemySlots {
    _retainEnemySlots(_battleEnemies); // includes enemies summoned this round.
    return {
      for (var i = _battleEnemies.length; i < 7; i++)
        if (_sourceEnemySlots[i]?.isDead == true) i + 1,
    };
  }

  // GameOver 상태 (`party.etc[6]` 갈래, 진행 중인 화면, `Halt`)
  int _gameOverEtc6 = 255;
  int _gameOverSerial = 0;
  Completer<LoreGameOverResult>? _gameOverDone;
  LoreGameOverResult? _halt;

  final FocusNode _focusNode = FocusNode();
  bool _appSettingsOpen = false;

  @override
  void initState() {
    super.initState();
    _sessionRandom = widget.encounterRandom ?? LoreRandom.fromClock();
    _scripts = LoreScriptEngine.instance.fork(random: _sessionRandom);
    _initParty();
    _initGame();
    // 화면 진입 직후 키보드 포커스를 게임으로 가져온다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reclaimFocus());
  }

  /// 버튼/대화상자 조작 뒤 키보드 입력이 게임으로 돌아오게 한다.
  void _reclaimFocus() {
    if (mounted && !_appSettingsOpen && !_focusNode.hasPrimaryFocus) {
      _focusNode.requestFocus();
    }
  }

  void _initParty() {
    if (widget.initialSaveData != null) {
      _party = LoreSaveParty.snapshot(widget.initialSaveData!.party);
      _partyGold = widget.initialSaveData!.gold;
      _partyFood = widget.initialSaveData!.food;
      LoreDialogueManager.instance.loadFlags(
        widget.initialSaveData!.flags,
        fieldCounters: widget.initialSaveData!.etc,
      );
      _scripts.consumedScripts
        ..clear()
        ..addAll(widget.initialSaveData!.consumedScripts);
      _normalizeLoadedEtc();
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
    // LORESUB.PAS Set_All: initial Display_Condition.
    PartyMember.simpleDisCond(_party);
  }

  /// LORESUB `Load`: `if not (encounter^ in [1..3]) then encounter^ := 2;
  /// if not (maxenemy^ in [3..7]) then maxenemy^ := 5` (etc[7], etc[8]), on
  /// every save load and map change.
  void _normalizeLoadedEtc() {
    if (_encounterFrequency < 1 || _encounterFrequency > 3) {
      _encounterFrequency = 2;
    }
    if (_maxEnemies < 3 || _maxEnemies > 7) _maxEnemies = 5;
    _sourceScroll.restore(_sourceEtc);
  }

  void _initGame() {
    _logs.clear();
    _logColors.clear();

    final initialMapId = widget.initialSaveData?.mapId ?? 6;
    final startX = widget.initialSaveData?.playerX ?? 51;
    final startY = widget.initialSaveData?.playerY ?? 31;

    _game = LoreGame(
      sourceScroll: _sourceScroll,
      initialMapId: initialMapId,
      initialPlayerX: startX,
      initialPlayerY: startY,
      initialMapTiles: widget.initialSaveData?.mapTiles,
      initialMapWidth: widget.initialSaveData?.mapWidth,
      initialMapHeight: widget.initialSaveData?.mapHeight,
      initialSnapshotName: 'save${widget.initialSaveData?.slot ?? 1}.map',
      random: _sessionRandom,
      mapLoader: widget.mapLoader,
      fontLoader: widget.fontLoader,
      onLoadFailure: (failure) {
        if (!mounted) return;
        AudioManager.instance.stopBgm();
        setState(() => _loadFailure = failure);
      },
      onLog: (msg) => _addLog(msg),
      onSign: _printLines,
      onMapLoaded: _normalizeLoadedEtc,
      onEncounter: () => _startBattle(),
      encounterFrequencyProvider: () => _encounterFrequency,
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
      canWalkOnWater: () => _waterWalkSteps > 0,
      waterWalkStepsProvider: () => _waterWalkSteps,
      onWaterWalkStepsChanged: (steps) {
        setState(() => _waterWalkSteps = steps);
      },
      onHazardTile: (cat) => _handleHazardTile(cat),
      onMoveMode: () {
        unawaited(
          LoreMainProcedures.moveMode(
            party: _party,
            scrollToParty: _game.clearPeek,
            displayHealthAndCondition: _displayCondition,
            gameOver: _detectedGameOver,
            mindReadSteps: () => _mindReadCount,
            setMindReadSteps: (steps) => setState(() => _mindReadCount = steps),
            encounterFrequency: () => _encounterFrequency,
            random: _sessionRandom.nextInt,
            encounterEnemy: _startBattle,
          ).then((_) => _continuePositionBlocks()),
        );
      },
      onMindReadTick: () {
        if (_mindReadCount > 0) setState(() => _mindReadCount--);
      },
      onStepTaken: () => _handleStepTaken(),
      partyProvider: () => _party,
      scriptContextProvider: _scriptContext,
      scriptEngine: _scripts,
      onTalkProcedure: _runTalkProcedure,
      onPortalRequested: (portal, tx, ty) =>
          _confirmPortalEntry(portal, tx, ty),
    );
  }

  /// 원작 `LORESUB.PAS:986 wantenter` / `:999 wantexit`
  /// 성문·동굴 입구 진입 여부를 확인한 뒤 이동한다.
  Future<void> _confirmPortalEntry(PortalInfo portal, int tx, int ty) async {
    _scriptDepth++;
    try {
      await _confirmPortalEntryBody(portal, tx, ty);
    } finally {
      _scriptDepth--;
    }
  }

  Future<void> _confirmPortalEntryBody(
    PortalInfo portal,
    int tx,
    int ty, {
    bool forceSourceExit = false,
  }) async {
    // Map 7's secret wall write precedes its exit question in the source.
    if (_game.currentMapId == 7 && (tx == 30 || tx == 32) && ty == 71) {
      _game.currentMap!.setTile(31, ty, 45);
    }
    final sourceRejectY = forceSourceExit
        ? ty - 1
        : LoreWorldManager.sourceExitRejectY(_game.currentMapId, ty, x: tx);
    final sourceDungeonExit =
        sourceRejectY != null &&
        (forceSourceExit ||
            !LoreWorldManager.sourceAsksEnter(_game.currentMapId, tx, ty));
    final leavingTown =
        sourceDungeonExit ||
        _game.currentMapName.startsWith('TOWN') &&
            LoreWorldManager.mapRegistry[portal.targetMapId]?.category ==
                MapCategory.ground;
    final prompt = leavingTown
        ? LoreFieldLogic.exitPrompt
        : LoreFieldLogic.enterPrompt(portal.name);

    // LORESUB.wantenter/wantexit use Select(..., FALSE, TRUE): row one
    // by default, arrows/Enter select and Esc returns zero. Keep Print(11)
    // as a colored line rather than inventing a yellow dialog heading.
    final choice = await showLoreSelectDialog(
      context,
      title: '',
      lines: [(11, prompt)],
      items: const [LoreFieldLogic.confirmYes, LoreFieldLogic.confirmNo],
    );
    if (!mounted) return;
    final confirmed = LorePortalSession.acceptsChoice(choice);

    final plan = LorePortalSession.begin(
      confirmed: confirmed,
      portal: portal,
      context: _scriptContext(),
      scripts: _scripts,
      x: tx,
      y: ty,
    );
    if (plan.action == LorePortalAction.cancelled) {
      // Refusing the first IF does not skip the following IF y = 71.
      if (_game.currentMapId == 7 && tx == 50 && ty == 71 && !forceSourceExit) {
        await _confirmPortalEntryBody(
          const PortalInfo(
            targetMapId: 1,
            targetX: 77,
            targetY: 57,
            name: 'TOWN2 출구',
          ),
          tx,
          ty,
          forceSourceExit: true,
        );
        return;
      }
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
          await _showDialogue([
            for (final line in pre.outcome.messages) (13, line),
          ]);
          if (!mounted) return;
          if (_party.length >= 6 && _party[5].name == 'Draconian') {
            LoreEntProcedures.strikeDraconianBeforeDungeon(_party);
            _displayCondition();
            await _showDialogue(const [
              (7, ' ArchiDraconian은 마지막에 있는 Draconian'),
              (7, '을 발견했다.'),
              (13, ' 아니 너는 누구냐! 감히 Draconian 족이면'),
              (13, '서 Necromancer님에게 반기를 들다니... 그'),
              (13, '것은 바로 죽음이다. 받아랏!!'),
            ]);
            if (!mounted) return;
          }
          alreadyApplied = ScriptOutcome(
            messages: pre.outcome.messages,
            events: pre.outcome.events,
          );
        }
        _pendingPortalTransition = (
          portal: portal,
          tx: tx,
          ty: ty,
          fromMap: _game.currentMapId,
        );
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
        _pendingPortalTransition = (
          portal: portal,
          tx: tx,
          ty: ty,
          fromMap: _game.currentMapId,
        );
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

  Future<void> _finishPortalEntry(
    PortalInfo portal,
    int tx,
    int ty, {
    int? fromMap,
  }) async {
    final enteredFromMap = fromMap ?? _game.currentMapId;
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
      sourceEtc: context.sourceEtc,
    );
    if (!mounted) return;
    _game.finishEntrance();
    setState(() {});
    // The later `if position = ...` blocks of Main see the arrival cell.
    _continuePositionBlocks();
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

  void _refreshTalkWindow() {
    if (mounted) setState(() {});
  }

  void _showRemainsFrame(LoreRemainsFrame frame) {
    if (mounted) setState(() => _game.remainsBlinkFrame = frame);
  }

  Future<void> _runTalkProcedure(
    LoreTalkProcedure procedure,
    int tx,
    int ty,
  ) async {
    _scriptDepth++;
    try {
      switch (procedure) {
        case LoreTalkProcedure.talkMode:
          await LoreTalkMode.run(
            mapId: _game.currentMapId,
            targetX: tx,
            targetY: ty,
            x: _game.playerX,
            y: _game.playerY,
            party: _party,
            etc: _sourceEtc,
            roll: _scripts.roll,
            io: _ScreenTalkIo(this),
          );
        case LoreTalkProcedure.waterFieldLord:
          await LoreWaterLord.run(
            party: _party,
            etc: _sourceEtc,
            io: _ScreenTalkIo(this),
          );
      }
      if (mounted) {
        _game.clearPeek();
        setState(() {});
      }
    } finally {
      _scriptDepth--;
    }
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
    // The source blocks all input while an event runs: no pad or arrow-key
    // step may start another one meanwhile.
    _scriptDepth++;
    try {
      return await _driveScriptBody(
        run,
        alreadyApplied: alreadyApplied,
        talkTargetX: talkTargetX,
        talkTargetY: talkTargetY,
      );
    } finally {
      _scriptDepth--;
      _game.specialArrivalDraws.clear();
      if (_scriptDepth == 0 && _currentMode == GameScreenMode.field) {
        _reclaimFocus();
      }
    }
  }

  int _scriptDepth = 0;

  Future<bool> _driveScriptBody(
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
      if (current.pendingConditionRefresh) {
        if (!mounted) return false;
        _displayCondition();
        current = current.acknowledgeConditionRefresh();
        continue;
      }
      if (current.awaitingBattle) {
        _pendingScriptBattle = current;
        _pendingScriptTargetX = talkTargetX;
        _pendingScriptTargetY = talkTargetY;
        return false;
      }
      if (current.pendingScene case final scene?) {
        if (!mounted) return false;
        final shown = scene.withPartyNames([
          for (final member in _party) member.name,
        ]);
        // The story speech of a scene is kept in the previous-dialogue tab too.
        _dialogueHistory.addColored([
          ..._scenePrefix,
          for (var i = 0; i < shown.lines.length; i++)
            (
              shown.lineColors[i] ??
                  LoreSourceSpeech.lines[shown.lines[i]]?.color ??
                  7,
              shown.lines[i],
            ),
          if (shown.lines.isNotEmpty &&
              LoreSourceSpeech.lines[shown.lines.last]?.blank == true)
            (7, ''),
        ]);
        LogicalKeyboardKey? sceneKey;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ScriptSceneDialog(
            scene: shown,
            prefixLines: _scenePrefix,
            actors: [for (final id in scene.actors) Monster.create(id)],
            onKeyAcknowledged: (key) {
              // End_Demo/ThunderEffect inherit the source's shared c from
              // the farewell PressAnyKey; it is not reset before ThunderEffect.
              sceneKey = key;
            },
          ),
        );
        if (!mounted) return false;
        // System back is the scene adapter's Esc acknowledgement too.
        _lastSceneKeyWasEscape =
            sceneKey == null || sceneKey == LogicalKeyboardKey.escape;
        current = current.acknowledgeScene();
        continue;
      }
      final options = current.pendingChoice;
      if (options == null) return true;
      if (!mounted) return false;

      // The speech lines stay above the menu (`select(.., clean = FALSE, ..)`);
      // `m[0]` is the title ('' when the source leaves it empty).
      final held = _choiceLines;
      _choiceLines = const [];
      if (held.isNotEmpty) {
        _dialogueHistory.addColored(held);
      }
      final k = await showLoreSelectDialog(
        context,
        title: current.choicePrompt ?? '',
        items: options,
        lines: held,
      );
      if (!mounted) return false;
      final int? chosen = k == 0 ? null : k - 1;
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

  /// NPC 대사: 원작처럼 대사 창 하나에 `Print` 줄들이 쌓이고 `PressAnyKey`로
  /// 닫는다. 줄은 원본 그대로이며, 닫은 뒤에는 `이전 대화` 탭에서 다시 본다.
  Future<void> _showDialogue(List<(int, String)> lines) async {
    if (lines.isEmpty || !mounted) return;
    _dialogueHistory.addColored(lines);
    await showLoreMessageDialog(context, lines: lines);
  }

  List<(int, String)> _scenePrefix = const [];

  Future<void> _playSpecialArrival(String kind) async {
    final startX = _game.playerX;
    final startY = _game.playerY;
    _entryAnimationActive = true;
    _game.specialArrivalDraws.clear();
    try {
      if (kind == 'final') {
        _clearSourceMessageWindow();
        _game.applySourceFace(5);
        setState(() {});
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        for (var i = 1; i <= 3; i++) {
          if (!mounted) return;
          _game.playerY--;
          setState(() {});
          await Future<void>.delayed(const Duration(milliseconds: 1500));
        }
        _game.applySourceFace(6);
        while (_game.playerX < 26) {
          if (!mounted) return;
          _game.playerX++;
          setState(() {});
          await Future<void>.delayed(const Duration(milliseconds: 1500));
        }
        _game.applySourceFace(5);
      } else {
        _addLog(' 금속으로된 어떤 적이 나타났다.', color: 15);
      }
      final operations = kind == 'final'
          ? LoreSpecialArrival.finalActors(_game.playerX, _game.playerY)
          : LoreSpecialArrival.guardian(startX, startY);
      for (final op in operations) {
        if (!mounted) return;
        if (op.kind == 'delay') {
          setState(() {});
          await Future<void>.delayed(Duration(milliseconds: op.index));
        } else {
          _game.addSpecialArrivalDraw(op);
        }
      }
      if (mounted) setState(() {});
      if (kind == 'guardian' && mounted) _clearSourceMessageWindow();
    } finally {
      // The outcome reducer commits the original nudges once after presentation.
      _game.playerX = startX;
      _game.playerY = startY;
      _entryAnimationActive = false;
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
    _scenePrefix = const [];
    final renderedScene = sourceScene?.withPartyNames([
      for (final member in _party) member.name,
    ]);
    String presented(String message) {
      final line = sourceScene?.appendPartyNameLine;
      if (line != null && message == sourceScene!.lines[line]) {
        return renderedScene!.lines[line];
      }
      // `{hero}` is the source's `player[1].name`, `{sex}` its `ReturnSex(1)`.
      if (message.contains('{hero}') || message.contains('{sex}')) {
        final first = _party.isEmpty ? null : _party.first;
        return message
            .replaceAll('{hero}', first?.name ?? '')
            .replaceAll('{sex}', first?.sex == Gender.female ? '여성' : '남성');
      }
      return message;
    }

    // LORETALK, LORESPEC and LOREENT share the source Print/PressAnyKey
    // window. Only Message/asyouwish is an immediate log line.
    final isTalk = talkTargetX != null;
    final speech = <(int, String)>[];
    List<(int, String)> equipmentLines = const [];
    Future<void> flushSpeech() async {
      if (speech.isEmpty) return;
      final lines = List<(int, String)>.of(speech);
      speech.clear();
      await _showDialogue(lines);
    }

    Future<void> say(String text) async {
      final source = isTalk
          ? LoreSourceSpeech.talkLines[text]
          : LoreSourceSpeech.lines[text];
      if (source?.log == true) {
        await flushSpeech();
        if (mounted) _addLog(text);
        return;
      }
      speech.add((source?.color ?? 7, text));
      if (source?.blank == true) speech.add((7, ''));
      // LORETALK already carries explicit pause events; preserve those boundaries.
      if (!isTalk && source?.wait == true) await flushSpeech();
    }

    // A speech that ends in a `Select` keeps its lines on screen under the
    // menu, with no key wait of their own.
    final holdsChoice = run.pendingChoice != null;
    Future<void> endSpeech() async {
      if (holdsChoice) {
        _choiceLines = List<(int, String)>.of(speech);
        speech.clear();
      } else if (sourceScene != null) {
        // Print lines followed by talk/PressAnyKey share one source window.
        _scenePrefix = List<(int, String)>.of(speech);
        speech.clear();
      } else if (outcome.equips.any((equip) => equip.prompt)) {
        equipmentLines = List<(int, String)>.of(speech);
        speech.clear();
      } else {
        await flushSpeech();
      }
    }

    if (outcome.events.isEmpty) {
      for (final m in outcome.messages) {
        await say(presented(m));
        if (!mounted) return false;
      }
      await endSpeech();
    } else {
      // 대사와 카메라 연출(원작 scroll(FALSE))을 원작 순서대로 재생한다.
      for (final event in outcome.events) {
        if (event.kind == 'peek') {
          await flushSpeech();
          if (!mounted) return false;
          _game.peekAt(event.x!, event.y!);
          setState(() {});
          await Future<void>.delayed(_peekHold);
          if (!mounted) return false;
        } else if (event.kind == 'sourceFace') {
          _game.applySourceFace(event.face!);
        } else if (event.kind == 'specialArrival') {
          if (event.text == 'guardian' && outcome.torchLit) {
            _torchSteps = 1;
          }
          await _playSpecialArrival(event.text!);
          if (!mounted) return false;
        } else if (event.kind == 'message') {
          await say(presented(event.text!));
          if (!mounted) return false;
        } else if (event.kind == 'sceneLine') {
          // Displayed once by the same message window via ScriptSceneDialog.
          continue;
        } else if (event.kind == 'log') {
          // `message(color, s)`/`asyouwish`: one line, no key wait.
          await flushSpeech();
          if (!mounted) return false;
          _addLog(presented(event.text!));
        } else if (event.kind == 'pause') {
          // `talk(..)`/`PressAnyKey` inside a speech: the window is cleared.
          await flushSpeech();
          if (!mounted) return false;
        }
      }
      await endSpeech();
      if (!mounted) return false;
      _game.clearPeek();
      setState(() {});
    }

    for (final equip in outcome.equips) {
      if (!await _applyScriptEquip(equip, lines: equipmentLines)) return false;
      equipmentLines = const [];
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
      // Mad Joe writes bit2 only after join, Display_Condition, map mutation
      // and Silent_Scroll (LORETALK:198-215), including on a repeat recruit.
      if (outcome.recruits.any((recruit) => recruit.key == 'mad_joe'))
        'etc50_bit2',
      if (outcome.recruits.any((recruit) => recruit.key == 'lore_hunter'))
        'etc38_bit4',
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

    for (final recruit in outcome.recruits) {
      final member = LoreJoin.byKey(recruit.key);
      if (member == null) continue;
      final joined = await _requestJoinSlot(
        PendingRecruit(member, forcedSlotOption: recruit.slot),
      );
      if (!joined) {
        // `if k = 1 then ... exit`: the arm's own refusal steps, then nothing.
        if (recruit.cancelSteps.isNotEmpty && mounted) {
          await _driveScript(
            _scripts.startProcedure(
              LoreScript(
                id: 'join-refused-${recruit.key}',
                trigger: 'step',
                map: _game.currentMapId,
                once: false,
                require: const ScriptRequire(),
                steps: recruit.cancelSteps,
              ),
              _scriptContext(),
            ),
          );
        }
        return false;
      }
      final flag = recruitFlagByKey[recruit.key];
      if (const {'mad_joe', 'polaris', 'lore_hunter'}.contains(recruit.key)) {
        _displayCondition();
      }
      if (flag != null &&
          !const {'mad_joe', 'polaris', 'lore_hunter'}.contains(recruit.key) &&
          deferredRecruitFlags.contains(flag)) {
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

    if (outcome.recruits.any((recruit) => recruit.key == 'mad_joe')) {
      _game.clearPeek(); // Silent_Scroll after map[40,15] := 47.
      for (final flag in const ['madJoeJoined', 'etc50_bit2']) {
        if (deferredRecruitFlags.contains(flag)) dialogue.setFlag(flag);
      }
    }

    if (outcome.recruits.any((recruit) => recruit.key == 'polaris')) {
      _game.clearPeek(); // Display_Condition -> tile 44 -> Silent_Scroll.
      if (deferredRecruitFlags.contains('polarisJoined')) {
        dialogue.setFlag('polarisJoined');
      }
    }

    if (outcome.recruits.any((recruit) => recruit.key == 'lore_hunter')) {
      _game.clearPeek(); // tile 44 -> Silent_Scroll -> etc[38] OR bit4.
      for (final flag in const ['etc38_bit4', 'loreHunterJoined']) {
        if (deferredRecruitFlags.contains(flag)) dialogue.setFlag(flag);
      }
    }

    // 마법의 횃불 (원작 `party.etc[1] := 1`)
    if (outcome.torchLit && _torchSteps <= 0) {
      setState(() => _torchSteps = 1);
    }

    if (outcome.events.any((event) => event.kind == 'endDemo')) {
      if (!mounted) return false;
      // End_Demo starts FadeIn/FadeSub, replacing the field DAC palette.
      SourcePalette.instance.reset();
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
      SourcePalette.instance.reset();
      setState(() => _currentMode = GameScreenMode.ending);
      return false;
    }

    if (outcome.battleMonsters.isNotEmpty) {
      if ((run.script.id == 'prison-battle-first' ||
              run.script.id == 'prison-battle-return') &&
          LoreJoin.removeMadJoeAtPrison(_party)) {
        // LORESPEC.PAS:222-228: removal, Display_Condition, PressAnyKey.
        _displayCondition();
        await _showDialogue(const [
          (7, ' 우리들 뒤에 있던  Mad Joe가 전투가 일어나'),
          (7, '자마자 도망을 가버렸다.'),
        ]);
        if (!mounted) return false;
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
    ({String kind, int index, int power, bool prompt, bool onlyUnarmed})
    equip, {
    List<(int, String)> lines = const [],
  }) async {
    int? chosen;
    if (equip.prompt) {
      final indexes = [
        for (var i = 0; i < _party.length && i < 6; i++)
          if (_party[i].name.isNotEmpty) i,
      ];
      if (lines.isNotEmpty) {
        _dialogueHistory.addColored(lines);
      }
      final k = await showLoreSelectDialog(
        context,
        title: '',
        lines: lines,
        items: [for (final i in indexes) _party[i].name],
      );
      chosen = k == 0 ? -1 : indexes[k - 1];
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
      final message = ScriptEquipReducer.completionMessage(member, equip);
      if (message != null) _addLog(message);
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

    // LORESUB `ReturnJoinMember := select(80,5,5,FALSE,TRUE) + 1`: m[1..5] are
    // player[2..6].name (m[5] '보조 일원으로 둠' when empty); 1 (Esc) refuses.
    final k = await showLoreSelectDialog(
      context,
      title: LoreJoin.joinMenuPrompt,
      items: LoreJoin.joinMenuLabels(_party),
    );
    if (!mounted || k == 0) return false;
    final option = k - 1;
    setState(() => LoreJoin.applyJoin(_party, recruit, option));
    return true;
  }

  /// LOREMAIN `Main` runs its `if position = ...` blocks one after another
  /// (town, ground, den, keep). A map loaded inside one block (an entrance, a
  /// GameOver reload, a special event) makes every later block whose position
  /// now matches dispatch the arrival cell as a step of its own.
  void _continuePositionBlocks() {
    if (!mounted ||
        _currentMode != GameScreenMode.field ||
        _halt != null ||
        !LoreMainProcedures.dispatchesArrivalCell(
          _game.dispatchStartMapId,
          _game.currentMapId,
        )) {
      return;
    }
    _game.tryMove(0, 0);
    setState(() {});
  }

  void _handleHazardTile(TileCategory cat) {
    if (cat == TileCategory.swamp) {
      unawaited(
        LoreMainProcedures.enterSwamp(
          party: _party,
          scrollToParty: _game.clearPeek,
          swampWalkSteps: () => _swampWalkSteps,
          setSwampWalkSteps: (steps) {
            setState(() => _swampWalkSteps = steps);
          },
          random: _sessionRandom,
          showSwampWarning: () => _addLog('일행은 독이 있는 늪에 들어갔다 !!!', color: 12),
          showPoisonMessage: (member) {
            _addLog('${member.name}는 중독 되었다.', color: 13);
          },
          displayCondition: _displayCondition,
          displayHealthAndCondition: _displayCondition,
          gameOver: _detectedGameOver,
          clearMessageWindow: _clearSourceMessageWindow,
        ).then((_) => _continuePositionBlocks()),
      );
    } else if (cat == TileCategory.lava) {
      unawaited(
        LoreMainProcedures.enterLava(
          party: _party,
          random: _sessionRandom,
          scrollToParty: _game.clearPeek,
          showLavaWarning: () => _addLog('일행은 용암지대로 들어섰다 !!!', color: 12),
          showDamage: (member, damage) =>
              _addLog('${member.name}는 $damage의 피해를 입었다 !', color: 13),
          displayCondition: _displayCondition,
          gameOver: _detectedGameOver,
          clearMessageWindow: _clearSourceMessageWindow,
        ).then((_) => _continuePositionBlocks()),
      );
    }
  }

  void _clearSourceMessageWindow() {
    setState(() {
      _logs.clear();
      _logColors.clear();
      _logRevision++;
    });
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
    );
    if (selected.script case final scriptRun?) {
      unawaited(_driveScript(scriptRun).then((_) => _continuePositionBlocks()));
      return true;
    }

    return false;
  }

  /// `Print` lines the source leaves in the window (no key wait).
  void _printLines(List<(int, String)> lines) {
    for (final (color, text) in lines) {
      _addLog(text, color: color);
    }
  }

  /// LOREMENU `ViewParty` (hotkey P or SelectMode 1).
  Future<void> _runViewParty() async => _printLines(
    LoreViewProcedures.viewParty(
      x: _game.playerX,
      y: _game.playerY,
      food: _partyFood,
      gold: _partyGold,
      etc: _sourceEtc,
    ),
  );

  /// LOREMENU `QuickView` (hotkey Q or SelectMode 3).
  Future<void> _runQuickView() async =>
      _printLines(LoreViewProcedures.quickView(_party));

  /// LOREMENU `ViewCharacter` (hotkey V or SelectMode 2): the prompt and
  /// `ChooseWhom`, the first page with `PressAnyKey`, then the second page.
  Future<void> _runViewCharacter() async {
    final slots = [
      for (var i = 0; i < _party.length && i < 6; i++)
        if (_party[i].name.isNotEmpty) i,
    ];
    final k = await showLoreSelectDialog(
      context,
      title: '',
      items: [for (final i in slots) _party[i].name],
      lines: const [
        (15, LoreMenuText.viewCharWho),
        (10, LoreSubText.chooseOne),
      ],
    );
    if (k == 0 || !mounted) return;
    final member = _party[slots[k - 1]];
    await showLoreMessageDialog(
      context,
      lines: LoreViewProcedures.characterPage1(member),
    );
    if (!mounted) return;
    _printLines(LoreViewProcedures.characterPage2(member));
  }

  /// LOREMENU `Extrasense` (hotkey E or SelectMode 5).
  Future<void> _openEspDialog() =>
      LoreExtrasense.run(_ScreenExtrasenseIo(this), _party, _sourceEtc);

  /// LORESUB `Grocery` / `Weapon_Shop` / `Train_Center` / `Hospital`.
  Future<void> _openTownFacilityDialog(TownFacilityType type) => showLoreWindow(
    context,
    run: (window) {
      final io = _ScreenShopIo(this, window);
      return switch (type) {
        TownFacilityType.grocery => LoreTownShops.grocery(io),
        TownFacilityType.weaponShop => LoreTownShops.weaponShop(io, _party),
        TownFacilityType.trainCenter => LoreTownShops.trainCenter(
          io,
          _party,
          _sessionRandom,
        ),
        TownFacilityType.hospital => LoreTownShops.hospital(io, _party),
      };
    },
    onClose: (lines) {
      _printLines(lines);
      _refresh();
    },
  );

  /// LOREMENU `SelectMode` (Space; LOREMAIN cleared etc[6] first): one source
  /// Select, then the chosen procedure; nothing returns to the menu.
  Future<void> _runSelectMode() async {
    final k = await showLoreSelectDialog(
      context,
      title: LoreMenuText.selectModePrompt,
      items: const [
        LoreMenuText.selectModeParty,
        LoreMenuText.selectModeCharacter,
        LoreMenuText.selectModeQuick,
        LoreMenuText.selectModeCast,
        LoreMenuText.selectModeEsp,
        LoreMenuText.selectModeRest,
        LoreMenuText.selectModeOption,
      ],
    );
    if (!mounted) return;
    switch (FieldHotkeys.fromSelect(k)) {
      case FieldAction.viewParty:
        await _runViewParty();
      case FieldAction.viewCharacter:
        await _runViewCharacter();
      case FieldAction.quickView:
        await _runQuickView();
      case FieldAction.castSpell:
        await _runCastSpell();
      case FieldAction.extrasense:
        await _openEspDialog();
      case FieldAction.rest:
        await _runRest();
      case FieldAction.gameOption:
        await _runGameOption();
      case FieldAction.none:
      case FieldAction.openMenu:
      case FieldAction.toggleSound:
        break;
    }
  }

  /// LOREMENU `CastSpell` (hotkey C or SelectMode item 4).
  Future<void> _runCastSpell() =>
      LoreCastSpell.run(_ScreenCastSpellIo(this), _party, _sourceEtc);

  /// LOREMENU `Rest` (hotkey R or SelectMode item 6): it runs at once, then
  /// `etc[1]` drops by one, `etc[2..4] := 0`, SP/ESP refill, `SimpleDisCond`
  /// and `PressAnyKey`.
  Future<void> _runRest() async {
    final outcome = TownLogic.rest(_party, _partyFood, torchSteps: _torchSteps);
    setState(() {
      _partyFood = outcome.food;
      _torchSteps = outcome.torchSteps;
      _waterWalkSteps = 0;
      _swampWalkSteps = 0;
      _levitateSteps = 0;
    });
    await showLoreMessageDialog(context, lines: outcome.lines);
  }

  /// LOREMENU `GameOption` (hotkey G or SelectMode item 7).
  Future<void> _runGameOption() => LoreGameOption.run(
    _ScreenGameOptionIo(this),
    _party,
    _sourceEtc,
    slots: _transientSlots,
  );

  /// `Save` for slot 1..4 (`party`/`player`/`SaveN.map`): the current game.
  SaveData _captureSave(int slot) => SaveData(
    slot: slot,
    slotName: SaveManager.slotNames[slot - 1],
    timestamp: DateTime.now(),
    mapId: _game.currentMapId,
    mapTitle:
        LoreWorldManager.mapRegistry[_game.currentMapId]?.title ??
        '${_game.currentMapId}',
    playerX: _game.playerX,
    playerY: _game.playerY,
    gold: _partyGold,
    food: _partyFood,
    party: LoreSaveParty.snapshot(_party),
    flags: LoreDialogueManager.instance.getSaveFlags(),
    etc: _sourceEtc.fieldCounters(),
    mapTiles: _game.currentMap?.tileSnapshot() ?? const [],
    mapWidth: _game.currentMap?.xmax,
    mapHeight: _game.currentMap?.ymax,
    consumedScripts: _scripts.consumedScripts.toList(),
  );

  /// GameOption 4: `Load` (a missing save ends in `ErrorMessage`/`Halt`).
  Future<void> _optionLoad(int slot) async {
    _addLog(LoreSubText.loadingGame);
    if (await _loadSaveSlot(slot) || !mounted) return;
    AudioManager.instance.stopBgm();
    setState(
      () =>
          _halt = LoreGameOverResult(LoreGameOverEnd.halted, missingSlot: slot),
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _runFieldProcedure(
    FieldAction action,
    Future<void> Function() procedure,
  ) async {
    final input = LoreMainInput();
    await input.run(() async {
      await procedure();
      // LOREMAIN.Main: c is shared with PressAnyKey. Its Space branch is
      // checked after the hotkey returns, once, before tile dispatch.
      if (mounted &&
          _halt == null &&
          _currentMode == GameScreenMode.field &&
          action != FieldAction.openMenu &&
          LoreMainProcedures.mainRedispatchesCurrentTile(action) &&
          input.lastKeyWasSpace) {
        LoreDialogueManager.instance.setBattleResult(0);
        await _runSelectMode();
      }
      // Main checks Backspace after the Space/SelectMode branch as well.
      if (mounted &&
          _halt == null &&
          _currentMode == GameScreenMode.field &&
          LoreMainProcedures.mainRedispatchesCurrentTile(action) &&
          input.lastKeyWasTab) {
        SourcePalette.instance.requestGrayscale();
      }
      if (mounted &&
          _halt == null &&
          _currentMode == GameScreenMode.field &&
          LoreMainProcedures.mainRedispatchesCurrentTile(action) &&
          input.lastKeyWasBackspace) {
        setState(() => AudioManager.instance.toggleSourceSound());
      }
    });
    _redispatchCurrentTileAfter(
      action,
      lastKeyWasEscape: input.lastKeyWasEscape,
    );
  }

  void _redispatchCurrentTileAfter(
    FieldAction action, {
    bool lastKeyWasEscape = false,
  }) {
    if (!mounted ||
        _currentMode != GameScreenMode.field ||
        !LoreMainProcedures.mainRedispatchesCurrentTile(
          action,
          lastKeyWasEscape: lastKeyWasEscape,
        )) {
      return;
    }
    _game.tryMove(0, 0);
    setState(() {});
  }

  void _addLog(String msg, {int? color}) {
    if (!mounted) return;
    setState(() {
      _logs.add(msg);
      _logColors.add(color ?? LoreSourceSpeech.lines[msg]?.color ?? 7);
      _logRevision++;
      if (_logs.length > 80) {
        _logs.removeAt(0);
        _logColors.removeAt(0);
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
    _clearSourceMessageWindow();
    setState(() {
      _currentMode = GameScreenMode.encounter;
      _battleEnemies = monsterIds.map(LoreData.instance.monster).toList();
      _retainEnemySlots(_battleEnemies);

      // 원작 LOREBATT.PAS:1228-1240 - 조우 화면: `적이 출현했다 !!!` /
      // `적의 평균 민첩성 : n` / `적과 교전한다` / `도망간다`
      _addLog(LoreBattText.encounter);
      for (final e in _battleEnemies) {
        _addLog(e.name);
      }
      _addLog(
        '${LoreBattText.enemyAgility} : ${LoreEncounterLogic.averageEnemyAgility(_battleEnemies)}',
      );
    });
  }

  void _engageEncounter() {
    if (_currentMode != GameScreenMode.encounter) return;
    _clearSourceMessageWindow();
    final decision = LoreEncounterLogic.decide(
      EncounterChoice.engage,
      _party,
      _battleEnemies,
    );
    _beginEncounterBattle(enemyFirst: decision.enemyFirst);
  }

  void _fleeEncounter() {
    if (_currentMode != GameScreenMode.encounter) return;
    _clearSourceMessageWindow();
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
      _retainEnemySlots(_battleEnemies);
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
      inactiveDeadEnemySlots: _inactiveDeadEnemySlots,
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
      inactiveDeadEnemySlots: _inactiveDeadEnemySlots,
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
    await _finishPortalEntry(
      portal.portal,
      portal.tx,
      portal.ty,
      fromMap: portal.fromMap,
    );
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

  /// `BattleMode` 패배: `1 : begin GameOver; exit; end` (`party.etc[6] = 1`).
  /// 불러오기로 돌아온 경우에만 호출한 절차의 나머지(전투 뒤 코드)가 불러온
  /// 게임 위에서 이어진다. 그렇지 않으면 `GameOver` 가 `Halt` 로 끝난다.
  Future<void> _onBattleDefeat() async {
    final pendingScript = _pendingScriptBattle;
    final targetX = _pendingScriptTargetX;
    final targetY = _pendingScriptTargetY;
    final portal = _pendingPortalTransition;
    final session = ScriptBattleSession.resolve(
      before: _battleProgressState(),
      end: LoreBattleEnd.defeat,
      enemies: _battleEnemies,
      inactiveDeadEnemySlots: _inactiveDeadEnemySlots,
      pendingScript: pendingScript,
    );
    _pendingScriptBattle = null;
    _pendingScriptTargetX = null;
    _pendingScriptTargetY = null;
    _pendingVictoryFlags.clear();
    _pendingPortalTransition = null;
    _applyBattleProgress(session.progress);
    // LOREBATT.PAS:1005 left etc[6] = 1 for GameOver; a reload sets 255.
    LoreDialogueManager.instance.setBattleResult(1);
    final result = await _runGameOver(1);
    if (!mounted || result.end != LoreGameOverEnd.reloaded) return;
    // BattleMode returns into its caller. Arms without an `etc[6] = 255` check
    // go on with their escape path on the loaded game (`Load` set x, y), and a
    // pending entrance still loads its destination.
    final continuation = session.continuation;
    if (continuation == null || pendingScript == null) {
      _continuePositionBlocks();
      return;
    }
    _pendingPortalTransition = portal;
    await _resumeScriptAfterBattle(
      continuation,
      session.appliedOutcome!,
      session.delta,
      talkTargetX: targetX,
      talkTargetY: targetY,
    );
    if (!mounted || !pendingScript.resumesAfterReload) {
      _continuePositionBlocks();
      return;
    }
    final resumed = LoreSpecProcedures.afterReload(
      pendingScript.script.map,
      _game.playerX,
      _game.playerY,
      _scriptContext(),
      _scripts,
    );
    if (resumed != null) await _driveScript(resumed);
    _continuePositionBlocks();
  }

  /// `DetectGameOver`: `party.etc[6] := 255; gameover`.
  Future<void> _detectedGameOver() async {
    LoreDialogueManager.instance.setBattleResult(255);
    await _runGameOver(255);
  }

  /// `LORESUB.PAS` `GameOver`. 뷰포트에서 진행하고, 불러오기나 `<< 아니오 >>` 로
  /// 돌아오면 필드로, `Halt` 면 종료 화면으로 바꾼다.
  Future<LoreGameOverResult> _runGameOver(int etc6) async {
    final done = Completer<LoreGameOverResult>();
    setState(() {
      _gameOverEtc6 = etc6;
      _gameOverSerial++;
      _gameOverDone = done;
      _currentMode = GameScreenMode.gameOver;
    });
    final result = await done.future;
    if (!mounted) return result;
    if (result.end == LoreGameOverEnd.halted) {
      AudioManager.instance.stopBgm(); // `if AdLibOn then PlayOff`
      setState(() => _halt = result);
      // `Halt` ends the program: nothing after the caller's GameOver runs.
      return Completer<LoreGameOverResult>().future;
    }
    if (result.etc6 case final etc6?) {
      LoreDialogueManager.instance.setBattleResult(etc6);
    }
    setState(() => _currentMode = GameScreenMode.field);
    _reclaimFocus();
    return result;
  }

  /// `LoadNo := chr(k+47); Load`: a storage fault never returns from Halt.
  Future<bool> _loadSaveSlot(int slot) async {
    final result = await SaveManager.instance.readGame(slot);
    if (!mounted) return false;
    if (result.failure case final failure?) {
      await _game.haltLoad(failure);
      return false;
    }
    final save = result.data!;
    LoreDialogueManager.instance.loadFlags(save.flags, fieldCounters: save.etc);
    await _applyLoadedSave(save);
    return true;
  }

  /// 불러온 저장 자료를 화면 상태와 지도에 반영한다.
  Future<void> _applyLoadedSave(SaveData save) async {
    setState(() {
      _scripts.consumedScripts
        ..clear()
        ..addAll(save.consumedScripts);
      _party = LoreSaveParty.snapshot(save.party);
      _partyGold = save.gold;
      _partyFood = save.food;
      _normalizeLoadedEtc();
    });
    await _game.loadMapById(
      save.mapId,
      startX: save.playerX,
      startY: save.playerY,
      mapTiles: save.mapTiles,
      mapWidth: save.mapWidth,
      mapHeight: save.mapHeight,
      snapshotName: 'save${save.slot}.map',
    );
    if (mounted) _displayCondition();
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
    // Displaying the field is pure. Source Display_Condition/SimpleDisCond
    // call sites own ReturnCondition, including between ordered event effects.
    return _party.take(6).map((p) {
      return PartyMemberStatus(
        name: p.name,
        hp: p.hp,
        maxHp: p.maxHp,
        sp: p.sp,
        maxSp: p.maxSp,
        level: p.battleLevel,
        esp: p.esp,
        ac: p.ac,
        condition: p.condition,
      );
    }).toList();
  }

  /// `Display_Condition`/`SimpleDisCond` at a migrated call site.
  void _displayCondition() {
    PartyMember.simpleDisCond(_party);
    if (mounted) setState(() {});
  }

  Widget _buildFieldCommands() => LayoutBuilder(
    builder: (context, constraints) {
      final vertical = constraints.maxHeight > constraints.maxWidth;
      final items = [
        (Icons.menu, LoreMenuText.selectModePrompt, FieldAction.openMenu),
        (Icons.favorite, LoreMenuText.selectModeQuick, FieldAction.quickView),
        (Icons.psychology, LoreMenuText.selectModeEsp, FieldAction.extrasense),
      ];
      return Flex(
        direction: vertical ? Axis.vertical : Axis.horizontal,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
              child: Flex(
                direction: vertical ? Axis.vertical : Axis.horizontal,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (icon, label, action) in items)
                    Semantics(
                      button: true,
                      label: label,
                      child: IconButton(
                        icon: Icon(icon, size: 20, color: RetroTheme.lightGray),
                        onPressed: () async {
                          if (_entryAnimationActive ||
                              _scriptDepth > 0 ||
                              _currentMode != GameScreenMode.field) {
                            return;
                          }
                          await _runFieldProcedure(action, () async {
                            switch (action) {
                              case FieldAction.openMenu:
                                LoreDialogueManager.instance.setBattleResult(0);
                                await _runSelectMode();
                              case FieldAction.quickView:
                                await _runQuickView();
                              case FieldAction.extrasense:
                                await _openEspDialog();
                              default:
                                break;
                            }
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          const BrowserFullscreenButton(),
          AppSettingsButton(
            enabled: !_entryAnimationActive && _scriptDepth == 0,
            onOpenChanged: (open) {
              setState(() => _appSettingsOpen = open);
              if (!open) _reclaimFocus();
            },
          ),
        ],
      );
    },
  );

  Widget _buildViewportContent() {
    switch (_currentMode) {
      case GameScreenMode.field:
        return Stack(
          children: [
            // Flame 2D 타일맵 게임 위젯
            // MainGameScreen owns field hotkeys. Flame's default focus
            // handles keys itself and would swallow R/G after a battle.
            Positioned.fill(child: GameWidget(game: _game, autofocus: false)),
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
          ],
        );

      case GameScreenMode.battle:
        return BattleViewportView(
          key: ValueKey(_battleSerial),
          random: _sessionRandom,
          partyMembers: _party,
          enemies: _battleEnemies,
          slots: _transientSlots,
          enemyFirst: _battleEnemyFirst,
          espAccessGranted:
              LoreDialogueManager.instance.getFlagsCopy()['etc39_bit1'] == true,
          onLog: (msg) => _addLog(msg),
          onPrint: (color, text) => _addLog(text, color: color),
          onClearMessageWindow: _clearSourceMessageWindow,
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
        return GameOverView(
          key: ValueKey('game-over-$_gameOverSerial'),
          etc6: _gameOverEtc6,
          load: _loadSaveSlot,
          onFinished: (result) {
            final done = _gameOverDone;
            if (done != null && !done.isCompleted) done.complete(result);
          },
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

  LoreLoadFailure? _loadFailure;

  @override
  void dispose() {
    _focusNode.dispose();
    _dialogueHistory.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMode == GameScreenMode.ending) {
      return Scaffold(
        backgroundColor: RetroTheme.black,
        body: EndingView(
          heroName: _party.first.name,
          onFinish: _restartGame,
          random: _sessionRandom,
          initialKeyWasEscape: _lastSceneKeyWasEscape,
        ),
      );
    }
    if (_halt case final halt?) {
      return Scaffold(
        backgroundColor: RetroTheme.black,
        body: HaltView(missingSlot: halt.missingSlot, onHalt: widget.onHalt),
      );
    }
    if (_loadFailure case final failure?) {
      return Scaffold(
        backgroundColor: RetroTheme.black,
        body: HaltView(loadFailure: failure, onHalt: widget.onHalt),
      );
    }
    return Focus(
      onKeyEvent: (_, event) {
        if (_currentMode == GameScreenMode.field &&
            !_appSettingsOpen &&
            !_entryAnimationActive &&
            event.logicalKey == LogicalKeyboardKey.tab) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) async {
          if (_loadFailure != null || _halt != null) return;
          if (_appSettingsOpen) return;
          if (_entryAnimationActive) return;
          if (_currentMode == GameScreenMode.encounter &&
              event is KeyDownEvent) {
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
            if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
                event.logicalKey == LogicalKeyboardKey.tab) {
              SourcePalette.instance.requestGrayscale();
              return;
            }
            if (event is KeyDownEvent) {
              // 원작 LOREMAIN.PAS 핫키: P/V/Q/C/E/R/G + Space
              final action = FieldHotkeys.resolve(event.logicalKey);
              if (action != FieldAction.none) {
                await _runFieldProcedure(action, () async {
                  switch (action) {
                    case FieldAction.openMenu:
                      // LOREMAIN.Main clears party.etc[6] before SelectMode.
                      LoreDialogueManager.instance.setBattleResult(0);
                      await _runSelectMode();
                    case FieldAction.viewParty:
                      await _runViewParty();
                    case FieldAction.viewCharacter:
                      await _runViewCharacter();
                    case FieldAction.castSpell:
                      await _runCastSpell();
                    case FieldAction.rest:
                      await _runRest();
                    case FieldAction.gameOption:
                      await _runGameOption();
                    case FieldAction.toggleSound:
                      setState(() => AudioManager.instance.toggleSourceSound());
                    case FieldAction.quickView:
                      await _runQuickView();
                    case FieldAction.extrasense:
                      await _openEspDialog();
                    case FieldAction.none:
                      break;
                  }
                });
                return;
              }
            }
            if (_scriptDepth == 0) _game.handleKeyEvent(event);
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
              commands: _currentMode == GameScreenMode.field
                  ? _buildFieldCommands()
                  : null,
              party: PartyStatusView(members: _mapPartyStatus()),
              messages: MessageLogView(
                logs: _logs,
                colors: _logColors,
                revision: _logRevision,
              ),
              history: DialogueHistoryView(history: _dialogueHistory),
              controls: _currentMode == GameScreenMode.field
                  ? Opacity(
                      opacity: .6,
                      child: DPadWidget(
                        onDirectionPressed: (dx, dy) {
                          if (_appSettingsOpen ||
                              _entryAnimationActive ||
                              _scriptDepth > 0 ||
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
      ),
    );
  }
}

/// Escape cancels a source `select` menu (`select` returns 0).

class _ScreenGameOptionIo implements LoreGameOptionIo {
  _ScreenGameOptionIo(this._screen);

  final _MainGameScreenState _screen;

  @override
  Future<int> select(
    String title,
    List<String> items, {
    List<(int, String)> lines = const [],
  }) async {
    if (!_screen.mounted) return 0;
    return showLoreSelectDialog(
      _screen.context,
      title: title,
      items: items,
      lines: lines,
    );
  }

  @override
  Future<void> message(List<(int, String)> lines) async {
    if (!_screen.mounted) return;
    await showLoreMessageDialog(_screen.context, lines: lines);
  }

  @override
  Future<void> load(int slot) => _screen._optionLoad(slot);

  @override
  Future<void> save(int slot) =>
      SaveManager.instance.saveGame(_screen._captureSave(slot));

  @override
  Future<void> gameOver() async {
    await _screen._runGameOver(LoreDialogueManager.instance.lastBattleResult);
  }

  @override
  void displayCondition() => _screen._displayCondition();
}

/// [LoreCastSpell] on the game screen: selects and `Talk` as dialogs,
/// `Message`/`Print` in the message log, the map and position globals from
/// the field.
class _ScreenCastSpellIo implements LoreCastSpellIo {
  _ScreenCastSpellIo(this._screen);

  final _MainGameScreenState _screen;

  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    List<(int, String)> lines = const [],
  }) async {
    if (!_screen.mounted) return 0;
    return showLoreSelectDialog(
      _screen.context,
      title: title,
      items: items,
      maxsum: maxsum,
      lines: lines,
    );
  }

  @override
  Future<void> talk(List<(int, String)> lines) async {
    if (!_screen.mounted) return;
    await showLoreMessageDialog(_screen.context, lines: lines);
  }

  @override
  void message(int color, String text) => _screen._addLog(text, color: color);

  @override
  void print(int color, String text) => _screen._addLog(text, color: color);

  @override
  Future<int?> spacePower() async {
    if (!_screen.mounted) return null;
    return showLoreSpacePowerDialog(_screen.context);
  }

  @override
  int get x => _screen._game.playerX;

  @override
  int get y => _screen._game.playerY;

  @override
  int get xmax => _screen._game.currentMap?.xmax ?? 0;

  @override
  int get ymax => _screen._game.currentMap?.ymax ?? 0;

  @override
  int get mapId => _screen._game.currentMapId;

  @override
  String get position =>
      switch (LoreWorldManager.mapRegistry[mapId]?.category) {
        MapCategory.ground => 'ground',
        MapCategory.den => 'den',
        MapCategory.keep => 'keep',
        _ => 'town',
      };

  @override
  int tileAt(int x, int y) => _screen._game.currentMap?.getTile(x, y) ?? 0;

  @override
  void setTile(int x, int y, int tile) {
    final map = _screen._game.currentMap;
    if (map == null || x < 1 || x > map.xmax || y < 1 || y > map.ymax) return;
    map.setTile(x, y, tile);
    _screen._refresh();
  }

  @override
  void moveTo(int x, int y) {
    _screen._game.playerX = x;
    _screen._game.playerY = y;
    _screen._refresh();
  }

  @override
  int get food => _screen._partyFood;

  @override
  set food(int value) => _screen._partyFood = value;

  @override
  void displayCondition() => _screen._displayCondition();
}

/// [LoreExtrasense] on the game screen: selects and `Talk` as dialogs,
/// `Message` in the message log, 투시 and 천리안 through the map view.
class _ScreenExtrasenseIo implements LoreExtrasenseIo {
  _ScreenExtrasenseIo(this._screen);

  final _MainGameScreenState _screen;
  final LoreKeyWait _wait = LoreKeyWait();

  @override
  Future<int> select(
    String title,
    List<String> items, {
    List<(int, String)> lines = const [],
  }) async {
    if (!_screen.mounted) return 0;
    return showLoreSelectDialog(
      _screen.context,
      title: title,
      items: items,
      lines: lines,
    );
  }

  @override
  Future<void> talk(List<(int, String)> lines) async {
    if (!_screen.mounted) return;
    await showLoreMessageDialog(_screen.context, lines: lines);
  }

  @override
  void message(int color, String text) => _screen._addLog(text, color: color);

  @override
  Future<void> seeThrough(String text) async {
    if (!_screen.mounted) return;
    final audio = AudioManager.instance;
    final previousSound = audio.sourceSoundEnabled;
    audio.sourceSoundEnabled = false;
    _screen._game.seeThroughSpecial = true;
    _screen._refresh();
    try {
      await showLoreMessageDialog(
        _screen.context,
        lines: [(15, text)],
        transparentBarrier: true,
      );
    } finally {
      _screen._game.seeThroughSpecial = false;
      audio.sourceSoundEnabled = previousSound;
      if (_screen.mounted) _screen._refresh();
    }
  }

  bool? _previousSound;
  DialogRoute<void>? _clairvoyanceRoute;

  @override
  void clairvoyanceBegin() {
    if (!_screen.mounted) {
      _wait.close();
      return;
    }
    _previousSound = AudioManager.instance.sourceSoundEnabled;
    AudioManager.instance.sourceSoundEnabled = false;
    unawaited(
      showLoreKeyWaitOverlay(
        _screen.context,
        wait: _wait,
        onRoute: (route) => _clairvoyanceRoute = route,
        lines: const [
          (15, LoreMenuText.espClairvoyanceBusy),
          (14, LoreMenuText.espPressKey),
        ],
      ),
    );
  }

  @override
  Future<bool> clairvoyanceStep(int x, int y) async {
    if (!_screen.mounted) return false;
    _screen._game.peekAt(x, y);
    _screen._refresh();
    // `LoreKeyWait.next` is true for Esc; the procedure wants false for Esc.
    return !await _wait.next();
  }

  @override
  void clairvoyanceEnd() {
    if (_previousSound case final previous?) {
      AudioManager.instance.sourceSoundEnabled = previous;
      _previousSound = null;
    }
    _wait.close();
    final route = _clairvoyanceRoute;
    _clairvoyanceRoute = null;
    // A back action may already have removed the overlay. Never pop the
    // game (or another dialog) just because the procedure has finished.
    if (route != null && route.isActive) {
      if (route.isCurrent) {
        route.navigator!.pop();
      } else {
        route.navigator!.removeRoute(route);
      }
    }
    _screen._game.clearPeek();
    if (_screen.mounted) _screen._refresh();
  }

  @override
  int get x => _screen._game.playerX;

  @override
  int get y => _screen._game.playerY;

  @override
  int get xmax => _screen._game.currentMap?.xmax ?? 0;

  @override
  int get ymax => _screen._game.currentMap?.ymax ?? 0;

  @override
  int get mapId => _screen._game.currentMapId;

  @override
  void displayEsp() => _screen._refresh();
}

/// [LoreTownShops] on the game screen: the shared text window, the party's
/// gold and food, and a status refresh.
class _ScreenShopIo implements LoreShopIo {
  _ScreenShopIo(this._screen, this._window);

  final _MainGameScreenState _screen;
  final LoreWindowController _window;

  @override
  void clear() => _window.clear();

  @override
  void print(int color, String text) => _window.print(color, text);

  @override
  Future<void> pressAnyKey() => _window.pressAnyKey();

  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  }) => _window.select(title, items, maxsum: maxsum, clean: clean);

  @override
  int get gold => _screen._partyGold;

  @override
  set gold(int value) => _screen._partyGold = value;

  @override
  int get food => _screen._partyFood;

  @override
  set food(int value) => _screen._partyFood = value;

  @override
  void displayCondition() => _screen._displayCondition();
}

/// Buffered source Print lines; the direct procedure controls mutation/wait order.
class _ScreenTalkIo implements LoreTalkModeIo {
  _ScreenTalkIo(this._screen);
  final _MainGameScreenState _screen;
  final List<(int, String)> _lines = [];
  @override
  Future<void> blinkRemains(int dx, int dy) async {
    try {
      for (final frame in LoreRemainsBlink.frames(dx, dy)) {
        await Future<void>.delayed(
          Duration(milliseconds: frame.waitMilliseconds),
        );
        if (!isOpen) return;
        _screen._showRemainsFrame(frame);
      }
    } finally {
      _screen._game.remainsBlinkFrame = null;
    }
  }

  @override
  void setTile(int x, int y, int tile) =>
      _screen._game.currentMap?.setTile(x, y, tile);
  @override
  void refresh() {
    _screen._game.clearPeek();
    _screen._refreshTalkWindow();
  }

  @override
  void cprint(
    int color,
    int highlight,
    String before,
    String word,
    String after,
  ) => print(color, before + word + after);
  @override
  void message(int color, String text) {
    clear();
    _screen._addLog(text);
  }

  @override
  Future<void> recruit(LoreScript procedure) async {
    await _screen._driveScript(
      _screen._scripts.startProcedure(procedure, _screen._scriptContext()),
      talkTargetX: procedure.x,
      talkTargetY: procedure.y,
    );
  }

  @override
  Future<String> challengeKey() async {
    final choice = await select('', ['예.', '아니오.'], clean: false);
    return choice == 1 ? 'Y' : 'N';
  }

  @override
  bool get isOpen => _screen.mounted;
  @override
  void clear() => _lines.clear();
  @override
  void print(int color, String text) => _lines.add((color, text));
  @override
  Future<void> pressAnyKey() async {
    if (!isOpen) return;
    _screen
        ._refreshTalkWindow(); // EXP is already changed before the source wait.
    await _screen._showDialogue(List.of(_lines));
    clear();
  }

  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  }) async {
    if (!isOpen) return 0;
    if (clean) clear();
    final result = await showLoreSelectDialog(
      _screen.context,
      title: title,
      items: items,
      maxsum: maxsum,
      lines: List.of(_lines),
    );
    clear();
    return result;
  }
}
