import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_creation_name.dart';

// LORECRET.PAS Name: original counters, string operations and sex stores.
void main() {
  test(
    '8704 native name transitions include all byte keys/scans at each length',
    () {
      final data = jsonDecode(
        File('test/fixtures/dos_creation_name.json').readAsStringSync(),
      );
      expect(data['cases'].length, 8704);
      for (final row in data['cases']) {
        final name = LoreCreationName(text: 'A' * (row['length'] as int));
        name.readKey(row['key'], scan: row['scan']);
        expect(name.text.codeUnits, row['text'], reason: '$row');
        expect(name.counter, row['counter']);
        expect(name.nameAccepted, row['complete']);
        expect(row['reads'], row['key'] == 0 ? 2 : 1);
      }
      for (final row in data['gender']) {
        final name = LoreCreationName(text: 'A')
          ..readKey(13)
          ..readKey(row['key']);
        expect(name.sex, row['sex'], reason: '$row');
        expect(name.sex != null, row['complete']);
      }
    },
  );
}
