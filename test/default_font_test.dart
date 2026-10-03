import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_tile_protocol.dart';

/// LORESUB.PAS `ReturnDefaultFont`: the font slot `Load` copies into slot 0.
void main() {
  test('defaultFontSlot equals every case of the Pascal function', () {
    final source = File('repo_source/LORE_1993_src/LORESUB.PAS')
        .readAsStringSync(encoding: latin1);
    final start = source.indexOf(
      'Function ReturnDefaultFont(font : integer) : integer;\r\nbegin',
    );
    final alt = source.indexOf(
      'Function ReturnDefaultFont(font : integer) : integer;\nbegin',
    );
    final from = start >= 0 ? start : alt;
    expect(from, greaterThan(0));
    final body = source.substring(from, source.indexOf('end;', from + 200));
    final cases = RegExp(r'(\d+) : ReturnDefaultFont := (\d+)')
        .allMatches(body)
        .map((m) => (int.parse(m[1]!), int.parse(m[2]!)))
        .toList();
    expect(cases.length, 27);
    for (final (map, slot) in cases) {
      expect(LoreTileProtocol.defaultFontSlot(map), slot, reason: 'map $map');
    }
  });

  test('a special cell is not drawn from the solid black slot 0 of the files', () {
    for (var map = 1; map <= 27; map++) {
      final slot = LoreTileProtocol.defaultFontSlot(map);
      // Slot 0 itself is only the default on maps 2, 3, 5 and 12 (the source).
      expect(slot == 0, const {2, 3, 5, 12}.contains(map), reason: 'map $map');
    }
  });
}
