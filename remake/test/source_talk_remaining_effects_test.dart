import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_talk_mode.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/models/party_member.dart';

import 'support/talk_mode_io.dart';

// LORETALK.PAS reward loops/map strips/early-return. Pascal input is independent
// of executable runtime JSON and the Dart script/procedure definitions.
void main() {
  final lines = latin1
      .decode(File('repo_source/LORE_1993_src/LORETALK.PAS').readAsBytesSync())
      .split('\n');
  Future<void> run(
    int map,
    int x,
    int y,
    List<PartyMember> party,
    LorePartyEtc etc,
    TalkModeIo io,
  ) => LoreTalkMode.run(
    mapId: map,
    targetX: x,
    targetY: y,
    x: 5,
    y: 5,
    party: party,
    etc: etc,
    roll: (_) => 0,
    io: io,
  );
  test(
    'all reward loops, all named masks, signed XP and wait-side stores',
    () async {
      for (final (map, x, y, index, stage, line, before, questBefore) in [
        (6, 51, 28, 10, 4, 365, true, true),
        (7, 38, 17, 13, 2, 465, false, false),
        (9, 42, 25, 14, 2, 543, true, false),
        (9, 42, 25, 14, 5, 569, true, false),
        (10, 25, 18, 15, 2, 682, true, false),
        (10, 25, 18, 15, 4, 712, true, false),
      ]) {
        // Find the exact six-slot source loop by its reward amount/quest stage;
        // the final two are located from the source, not guessed line offsets.
        final expectedAmount = map == 6
            ? 1000
            : map == 7
            ? 10000
            : map == 9
            ? (stage == 2 ? 10000 : 40000)
            : stage == 2
            ? 150000
            : 300000;
        final pattern = RegExp(
          r"for i := 1 to 6 do if player\[i\]\.name <> '' then\s*player\[i\]\.experience := player\[i\]\.experience \+ (\d+);",
        );
        final loops = pattern
            .allMatches(lines.join('\n'))
            .where((m) => int.parse(m.group(1)!) == expectedAmount)
            .toList();
        expect(
          loops,
          isNotEmpty,
          reason: 'source reward $expectedAmount at $line',
        );
        final amount = int.parse(loops.first.group(1)!);
        for (var mask = 0; mask < 64; mask++) {
          const initial = [2147483647, -2147483648, -1, 0, 1, 2147483548, 77];
          final party = [
            for (var i = 0; i < 7; i++)
              PartyMember.createPreset(1)
                ..name = i == 6
                    ? 'Outside'
                    : (mask & (1 << i)) == 0
                    ? ''
                    : 'Slot$i'
                ..experience = initial[i]
                ..dead = i % 2
                ..unconscious = i % 3,
          ];
          final snapshot = [for (final p in party) p.toJson()];
          final etc = LorePartyEtc()..[index] = stage;
          final io = TalkModeIo();
          int result(int i) => i == 6 || (mask & (1 << i)) == 0
              ? initial[i]
              : (BigInt.from(initial[i]) + BigInt.from(amount))
                    .toSigned(32)
                    .toInt();
          io.beforeWait = () {
            expect(
              [for (var i = 0; i < 7; i++) party[i].experience],
              [for (var i = 0; i < 7; i++) before ? result(i) : initial[i]],
            );
            expect(etc.read(index), stage + (questBefore ? 1 : 0));
          };
          await run(map, x, y, party, etc, io);
          expect(
            [for (final p in party) p.toJson()],
            [
              for (var i = 0; i < 7; i++)
                {...snapshot[i], 'experience': result(i)},
            ],
          );
          expect(etc.read(index), stage + 1);
        }
      }
    },
  );
  test(
    'source tile strip loops every flag byte and mutation after wait',
    () async {
      expect(lines[125], contains('for i := 79 to 81 do  map[62,i] := 44;'));
      expect(lines[286], contains('for i := 49 to 53 do map[i,88] := 44;'));
      for (var flag = 0; flag < 256; flag++) {
        final party = [PartyMember.createPreset(1)];
        final secret = LorePartyEtc()..[50] = flag;
        final io = TalkModeIo()..beforeWait = () {};
        io.beforeWait = () => expect(io.tiles, isEmpty);
        await run(6, 63, 76, party, secret, io);
        expect(
          io.tiles,
          (flag & 1) != 0
              ? <Object>[]
              : [
                  (62, 79, 44),
                  (62, 80, 44),
                  (62, 81, 44),
                  (62, 82, 0),
                  (62, 83, 14),
                ],
        );
        expect(secret.read(50), flag | 1);
        final gate = LorePartyEtc()..[30] = flag;
        final gateIo = TalkModeIo();
        await run(6, 51, 87, party, gate, gateIo);
        expect(
          gateIo.tiles,
          (flag & 2) != 0
              ? <Object>[]
              : [for (var x = 49; x <= 53; x++) (x, 88, 44)],
        );
        expect(gate.read(30), flag | 2);
      }
    },
  );
  test(
    'parchment source Select <> 1 exits without acknowledgement or tile write',
    () async {
      expect(
        lines[1022],
        contains('select(125,2,2,FALSE,TRUE) <> 1 then exit'),
      );
      for (final choice in [0, 1, 2, 255]) {
        final party = [PartyMember.createPreset(1)];
        final before = party.first.toJson();
        final etc = LorePartyEtc();
        final io = TalkModeIo()..choice = choice;
        await run(27, 21, 12, party, etc, io);
        expect(io.tiles, choice == 1 ? [(21, 12, 35)] : <Object>[]);
        expect(io.pages.length, choice == 1 ? 2 : 1);
        expect(party.first.toJson(), before);
      }
    },
  );
}
