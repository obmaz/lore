import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_source_coordinates.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_talk_mode.dart';

import 'support/talk_mode_io.dart';

void main() {
  test(
    'at/on compare original native results at signed integer boundaries',
    () {
      final source = latin1.decode(
        File('repo_source/LORE_1993_src/LORESUB.PAS').readAsBytesSync(),
      );
      expect(
        source,
        contains(
          'if (x+x1=xx) and (y+y1=yy) then at := TRUE else at := FALSE;',
        ),
      );
      expect(
        source,
        contains('if (x=xx) and (y=yy) then on := TRUE else on := FALSE;'),
      );
      final data = jsonDecode(
        File('test/fixtures/dos_coordinates.json').readAsStringSync(),
      );
      expect(data['at'].length, 1764);
      expect(data['on'].length, 1764);
      for (final row in data['at']) {
        expect(
          LoreSourceCoordinates.at(
            row[0],
            row[1],
            row[2],
            row[3],
            row[4],
            row[5],
          ),
          row[6],
          reason: '$row',
        );
      }
      for (final row in data['on']) {
        expect(
          LoreSourceCoordinates.on(row[0], row[1], row[2], row[3]),
          row[4],
          reason: '$row',
        );
      }
    },
  );

  test(
    'at/on preserve all canonical map positions and four facing offsets',
    () {
      for (var x = 1; x <= 100; x++) {
        for (var y = 1; y <= 100; y++) {
          expect(LoreSourceCoordinates.on(x, y, x, y), isTrue);
          expect(LoreSourceCoordinates.on(x, y, x + 1, y), isFalse);
          expect(LoreSourceCoordinates.on(x, y, x, y + 1), isFalse);
          for (final (dx, dy) in [(0, -1), (1, 0), (0, 1), (-1, 0)]) {
            expect(
              LoreSourceCoordinates.at(x, y, dx, dy, x + dx, y + dy),
              isTrue,
            );
            expect(
              LoreSourceCoordinates.at(x, y, dx, dy, x + dx + 1, y + dy),
              isFalse,
            );
            expect(
              LoreSourceCoordinates.at(x, y, dx, dy, x + dx, y + dy + 1),
              isFalse,
            );
          }
        }
      }
    },
  );

  test(
    'actual talk owner uses at for each facing and wrapped adapter targets',
    () async {
      final source = latin1.decode(
        File('repo_source/LORE_1993_src/LORETALK.PAS').readAsBytesSync(),
      );
      expect(source, contains('if at(9,64) then'));
      for (final (dx, dy) in [(0, -1), (1, 0), (0, 1), (-1, 0)]) {
        for (final multiple in [-1, 0, 1]) {
          for (final miss in [0, 1]) {
            final io = TalkModeIo();
            await LoreTalkMode.run(
              mapId: 6,
              targetX: 9 + 65536 * multiple + miss,
              targetY: 64 - 65536 * multiple,
              x: 9 - dx,
              y: 64 - dy,
              party: [],
              etc: LorePartyEtc(),
              roll: (_) => throw StateError('unexpected random'),
              io: io,
            );
            expect(io.pages.length, miss == 0 ? 1 : 0);
            if (miss == 0) {
              expect(io.text, contains('Serpent 와 Insects 와 Python'));
            }
            expect(io.tiles, isEmpty);
            expect(io.recruits, isEmpty);
          }
        }
      }
    },
  );

  test('actual MENACE owner uses signed on arguments without a map clamp', () {
    for (final multiple in [-1, 0, 1]) {
      for (final x in [24, 25, 26, 27]) {
        for (final y in [7, 8, 9]) {
          final run = LoreSpecProcedures.map14(
            x + 65536 * multiple,
            y - 65536 * multiple,
            const ScriptContext(tileAtPlayer: 52, sourceEtc: {10: 3}),
            LoreScriptEngine(),
          );
          expect(run != null, (x == 25 || x == 26) && y == 8);
          if (run != null) {
            expect(run.outcome.sourceEtcWrites, isEmpty);
            expect(run.acknowledgeScene().outcome.sourceEtcWrites, [
              (index: 10, value: 4),
            ]);
          }
        }
      }
    }
  });
}
