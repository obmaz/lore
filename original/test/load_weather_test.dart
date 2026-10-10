import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_load_weather.dart';
import 'package:lore/logic/lore_source_memory.dart';

void main() {
  test(
    'Load normalizes every byte without changing other party etc fields',
    () {
      // Derive the valid selectors independently from the original CASE.
      final source = File('repo_source/LORE_1993_src/LORESUB.PAS')
          .readAsBytesSync();
      final text = String.fromCharCodes(source);
      final start = text.indexOf('case party.etc[12] of');
      final block = text.substring(start, text.indexOf('end;', start));
      final valid = RegExp(r'(\d+)\s*:\s*setscrolltype\(')
          .allMatches(block)
          .map((m) => int.parse(m[1]!))
          .toSet();
      expect(valid, {1, 2, 3, 4, 5});
      expect(block, contains('else setscrolltype(normal)'));
      expect(text, contains('party.etc[12] := 0;'));
      for (var raw = 0; raw < 256; raw++) {
        final etc = LorePartyEtc();
        for (var i = 1; i <= 40; i++) {
          etc[i] = i;
        }
        etc[12] = raw;
        final before = Map<int, int>.from(etc);
        LoreLoadWeather.normalize(etc);
        expect(etc.read(12), valid.contains(raw) ? raw : 0);
        for (final entry in before.entries) {
          if (entry.key != 12) expect(etc.read(entry.key), entry.value);
        }
        final once = Map<int, int>.from(etc);
        LoreLoadWeather.normalize(etc);
        expect(etc, once);
      }
    },
  );
}
