import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';

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
    final first = LoreScriptEngine()..loadFromJson(rules);
    final second = LoreScriptEngine()..loadFromJson(rules);

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
    final first = LoreScriptEngine(random: Random(1993))..loadFromJson(rules);
    final second = LoreScriptEngine(random: Random(1993))..loadFromJson(rules);

    for (var i = 0; i < 10; i++) {
      final a = first.startStep(1, 6, 7, const ScriptContext())!.outcome;
      final b = second.startStep(1, 6, 7, const ScriptContext())!.outcome;
      expect(a.setFlags, b.setFlags);
      expect(a.battleMonsters, b.battleMonsters);
    }
  });
}
