import 'support/legacy_json_fixture_engine.dart';

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';

void main() {
  final rules = jsonEncode({
    'scripts': [
      {
        'id': 'choice',
        'map': 1,
        'x': 2,
        'y': 3,
        'once': true,
        'steps': [
          {
            'choice': {
              'prompt': '선택',
              'options': [
                {
                  'text': '진행',
                  'steps': [
                    {'flag': 'selected'},
                  ],
                },
              ],
            },
          },
        ],
      },
      {
        'id': 'battle',
        'map': 1,
        'x': 4,
        'y': 5,
        'once': true,
        'steps': [
          {
            'battle': {
              'monsters': [1],
            },
          },
          {'flag': 'won'},
        ],
      },
      {
        'id': 'random',
        'map': 1,
        'x': 6,
        'y': 7,
        'steps': [
          {
            'randomFlag': ['north', 'south', 'east'],
          },
          {
            'battle': {
              'monsters': [],
              'random': {
                'pool': [1, 2],
                'min': 2,
                'max': 3,
              },
            },
          },
        ],
      },
    ],
  });

  test('선택지와 전투 후속 처리는 시작한 엔진의 상태만 바꾼다', () {
    final first = LegacyJsonFixtureEngine()..loadFromJson(rules);
    final second = LegacyJsonFixtureEngine()..loadFromJson(rules);

    final choice = first.startStep(1, 2, 3, const ScriptContext())!;
    expect(choice.choose(0).outcome.setFlags, contains('selected'));
    expect(first.consumedScripts, contains('choice'));
    expect(second.consumedScripts, isEmpty);
    expect(second.startStep(1, 2, 3, const ScriptContext()), isNotNull);

    final battle = first.startStep(1, 4, 5, const ScriptContext())!;
    expect(battle.continueAfterBattle().outcome.setFlags, contains('won'));
    expect(first.consumedScripts, contains('battle'));
    expect(second.consumedScripts, isNot(contains('battle')));
    expect(second.startStep(1, 4, 5, const ScriptContext()), isNotNull);
  });

  test('같은 시드와 규칙은 같은 난수 분기를 재현한다', () {
    final first = LegacyJsonFixtureEngine(random: Random(1993))
      ..loadFromJson(rules);
    final second = LegacyJsonFixtureEngine(random: Random(1993))
      ..loadFromJson(rules);

    for (var i = 0; i < 10; i++) {
      final a = first.startStep(1, 6, 7, const ScriptContext())!.outcome;
      final b = second.startStep(1, 6, 7, const ScriptContext())!.outcome;
      expect(a.setFlags, b.setFlags);
      expect(a.battleMonsters, b.battleMonsters);
    }
  });

  test('한 번 파싱한 규칙에서 만든 세션은 난수와 1회성 이력을 격리한다', () {
    final catalog = LegacyJsonFixtureEngine()..loadFromJson(rules);
    final first = catalog.fork(random: Random(1993));
    final second = catalog.fork(random: Random(1993));
    first.startStep(1, 2, 3, const ScriptContext())!.choose(0);
    expect(first.consumedScripts, contains('choice'));
    expect(second.consumedScripts, isEmpty);
    expect(catalog.consumedScripts, isEmpty);
    for (var i = 0; i < 5; i++) {
      final a = first.startStep(1, 6, 7, const ScriptContext())!.outcome;
      final b = second.startStep(1, 6, 7, const ScriptContext())!.outcome;
      expect(a.setFlags, b.setFlags);
      expect(a.battleMonsters, b.battleMonsters);
    }
  });

  test('기존 JSON NPC를 주입해도 원본에 없는 대화는 실행되지 않는다', () {
    final scripts = LegacyJsonFixtureEngine()
      ..loadFromJson(
        jsonEncode({
          'scripts': [
            {
              'id': 'session-talk',
              'trigger': 'talk',
              'map': 8,
              'x': 7,
              'y': 6,
              'steps': [
                {'say': 'session'},
              ],
            },
          ],
        }),
      );
    final grid = List.generate(20, (_) => List.filled(20, 42));
    grid[5][6] = 48;
    final map = LoreMapData(
      name: 'TEST',
      category: 'town',
      xmax: 20,
      ymax: 20,
      grid: grid,
    );
    var called = false;
    final game = LoreGame(
      initialMapId: 8, // a map without a direct talk procedure
      initialPlayerX: 6,
      initialPlayerY: 6,
      scriptEngine: scripts,
      scriptContextProvider: () => const ScriptContext(),
      onTalkProcedure: (_, _, _) => called = true,
    )..currentMap = map;
    expect(game.tryMove(1, 0), isFalse);
    expect(called, isFalse); // JSON injection has no runtime owner.
  });
}
