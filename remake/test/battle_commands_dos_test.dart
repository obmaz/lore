import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle_commands.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

// LOREBATT.PAS BattleMode manual numeric CASE and selection reset; native
// SelectEnemy/Clear stubs are explicit. BGI output and unknown storage excluded.
void main() {
  test(
    '58368 native manual command records match byte stores and cancel guards',
    () {
      final data = jsonDecode(
        File('test/fixtures/dos_battle_commands.json').readAsStringSync(),
      );
      expect(data['cases'].length, 58368);
      for (final r in data['cases']) {
        final command = LoreBattleCommands.manual(
          how: r['how'],
          result: r['k'],
          maxsum: r['maxsum'],
          target: r['target'],
          weapon: r['weapon'],
          targetUnavailable: r['flags'] != 0,
        );
        expect(command, r['command'], reason: '$r');
        expect(
          r['asked'],
          (r['how'] == 2 || r['how'] == 4)
              ? r['k'] > 1
              : r['how'] == 6 && r['k'] != 0,
        );
      }
    },
  );
  test('selection resets six how bytes only, preserving unused operands and slot zero', () {
    final source = String.fromCharCodes(
      File('repo_source/LORE_1993_src/LOREBATT.PAS').readAsBytesSync(),
    );
    expect(source, contains('for person := 1 to 6 do battle[person,1] := 0;'));
    for (var byte = 0; byte < 256; byte++) {
      final b = LoreBattle(
        party: [PartyMember.createPreset(1)],
        enemy: [Monster.create(1)],
        random: Random(1),
        print: (_, _) {},
      );
      for (var slot = 0; slot <= 6; slot++) {
        b.battle[slot] = [
          99,
          (byte + slot) & 255,
          (byte + 17 * slot) & 255,
          (byte + 31 * slot) & 255,
        ];
      }
      final expected = [
        for (var slot = 0; slot <= 6; slot++)
          [
            99,
            slot == 0 ? byte : 0,
            (byte + 17 * slot) & 255,
            (byte + 31 * slot) & 255,
          ],
      ];
      b.beginSelection();
      expect(b.battle, expected);
    }
  });
}
