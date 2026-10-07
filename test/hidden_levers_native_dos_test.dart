import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/script_world_reducer.dart';

void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_hidden_levers_continuation.json')
        .readAsStringSync(),
  );
  List<int> bytes(String tag) {
    final hex = f['saves'][tag]['files']['SAVE1.MAP']['hex'] as String;
    return [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
  }

  for (final spec in [
    ('healthy', 'leftCorridor', 15, 34, false),
    ('leftLever', 'rightCorridor', 36, 34, true),
    ('rightCorridor', 'leversOpen', 46, 34, true),
  ]) {
    test('native ${spec.$2} matches every saved tile', () {
      final raw = bytes(spec.$1), w = raw[0], h = raw[1];
      final grid = [
        for (var y = 0; y < h; y++) raw.sublist(2 + y * w, 2 + (y + 1) * w),
      ];
      final run = LoreSpecProcedures.map25(
        spec.$3,
        spec.$4,
        ScriptContext(tileAtPlayer: 0, flags: spec.$5 ? {'etc45_bit7'} : {}),
        LoreScriptEngine(),
      )!;
      final result = ScriptWorldReducer.applyMap(
        ScriptMapState(
          mapId: 25,
          x: spec.$3,
          y: spec.$4,
          direction: 1,
          grid: grid,
        ),
        run.outcome,
      );
      expect([w, h, ...result.grid.expand((r) => r)], bytes(spec.$2));
      if (spec.$2 == 'leversOpen') {
        expect(run.hasPendingScene, isTrue);
        expect(run.outcome.setFlags, contains('etc45_bit8'));
      }
    });
  }
}
