import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<Map<String, dynamic>> _battles(Object? value) sync* {
  if (value is List) {
    for (final item in value) {
      yield* _battles(item);
    }
  } else if (value is Map<String, dynamic>) {
    if (value['battle'] case final Map<String, dynamic> battle) {
      yield battle;
    }
    for (final child in value.values) {
      yield* _battles(child);
    }
  }
}

void main() {
  test('활성 스크립트의 전투 선공은 원본의 네 파티 선공 지점만 예외로 둔다', () {
    // LORESPEC.PAS:1157, 1430, 1865 / LOREENT.PAS:342.
    const partyFirst = {
      'spec-17-L1010-1xx',
      'spec-17-L1010-2xx',
      'evil-seal-guardians',
      'keep2-guards-y25',
      'portal-25-26-chamber',
    };
    final scripts =
        (jsonDecode(File('assets/data/scripts.json').readAsStringSync())
                as Map<String, dynamic>)['scripts']
            as List<dynamic>;
    final seenPartyFirst = <String>{};
    var checked = 0;
    for (final raw in scripts) {
      final script = raw as Map<String, dynamic>;
      if (script['disabled'] == true) continue;
      final id = script['id'] as String;
      for (final battle in _battles(script['steps'])) {
        checked++;
        final expected = !partyFirst.contains(id);
        expect(battle['enemyFirst'] == true, expected, reason: id);
        if (!expected) seenPartyFirst.add(id);
      }
    }
    expect(checked, greaterThan(partyFirst.length));
    expect(seenPartyFirst, partyFirst);
  });
}
