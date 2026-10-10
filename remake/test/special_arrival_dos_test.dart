import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_special_arrival.dart';

// LORESPEC.PAS:2015-2030,2120-2153; original EXE platform-call traces.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_special_arrival.json').readAsStringSync(),
  );
  for (final item in fixture['cases']) {
    test('${item['kind']} ${item['x']},${item['y']} salt ${item['salt']}', () {
      final int x = item['x'], y = item['y'], salt = item['salt'];
      final ops = item['kind'] == 'guardian'
          ? LoreSpecialArrival.guardian(x, y)
          : LoreSpecialArrival.finalActors(x, y);
      final trace = [
        for (final op in ops)
          if (op.kind == 'delay')
            ['delay', op.index]
          else if (op.kind == 'tile')
            [
              'draw',
              'font',
              op.x,
              op.y,
              (op.index * 17 + op.operation * 13 + salt) % 56,
              0,
            ]
          else
            ['draw', 'chara', op.x, op.y, op.index, op.operation],
      ];
      expect(trace, item['trace']);
    });
  }
}
