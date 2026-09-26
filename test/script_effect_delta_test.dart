import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';

void main() {
  test('선택 이후 같은 값의 일회성 효과도 새 구간에서 다시 전달한다', () {
    final effects = [
      {
        'teleport': {'map': 4, 'x': 20, 'y': 30},
      },
      {'setTileAtTarget': 47},
      {'partyClass': 10},
      {'torch': true},
      {'rigelBlessing': true},
      {'stepBack': true},
      {'block': true},
    ];
    final engine = LoreScriptEngine()
      ..loadFromJson(
        jsonEncode({
          'scripts': [
            {
              'id': 'repeat-effects',
              'map': 1,
              'x': 10,
              'y': 10,
              'steps': [
                ...effects,
                {
                  'choice': {
                    'prompt': '계속',
                    'options': [
                      {'text': '예', 'steps': effects},
                    ],
                  },
                },
              ],
            },
          ],
        }),
      );

    final before = engine.startStep(1, 10, 10, const ScriptContext())!;
    expect(before.hasPendingChoice, isTrue);
    final continued = before.choose(0);
    final delta = continued.outcome.since(before.outcome);

    expect((delta.teleportMap, delta.teleportX, delta.teleportY), (4, 20, 30));
    expect(delta.tileAtTarget, 47);
    expect(delta.partyClassId, 10);
    expect(delta.torchLit, isTrue);
    expect(delta.rigelBlessing, isTrue);
    expect(delta.stepBack, isTrue);
    expect(delta.blockMove, isTrue);
    expect(delta.goldDelta, 0);
  });

  test('전투 승리 후 같은 목적지로 다시 이동하는 효과도 유지한다', () {
    final engine = LoreScriptEngine()
      ..loadFromJson(
        jsonEncode({
          'scripts': [
            {
              'id': 'battle-repeat',
              'map': 1,
              'x': 11,
              'y': 11,
              'steps': [
                {
                  'teleport': {'map': 4, 'x': 20, 'y': 30},
                },
                {
                  'battle': {
                    'monsters': [1],
                  },
                },
                {
                  'teleport': {'map': 4, 'x': 20, 'y': 30},
                },
              ],
            },
          ],
        }),
      );
    final battle = engine.startStep(1, 11, 11, const ScriptContext())!;
    expect(battle.awaitingBattle, isTrue);
    final afterVictory = battle.continueAfterBattle();
    final delta = afterVictory.outcome.since(battle.outcome);
    expect((delta.teleportMap, delta.teleportX, delta.teleportY), (4, 20, 30));
  });
}
