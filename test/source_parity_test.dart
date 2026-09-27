import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';

/// 원본의 선택된 분기를 사람이 명세로 옮긴 뒤, 엔진 경계의 효과를 비교한다.
/// 좌표만 대조하는 감사와 달리 전투 후속 단계까지 같은 입력으로 재생한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manifest = jsonDecode(
    File('test/fixtures/source_parity.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final sources = manifest['sources'] as Map<String, dynamic>;
  final scenarios = manifest['scenarios'] as List<dynamic>;

  test('원본 근거가 현재 소스의 지정된 줄에 남아 있다', () {
    expect(manifest['version'], 1);
    expect(scenarios, isNotEmpty);
    for (final entry in sources.entries) {
      final source = entry.value as Map<String, dynamic>;
      final lines = (source['lines'] as List<dynamic>).cast<int>();
      final file = File(
        'repo_source/LORE_1993_src/${source['file'] as String}',
      );
      final rawLines = latin1.decode(file.readAsBytesSync()).split('\n');
      expect(lines[0], greaterThan(0), reason: entry.key);
      expect(lines[1], lessThanOrEqualTo(rawLines.length), reason: entry.key);
      final excerpt = rawLines.sublist(lines[0] - 1, lines[1]).join('\n');
      for (final evidence in source['evidence'] as List<dynamic>) {
        expect(excerpt, contains(evidence), reason: entry.key);
      }
    }
  });

  for (final raw in scenarios) {
    final scenario = raw as Map<String, dynamic>;
    test('원본 분기: ${scenario['id']}', () async {
      expect(sources, contains(scenario['source']));
      final engine = LoreScriptEngine();
      engine.loadFromJson(
        await rootBundle.loadString('assets/data/scripts.json'),
      );
      final input = scenario['input'] as Map<String, dynamic>;
      final context = ScriptContext(
        flags: (input['flags'] as List<dynamic>? ?? const [])
            .cast<String>()
            .toSet(),
        tileAtPlayer: input['tileAtPlayer'] as int?,
      );
      final firstRun = engine.startStep(
        input['map'] as int,
        input['x'] as int,
        input['y'] as int,
        context,
      );
      expect(firstRun?.script.id, scenario['selected'], reason: scenario['id']);

      final trace = scenario['trace'] as List<dynamic>;
      if (firstRun == null) {
        expect(trace, isEmpty);
        return;
      }
      var run = firstRun;
      for (var index = 0; index < trace.length; index++) {
        final checkpoint = trace[index] as Map<String, dynamic>;
        final action = checkpoint['action'] as String;
        ScriptOutcome delta;
        if (index == 0) {
          expect(action, 'start');
          delta = run.outcome;
        } else {
          final previous = run.outcome;
          run = switch (action) {
            'victory' => run.continueAfterBattle(),
            'retreat' => run.continueAfterRunAway(
              defeatedEnemySlots:
                  (checkpoint['defeated'] as List<dynamic>? ?? const [])
                      .cast<int>()
                      .toSet(),
            ),
            _ => throw FormatException('지원하지 않는 시나리오 행동: $action'),
          };
          delta = run.outcome.since(previous);
        }
        final expected = <String, Object?>{
          'battle': <int>[],
          'flags': <String>[],
          'torch': false,
          'nudges': <List<int>>[],
          'teleport': null,
          'tiles': <List<int?>>[],
          'areas': <List<Object?>>[],
          'playerTiles': <List<int?>>[],
          'blocked': false,
          'awaitingBattle': false,
          ...(checkpoint['expect'] as Map<String, dynamic>),
        };
        expect(
          _effects(run, delta),
          expected,
          reason: '${scenario['id']} / $action #$index',
        );
      }
    });
  }
}

Map<String, Object?> _effects(ScriptRun run, ScriptOutcome delta) => {
  'battle': delta.battleMonsters,
  'flags': delta.setFlags,
  'torch': delta.torchLit,
  'nudges': [
    for (final nudge in delta.nudges) [nudge.dx, nudge.dy],
  ],
  'teleport': delta.teleportMap == null
      ? null
      : [delta.teleportMap, delta.teleportX, delta.teleportY],
  'tiles': [
    for (final tile in delta.tileChanges)
      [tile.map, tile.x, tile.y, tile.tile, tile.ifZero],
  ],
  'areas': [
    for (final area in delta.tileAreas)
      [
        area.map,
        area.xMin,
        area.xMax,
        area.yMin,
        area.yMax,
        area.tile,
        area.atPlayerX,
        area.atPlayerY,
      ],
  ],
  'playerTiles': [
    for (final tile in delta.playerTiles) [tile.tile, tile.ifZero],
  ],
  'blocked': delta.blockMove,
  'awaitingBattle': run.awaitingBattle,
};
