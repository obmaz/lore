import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';

/// LORESPEC.PAS의 일회성 금화 발견 분기를 원본 수치로 재생한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('맵 9·14 금화 11곳은 첫 방문에만 원본 금액을 지급한다', () async {
    final data = jsonDecode(
      File('test/fixtures/source_gold_replay.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final engine = LoreScriptEngine();
    engine.loadFromJson(await rootBundle.loadString('assets/data/scripts.json'));
    for (final raw in data['cases'] as List<dynamic>) {
      final item = raw as Map<String, dynamic>;
      final flag = item['flag'] as String;
      final collected = item['collected'] as bool;
      final run = engine.startStep(
        item['map'] as int,
        item['x'] as int,
        item['y'] as int,
        ScriptContext(flags: {if (collected) flag}),
      );
      final actualGold = run?.outcome.goldDelta ?? 0;
      expect(actualGold, item['gold'], reason: 'LORESPEC.PAS:${item['line']}');
      if (!collected) {
        expect(run, isNotNull, reason: 'LORESPEC.PAS:${item['line']}');
        expect(run!.outcome.setFlags, contains(flag));
      } else {
        expect(run?.outcome.setFlags ?? const <String>[], isNot(contains(flag)));
      }
    }
  });
}
