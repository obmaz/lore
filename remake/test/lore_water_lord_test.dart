import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/logic/lore_water_lord.dart';
import 'package:lore/models/party_member.dart';

// LORETALK.PAS:640-704, including the two six-slot experience loops.
class Window implements LoreTalkIo {
  final lines = <(int, String)>[];
  final gate = Completer<void>();
  var waits = 0;
  @override
  bool isOpen = true;
  @override
  void clear() => lines.clear();
  @override
  void print(int color, String text) => lines.add((color, text));
  @override
  Future<void> pressAnyKey() {
    waits++;
    return gate.future;
  }

  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  }) => throw StateError('this source case has no select');
}

void main() {
  test(
    'all raw byte stages: reward before key wait, quest increment afterwards',
    () async {
      for (var stage = 0; stage < 256; stage++) {
        final named = PartyMember.createPreset(1)
          ..name = 'Hero'
          ..experience = 100;
        final dead = PartyMember.createPreset(1)
          ..name = 'Dead'
          ..dead = 10
          ..experience = 200;
        final empty = PartyMember.blank()..experience = 300;
        final seventh = PartyMember.createPreset(1)
          ..name = 'Outside'
          ..experience = 400;
        final party = [
          named,
          dead,
          empty,
          PartyMember.blank(),
          PartyMember.blank(),
          PartyMember.blank(),
          seventh,
        ];
        final etc = LorePartyEtc({15: stage});
        final io = Window();
        final done = LoreWaterLord.run(party: party, etc: etc, io: io);
        final amount = stage == 2
            ? 150000
            : stage == 4
            ? 300000
            : 0;
        expect(named.experience, 100 + amount);
        expect(dead.experience, 200 + amount); // name<>'', not alive.
        expect(empty.experience, 300);
        expect(seventh.experience, 400); // original array is player[1..6].
        expect(etc.read(15), stage); // source inc follows PressAnyKey.
        expect(io.waits, stage <= 5 ? 1 : 0);
        if (stage > 5) expect(io.lines, isEmpty);
        if (amount > 0) {
          expect(io.lines[1], (11, '[ EXP + $amount ]'));
          expect(io.lines[2], (7, ''));
        }
        io.gate.complete();
        await done;
        expect(etc.read(15), [0, 2, 4].contains(stage) ? stage + 1 : stage);
      }
    },
  );

  test(
    'independent DOS reward saves match signed EXP, dead and empty slots',
    () async {
      final fixture = jsonDecode(
        File('test/fixtures/dos_water_lord_rewards.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final scenario in fixture['cases'] as List) {
        final initial = scenario['initial'];
        final party = <PartyMember>[];
        for (final member in initial['party'] as List) {
          party.add(
            PartyMember.createPreset(1)
              ..name = member['name'] as String
              ..experience = member['experience'] as int
              ..dead = member['dead'] as int,
          );
        }
        final etc = LorePartyEtc({15: initial['etc15'] as int});
        final io = Window();
        final done = LoreWaterLord.run(party: party, etc: etc, io: io);
        expect(
          party.map((m) => m.experience).toList(),
          scenario['observed']['experience'],
        );
        expect(etc.read(15), initial['etc15']);
        io.gate.complete();
        await done;
        expect(etc.read(15), scenario['observed']['etc15']);
      }
    },
  );

  test('closed screen does not continue a waiting procedure', () async {
    final etc = LorePartyEtc({15: 0});
    final io = Window();
    final done = LoreWaterLord.run(party: [], etc: etc, io: io);
    expect(io.lines.last, (7, '')); // original talk('') blank line.
    io.isOpen = false;
    io.gate.complete();
    await done;
    expect(etc.read(15), 0);
  });
}
