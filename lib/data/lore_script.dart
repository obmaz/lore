/// 좌표 기반 이벤트/대화를 JSON으로 관리하는 스크립트 엔진.
///
/// `assets/data/scripts.json`의 스크립트를 읽어 실행한다.
/// 원작 `LORESPEC.PAS`(좌표 이벤트) / `LORETALK.PAS`(NPC 대화)를 JSON 데이터로
/// 옮겨, 게임 코드 수정 없이 대사·보상·분기를 편집할 수 있게 한다.
///
/// 지원 스텝(`steps` 배열):
/// - `{"say": "..."}`                 메시지 출력
/// - `{"gold": 5000}` / `{"food": -5}` 보상/소모
/// - `{"flag": "이름"}`               플래그 설정
/// - `{"join": "polaris", "slot": 4}` 동료 영입 (slot은 0~4 = 2~6번 슬롯 고정)
/// - `{"battle": {"title": "..", "monsters": [26, 8, 8]}}` 전투 개시
/// - `{"teleport": {"x": 46, "y": 41, "map": 1}}`   강제 이동 (map 생략 시 현재 맵)
/// - `{"setTile": {"x": 62, "y": 82, "tile": 44}}`  지형 변형 (통로 개방/상자 제거)
/// - `{"peek": {"x": 48, "y": 57}}`  카메라 연출 (원작 `scroll(FALSE)`):
///   파티는 그대로 두고 시야만 옮겨 다른 장소를 보여준 뒤 돌아온다.
/// - `{"equip": {"kind": "weapon", "index": 3, "power": 12, "prompt": true}}`
///   장비 지급 (원작 `choosewhom` + `weapon := n`). `onlyUnarmed`면 무기 없는
///   대원만 대상이 된다(원작 맵 6의 기본 무장).
/// - `{"choice": {"prompt": "..", "options": [{"text": "..", "steps": [...]}]}}`
///
/// 좌표(`x`,`y`) 대신 `xMin`/`xMax`/`yMin`/`yMax`로 "열/행 전체" 트리거도
/// 정의할 수 있다(원작 `if y = 44 then ...` 같은 조건).
///
/// 조건(`require`):
/// - `flag` / `flagNot`               플래그 설정/미설정
/// - `mindRead`                       독심술(ESP) 사용 가능
/// - `minEspLevel`                    파티 최고 초능력 레벨 이상
/// - `notMindReadOrLowEsp`            위 두 조건의 부정(안내 문구용)
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

// ── 스크립트 데이터 모델 ──────────────────────────────────────────────

/// 스크립트 실행 조건.
class ScriptRequire {
  final String? flag;
  final String? flagNot;
  final bool mindRead;
  final int? minEspLevel;
  final bool notMindReadOrLowEsp;

  const ScriptRequire({
    this.flag,
    this.flagNot,
    this.mindRead = false,
    this.minEspLevel,
    this.notMindReadOrLowEsp = false,
  });

  factory ScriptRequire.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ScriptRequire();
    return ScriptRequire(
      flag: json['flag'] as String?,
      flagNot: json['flagNot'] as String?,
      mindRead: json['mindRead'] == true,
      minEspLevel: json['minEspLevel'] as int?,
      notMindReadOrLowEsp: json['notMindReadOrLowEsp'] == true,
    );
  }
}

/// 스크립트 실행에 필요한 상황 정보.
class ScriptContext {
  final bool mindReadActive;
  final int maxEspLevel;
  final Set<String> flags;

  const ScriptContext({
    this.mindReadActive = false,
    this.maxEspLevel = 0,
    this.flags = const {},
  });
}

/// 선택지 1개.
class ScriptOption {
  final String text;
  final List<ScriptStep> steps;

  const ScriptOption(this.text, this.steps);
}

/// 스크립트 실행 중 일어난 일 1건(순서 보존).
class ScriptEvent {
  /// 'message' = 대사 출력, 'peek' = 카메라 연출(원작 `scroll(FALSE)`).
  final String kind;
  final String? text;
  final int? x;
  final int? y;

  const ScriptEvent.message(String this.text) : kind = 'message', x = null, y = null;
  const ScriptEvent.peek(this.x, this.y) : kind = 'peek', text = null;
}

/// 스크립트 스텝 1개.
class ScriptStep {
  final String kind; // say / gold / food / flag / join / battle / choice / equip / peek
  final String? text;
  final int? amount;
  final String? key;
  final int? slot;
  final String? prompt;
  final List<ScriptOption>? options;
  final List<int>? monsters;
  final String? battleTitle;

  /// teleport 스텝 (강제 이동) - map이 null이면 현재 맵.
  final int? teleportMap;
  final int? tileX;
  final int? tileY;
  final int? tileValue;

  /// equip 스텝 (장비 지급): 원작 `weapon := 3; wea_power := 12` 등.
  final String? equipKind; // weapon | shield | armor
  final int? equipIndex;
  final int? equipPower;
  final bool equipPrompt;
  final bool equipOnlyUnarmed;

  /// peek 스텝 (카메라 연출): 시야만 옮길 좌표.
  final int? peekX;
  final int? peekY;

  const ScriptStep({
    required this.kind,
    this.text,
    this.amount,
    this.key,
    this.slot,
    this.prompt,
    this.options,
    this.monsters,
    this.battleTitle,
    this.teleportMap,
    this.tileX,
    this.tileY,
    this.tileValue,
    this.equipKind,
    this.equipIndex,
    this.equipPower,
    this.equipPrompt = false,
    this.equipOnlyUnarmed = false,
    this.peekX,
    this.peekY,
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

  final bool once;
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
    required this.once,
    required this.require,
    required this.steps,
  });

  /// 이 스크립트가 (mapId, tx, ty)에서 발동되는지 검사한다.
  bool matches(String triggerName, int mapId, int tx, int ty) {
    if (trigger != triggerName || map != mapId) return false;
    if (x != null || y != null) {
      if (x != null && x != tx) return false;
      if (y != null && y != ty) return false;
    }
    if (xMin != null && tx < xMin!) return false;
    if (xMax != null && tx > xMax!) return false;
    if (yMin != null && ty < yMin!) return false;
    if (yMax != null && ty > yMax!) return false;
    return true;
  }
}

/// 스크립트 실행 결과(누적).
class ScriptOutcome {
  final List<String> messages;
  final int goldDelta;
  final int foodDelta;
  final List<String> setFlags;
  final List<({String key, int? slot})> recruits;
  final List<int> battleMonsters;
  final String? battleTitle;

  /// 강제 이동 목적지 (없으면 null).
  final int? teleportMap;
  final int? teleportX;
  final int? teleportY;

  /// 지형 변형 목록 (원작 `map[x,y] := 값`).
  final List<({int? map, int x, int y, int tile})> tileChanges;

  /// 장비 지급 목록 (원작 `weapon := n` / `shield := n` / `armor := n`).
  final List<
    ({String kind, int index, int power, bool prompt, bool onlyUnarmed})
  >
  equips;

  /// 대사와 카메라 연출의 **실행 순서**(UI가 순서대로 재생하기 위해 쓴다).
  final List<ScriptEvent> events;

  const ScriptOutcome({
    this.messages = const [],
    this.goldDelta = 0,
    this.foodDelta = 0,
    this.setFlags = const [],
    this.recruits = const [],
    this.battleMonsters = const [],
    this.battleTitle,
    this.teleportMap,
    this.teleportX,
    this.teleportY,
    this.tileChanges = const [],
    this.equips = const [],
    this.events = const [],
  });
}

/// 실행 중인 스크립트. 선택지가 나오면 [pendingChoice]가 채워진다.
class ScriptRun {
  final LoreScript script;
  final List<ScriptStep> _remaining;
  final ScriptOutcome _acc;
  final String? choicePrompt;
  final List<String>? choiceTexts;
  final ScriptStep? _choiceStep;

  ScriptRun._(
    this.script,
    this._remaining,
    this._acc, {
    this.choicePrompt,
    this.choiceTexts,
    this._choiceStep,
  });

  /// UI가 사용자에게 물어봐야 하는 선택지 (없으면 null).
  List<String>? get pendingChoice => choiceTexts;

  /// 지금까지 누적된 결과.
  ScriptOutcome get outcome => _acc;

  bool get hasPendingChoice => choiceTexts != null;

  /// 선택지 인덱스를 골라 실행을 이어간다. 반환값은 갱신된 [ScriptRun].
  ScriptRun choose(int optionIndex) {
    final options = _choiceStep?.options;
    if (options == null) return this;
    final chosen = (optionIndex >= 0 && optionIndex < options.length)
        ? options[optionIndex]
        : null;
    // 선택 이후 실행할 스텝 = 고른 옵션의 스텝 + 원래 스크립트의 나머지
    final queue = <ScriptStep>[...?chosen?.steps, ..._remaining];
    return LoreScriptEngine.instance._execute(script, queue, _acc);
  }
}

// ── 엔진 ────────────────────────────────────────────────────────────

class LoreScriptEngine {
  static final LoreScriptEngine instance = LoreScriptEngine._internal();
  LoreScriptEngine._internal();

  List<LoreScript> _scripts = [];
  bool _loaded = false;
  bool usingJson = false;
  String? loadError;

  /// 1회성 스크립트 실행 이력 (원작 `party.etc` 비트에 대응).
  final Set<String> consumedScripts = {};

  List<LoreScript> get scripts => _scripts;

  Future<void> load({AssetBundle? bundle}) async {
    if (_loaded) return;
    try {
      final raw = await (bundle ?? rootBundle).loadString(
        'assets/data/scripts.json',
      );
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _scripts = (decoded['scripts'] as List<dynamic>)
          .map((e) => _parseScript(e as Map<String, dynamic>))
          .toList();
      usingJson = true;
    } catch (e) {
      _scripts = [];
      usingJson = false;
      loadError = e.toString();
    }
    _loaded = true;
  }

  void resetForTest() {
    _loaded = false;
    usingJson = false;
    loadError = null;
    _scripts = [];
    consumedScripts.clear();
  }

  /// 좌표에 해당하는 스크립트를 찾는다(조건 검사 포함).
  LoreScript? find(String trigger, int mapId, int x, int y, ScriptContext ctx) {
    for (final s in _scripts) {
      if (!s.matches(trigger, mapId, x, y)) continue;
      if (s.once && consumedScripts.contains(s.id)) continue;
      if (!_meets(s.require, ctx)) continue;
      return s;
    }
    // 조건을 만족하는 스크립트가 없으면 "안내용" 스크립트(조건 부정)를 찾는다.
    for (final s in _scripts) {
      if (!s.matches(trigger, mapId, x, y)) continue;
      if (s.once && consumedScripts.contains(s.id)) continue;
      if (s.require.notMindReadOrLowEsp &&
          (!ctx.mindReadActive || ctx.maxEspLevel < 5)) {
        return s;
      }
    }
    return null;
  }

  /// `step` 트리거 (좌표 진입).
  ScriptRun? startStep(int mapId, int x, int y, ScriptContext ctx) {
    final s = find('step', mapId, x, y, ctx);
    if (s == null) return null;
    return _start(s, ctx);
  }

  /// `talk` 트리거 (NPC 대화).
  ScriptRun? startTalk(int mapId, int x, int y, ScriptContext ctx) {
    final s = find('talk', mapId, x, y, ctx);
    if (s == null) return null;
    return _start(s, ctx);
  }

  ScriptRun _start(LoreScript s, ScriptContext ctx) {
    if (s.once) consumedScripts.add(s.id);
    return _execute(s, s.steps, const ScriptOutcome());
  }

  /// 스텝 목록을 순차 실행한다. choice를 만나면 거기서 멈추고 선택지를 돌려준다.
  ScriptRun _execute(
    LoreScript script,
    List<ScriptStep> steps,
    ScriptOutcome acc,
  ) {
    var messages = List<String>.from(acc.messages);
    var gold = acc.goldDelta;
    var food = acc.foodDelta;
    var flags = List<String>.from(acc.setFlags);
    var recruits = List<({String key, int? slot})>.from(acc.recruits);
    var monsters = List<int>.from(acc.battleMonsters);
    var battleTitle = acc.battleTitle;
    var teleportMap = acc.teleportMap;
    var teleportX = acc.teleportX;
    var teleportY = acc.teleportY;
    var tileChanges = List<({int? map, int x, int y, int tile})>.from(
      acc.tileChanges,
    );
    var equips = List<
      ({String kind, int index, int power, bool prompt, bool onlyUnarmed})
    >.from(acc.equips);
    var events = List<ScriptEvent>.from(acc.events);

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      switch (step.kind) {
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
        case 'join':
          recruits.add((key: step.key!, slot: step.slot));
          break;
        case 'battle':
          monsters = List<int>.from(step.monsters ?? const []);
          battleTitle = step.battleTitle;
          break;
        case 'teleport':
          teleportMap = step.teleportMap;
          teleportX = step.tileX;
          teleportY = step.tileY;
          break;
        case 'setTile':
          tileChanges.add((
            map: step.teleportMap,
            x: step.tileX!,
            y: step.tileY!,
            tile: step.tileValue!,
          ));
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
            script,
            steps.sublist(i + 1),
            ScriptOutcome(
              messages: messages,
              goldDelta: gold,
              foodDelta: food,
              setFlags: flags,
              recruits: recruits,
              battleMonsters: monsters,
              battleTitle: battleTitle,
              teleportMap: teleportMap,
              teleportX: teleportX,
              teleportY: teleportY,
              tileChanges: tileChanges,
              equips: equips,
              events: events,
            ),
            choicePrompt: step.prompt,
            choiceTexts: step.options!.map((o) => o.text).toList(),
            choiceStep: step,
          );
          return run;
      }
    }

    return ScriptRun._(
      script,
      const [],
      ScriptOutcome(
        messages: messages,
        goldDelta: gold,
        foodDelta: food,
        setFlags: flags,
        recruits: recruits,
        battleMonsters: monsters,
        battleTitle: battleTitle,
        teleportMap: teleportMap,
        teleportX: teleportX,
        teleportY: teleportY,
        tileChanges: tileChanges,
        equips: equips,
        events: events,
      ),
    );
  }

  bool _meets(ScriptRequire r, ScriptContext ctx) {
    if (r.flag != null && !ctx.flags.contains(r.flag)) return false;
    if (r.flagNot != null && ctx.flags.contains(r.flagNot)) return false;
    if (r.mindRead && !ctx.mindReadActive) return false;
    if (r.minEspLevel != null && ctx.maxEspLevel < r.minEspLevel!) return false;
    if (r.notMindReadOrLowEsp) return false; // 안내용 스크립트는 위에서 처리
    return true;
  }

  // ── JSON 파싱 ──

  LoreScript _parseScript(Map<String, dynamic> json) {
    return LoreScript(
      id: json['id'] as String,
      trigger: json['trigger'] as String? ?? 'step',
      map: json['map'] as int,
      x: json['x'] as int?,
      y: json['y'] as int?,
      xMin: json['xMin'] as int?,
      xMax: json['xMax'] as int?,
      yMin: json['yMin'] as int?,
      yMax: json['yMax'] as int?,
      once: json['once'] == true,
      require: ScriptRequire.fromJson(json['require'] as Map<String, dynamic>?),
      steps: _parseSteps(json['steps'] as List<dynamic>),
    );
  }

  /// 스텝 배열을 파싱한다.
  ///
  /// 한 객체에 여러 키를 함께 쓸 수 있다(예: `{"join": "rigel", "flag": "rigelJoined"}`).
  List<ScriptStep> _parseSteps(List<dynamic> raw) {
    final steps = <ScriptStep>[];
    for (final e in raw) {
      final m = e as Map<String, dynamic>;
      var matched = false;

      if (m.containsKey('say')) {
        steps.add(ScriptStep(kind: 'say', text: m['say'] as String));
        matched = true;
      }
      if (m.containsKey('gold')) {
        steps.add(ScriptStep(kind: 'gold', amount: m['gold'] as int));
        matched = true;
      }
      if (m.containsKey('food')) {
        steps.add(ScriptStep(kind: 'food', amount: m['food'] as int));
        matched = true;
      }
      if (m.containsKey('join')) {
        steps.add(
          ScriptStep(
            kind: 'join',
            key: m['join'] as String,
            slot: m['slot'] as int?,
          ),
        );
        matched = true;
      }
      if (m.containsKey('flag')) {
        steps.add(ScriptStep(kind: 'flag', key: m['flag'] as String));
        matched = true;
      }
      if (m.containsKey('teleport')) {
        final t = m['teleport'] as Map<String, dynamic>;
        steps.add(
          ScriptStep(
            kind: 'teleport',
            teleportMap: t['map'] as int?,
            tileX: t['x'] as int,
            tileY: t['y'] as int,
          ),
        );
        matched = true;
      }
      if (m.containsKey('setTile')) {
        final t = m['setTile'] as Map<String, dynamic>;
        steps.add(
          ScriptStep(
            kind: 'setTile',
            teleportMap: t['map'] as int?,
            tileX: t['x'] as int,
            tileY: t['y'] as int,
            tileValue: t['tile'] as int,
          ),
        );
        matched = true;
      }
      if (m.containsKey('peek')) {
        final p = m['peek'] as Map<String, dynamic>;
        steps.add(
          ScriptStep(
            kind: 'peek',
            peekX: p['x'] as int,
            peekY: p['y'] as int,
          ),
        );
        matched = true;
      }
      if (m.containsKey('equip')) {
        final e = m['equip'] as Map<String, dynamic>;
        steps.add(
          ScriptStep(
            kind: 'equip',
            equipKind: e['kind'] as String,
            equipIndex: e['index'] as int,
            equipPower: e['power'] as int? ?? 0,
            equipPrompt: e['prompt'] == true,
            equipOnlyUnarmed: e['onlyUnarmed'] == true,
          ),
        );
        matched = true;
      }
      if (m.containsKey('battle')) {
        final b = m['battle'] as Map<String, dynamic>;
        steps.add(
          ScriptStep(
            kind: 'battle',
            monsters: (b['monsters'] as List<dynamic>).cast<int>(),
            battleTitle: b['title'] as String?,
          ),
        );
        matched = true;
      }
      if (m.containsKey('choice')) {
        final c = m['choice'] as Map<String, dynamic>;
        final options = (c['options'] as List<dynamic>).map((o) {
          final om = o as Map<String, dynamic>;
          return ScriptOption(
            om['text'] as String,
            _parseSteps(om['steps'] as List<dynamic>? ?? const []),
          );
        }).toList();
        steps.add(
          ScriptStep(
            kind: 'choice',
            prompt: c['prompt'] as String?,
            options: options,
          ),
        );
        matched = true;
      }

      if (!matched) throw FormatException('알 수 없는 스크립트 스텝: $m');
    }
    return steps;
  }
}
