import 'dart:io';
// Historical JSON compatibility fixtures. Never imported by lib or bundled.
// These tests do not establish parity of the direct Pascal runtime.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:lore/data/lore_script.dart';

Future<String> readHistoricalRuleAsset(String path) =>
    File(path).readAsString();

class LegacyJsonFixtureEngine extends LoreScriptEngine {
  static final LegacyJsonFixtureEngine instance = LegacyJsonFixtureEngine();
  LegacyJsonFixtureEngine({super.random});
  List<LoreScript> _scripts = [];
  bool usingJson = false;
  String? loadError;
  List<LoreScript> get scripts => _scripts;
  Future<void> load({AssetBundle? bundle}) async {
    try {
      loadFromJson(
        await (bundle == null
            ? readHistoricalRuleAsset('test/fixtures/legacy_rules/scripts.json')
            : bundle.loadString('test/fixtures/legacy_rules/scripts.json')),
      );
    } catch (e) {
      resetForTest();
      loadError = '$e';
    }
  }

  void loadFromJson(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rows = (decoded['scripts'] as List).cast<Map<String, dynamic>>();
    _validateIncludes(rows.map(_parseScript).toList());
    Map<String, dynamic> expand(Map<String, dynamic> row) {
      List<dynamic> steps(List<dynamic> values) => values.expand((raw) {
        final v = Map<String, dynamic>.from(raw as Map);
        if (v['includeScript'] case final String id) {
          return steps(rows.singleWhere((r) => r['id'] == id)['steps'] as List);
        }
        if (v['choice'] case final Map choice) {
          v['choice'] = {
            ...choice,
            'options': [
              for (final opt in choice['options'] as List)
                {...opt as Map, 'steps': steps(opt['steps'] as List? ?? [])},
            ],
          };
        }
        if (v['randomSteps'] case final List branches) {
          v['randomSteps'] = branches.map((b) => steps(b as List)).toList();
        }
        return [v];
      }).toList();
      return {...row, 'steps': steps(row['steps'] as List? ?? [])};
    }

    _scripts = rows
        .map(expand)
        .map((row) => jsonDecode(jsonEncode(row)) as Map<String, dynamic>)
        .map(_parseScript)
        .toList();
    consumedScripts.clear();
    usingJson = true;
    loadError = null;
  }

  @override
  void resetForTest() {
    _scripts = [];
    usingJson = false;
    loadError = null;
    consumedScripts.clear();
  }

  @override
  LegacyJsonFixtureEngine fork({Random? random}) {
    final session = LegacyJsonFixtureEngine(random: random);
    session._scripts = List.unmodifiable(_scripts);
    session.usingJson = usingJson;
    session.loadError = loadError;
    return session;
  }

  ScriptRun? startEnter(int mapId, ScriptContext ctx) {
    final s = find('enter', mapId, 0, 0, ctx);
    return s == null ? null : startProcedure(s, ctx);
  }

  void _validateIncludes(List<LoreScript> scripts) {
    final byId = <String, List<LoreScript>>{};
    for (final script in scripts) {
      byId.putIfAbsent(script.id, () => []).add(script);
    }
    Iterable<String> references(List<ScriptStep> steps) sync* {
      for (final step in steps) {
        if (step.includeScriptId case final id?) yield id;
        for (final option in step.options ?? const <ScriptOption>[]) {
          yield* references(option.steps);
        }
        for (final branch
            in step.randomBranches ?? const <List<ScriptStep>>[]) {
          yield* references(branch);
        }
        yield* references(step.battleRunAwaySteps);
      }
    }

    final visited = <LoreScript>{};
    final visiting = <LoreScript>{};
    void visit(LoreScript script) {
      if (visiting.contains(script)) {
        throw FormatException('순환 스크립트 참조: ${script.id}');
      }
      if (!visited.add(script)) return;
      visiting.add(script);
      for (final reference in references(script.steps)) {
        final matches = byId[reference] ?? const <LoreScript>[];
        if (matches.length != 1) {
          throw FormatException('스크립트 참조가 없거나 중복됨: $reference');
        }
        visit(matches.single);
      }
      visiting.remove(script);
    }

    for (final script in scripts) {
      visit(script);
    }
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
    return startProcedure(s, ctx);
  }

  /// `talk` 트리거 (NPC 대화).
  ScriptRun? startTalk(int mapId, int x, int y, ScriptContext ctx) {
    final s = find('talk', mapId, x, y, ctx);
    if (s == null) return null;
    return startProcedure(s, ctx);
  }

  /// id 로 지정한 스크립트를 실행한다(포털의 `script` 필드 등).
  ScriptRun? startById(
    String id,
    ScriptContext ctx, {
    bool allowDisabled = true,
  }) {
    for (final s in _scripts) {
      if (s.id != id) continue;
      if (s.disabled && !allowDisabled) continue;
      if (!_meets(s.require, ctx)) continue;
      if (s.once && consumedScripts.contains(s.id)) continue;
      return startProcedure(s, ctx);
    }
    return null;
  }

  bool _meets(ScriptRequire r, ScriptContext ctx) {
    if (r.flag != null && !ctx.flags.contains(r.flag)) return false;
    if (r.flagNot != null && ctx.flags.contains(r.flagNot)) return false;
    if (r.partyMember != null && !ctx.partyNames.contains(r.partyMember)) {
      return false;
    }
    if (r.enteredFromMap != null && ctx.enteredFromMap != r.enteredFromMap) {
      return false;
    }
    if (r.mindRead && !ctx.mindReadActive) return false;
    if (r.mindReadInactive && ctx.mindReadActive) return false;
    if (r.minEspLevel != null && ctx.maxEspLevel < r.minEspLevel!) return false;
    if (r.maxEspLevelBelow != null && ctx.maxEspLevel >= r.maxEspLevelBelow!) {
      return false;
    }
    // 원작 `if map[x,y] = 0 then ...` 같은 밟은 타일 판정.
    if (r.tileAtPlayerZero && ctx.tileAtPlayer != 0) return false;
    if (r.tileAtPlayerValue != null &&
        ctx.tileAtPlayer != r.tileAtPlayerValue) {
      return false;
    }
    if (r.moveDyNot != null && ctx.moveDy == r.moveDyNot) return false;
    if (r.allFlags.isNotEmpty &&
        !r.allFlags.every((f) => ctx.flags.contains(f))) {
      return false;
    }
    // `notAllFlags`: 나열한 플래그가 **하나도** 서 있지 않아야 한다
    // (원작 `party.etc[16] and bit2 = 0 and party.etc[5] = 0` 처럼 여러 개를
    //  동시에 본다. `every` 로 보면 하나만 서 있어도 통과해 버린다).
    if (r.notAllFlags.isNotEmpty &&
        r.notAllFlags.any((f) => ctx.flags.contains(f))) {
      return false;
    }
    // 원작 `case party.etc[10] of 3 : ...` 같은 퀘스트 단계 판정.
    for (final q in r.quests) {
      final value = ctx.questSteps[q.name] ?? 0;
      if (q.eq != null && value != q.eq) return false;
      if (q.lt != null && value >= q.lt!) return false;
      if (q.gte != null && value < q.gte!) return false;
    }
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
      excludeCoords: [
        for (final raw in json['excludeCoords'] as List<dynamic>? ?? const [])
          (x: (raw as Map<String, dynamic>)['x'] as int, y: raw['y'] as int),
      ],
      once: json['once'] == true,
      disabled: json['disabled'] == true,
      require: _parseRequire(json['require'] as Map<String, dynamic>?),
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
      // `{"message": "..."}`: the source's `message(color, s)` / `asyouwish`.
      if (m.containsKey('message')) {
        steps.add(ScriptStep(kind: 'message', text: m['message'] as String));
        matched = true;
      }
      // `{"pause": true}`: the source's `talk(..)`/`PressAnyKey` between pages.
      if (m['pause'] == true) {
        steps.add(ScriptStep(kind: 'pause'));
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
      if (m.containsKey('includeScript')) {
        steps.add(
          ScriptStep(
            kind: 'includeScript',
            includeScriptId: m['includeScript'] as String,
          ),
        );
        matched = true;
      }
      if (m.containsKey('teleport')) {
        final t = m['teleport'] as Map<String, dynamic>;
        steps.add(
          ScriptStep(
            kind: 'teleport',
            teleportMap: t['map'] as int?,
            tileX: t['x'] as int? ?? 0,
            tileY: t['y'] as int? ?? 0,
            teleportKeepX: t['keepX'] == true,
            teleportKeepY: t['keepY'] == true,
          ),
        );
        matched = true;
      }
      if (m.containsKey('block')) {
        steps.add(ScriptStep(kind: 'block', block: m['block'] == true));
        matched = true;
      }
      if (m.containsKey('torch')) {
        steps.add(ScriptStep(kind: 'torch', torchLit: m['torch'] == true));
        matched = true;
      }
      if (m.containsKey('rigelBlessing')) {
        steps.add(
          ScriptStep(
            kind: 'rigelBlessing',
            rigelBlessing: m['rigelBlessing'] == true,
          ),
        );
        matched = true;
      }
      if (m.containsKey('partyClass')) {
        steps.add(
          ScriptStep(kind: 'partyClass', partyClassId: m['partyClass'] as int),
        );
        matched = true;
      }
      if (m.containsKey('questStep')) {
        final q = m['questStep'] as Map<String, dynamic>;
        steps.add(
          ScriptStep(
            kind: 'questStep',
            questName: q['name'] as String,
            questSet: q['set'] as int?,
            questInc: q['inc'] as int?,
          ),
        );
        matched = true;
      }
      if (m.containsKey('exp')) {
        steps.add(ScriptStep(kind: 'exp', expDelta: m['exp'] as int));
        matched = true;
      }
      if (m.containsKey('randomSteps')) {
        final branches = (m['randomSteps'] as List<dynamic>)
            .map((b) => _parseSteps(b as List<dynamic>))
            .toList();
        steps.add(ScriptStep(kind: 'randomSteps', randomBranches: branches));
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
            tileIfZero: t['ifZero'] as int?,
            tileAtPlayerX: t['atPlayerX'] == true,
          ),
        );
        matched = true;
      }
      if (m.containsKey('peek')) {
        final p = m['peek'] as Map<String, dynamic>;
        steps.add(
          ScriptStep(kind: 'peek', peekX: p['x'] as int, peekY: p['y'] as int),
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
      if (m.containsKey('setTileArea')) {
        final t = m['setTileArea'] as Map<String, dynamic>;
        steps.add(
          ScriptStep(
            kind: 'setTileArea',
            teleportMap: t['map'] as int?,
            tileX: t['xMin'] as int,
            tileXMax: t['xMax'] as int?,
            tileY: t['yMin'] as int,
            tileYMax: t['yMax'] as int?,
            tileValue: t['tile'] as int,
            tileIfZero: t['ifZero'] as int?,
            tileAtPlayerX: t['atPlayerX'] == true,
            tileAtPlayerY: t['atPlayerY'] == true,
            tileOnlyIf: t['onlyIf'] as int?,
          ),
        );
        matched = true;
      }
      if (m.containsKey('setTileAtPlayer')) {
        final t = m['setTileAtPlayer'] as Map<String, dynamic>;
        steps.add(
          ScriptStep(
            kind: 'setTileAtPlayer',
            tileValue: t['tile'] as int? ?? 49,
            tileIfZero: t['ifZero'] as int?,
          ),
        );
        matched = true;
      }
      if (m.containsKey('setTileAtTarget')) {
        // 원작 `map[x+x1,y+y1] := 값` - 대화 상대(앞 칸)의 지형 변형.
        steps.add(
          ScriptStep(
            kind: 'setTileAtTarget',
            tileValue: m['setTileAtTarget'] as int,
          ),
        );
        matched = true;
      }
      if (m.containsKey('nudge')) {
        final n = m['nudge'] as Map<String, dynamic>;
        steps.add(
          ScriptStep(
            kind: 'nudge',
            nudgeDx: n['dx'] as int? ?? 0,
            nudgeDy: n['dy'] as int? ?? 0,
          ),
        );
        matched = true;
      }
      if (m['stepBack'] == true) {
        steps.add(const ScriptStep(kind: 'stepBack'));
        matched = true;
      }
      if (m.containsKey('randomFlag')) {
        steps.add(
          ScriptStep(
            kind: 'randomFlag',
            randomFlagNames: (m['randomFlag'] as List<dynamic>).cast<String>(),
          ),
        );
        matched = true;
      }
      if (m.containsKey('battle')) {
        final b = m['battle'] as Map<String, dynamic>;
        final random = b['random'] as Map<String, dynamic>?;
        steps.add(
          ScriptStep(
            kind: 'battle',
            monsters: (b['monsters'] as List<dynamic>? ?? const []).cast<int>(),
            battleTitle: b['title'] as String?,
            battleEnemyFirst: b['enemyFirst'] == true,
            battleOverrides: (b['overrides'] as List<dynamic>?)
                ?.map(
                  (o) => (o as Map<String, dynamic>).cast<String, Object?>(),
                )
                .toList(),
            battleVictoryFlags: switch (b['victoryFlag']) {
              final String s => [s],
              final List<dynamic> list => list.cast<String>(),
              _ => const <String>[],
            },
            battleEnemyDefeatFlags:
                (b['onEnemyDeadFlags'] as Map<String, dynamic>? ?? const {})
                    .map(
                      (slot, flag) => MapEntry(int.parse(slot), flag as String),
                    ),
            battleRunAwayFlagsWhenDead:
                (b['onRunAwayIfDead'] as List<dynamic>? ?? const []).map((
                  entry,
                ) {
                  final condition = entry as Map<String, dynamic>;
                  final slots = (condition['slots'] as List<dynamic>)
                      .cast<int>();
                  if (slots.isEmpty) {
                    throw const FormatException('빈 도주 격퇴 슬롯 조건');
                  }
                  return (slots: slots, flag: condition['flag'] as String);
                }).toList(),
            battleRunAwaySteps: _parseSteps(
              b['onRunAway'] as List<dynamic>? ?? const [],
            ),
            battleContinueOnRunAway: b['continueOnRunAway'] == true,
            battleRetryOnRunAway: b['retryOnRunAway'] == true,
            battleMirrorParty: b['mirrorParty'] == true,
            battleShuffle: b['shuffle'] == true,
            battleVictoryIfEnemyDead: b['victoryIfEnemyDead'] as int?,
            battleRunAwayIfEnemyAlive: b['runAwayIfEnemyAlive'] as int?,
            battleRunAwayProgressQuest:
                (b['runAwayProgress'] as Map<String, dynamic>?)?['quest']
                    as String?,
            battleRunAwayProgressTotal:
                (b['runAwayProgress'] as Map<String, dynamic>?)?['total']
                    as int?,
            randomPool: (random?['pool'] as List<dynamic>?)?.cast<int>(),
            randomMin: random?['min'] as int?,
            randomMax: random?['max'] as int?,
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
        final cancelOption = c['cancelOption'] as int?;
        if (cancelOption != null &&
            (cancelOption < 0 || cancelOption >= options.length)) {
          throw FormatException('취소 선택지 범위 오류: $cancelOption');
        }
        steps.add(
          ScriptStep(
            kind: 'choice',
            prompt: c['prompt'] as String?,
            options: options,
            cancelOptionIndex: cancelOption,
          ),
        );
        matched = true;
      }

      if (!matched) throw FormatException('알 수 없는 스크립트 스텝: $m');
    }
    return steps;
  }

  ScriptRequire _parseRequire(Map<String, dynamic>? json) {
    if (json == null) return const ScriptRequire();
    final rawQuest = json['quest'];
    final quests = <({String name, int? eq, int? lt, int? gte})>[];
    if (rawQuest is Map<String, dynamic>) {
      quests.add(_questFrom(rawQuest));
    } else if (rawQuest is List<dynamic>) {
      for (final q in rawQuest) {
        quests.add(_questFrom(q as Map<String, dynamic>));
      }
    }
    return ScriptRequire(
      flag: json['flag'] as String?,
      flagNot: json['flagNot'] as String?,
      partyMember: json['partyMember'] as String?,
      enteredFromMap: json['enteredFromMap'] as int?,
      mindRead: json['mindRead'] == true,
      mindReadInactive: json['mindReadInactive'] == true,
      minEspLevel: json['minEspLevel'] as int?,
      maxEspLevelBelow: json['maxEspLevelBelow'] as int?,
      notMindReadOrLowEsp: json['notMindReadOrLowEsp'] == true,
      tileAtPlayerZero: json['tileAtPlayerZero'] == true,
      tileAtPlayerValue: json['tileAtPlayerValue'] as int?,
      moveDyNot: json['moveDyNot'] as int?,
      quests: quests,
      allFlags: (json['allFlags'] as List<dynamic>? ?? const []).cast<String>(),
      notAllFlags: (json['notAllFlags'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }

  static ({String name, int? eq, int? lt, int? gte}) _questFrom(
    Map<String, dynamic> q,
  ) => (
    name: q['name'] as String,
    eq: q['eq'] as int?,
    lt: q['lt'] as int?,
    gte: q['gte'] as int?,
  );
}
