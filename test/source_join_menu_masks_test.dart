import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_join.dart';
import 'package:lore/models/party_member.dart';

// ReturnJoinMember's five labels are player[2..6], not all named players.
void main() {
  test('all named masks, short party lengths and seventh-slot exclusion', () {
    final source = File('repo_source/LORE_1993_src/LORESUB.PAS')
        .readAsBytesSync();
    final ascii = String.fromCharCodes(source);
    expect(ascii, contains('for i := 2 to 6 do m[i-1] := player[i].name;'));
    expect(ascii, contains("if m[5] = '' then m[5] :="));
    for (var mask = 0; mask < 128; mask++) {
      for (var length = 0; length <= 7; length++) {
        final party = [
          for (var slot = 1; slot <= length; slot++)
            PartyMember.blank()
              ..name = (mask & (1 << (slot - 1))) != 0 ? 'Source $slot' : '',
        ];
        final expected = [
          for (var slot = 2; slot <= 6; slot++)
            slot <= length && (mask & (1 << (slot - 1))) != 0
                ? 'Source $slot'
                : '',
        ];
        if (expected[4].isEmpty) expected[4] = '보조 일원으로 둠';
        expect(LoreJoin.joinMenuLabels(party), expected);
      }
    }
  });
}
