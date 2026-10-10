import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_main_procedures.dart';
import 'package:lore/models/party_member.dart';

/// LORESUB.PAS:547-556 DetectGameOver's six-slot loop and Exist predicate.
/// GameOver pixels are bypassed by native extraction, not claimed here.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_detect_game_over.json').readAsStringSync(),
  );
  Future<void> check(dynamic row) async {
    final party = [
      for (final r in row['records'])
        PartyMember.zero()
          ..name = r['name']
          ..hp = r['hp']
          ..unconscious = r['unconscious']
          ..dead = r['dead'],
      PartyMember.zero()
        ..name = 'Seventh'
        ..hp = 1,
    ];
    final before = jsonEncode([for (final p in party) p.toJson()]);
    final complete = Completer<void>();
    final calls = <int>[];
    var etc6 = row['etc6'] as int;
    var returned = false;
    final pending = LoreMainProcedures.detectGameOver(party, () {
      // The screen's _detectedGameOver stores etc[6] before presenting the UI.
      etc6 = 255;
      calls.add(etc6);
      return complete.future;
    }).then((_) => returned = true);
    await Future<void>.delayed(Duration.zero);
    expect(calls, row['calls']);
    expect(etc6, row['afterEtc6']);
    expect(returned, calls.isEmpty);
    expect(jsonEncode([for (final p in party) p.toJson()]), before);
    complete.complete();
    await pending;
    expect(returned, isTrue);
  }

  test('all six-slot masks ignore active seventh slot and await native game-over callback', () async {
    for (final row in fixture['masks']) {
      await check(row);
    }
  });
  test(
    'all names and signed status/HP predicate boundaries execute in every slot',
    () async {
      for (final row in fixture['predicates']) {
        await check(row);
      }
    },
  );
}
