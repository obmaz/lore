import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_creation_companions.dart';

// LORECRET.PAS Fourth source keyboard/count states; actual Profile UI is separate.
void main() {
  test(
    'native all cursor/key bytes, every valid flag mask and choice outcome',
    () {
      final data = jsonDecode(
        File('test/fixtures/dos_companion_selection.json').readAsStringSync(),
      );
      expect(LoreCreationCompanions().flags.skip(1).toList(), data['initial']);
      for (final r in data['cases']) {
        final state = LoreCreationCompanions(
          selected: {
            for (var i = 0; i < 10; i++)
              if ((r['mask'] & (1 << i)) != 0) i + 1,
          },
          cursor: r['cursor'],
          choosing: r['pending'],
        );
        final action = state.readKey(r['key'], scan: r['scan']);
        expect(state.selected, {
          for (var i = 0; i < 10; i++)
            if ((r['afterMask'] & (1 << i)) != 0) i + 1,
        }, reason: '$r');
        expect(state.cursor, r['afterCursor'], reason: '$r');
        expect(state.choosing, r['afterPending'], reason: '$r');
        expect(state.complete, r['complete'], reason: '$r');
        expect(
          action == LoreCompanionInput.profile ? [state.cursor] : <int>[],
          r['profiles'],
          reason: '$r',
        );
      }
    },
  );
  test('touch join shares flags; duplicate/full joins ignored and review gate exact', () {
    for (var mask = 0; mask < 1024; mask++) {
      final selected = {
        for (var i = 0; i < 10; i++)
          if ((mask & (1 << i)) != 0) i + 1,
      };
      if (selected.length > 4) continue;
      for (var id = 1; id <= 10; id++) {
        final state = LoreCreationCompanions(selected: selected)
          ..join(id)
          ..join(id);
        expect(
          state.selected,
          selected.length == 4 ? selected : {...selected, id},
        );
      }
      if (selected.length == 4) {
        for (var key = 0; key < 256; key++) {
          final state = LoreCreationCompanions(selected: selected);
          expect(
            state.readKey(key),
            key == 27 ? LoreCompanionInput.restart : LoreCompanionInput.finish,
          );
          expect(state.selected, selected);
        }
      }
    }
  });
}
