import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_sub_text.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_view_procedures.dart';
import 'package:lore/models/party_member.dart';

/// LORESUB.PAS literals independently decoded from legacy source, not Dart.
void main() {
  test('both ReturnSex and ReturnSexData paths in all six source slots', () {
    final sex = jsonDecode(
      File('test/fixtures/source_sub_labels.json').readAsStringSync(),
    )['sex'];
    for (var person = 1; person <= 6; person++) {
      for (final gender in Gender.values) {
        final party = [for (var i = 0; i < 6; i++) PartyMember.createPreset(1)];
        party[person - 1].sex = gender;
        final branch = gender == Gender.male ? 'male' : 'else';
        final battle = LoreBattle(
          party: party,
          enemy: [],
          random: LoreRandom(1),
          print: (_, _) {},
        )..person = person;
        expect(battle.sexData, sex['ReturnSexData'][branch]);
        final header = LoreViewProcedures.characterPage1(party[person - 1])[1];
        expect(header.$1, 11);
        expect(header.$2.endsWith(sex['ReturnSex'][branch]), isTrue);
      }
    }
  });
  final data =
      jsonDecode(
            File('test/fixtures/source_sub_labels.json').readAsStringSync(),
          )['labels']
          as Map<String, dynamic>;
  test('source label cases cover every stored class/equipment byte', () {
    final readers = <String, String Function(int)>{
      'ReturnClass': LoreSubText.classLabel,
      'ReturnWeapon': LoreSubText.weaponLabel,
      'ReturnDefense': LoreSubText.defenseLabel,
      'ReturnMagic': LoreSubText.magicName,
    };
    for (final entry in readers.entries) {
      final labels = data[entry.key];
      expect(
        (labels['values'] as Map).length,
        {
          'ReturnClass': 10,
          'ReturnWeapon': 10,
          'ReturnDefense': 6,
          'ReturnMagic': 45,
        }[entry.key],
      );
      for (var value = 0; value <= 255; value++) {
        final expected = labels['values']['$value'] ?? labels['default'];
        // Pascal ReturnMagic has no default: do not invent evidence for it.
        if (expected != null) expect(entry.value(value), expected);
      }
    }
  });
  test('source grammatical set and both outputs cover all byte operands', () {
    for (final name in ['ReturnWeapon', 'ReturnMagic']) {
      final row = data[name];
      for (var value = 0; value <= 255; value++) {
        final outputs =
            row[(row['membership'] as List).contains(value) ? 'then' : 'else'];
        expect(
          name == 'ReturnWeapon'
              ? LoreSubText.weaponJosa(value)
              : LoreSubText.magicJosa(value),
          outputs['Josa'],
        );
        if (name == 'ReturnMagic') {
          expect(LoreSubText.magicMokjuk(value), outputs['Mokjuk']);
        }
      }
    }
  });
}
