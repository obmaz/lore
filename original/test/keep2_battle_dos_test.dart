import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';

import 'wivern_battle_dos_test.dart' show enemyRecord;

void main() {
  // LOREBATT.PAS BattleMode; LORESPEC.PAS:1840-1865, actual original phases.
  final f = jsonDecode(
    File('test/fixtures/dos_keep2_continuation.json').readAsStringSync(),
  );
  final inputs = [
    for (final s in f['segments'])
      for (final b in s['trace'])
        if (b.containsKey('input')) b['input'],
  ];
  dynamic row(int n) =>
      inputs.singleWhere((r) => r['capture'] == 'lore_$n.png');
  LoreBattle start(dynamic s, LoreRandom random) => LoreBattle(
    party: [
      for (final p in s['records'])
        PartyMember.fromJson(Map<String, dynamic>.from(p)),
    ],
    enemy: [for (final e in s['enemyRecords']) Monster.create(e['eNumber'])],
    random: random,
    print: (_, _) {},
  );
  void check(LoreBattle b, LoreRandom r, dynamic s) {
    expect(r.seed, s['seed']);
    expect(b.party.map((p) => p.toJson()).toList(), s['records']);
    expect(b.enemy.map(enemyRecord).toList(), s['enemyRecords']);
  }

  test(
    'native Death Knight enemy-first phase preserves every record and RNG',
    () {
      final s = row(16380)['after'];
      final r = LoreRandom(s['seed']);
      final b = start(s, r);
      b.enemyPhase();
      check(b, r, row(16399)['before']);
    },
  );
  test('native KEEP2 ally-first PowerDown, Wave and next enemy phase preserve all fields', () {
    final s = row(16595)['after'];
    final r = LoreRandom(s['seed']);
    final b = start(s, r);
    final commands = row(16627)['after']['commands'];
    for (var i = 1; i <= 6; i++) {
      b.battle[i] = [0, ...List<int>.from(commands[i - 1])];
    }
    for (var i = 1; i <= 6; i++) {
      if (b.exist(i)) b.executePerson(i);
    }
    final closed = inputs.firstWhere(
      (v) =>
          v['after']['live']['person'] == 6 && v['after']['seed'] == 2727528370,
    )['after'];
    check(b, r, closed);
    b.enemyPhase();
    check(b, r, row(16649)['before']);
  });
}
