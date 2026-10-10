import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/logic/lore_talk_mode.dart';
import 'package:lore/models/party_member.dart';

import 'support/talk_mode_io.dart';

class _TraceIo extends TalkModeIo {
  _TraceIo(this.etc, this.party, this.stopAfter);
  final LorePartyEtc etc;
  final List<PartyMember> party;
  final int stopAfter;
  final trace = <Object?>[];
  List<Object?> get state => [
    [for (var i = 1; i <= 50; i++) etc.read(i)],
    party.map((member) => member.experience).toList(),
  ];
  @override
  void clear() {
    trace.add(['clear']);
    super.clear();
  }

  @override
  void print(int color, String text) {
    trace.add(['print', color, text]);
    super.print(color, text);
  }

  @override
  void cprint(
    int color,
    int highlight,
    String before,
    String word,
    String after,
  ) {
    trace.add(['cprint', color, highlight, before, word, after]);
    super.cprint(color, highlight, before, word, after);
  }

  @override
  Future<void> pressAnyKey() async {
    trace.add(['wait', ...state]);
    if (stopAfter != 0 && pages.length + 1 == stopAfter) open = false;
    await super.pressAnyKey();
  }

  @override
  void setTile(int x, int y, int tile) {
    trace.add(['tile', x, y, tile]);
    super.setTile(x, y, tile);
  }

  @override
  void refresh() {
    trace.add(['refresh', ...state]);
    super.refresh();
  }

  @override
  void message(int color, String text) {
    trace.add(['log', color, text]);
    super.message(color, text);
  }

  @override
  Future<void> recruit(LoreScript procedure) async {
    trace.add(['recruit', procedure.id]);
    await super.recruit(procedure);
  }

  @override
  Future<String> challengeKey() async {
    trace.add(['challenge', key]);
    return super.challengeKey();
  }

  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  }) async {
    trace.add(['select', title, items, clean, choice]);
    return super.select(title, items, maxsum: maxsum, clean: clean);
  }

  @override
  Future<void> blinkRemains(int dx, int dy) async {
    trace.add(['blink', dx, dy, ...state]);
    await super.blinkRemains(dx, dy);
  }
}

Future<Map<String, Object?>> _run(
  Map<String, dynamic> sample, {
  bool continuous = false,
}) async {
  final party = [
    for (var i = 0; i < 7; i++)
      PartyMember.fromJson({
        'name': i == 2
            ? ''
            : i == 0
            ? 'Hero'
            : 'Member $i',
        'sex': sample['female'] == true ? 1 : 0,
        'experience': i == 0 ? 2147483548 : 100 + i,
        'dead': i == 1 ? 5 : 0,
      }),
  ];
  final etc = LorePartyEtc();
  for (final entry in (sample['bytes'] as Map<String, dynamic>).entries) {
    etc[int.parse(entry.key)] = entry.value as int;
  }
  final io = _TraceIo(etc, party, sample['stopAfter'] as int? ?? 0)
    ..choice = sample['choice'] as int? ?? 1
    ..key = sample['key'] as String? ?? 'Y';
  int roll(int bound) {
    io.trace.add(['random', bound]);
    return (sample['random'] as int? ?? 0) % bound;
  }

  await LoreTalkMode.run(
    mapId: sample['map'] as int,
    targetX: sample['tx'] as int,
    targetY: sample['ty'] as int,
    x: sample['x'] as int? ?? 5,
    y: sample['y'] as int? ?? 5,
    party: party,
    etc: etc,
    io: io,
    roll: roll,
    continuous: continuous,
  );
  return {
    'trace': io.trace,
    'final': io.state,
    'open': io.open,
    'pages': io.pages.length,
  };
}

void main() {
  test(
    'migrated dialogue nodes preserve complete native execution traces',
    () async {
      final baseline = jsonDecode(
        utf8.decode(
          gzip.decode(
            File('test/fixtures/source_dialogue_migration_baseline.json.gz')
                .readAsBytesSync(),
          ),
        ),
      ) as Map<String, dynamic>;
      final samples = baseline['samples'] as List<dynamic>;
      expect(samples.length, 2525);
      for (var i = 0; i < samples.length; i++) {
        final sample = samples[i] as Map<String, dynamic>;
        final input = sample['input'] as Map<String, dynamic>;
        final actual = await _run(input)
          ..remove('pages');
        expect(
          jsonDecode(jsonEncode(actual)),
          sample['expected'],
          reason: 'pre-migration source trace $i: $input',
        );
      }
    },
  );

  test(
    'explicit mobile links stop at mission boundaries and award once',
    () async {
      for (final (map, tx, ty, byte, stage, pages, after, award) in [
        (6, 51, 28, 10, 0, 3, 3, 0),
        (6, 51, 28, 10, 1, 2, 3, 0),
        (6, 51, 28, 10, 2, 1, 3, 0),
        (6, 51, 28, 10, 3, 1, 3, 0),
        (6, 51, 28, 10, 4, 2, 6, 1000),
        (6, 51, 28, 10, 6, 1, 6, 0),
        (7, 38, 17, 13, 0, 1, 1, 0),
        (7, 38, 17, 13, 2, 2, 3, 10000),
        (9, 42, 25, 14, 0, 1, 1, 0),
        (9, 42, 25, 14, 2, 2, 4, 10000),
        (9, 42, 25, 14, 3, 1, 4, 0),
        (9, 42, 25, 14, 4, 1, 4, 0),
        (9, 42, 25, 14, 5, 2, 6, 40000),
        (9, 42, 25, 14, 6, 1, 6, 0),
        (10, 25, 18, 15, 0, 2, 1, 0),
        (10, 25, 18, 15, 2, 2, 3, 150000),
        (10, 25, 18, 15, 3, 1, 3, 0),
        (10, 25, 18, 15, 4, 2, 5, 300000),
        (10, 25, 18, 15, 5, 1, 5, 0),
        (10, 25, 18, 15, 255, 0, 255, 0),
      ]) {
        final actual = await _run({
          'map': map,
          'tx': tx,
          'ty': ty,
          'bytes': {'$byte': stage},
        }, continuous: true);
        expect(actual['pages'], pages, reason: '$map/$stage');
        final afterState = actual['final'] as List<Object?>;
        expect((afterState.first as List<int>)[byte - 1], after);
        expect(afterState.last, [
          LorePascal.longint(2147483548 + award),
          101 + award,
          102,
          103 + award,
          104 + award,
          105 + award,
          106,
        ]);
        final waits = (actual['trace'] as List<Object?>)
            .where((entry) => (entry as List).first == 'wait')
            .toList();
        if (stage == 3 || stage == 4 && byte == 14) expect(waits.length, 1);
      }
    },
  );

  test(
    'closed mobile wait preserves each source reward boundary and stops links',
    () async {
      for (final (map, tx, ty, byte, stage, after, award) in [
        (6, 51, 28, 10, 0, 0, 0),
        (6, 51, 28, 10, 4, 5, 1000),
        (7, 38, 17, 13, 2, 2, 0),
        (9, 42, 25, 14, 2, 2, 10000),
        (10, 25, 18, 15, 2, 2, 150000),
      ]) {
        final actual = await _run({
          'map': map,
          'tx': tx,
          'ty': ty,
          'bytes': {'$byte': stage},
          'stopAfter': 1,
        }, continuous: true);
        expect(actual['pages'], 1);
        final state = actual['final'] as List<Object?>;
        expect((state.first as List<int>)[byte - 1], after);
        expect(
          (state.last as List<int>).first,
          LorePascal.longint(2147483548 + award),
        );
      }
    },
  );
}
