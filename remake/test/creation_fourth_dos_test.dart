import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_creation.dart';
import 'package:lore/models/party_member.dart';

import 'support/native_battle_records.dart';

// LORECRET.PAS Fourth data continuations, not original keyboard/BGI timing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native Fourth every four-companion set and every class/accuracy byte', () async {
    await LoreCreationData.instance.load(force: true);
    final data = jsonDecode(
      File('test/fixtures/dos_creation_fourth.json').readAsStringSync(),
    );
    expect(data['cases'].length, 3026);
    for (final row in data['cases']) {
      final hero = nativePlayer(List<int>.from(row['beforeHero']));
      final members = [
        hero,
        for (final id in row['selected'])
          LoreCreationData.instance.characters
              .firstWhere((c) => c.id == id)
              .toMember(),
      ];
      for (final m in members) {
        m.applyCreationInit();
      }
      members.add(PartyMember.zero());
      expect(
        [for (final m in members) m.toJson()],
        [
          for (final r in row['afterParty'])
            nativePlayer(List<int>.from(r)).toJson(),
        ],
        reason:
            'selected=${row['selected']} class=${row['classId']} accuracy=${row['accuracy']}',
      );
    }
  });
}
