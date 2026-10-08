import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_remains_blink.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/logic/lore_talk_mode.dart';
import 'package:lore/models/party_member.dart';

import 'support/talk_mode_io.dart';

/// LORETALK.PAS:827,873,909,960,1009,1038,1050: complete blink loops.
void main() {
  test(
    'seven native loops match every delay, image argument and final store',
    () async {
      final data = jsonDecode(
        File('test/fixtures/dos_remains_blink.json').readAsStringSync(),
      );
      expect(data['cases'].length, 98);
      for (final row in data['cases']) {
        final trace = <List<Object>>[];
        final frames = LoreRemainsBlink.frames(row['dx'], row['dy']).toList();
        expect(frames.length, 60);
        for (final frame in frames) {
          trace.add(['delay', frame.waitMilliseconds]);
          trace.add(['draw', frame.x, frame.y, frame.tile, 0]);
        }
        trace.add(['write', 35]);
        expect(trace, row['trace'], reason: 'source line ${row['line']}');
        expect(frames.fold(0, (sum, f) => sum + f.waitMilliseconds), 1860);
        final target = row['target'];
        final io = TalkModeIo();
        io.beforeWait = () => expect(io.tiles, isEmpty);
        io.beforeBlink = () => expect(io.tiles, isEmpty);
        await LoreTalkMode.run(
          mapId: 27,
          targetX: target[0],
          targetY: target[1],
          x: LorePascal.integer(target[0] - row['dx']),
          y: LorePascal.integer(target[1] - row['dy']),
          party: [PartyMember.createPreset(1)],
          etc: LorePartyEtc(),
          roll: (_) => throw StateError('remains must not consume RNG'),
          io: io,
        );
        expect(io.blinks.length, 1);
        expect(
          [
            for (final frame in io.blinks.single)
              [frame.waitMilliseconds, frame.x, frame.y, frame.tile],
          ],
          [
            for (final frame in frames)
              [frame.waitMilliseconds, frame.x, frame.y, frame.tile],
          ],
        );
        expect(io.tiles, [(target[0], target[1], 35)]);
      }
    },
  );

  test(
    'declined parchment and closed acknowledgement do not animate or write',
    () async {
      for (final choice in [0, 2]) {
        final io = TalkModeIo()..choice = choice;
        await LoreTalkMode.run(
          mapId: 27,
          targetX: 21,
          targetY: 12,
          x: 21,
          y: 11,
          party: [PartyMember.createPreset(1)],
          etc: LorePartyEtc(),
          roll: (_) => throw StateError('RNG'),
          io: io,
        );
        expect(io.blinks, isEmpty);
        expect(io.tiles, isEmpty);
      }
      final io = TalkModeIo();
      io.afterWait = () => io.open = false;
      await LoreTalkMode.run(
        mapId: 27,
        targetX: 10,
        targetY: 14,
        x: 10,
        y: 13,
        party: [PartyMember.createPreset(1)],
        etc: LorePartyEtc(),
        roll: (_) => throw StateError('RNG'),
        io: io,
      );
      expect(io.blinks, isEmpty);
      expect(io.tiles, isEmpty);
    },
  );
}
