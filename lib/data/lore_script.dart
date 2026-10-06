// Continuation runner for source-owned Dart procedures. No JSON rules.
import 'dart:math';

import '../logic/lore_random.dart';

import '../logic/lore_source_memory.dart';

// ── 스크립트 데이터 모델 ──────────────────────────────────────────────

/// 스크립트 실행 조건.
class ScriptRequire {
  final String? flag;
  final String? flagNot;

  /// 원작 `player[i].name` 검사처럼 현재 파티에 있는 동료 이름.
  final String? partyMember;

  /// 진입 직전 지도 ID (`LOREENT.PAS`의 출발 `party.map`).
  final int? enteredFromMap;
  final bool mindRead;
  final bool mindReadInactive;
  final int? minEspLevel;
  final int? maxEspLevelBelow;
  final bool notMindReadOrLowEsp;

  /// 플레이어가 밟고 있는 타일이 0일 때만 발동한다(원작 `if map[x,y] = 0`).
  final bool tileAtPlayerZero;
  final int? tileAtPlayerValue;

  /// 원작 `y1 <> n` 등 이벤트 진입 방향 조건.
  final int? moveDyNot;

  /// 퀘스트 단계 조건 (원작 `party.etc[10] = 3` / `< 3`).
  final List<({String name, int? eq, int? lt, int? gte})> quests;

  /// 나열한 플래그가 **모두** 세워졌을 때만 발동한다.
  final List<String> allFlags;

  /// 나열한 플래그가 **모두** 세워지지 않았을 때만 발동한다
  /// (원작 `if not (odd(etc[40]) and odd(etc[41])) then`).
  final List<String> notAllFlags;

  const ScriptRequire({
    this.flag,
    this.flagNot,
    this.partyMember,
    this.enteredFromMap,
    this.mindRead = false,
    this.mindReadInactive = false,
    this.minEspLevel,
    this.maxEspLevelBelow,
    this.notMindReadOrLowEsp = false,
    this.tileAtPlayerZero = false,
    this.tileAtPlayerValue,
    this.moveDyNot,
    this.quests = const [],
    this.allFlags = const [],
    this.notAllFlags = const [],
  });
}

/// 스크립트 실행에 필요한 상황 정보.
class ScriptContext {
  final bool mindReadActive;
  final int maxEspLevel;
  final Set<String> flags;
  final Set<String> partyNames;
  final int? enteredFromMap;

  /// 플레이어가 지금 밟고 있는 타일 값(원작 `map[x,y]` 판정용, 모르면 null).
  final int? tileAtPlayer;
  final int moveDy;

  /// 퀘스트 단계 값 (원작 `party.etc[10/13/14/15]` 등).
  final Map<String, int> questSteps;

  /// Raw source bytes for directly ported procedures. A present zero overrides
  /// compatibility flag names; absent entries may be recovered from old saves.
  final Map<int, int> sourceEtc;

  const ScriptContext({
    this.mindReadActive = false,
    this.maxEspLevel = 0,
    this.flags = const {},
    this.partyNames = const {},
    this.enteredFromMap,
    this.tileAtPlayer,
    this.moveDy = 0,
    this.questSteps = const {},
    this.sourceEtc = const {},
  });

  int etcValue(int index, {Map<int, String> bitAliases = const {}}) {
    LorePartyEtc.checkIndex(index);
    if (sourceEtc.containsKey(index)) return LorePascal.byte(sourceEtc[index]!);
    var value = 0;
    for (var bit = 1; bit <= 8; bit++) {
      if (flags.contains('etc${index}_bit$bit') ||
          (bitAliases[bit] != null && flags.contains(bitAliases[bit]))) {
        value |= LorePascal.bit(bit);
      }
    }
    return value;
  }
}

/// 선택지 1개.
class ScriptOption {
  final String text;
  final List<ScriptStep> steps;

  const ScriptOption(this.text, this.steps);
}

/// Original DisplayEnemies/Print/PressAnyKey or talk('') scene, without combat.
/// Acknowledgement resumes the procedure; it is not a game choice.
class ScriptScene {
  final String title;
  final List<int> actors;
  final List<String> lines;
  final int? appendPartyNameSlot;
  final int? appendPartyNameLine;

  /// Text after the name, for `Print(c,'..'+player[n].name+'.')`.
  final String appendPartyNameSuffix;

  /// Name first, for `Print(c,player[n].name+', ..')`.
  final bool partyNameBefore;

  const ScriptScene({
    required this.title,
    this.actors = const [],
    required this.lines,
    this.appendPartyNameSlot,
    this.appendPartyNameLine,
    this.appendPartyNameSuffix = '',
    this.partyNameBefore = false,
  });

  /// Resolve text when presented, after battle/recruits; player[1] stays slot 1.
  ScriptScene withPartyNames(List<String> slots) {
    final slot = appendPartyNameSlot;
    if (slot == null) return this;
    RangeError.checkValueInInterval(slot, 1, 7, 'player slot');
    final line = appendPartyNameLine!;
    RangeError.checkValidIndex(line, lines, 'scene line');
    return ScriptScene(
      title: title,
      actors: actors,
      lines: [
        for (var i = 0; i < lines.length; i++)
          i == line
              ? partyNameBefore
                    ? '${slot <= slots.length ? slots[slot - 1] : ''}${lines[i]}'
                    : '${lines[i]}${slot <= slots.length ? slots[slot - 1] : ''}'
                          '$appendPartyNameSuffix'
              : lines[i],
      ],
    );
  }
}

/// 스크립트 실행 중 일어난 일 1건(순서 보존).
class ScriptEvent {
  /// 'message' = 대사 출력, 'peek' = 카메라 연출(원작 `scroll(FALSE)`),
  /// 'pause' = 원작 `talk(..)`/`PressAnyKey`: 키를 누르면 대사 창을 지운다,
  /// 'log' = 원작 `message(color, s)`: 키 대기 없이 한 줄만 보인다.
  final String kind;
  final String? text;
  final int? x;
  final int? y;
  final int? face;

  const ScriptEvent.message(String this.text)
    : kind = 'message',
      x = null,
      y = null,
      face = null;
  const ScriptEvent.sceneLine(String this.text)
    : kind = 'sceneLine',
      x = null,
      y = null,
      face = null;
  const ScriptEvent.peek(this.x, this.y)
    : kind = 'peek',
      text = null,
      face = null;
  const ScriptEvent.sourceFace(this.face)
    : kind = 'sourceFace',
      text = null,
      x = null,
      y = null;
  const ScriptEvent.log(String this.text)
    : kind = 'log',
      x = null,
      y = null,
      face = null;
  const ScriptEvent.pause()
    : kind = 'pause',
      text = null,
      x = null,
      y = null,
      face = null;
  const ScriptEvent.endDemo()
    : kind = 'endDemo',
      text = null,
      x = null,
      y = null,
      face = null;
}

/// 스크립트 스텝 1개.
class ScriptStep {
  final String
  kind; // say / gold / food / flag / join / battle / choice / equip / peek
  final String? text;
  final int? amount;
  final String? key;

  /// Direct Pascal procedure assignment, independent of JSON flag names.
  final int? sourceEtcIndex;
  final int? sourceEtcValue;
  final ScriptScene? scene;
  final int? sourceFace;

  /// Reuse another script's steps in the current battle sequence.
  final String? includeScriptId;
  final int? slot;
  final String? prompt;
  final List<ScriptOption>? options;

  /// The option selected by Escape when the original menu treats it as a reply.
  final int? cancelOptionIndex;

  /// Steps run when Escape is not one of the options (`select` returned 0).
  final List<ScriptStep> cancelSteps;
  final List<int>? monsters;
  final String? battleTitle;

  /// 원본 BattleMode(FALSE): 첫 라운드에 적이 먼저 행동한다.
  final bool battleEnemyFirst;

  /// 전투 **승리 시** 설정할 플래그 (원작 `if party.etc[6] = 0 then party.etc[..] or bit`).
  final List<String> battleVictoryFlags;
  final Map<int, String> battleEnemyDefeatFlags;

  /// 도주 시 지정된 적 슬롯이 모두 쓰러졌으면 설정하는 플래그.
  final List<({List<int> slots, String flag})> battleRunAwayFlagsWhenDead;
  final List<ScriptStep> battleRunAwaySteps;

  /// The source code after this `BattleMode` never tests `party.etc[6]`: when
  /// `GameOver` reloads a defeat, the arm keeps running on the loaded game
  /// (`Load` set `x, y` to the loaded position), which is the escape
  /// continuation evaluated there.
  final bool battleResultUnchecked;

  /// LOREENT lava gate reads enemy[1..2].dead, including inactive old slots.
  final bool battleChecksStoredDeadSlots;

  /// After that continuation the source `case` body goes on to its later `if`
  /// checks with the loaded `x, y` (`LoreSpecProcedures.afterReload`).
  final bool battleReloadResume;
  final bool battleContinueOnRunAway;
  final bool battleRetryOnRunAway;
  final bool battleMirrorParty;
  final bool battleShuffle;

  /// Escape counts as victory when this enemy slot is `dead`.
  final int? battleVictoryIfEnemyDead;

  /// Escape counts as victory when this enemy slot has `hp <= 0`
  /// (LORESPEC `(party.etc[6]=0) or (enemy[3].hp<=0)`, maps 11 and 15).
  final int? battleVictoryIfEnemyHpZero;
  final int? battleRunAwayIfEnemyAlive;
  final String? battleRunAwayProgressQuest;
  final int? battleRunAwayProgressTotal;

  /// 진행을 취소한다 (원작 `exit` - 예: 라바 게이트가 열리지 않았을 때).
  final bool block;

  /// teleport 스텝 (강제 이동) - map이 null이면 현재 맵.
  final int? teleportMap;
  final int? tileX;
  final int? tileY;
  final int? tileValue;

  /// teleport 스텝에서 x/y를 그대로 둔다 (원작 `y := 80` 처럼 한 축만 바꿈).
  final bool teleportKeepX;
  final bool teleportKeepY;

  /// randomSteps 스텝: 여러 스텝 목록 중 하나를 무작위로 골라 실행한다
  /// (원작 퀴즈 미로의 문항 뽑기처럼 메시지와 효과가 같이 정해져야 하는 경우).
  final List<List<ScriptStep>>? randomBranches;

  /// torch 스텝: 마법의 횃불을 켠다 (원작 `party.etc[1] := 1`).
  final bool torchLit;
  final bool rigelBlessing;
  final int? partyClassId;

  /// questStep 스텝: 원작 `party.etc[N]` 숫자 상태를 바꾼다
  /// (예: `inc(party.etc[10])`).
  final String? questName;
  final int? questSet;
  final int? questInc;

  /// exp 스텝: 원작 `player[i].experience + n` (생존 중인 전원).
  final int? expDelta;

  /// equip 스텝 (장비 지급): 원작 `weapon := 3; wea_power := 12` 등.
  final String? equipKind; // weapon | shield | armor
  final int? equipIndex;
  final int? equipPower;
  final bool equipPrompt;
  final bool equipOnlyUnarmed;

  /// peek 스텝 (카메라 연출): 시야만 옮길 좌표.
  final int? peekX;
  final int? peekY;

  /// setTileArea 스텝 (영역 지형 변형): 원작 `for j := .. do map[i,j] := v`.
  final int? tileXMax;
  final int? tileYMax;

  /// setTileArea: 이 값인 타일만 변경한다.
  final int? tileOnlyIf;

  /// `atPlayerX`: 영역의 x를 플레이어가 선 **열**로 삼는다
  /// (원작 `for i := 10 to 23 do map[x,i] := 49`).
  final bool tileAtPlayerX;

  /// `atPlayerY`: 영역의 y를 플레이어가 선 **행**으로 삼는다
  /// (원작 `for j := 23 to 26 do map[j,y] := 44`).
  final bool tileAtPlayerY;

  /// battle 스텝의 적별 덮어쓰기: `[{"index": 3, "name": "Major Mummy", "ac": 1}]`
  /// (원작 `with enemy[i] do begin name := ...; ac := ...; end`).
  final List<Map<String, Object?>>? battleOverrides;

  /// battle 스텝의 난수 추가: `random.pool`에서 `random.min`~`random.max` 마리.
  final List<int>? randomPool;
  final int? randomMin;
  final int? randomMax;

  /// randomFlag 스텝: 이름 목록 중 하나를 무작위로 설정한다
  /// (미이전 JSON 규칙용; 직접 이식의 방 번호는 raw sourceEtc에 대입한다).
  final List<String>? randomFlagNames;

  /// `ifZero`: 현재 타일이 0(빈 땅)일 때만 다른 값으로 바꾼다
  /// (원작 `if map[x,y] = 0 then map[x,y] := 40 else map[x,y] := 46`).
  final int? tileIfZero;

  /// setTileAtPlayer 스텝: 플레이어가 밟고 있는 칸을 바꾼다 (원작 `map[x,y] := v`).
  final int? tileAtPlayer; // 1이면 setTileAtPlayer 스텝

  /// nudge 스텝: 원작 `inc(y)`/`dec(y)` 처럼 플레이어를 한 칸 민다.
  final int? nudgeDx;
  final int? nudgeDy;

  const ScriptStep({
    required this.kind,
    this.text,
    this.amount,
    this.key,
    this.sourceEtcIndex,
    this.sourceEtcValue,
    this.scene,
    this.sourceFace,
    this.includeScriptId,
    this.slot,
    this.prompt,
    this.options,
    this.cancelOptionIndex,
    this.cancelSteps = const [],
    this.monsters,
    this.battleTitle,
    this.battleEnemyFirst = false,
    this.battleVictoryFlags = const [],
    this.battleEnemyDefeatFlags = const {},
    this.battleRunAwayFlagsWhenDead = const [],
    this.battleRunAwaySteps = const [],
    this.battleResultUnchecked = false,
    this.battleChecksStoredDeadSlots = false,
    this.battleReloadResume = false,
    this.battleContinueOnRunAway = false,
    this.battleRetryOnRunAway = false,
    this.battleMirrorParty = false,
    this.battleShuffle = false,
    this.battleVictoryIfEnemyDead,
    this.battleVictoryIfEnemyHpZero,
    this.battleRunAwayIfEnemyAlive,
    this.battleRunAwayProgressQuest,
    this.battleRunAwayProgressTotal,
    this.block = false,
    this.teleportMap,
    this.tileX,
    this.tileY,
    this.tileValue,
    this.teleportKeepX = false,
    this.teleportKeepY = false,
    this.randomBranches,
    this.torchLit = false,
    this.rigelBlessing = false,
    this.partyClassId,
    this.questName,
    this.questSet,
    this.questInc,
    this.expDelta,
    this.equipKind,
    this.equipIndex,
    this.equipPower,
    this.equipPrompt = false,
    this.equipOnlyUnarmed = false,
    this.peekX,
    this.peekY,
    this.tileXMax,
    this.tileYMax,
    this.tileOnlyIf,
    this.tileAtPlayerX = false,
    this.tileAtPlayerY = false,
    this.randomPool,
    this.battleOverrides,
    this.randomMin,
    this.randomMax,
    this.randomFlagNames,
    this.tileIfZero,
    this.tileAtPlayer,
    this.nudgeDx,
    this.nudgeDy,
  });
}

/// 좌표에 배치된 스크립트 1개.
class LoreScript {
  final String id;
  final String trigger; // step | talk
  final int map;

  /// 정확 좌표(없으면 아래 영역 조건으로 판정한다).
  final int? x;
  final int? y;

  /// 영역(행/열) 트리거. 원작의 `if y = 44 then ...` 같은 조건을 그대로 옮긴다.
  final int? xMin;
  final int? xMax;
  final int? yMin;
  final int? yMax;

  /// 넓은 범위 이벤트에서 원작의 앞선 `else if on(x,y)` 좌표를 제외한다.
  final List<({int x, int y})> excludeCoords;

  final bool once;

  /// 조건을 충실히 옮길 수 없어 **실행하지 않고 보관만** 하는 항목.
  /// 원작 문구는 그대로 남기되(대조용), 게임에서는 무시한다.
  final bool disabled;

  final ScriptRequire require;
  final List<ScriptStep> steps;

  const LoreScript({
    required this.id,
    required this.trigger,
    required this.map,
    this.x,
    this.y,
    this.xMin,
    this.xMax,
    this.yMin,
    this.yMax,
    this.excludeCoords = const [],
    required this.once,
    this.disabled = false,
    required this.require,
    required this.steps,
  });

  /// 이 스크립트가 (mapId, tx, ty)에서 발동되는지 검사한다.
  bool matches(String triggerName, int mapId, int tx, int ty) {
    if (disabled) return false;
    if (trigger != triggerName || map != mapId) return false;
    if (x != null || y != null) {
      if (x != null && x != tx) return false;
      if (y != null && y != ty) return false;
    }
    if (xMin != null && tx < xMin!) return false;
    if (xMax != null && tx > xMax!) return false;
    if (yMin != null && ty < yMin!) return false;
    if (yMax != null && ty > yMax!) return false;
    if (excludeCoords.any((p) => p.x == tx && p.y == ty)) return false;
    return true;
  }
}

/// 스크립트 실행 결과(누적).
class ScriptOutcome {
  final List<String> messages;
  final int goldDelta;
  final int foodDelta;
  final List<String> setFlags;
  final List<({int index, int value})> sourceEtcWrites;

  /// `join` steps; [cancelSteps] run when `ReturnJoinMember` is refused
  /// (Esc, k = 1), after which the source `exit`s.
  final List<({String key, int? slot, List<ScriptStep> cancelSteps})> recruits;
  final List<int> battleMonsters;
  final int battleCount;
  final bool battleMirrorParty;
  final bool battleReuseExisting;
  final String? battleTitle;
  final bool battleEnemyFirst;

  /// 전투 적별 덮어쓰기 (원작 `with enemy[i] do begin name := ..; ac := ..; end`).
  final List<Map<String, Object?>> battleOverrides;

  /// 전투 승리 시 설정할 플래그.
  final List<String> battleVictoryFlags;

  /// 이동/진입을 취소할지 여부 (원작 `exit`).
  final bool blockMove;

  /// 강제 이동 목적지 (없으면 null).
  final int? teleportMap;
  final int? teleportX;
  final int? teleportY;

  /// 진입한 방향의 반대편으로 한 칸 되돌린다 (원작 `x:=x-x1; y:=y-y1`).
  final bool stepBack;

  /// 한 축만 바꾸는 이동인지(원작 `y := 80`).
  final bool teleportKeepX;
  final bool teleportKeepY;

  /// 마법의 횃불을 켰는지 (원작 `party.etc[1] := 1`).
  final bool torchLit;
  final bool rigelBlessing;

  /// 원작 `for i := 1 to 6 do if player[i].name <> '' then class := n`.
  final int? partyClassId;

  /// 퀘스트 단계 변경 (원작 `party.etc[N] := n` / `inc(party.etc[N])`).
  final List<({String name, int? set, int? inc})> questChanges;

  /// 경험치 증가 (원작 `player[i].experience + n`).
  final int expDelta;

  /// 지형 변형 목록 (원작 `map[x,y] := 값`).
  final List<({int? map, int x, int y, int tile, int? ifZero})> tileChanges;

  /// 영역 지형 변형 목록 (원작 `for j := .. do map[i,j] := 값`).
  final List<
    ({
      int? map,
      int xMin,
      int xMax,
      int yMin,
      int yMax,
      int tile,
      int? ifZero,
      bool atPlayerX,
      bool atPlayerY,
      int? onlyIf,
    })
  >
  tileAreas;

  /// 점·영역 지형 변경을 스크립트 실행 순서대로 보존한다.
  /// 기존 효과 목록은 저장/검사 계약을 위해 함께 유지한다.
  final List<ScriptStep> tileOperations;

  /// 플레이어가 밟고 있는 칸의 지형 변형 (원작 `map[x,y] := 값`).
  final List<({int tile, int? ifZero})> playerTiles;

  /// 대화 상대(앞 칸)의 지형 변형 (원작 `map[x+x1,y+y1] := 값`).
  ///
  /// 맵 27(운명의 피라밋)에서 관계없는 "의지"가 재로 변하는 연출에 쓰인다.
  final int? tileAtTarget;

  /// 플레이어를 미는 이동 (원작 `inc(y)` / `dec(y)`).
  final List<({int dx, int dy})> nudges;

  /// 장비 지급 목록 (원작 `weapon := n` / `shield := n` / `armor := n`).
  final List<
    ({String kind, int index, int power, bool prompt, bool onlyUnarmed})
  >
  equips;

  /// 대사와 카메라 연출의 **실행 순서**(UI가 순서대로 재생하기 위해 쓴다).
  final List<ScriptEvent> events;

  // 누적 결과의 값이 같아도 선택지/전투 이후 다시 발생한 효과를 구분한다.
  final int _teleportCount;
  final int _targetTileCount;
  final int _partyClassCount;
  final int _torchCount;
  final int _rigelBlessingCount;
  final int _stepBackCount;
  final int _blockCount;

  const ScriptOutcome({
    this.messages = const [],
    this.goldDelta = 0,
    this.foodDelta = 0,
    this.setFlags = const [],
    this.sourceEtcWrites = const [],
    this.recruits = const [],
    this.battleMonsters = const [],
    this.battleCount = 0,
    this.battleMirrorParty = false,
    this.battleReuseExisting = false,
    this.battleTitle,
    this.battleEnemyFirst = false,
    this.battleOverrides = const [],
    this.battleVictoryFlags = const [],
    this.blockMove = false,
    this.teleportMap,
    this.teleportX,
    this.teleportY,
    this.stepBack = false,
    this.teleportKeepX = false,
    this.teleportKeepY = false,
    this.torchLit = false,
    this.rigelBlessing = false,
    this.partyClassId,
    this.questChanges = const [],
    this.expDelta = 0,
    this.tileChanges = const [],
    this.tileAreas = const [],
    this.tileOperations = const [],
    this.playerTiles = const [],
    this.tileAtTarget,
    this.nudges = const [],
    this.equips = const [],
    this.events = const [],
    this._teleportCount = 0,
    this._targetTileCount = 0,
    this._partyClassCount = 0,
    this._torchCount = 0,
    this._rigelBlessingCount = 0,
    this._stepBackCount = 0,
    this._blockCount = 0,
  });

  /// 선택지 이전에 이미 적용한 결과를 제외한 이번 구간의 효과만 돌려준다.
  /// [ScriptRun.outcome]은 기존 호출자를 위해 누적 결과를 유지한다.
  ScriptOutcome since(ScriptOutcome previous) {
    List<T> added<T>(List<T> current, List<T> old) =>
        current.skip(old.length).toList();
    bool emitted(int current, int old, bool legacyChanged) =>
        current > old || (current == 0 && old == 0 && legacyChanged);

    final newBattle = battleCount > previous.battleCount;
    final newTeleport = emitted(
      _teleportCount,
      previous._teleportCount,
      teleportX != previous.teleportX ||
          teleportY != previous.teleportY ||
          teleportMap != previous.teleportMap,
    );

    return ScriptOutcome(
      messages: added(messages, previous.messages),
      goldDelta: goldDelta - previous.goldDelta,
      foodDelta: foodDelta - previous.foodDelta,
      setFlags: added(setFlags, previous.setFlags),
      sourceEtcWrites: added(sourceEtcWrites, previous.sourceEtcWrites),
      recruits: added(recruits, previous.recruits),
      battleMonsters: newBattle ? battleMonsters : const [],
      battleCount: battleCount - previous.battleCount,
      battleMirrorParty: newBattle && battleMirrorParty,
      battleReuseExisting: newBattle && battleReuseExisting,
      battleTitle: newBattle ? battleTitle : null,
      battleEnemyFirst: newBattle && battleEnemyFirst,
      battleOverrides: newBattle ? battleOverrides : const [],
      battleVictoryFlags: added(
        battleVictoryFlags,
        previous.battleVictoryFlags,
      ),
      blockMove: emitted(
        _blockCount,
        previous._blockCount,
        blockMove && !previous.blockMove,
      ),
      teleportMap: newTeleport ? teleportMap : null,
      teleportX: newTeleport ? teleportX : null,
      teleportY: newTeleport ? teleportY : null,
      stepBack: emitted(
        _stepBackCount,
        previous._stepBackCount,
        stepBack && !previous.stepBack,
      ),
      teleportKeepX: teleportKeepX,
      teleportKeepY: teleportKeepY,
      torchLit: emitted(
        _torchCount,
        previous._torchCount,
        torchLit && !previous.torchLit,
      ),
      rigelBlessing: emitted(
        _rigelBlessingCount,
        previous._rigelBlessingCount,
        rigelBlessing && !previous.rigelBlessing,
      ),
      partyClassId:
          emitted(
            _partyClassCount,
            previous._partyClassCount,
            partyClassId != previous.partyClassId,
          )
          ? partyClassId
          : null,
      questChanges: added(questChanges, previous.questChanges),
      expDelta: expDelta - previous.expDelta,
      tileChanges: added(tileChanges, previous.tileChanges),
      tileAreas: added(tileAreas, previous.tileAreas),
      tileOperations: added(tileOperations, previous.tileOperations),
      playerTiles: added(playerTiles, previous.playerTiles),
      tileAtTarget:
          emitted(
            _targetTileCount,
            previous._targetTileCount,
            tileAtTarget != previous.tileAtTarget,
          )
          ? tileAtTarget
          : null,
      nudges: added(nudges, previous.nudges),
      equips: added(equips, previous.equips),
      events: added(events, previous.events),
      teleportCount: _teleportCount - previous._teleportCount,
      targetTileCount: _targetTileCount - previous._targetTileCount,
      partyClassCount: _partyClassCount - previous._partyClassCount,
      torchCount: _torchCount - previous._torchCount,
      rigelBlessingCount: _rigelBlessingCount - previous._rigelBlessingCount,
      stepBackCount: _stepBackCount - previous._stepBackCount,
      blockCount: _blockCount - previous._blockCount,
    );
  }
}

/// 실행 중인 스크립트. 선택지가 나오면 [pendingChoice]가 채워진다.
class ScriptRun {
  final LoreScriptEngine _engine;
  final LoreScript script;
  final List<ScriptStep> _remaining;
  final ScriptOutcome _acc;
  final String? choicePrompt;
  final List<String>? choiceTexts;
  final ScriptStep? _choiceStep;
  final ScriptStep? _battleStep;
  final bool awaitingBattle;
  final ScriptScene? pendingScene;
  final bool pendingConditionRefresh;
  final bool _reuseFirstBattle;

  ScriptRun._(
    this._engine,
    this.script,
    this._remaining,
    this._acc, {
    this.choicePrompt,
    this.choiceTexts,
    this._choiceStep,
    this._battleStep,
    this.awaitingBattle = false,
    this.pendingScene,
    this.pendingConditionRefresh = false,
    this._reuseFirstBattle = false,
  });

  /// UI가 사용자에게 물어봐야 하는 선택지 (없으면 null).
  List<String>? get pendingChoice => choiceTexts;

  /// 지금까지 누적된 결과.
  ScriptOutcome get outcome => _acc;

  bool get hasPendingChoice => choiceTexts != null;
  bool get hasPendingScene => pendingScene != null;

  int? get cancelOptionIndex => _choiceStep?.cancelOptionIndex;

  /// 선택형 장비는 UI에서 장착이 확정된 뒤에만 1회 스크립트를 소모한다.
  bool get requiresEquipmentCommit => _acc.equips.any((equip) => equip.prompt);

  void completeEquipment() {
    if (script.once &&
        !hasPendingChoice &&
        !hasPendingScene &&
        !pendingConditionRefresh &&
        !awaitingBattle &&
        requiresEquipmentCommit) {
      _engine.consumedScripts.add(script.id);
    }
  }

  /// [defeatedEnemySlots] are the `dead` slots; [hpZeroEnemySlots] (default
  /// the same) those with `hp <= 0`.
  bool isVictoryAfterRunAway(
    Set<int> defeatedEnemySlots, {
    Set<int>? hpZeroEnemySlots,
  }) {
    final battle = _battleStep;
    if (!awaitingBattle || battle == null) return false;
    final dead = battle.battleVictoryIfEnemyDead;
    final down = battle.battleVictoryIfEnemyHpZero;
    return (dead != null && defeatedEnemySlots.contains(dead)) ||
        (down != null &&
            (hpZeroEnemySlots ?? defeatedEnemySlots).contains(down));
  }

  /// Whether Escape runs its own source branch instead of abandoning.
  bool get hasCancelSteps => _choiceStep?.cancelSteps.isNotEmpty ?? false;

  /// Escape on a source `select` whose 0 result has its own branch; the
  /// remaining steps after the choice are not run.
  ScriptRun cancel() {
    final steps = _choiceStep?.cancelSteps;
    if (steps == null || steps.isEmpty) return this;
    return _engine._execute(script, steps, _acc);
  }

  /// 선택지 인덱스를 골라 실행을 이어간다. 반환값은 갱신된 [ScriptRun].
  ScriptRun choose(int optionIndex) {
    final options = _choiceStep?.options;
    if (options == null) return this;
    final chosen = (optionIndex >= 0 && optionIndex < options.length)
        ? options[optionIndex]
        : null;
    if (chosen == null) return this;
    // 선택 이후 실행할 스텝 = 고른 옵션의 스텝 + 원래 스크립트의 나머지
    final queue = <ScriptStep>[...chosen.steps, ..._remaining];
    final run = _engine._execute(
      script,
      queue,
      _acc,
      reuseFirstBattle: _reuseFirstBattle,
    );
    if (script.once &&
        !run.hasPendingChoice &&
        !run.hasPendingScene &&
        !run.pendingConditionRefresh &&
        !run.awaitingBattle &&
        !run.requiresEquipmentCommit) {
      _engine.consumedScripts.add(script.id);
    }
    return run;
  }

  /// 전투에서 이긴 뒤에만 남은 스텝을 실행한다.
  bool get checksStoredDeadSlots =>
      _battleStep?.battleChecksStoredDeadSlots == true;

  ScriptRun continueAfterBattle({Set<int> defeatedEnemySlots = const {}}) {
    if (!awaitingBattle) return this;
    final run = _engine._execute(script, [
      if (checksStoredDeadSlots) ...[
        for (final entry in _battleStep!.battleEnemyDefeatFlags.entries)
          if (defeatedEnemySlots.contains(entry.key))
            ScriptStep(kind: 'flag', key: entry.value),
        for (final condition in _battleStep.battleRunAwayFlagsWhenDead)
          if (condition.slots.every(defeatedEnemySlots.contains))
            ScriptStep(kind: 'flag', key: condition.flag),
      ] else
        for (final flag
            in _battleStep?.battleEnemyDefeatFlags.values ?? const <String>[])
          ScriptStep(kind: 'flag', key: flag),
      ..._remaining,
    ], _acc);
    if (script.once &&
        !run.hasPendingChoice &&
        !run.hasPendingScene &&
        !run.pendingConditionRefresh &&
        !run.awaitingBattle &&
        !run.requiresEquipmentCommit) {
      _engine.consumedScripts.add(script.id);
    }
    return run;
  }

  /// 도망에 지정된 후속 스텝을 실행하고, 원작의 재도전 루프를 이어간다.
  ScriptRun continueAfterRunAway({
    Set<int> defeatedEnemySlots = const {},
    Set<int>? hpZeroEnemySlots,
  }) {
    final battle = _battleStep;
    if (!awaitingBattle || battle == null) return this;
    if (isVictoryAfterRunAway(
      defeatedEnemySlots,
      hpZeroEnemySlots: hpZeroEnemySlots,
    )) {
      return continueAfterBattle();
    }
    if (battle.battleRunAwayIfEnemyAlive != null &&
        defeatedEnemySlots.contains(battle.battleRunAwayIfEnemyAlive)) {
      return ScriptRun._(_engine, script, const [], _acc);
    }
    final queue = <ScriptStep>[
      for (final slot in defeatedEnemySlots.toList()..sort())
        if (battle.battleEnemyDefeatFlags.containsKey(slot))
          ScriptStep(kind: 'flag', key: battle.battleEnemyDefeatFlags[slot]),
      for (final condition in battle.battleRunAwayFlagsWhenDead)
        if (condition.slots.every(defeatedEnemySlots.contains))
          ScriptStep(kind: 'flag', key: condition.flag),
      if (battle.battleRunAwayProgressQuest != null &&
          battle.battleRunAwayProgressTotal != null)
        ScriptStep(
          kind: 'questStep',
          questName: battle.battleRunAwayProgressQuest,
          questSet:
              battle.battleRunAwayProgressTotal! -
              _acc.battleMonsters.length +
              defeatedEnemySlots
                  .where(
                    (index) =>
                        index >= 1 && index <= _acc.battleMonsters.length,
                  )
                  .length,
        ),
      ...battle.battleRunAwaySteps,
      if (battle.battleRetryOnRunAway) battle,
      if (battle.battleRetryOnRunAway) ..._remaining,
      if (battle.battleContinueOnRunAway && !battle.battleRetryOnRunAway)
        ..._remaining,
    ];
    return _engine._execute(
      script,
      queue,
      _acc,
      reuseFirstBattle: battle.battleRetryOnRunAway,
    );
  }

  /// The continuation after `GameOver` reloads a defeat: none when the source
  /// checks `party.etc[6] = 255`, else the escape path ([battleResultUnchecked]).
  ScriptRun? continueAfterDefeat({
    Set<int> defeatedEnemySlots = const {},
    Set<int>? hpZeroEnemySlots,
  }) {
    if (!awaitingBattle || _battleStep?.battleResultUnchecked != true) {
      return null;
    }
    return continueAfterRunAway(
      defeatedEnemySlots: defeatedEnemySlots,
      hpZeroEnemySlots: hpZeroEnemySlots,
    );
  }

  /// Whether the source goes on to the later checks of its `case` body.
  bool get resumesAfterReload => _battleStep?.battleReloadResume == true;

  /// Resume only after the UI applies the source Display_Condition call.
  ScriptRun acknowledgeConditionRefresh() {
    if (!pendingConditionRefresh) return this;
    final run = _engine._execute(
      script,
      _remaining,
      _acc,
      reuseFirstBattle: _reuseFirstBattle,
    );
    if (script.once &&
        !run.hasPendingChoice &&
        !run.hasPendingScene &&
        !run.pendingConditionRefresh &&
        !run.awaitingBattle &&
        !run.requiresEquipmentCommit) {
      _engine.consumedScripts.add(script.id);
    }
    return run;
  }

  ScriptRun acknowledgeScene() {
    if (!hasPendingScene) return this;
    final run = _engine._execute(
      script,
      _remaining,
      _acc,
      reuseFirstBattle: _reuseFirstBattle,
    );
    if (script.once &&
        !run.hasPendingChoice &&
        !run.hasPendingScene &&
        !run.pendingConditionRefresh &&
        !run.awaitingBattle &&
        !run.requiresEquipmentCommit) {
      _engine.consumedScripts.add(script.id);
    }
    return run;
  }
}

// ── 엔진 ────────────────────────────────────────────────────────────

class LoreScriptEngine {
  static final LoreScriptEngine instance = LoreScriptEngine();

  /// 별도 실행 세션을 만들 수 있다. 같은 시드와 입력이면 난수 분기를 재현한다.
  LoreScriptEngine({Random? random})
    : _random = random ?? LoreRandom.fromClock();

  /// Each game has its own Pascal RNG and continuation history.
  LoreScriptEngine fork({Random? random}) => LoreScriptEngine(random: random);
  final Set<String> consumedScripts = {};
  final Random _random;
  void resetForTest() => consumedScripts.clear();

  /// Run a source-ported procedure through the existing ordered effect and
  /// battle continuation interpreter without registering a JSON rule.
  ScriptRun startProcedure(LoreScript procedure, ScriptContext ctx) =>
      _start(procedure, ctx);

  int roll(int exclusiveUpperBound) => _random.nextInt(exclusiveUpperBound);

  ScriptRun _start(LoreScript s, ScriptContext ctx) {
    final run = _execute(s, s.steps, const ScriptOutcome());
    if (s.once &&
        !run.hasPendingChoice &&
        !run.hasPendingScene &&
        !run.pendingConditionRefresh &&
        !run.awaitingBattle &&
        !run.requiresEquipmentCommit) {
      consumedScripts.add(s.id);
    }
    return run;
  }

  /// 스텝 목록을 순차 실행한다. choice를 만나면 거기서 멈추고 선택지를 돌려준다.
  ScriptRun _execute(
    LoreScript script,
    List<ScriptStep> steps,
    ScriptOutcome acc, {
    bool reuseFirstBattle = false,
  }) {
    var messages = List<String>.from(acc.messages);
    var gold = acc.goldDelta;
    var food = acc.foodDelta;
    var flags = List<String>.from(acc.setFlags);
    var sourceEtcWrites = List<({int index, int value})>.from(
      acc.sourceEtcWrites,
    );
    var recruits =
        List<({String key, int? slot, List<ScriptStep> cancelSteps})>.from(
          acc.recruits,
        );
    var monsters = List<int>.from(acc.battleMonsters);
    var battleCount = acc.battleCount;
    var battleMirrorParty = acc.battleMirrorParty;
    var battleReuseExisting = acc.battleReuseExisting;
    var battleTitle = acc.battleTitle;
    var battleEnemyFirst = acc.battleEnemyFirst;
    var battleOverrides = List<Map<String, Object?>>.from(acc.battleOverrides);
    var teleportMap = acc.teleportMap;
    var teleportX = acc.teleportX;
    var teleportY = acc.teleportY;
    var teleportKeepX = acc.teleportKeepX;
    var teleportKeepY = acc.teleportKeepY;
    var torchLit = acc.torchLit;
    var rigelBlessing = acc.rigelBlessing;
    var partyClassId = acc.partyClassId;
    var questChanges = List<({String name, int? set, int? inc})>.from(
      acc.questChanges,
    );
    var expDelta = acc.expDelta;
    var tileChanges =
        List<({int? map, int x, int y, int tile, int? ifZero})>.from(
          acc.tileChanges,
        );
    var tileAreas =
        List<
          ({
            int? map,
            int xMin,
            int xMax,
            int yMin,
            int yMax,
            int tile,
            int? ifZero,
            bool atPlayerX,
            bool atPlayerY,
            int? onlyIf,
          })
        >.from(acc.tileAreas);
    var tileOperations = List<ScriptStep>.from(acc.tileOperations);
    var playerTiles = List<({int tile, int? ifZero})>.from(acc.playerTiles);
    var tileAtTarget = acc.tileAtTarget;
    var nudges = List<({int dx, int dy})>.from(acc.nudges);
    var battleVictory = List<String>.from(acc.battleVictoryFlags);
    var blockMove = acc.blockMove;
    var stepBack = acc.stepBack;
    var teleportCount = acc._teleportCount;
    var targetTileCount = acc._targetTileCount;
    var partyClassCount = acc._partyClassCount;
    var torchCount = acc._torchCount;
    var rigelBlessingCount = acc._rigelBlessingCount;
    var stepBackCount = acc._stepBackCount;
    var blockCount = acc._blockCount;
    var equips =
        List<
          ({String kind, int index, int power, bool prompt, bool onlyUnarmed})
        >.from(acc.equips);
    var events = List<ScriptEvent>.from(acc.events);

    ScriptOutcome snapshot() => ScriptOutcome(
      messages: messages,
      goldDelta: gold,
      foodDelta: food,
      setFlags: flags,
      sourceEtcWrites: sourceEtcWrites,
      recruits: recruits,
      battleMonsters: monsters,
      battleCount: battleCount,
      battleMirrorParty: battleMirrorParty,
      battleReuseExisting: battleReuseExisting,
      battleOverrides: battleOverrides,
      battleTitle: battleTitle,
      battleEnemyFirst: battleEnemyFirst,
      battleVictoryFlags: battleVictory,
      blockMove: blockMove,
      teleportMap: teleportMap,
      teleportX: teleportX,
      teleportY: teleportY,
      stepBack: stepBack,
      teleportKeepX: teleportKeepX,
      teleportKeepY: teleportKeepY,
      torchLit: torchLit,
      rigelBlessing: rigelBlessing,
      partyClassId: partyClassId,
      questChanges: questChanges,
      expDelta: expDelta,
      tileChanges: tileChanges,
      tileAreas: tileAreas,
      tileOperations: tileOperations,
      playerTiles: playerTiles,
      tileAtTarget: tileAtTarget,
      nudges: nudges,
      equips: equips,
      events: events,
      teleportCount: teleportCount,
      targetTileCount: targetTileCount,
      partyClassCount: partyClassCount,
      torchCount: torchCount,
      rigelBlessingCount: rigelBlessingCount,
      stepBackCount: stepBackCount,
      blockCount: blockCount,
    );

    // `randomSteps` 분기를 펼치기 위해 실행 목록을 큐로 다룬다.
    final queue = List<ScriptStep>.from(steps);
    for (var i = 0; i < queue.length; i++) {
      final step = queue[i];
      if (step.kind == 'randomSteps') {
        final branches = step.randomBranches ?? const [];
        if (branches.isNotEmpty) {
          final picked = branches[_random.nextInt(branches.length)];
          queue.insertAll(i + 1, picked);
        }
        continue;
      }
      switch (step.kind) {
        case 'displayCondition':
          return ScriptRun._(
            this,
            script,
            queue.sublist(i + 1),
            snapshot(),
            pendingConditionRefresh: true,
            reuseFirstBattle: reuseFirstBattle,
          );
        case 'scene':
          final scene = step.scene!;
          for (final line in scene.lines) {
            messages.add(line);
            events.add(ScriptEvent.sceneLine(line));
          }
          return ScriptRun._(
            this,
            script,
            queue.sublist(i + 1),
            snapshot(),
            pendingScene: scene,
            reuseFirstBattle: reuseFirstBattle,
          );
        case 'sourceFace':
          events.add(ScriptEvent.sourceFace(step.sourceFace!));
          break;
        case 'endDemo':
          events.add(const ScriptEvent.endDemo());
          break;
        case 'pause':
          events.add(const ScriptEvent.pause());
          break;
        case 'message':
          messages.add(step.text!);
          events.add(ScriptEvent.log(step.text!));
          break;
        case 'say':
          messages.add(step.text!);
          events.add(ScriptEvent.message(step.text!));
          break;
        case 'gold':
          gold += step.amount!;
          break;
        case 'food':
          food += step.amount!;
          break;
        case 'flag':
          flags.add(step.key!);
          break;
        case 'sourceEtc':
          LorePartyEtc.checkIndex(step.sourceEtcIndex!);
          sourceEtcWrites.add((
            index: step.sourceEtcIndex!,
            value: LorePascal.byte(step.sourceEtcValue!),
          ));
          break;
        case 'join':
          recruits.add((
            key: step.key!,
            slot: step.slot,
            cancelSteps: step.cancelSteps,
          ));
          break;
        case 'battle':
          monsters = List<int>.from(step.monsters ?? const []);
          battleCount++;
          battleMirrorParty = step.battleMirrorParty;
          battleReuseExisting = reuseFirstBattle;
          reuseFirstBattle = false;
          if (step.battleShuffle) monsters.shuffle(_random);
          // 원작 `enemynumber := random(3) + 3` 같은 난수 소환.
          if (step.randomPool != null && step.randomPool!.isNotEmpty) {
            final minCount = step.randomMin ?? 1;
            final maxCount = step.randomMax ?? minCount;
            final span = (maxCount - minCount).abs() + 1;
            final count = minCount + _random.nextInt(span);
            for (var n = 0; n < count; n++) {
              monsters.add(
                step.randomPool![_random.nextInt(step.randomPool!.length)],
              );
            }
          }
          battleTitle = step.battleTitle;
          battleEnemyFirst = step.battleEnemyFirst;
          battleOverrides = List<Map<String, Object?>>.from(
            step.battleOverrides ?? const [],
          );
          battleVictory.addAll(step.battleVictoryFlags);
          return ScriptRun._(
            this,
            script,
            queue.sublist(i + 1),
            snapshot(),
            awaitingBattle: true,
            battleStep: step,
          );
        case 'teleport':
          teleportCount++;
          teleportMap = step.teleportMap;
          teleportX = step.tileX;
          teleportY = step.tileY;
          teleportKeepX = step.teleportKeepX;
          teleportKeepY = step.teleportKeepY;
          break;
        case 'torch':
          torchCount++;
          torchLit = true;
          break;
        case 'rigelBlessing':
          rigelBlessingCount++;
          rigelBlessing = true;
          break;
        case 'partyClass':
          partyClassCount++;
          partyClassId = step.partyClassId;
          break;
        case 'block':
          blockCount++;
          blockMove = true;
          break;
        case 'questStep':
          questChanges.add((
            name: step.questName!,
            set: step.questSet,
            inc: step.questInc,
          ));
          break;
        case 'exp':
          expDelta += step.expDelta ?? 0;
          break;
        case 'setTile':
          tileOperations.add(step);
          tileChanges.add((
            map: step.teleportMap,
            x: step.tileX!,
            y: step.tileY!,
            tile: step.tileValue!,
            ifZero: step.tileIfZero,
          ));
          break;
        case 'setTileArea':
          tileOperations.add(step);
          tileAreas.add((
            map: step.teleportMap,
            xMin: step.tileX!,
            xMax: step.tileXMax ?? step.tileX!,
            yMin: step.tileY!,
            yMax: step.tileYMax ?? step.tileY!,
            tile: step.tileValue!,
            ifZero: step.tileIfZero,
            atPlayerX: step.tileAtPlayerX,
            atPlayerY: step.tileAtPlayerY,
            onlyIf: step.tileOnlyIf,
          ));
          break;
        case 'randomFlag':
          final names = step.randomFlagNames ?? const [];
          if (names.isNotEmpty) {
            flags.add(names[_random.nextInt(names.length)]);
          }
          break;
        case 'setTileAtPlayer':
          playerTiles.add((
            tile: step.tileValue ?? 49,
            ifZero: step.tileIfZero,
          ));
          break;
        case 'setTileAtTarget':
          targetTileCount++;
          tileAtTarget = step.tileValue;
          break;
        case 'nudge':
          nudges.add((dx: step.nudgeDx ?? 0, dy: step.nudgeDy ?? 0));
          break;
        case 'stepBack':
          stepBackCount++;
          stepBack = true;
          break;
        case 'equip':
          equips.add((
            kind: step.equipKind!,
            index: step.equipIndex!,
            power: step.equipPower ?? 0,
            prompt: step.equipPrompt,
            onlyUnarmed: step.equipOnlyUnarmed,
          ));
          break;
        case 'peek':
          events.add(ScriptEvent.peek(step.peekX, step.peekY));
          break;
        case 'choice':
          final run = ScriptRun._(
            this,
            script,
            queue.sublist(i + 1),
            snapshot(),
            choicePrompt: step.prompt,
            choiceTexts: step.options!.map((o) => o.text).toList(),
            choiceStep: step,
            reuseFirstBattle: reuseFirstBattle,
          );
          return run;
      }
    }

    return ScriptRun._(this, script, const [], snapshot());
  }
}
