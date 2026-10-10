import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/logic/lore_join.dart';

import 'support/native_battle_records.dart';

// LORESUB.PAS join1063/1075: full records at every byte level/cast and
// previous signed XP boundary. Unmatched CASE retains destination experience.
void main() {
  test(
    '6656 original join records and all five replacement slots match native',
    () {
      final data = jsonDecode(
        File('test/fixtures/dos_join_bounds.json').readAsStringSync(),
      );
      expect(data['cases'].length, 6656);
      for (final r in data['cases']) {
        final template = Monster(
          eNumber: 1,
          name: 'Template',
          strength: 30,
          mentality: 255,
          endurance: 255,
          resistance: 255,
          agility: 18,
          accArms: 19,
          accMagic: 20,
          ac: 7,
          special: 2,
          castLevel: r['cast'],
          specialCastLevel: 1,
          level: r['level'],
        );
        final expected = nativePlayer(List<int>.from(r['record'])).toJson();
        expect(
          PartyMember.fromMonsterTemplate(
            template,
            previousExperience: r['previousExperience'],
          ).toJson(),
          expected,
        );
        for (var option = 0; option < 5; option++) {
          final party = [
            for (var i = 0; i < 7; i++)
              PartyMember.blank()..experience = r['previousExperience'],
          ];
          final before = [for (final p in party) p.toJson()];
          LoreJoin.applyJoin(
            party,
            PartyMember.fromMonsterTemplate(template),
            option,
          );
          expect(party[option + 1].toJson(), expected);
          for (var i = 0; i < 7; i++) {
            if (i != option + 1) expect(party[i].toJson(), before[i]);
          }
        }
      }
    },
  );
}
