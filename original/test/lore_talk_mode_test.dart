import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/logic/lore_talk_dispatcher.dart';
import 'package:lore/logic/lore_talk_mode.dart';
import 'package:lore/models/party_member.dart';

import 'support/talk_mode_io.dart';

// Expectations are the original LORETALK.PAS lines/control flow, not scripts.json.
PartyMember member({
  required String name,
  Gender sex = Gender.male,
  int experience = 0,
  int dead = 0,
}) => PartyMember(
  name: name,
  sex: sex,
  experience: experience,
  dead: dead,
  playerClass: PlayerClass.knight,
  strength: 10,
  mentality: 10,
  concentration: 10,
  endurance: 10,
  resistance: 10,
  agility: 10,
  accArms: 10,
  accMagic: 5,
  accEsp: 5,
  luck: 10,
);

void main() {
  Future<TalkModeIo> run(
    int map,
    int tx,
    int ty, {
    LorePartyEtc? etc,
    List<PartyMember>? party,
    TalkModeIo? io,
    int x = 5,
    int y = 5,
    int Function(int)? roll,
  }) async {
    final window = io ?? TalkModeIo();
    await LoreTalkMode.run(
      mapId: map,
      targetX: tx,
      targetY: ty,
      x: x,
      y: y,
      party: party ?? [member(name: 'Hero')],
      etc: etc ?? LorePartyEtc(),
      roll: roll ?? (_) => 0,
      io: window,
    );
    return window;
  }

  test('LORETALK.PAS: original town words, variable concatenation and random call order', () async {
    final io = await run(6, 24, 50);
    expect(io.text, contains(' 힘내게, Hero'));
    final bounds = <int>[];
    final bartender = await run(
      6,
      13,
      27,
      party: [member(name: 'Hero', sex: Gender.female)],
      roll: (b) {
        bounds.add(b);
        return 0;
      },
    );
    expect(bounds, [2]);
    expect(bartender.text, contains(' 거기 여성분 어서 오십시오.'));
    expect(
      (await run(6, 18, 27, roll: (_) => 1)).text,
      contains('위스키에서 칵테일까지'),
    );
    expect((await run(7, 43, 9)).text, '당신은 PYRAMID 안에서 쉽게 창을 발견할 수 있을것입니다.');
    expect((await run(9, 23, 12)).text, contains('황금의 갑옷이 QUAKE'));
    expect((await run(24, 18, 10)).text, contains('안 영기라는 프로그래머'));
  });

  test(
    'LORETALK.PAS: all raw lord byte values: no clamp or fallback',
    () async {
      for (final (map, tx, ty, index, last) in [
        (6, 51, 28, 10, 6),
        (7, 38, 17, 13, 3),
        (9, 42, 25, 14, 6),
        (10, 25, 18, 15, 5),
      ]) {
        for (var stage = 0; stage < 256; stage++) {
          final etc = LorePartyEtc()..[index] = stage;
          final io = await run(map, tx, ty, etc: etc);
          expect(
            io.pages.isNotEmpty,
            stage <= last,
            reason: 'map $map etc[$index]=$stage',
          );
          if (stage > last) expect(etc.read(index), stage);
        }
      }
    },
  );

  test('LORETALK.PAS: EXP and quest mutation stay on their original side of the wait', () async {
    for (final (map, tx, ty, index, stage, amount, before, questBefore) in [
      (6, 51, 28, 10, 4, 1000, true, true),
      (7, 38, 17, 13, 2, 10000, false, false),
      (9, 42, 25, 14, 2, 10000, true, false),
      (9, 42, 25, 14, 5, 40000, true, false),
      (10, 25, 18, 15, 2, 150000, true, false),
      (10, 25, 18, 15, 4, 300000, true, false),
    ]) {
      final etc = LorePartyEtc()..[index] = stage;
      final party = [
        member(name: 'Hero', experience: 2147483548),
        member(name: 'Dead', dead: 5, experience: 1000),
        member(name: '', experience: 1234),
        member(name: ''),
        member(name: ''),
        member(name: ''),
        member(name: 'Extra', experience: 77),
      ];
      final io = TalkModeIo()
        ..beforeWait = () {
          expect(
            party[0].experience,
            before ? LorePascal.longint(2147483548 + amount) : 2147483548,
            reason: 'LORETALK map $map',
          );
          expect(etc.read(index), stage + (questBefore ? 1 : 0));
        };
      await run(map, tx, ty, etc: etc, party: party, io: io);
      expect(party[0].experience, LorePascal.longint(2147483548 + amount));
      expect(party[1].experience, 1000 + amount);
      expect(party[2].experience, 1234);
      expect(party[6].experience, 77);
      expect(etc.read(index), stage + 1);
    }
  });

  test('LORETALK.PAS: secret passage opens only after all three waits, with raw bit OR', () async {
    final etc = LorePartyEtc()..[50] = 128;
    final io = TalkModeIo();
    io.beforeWait = () => expect(io.tiles, isEmpty);
    await run(6, 63, 76, etc: etc, io: io);
    expect(io.pages.length, 3);
    expect(io.tiles, [
      (62, 79, 44),
      (62, 80, 44),
      (62, 81, 44),
      (62, 82, 0),
      (62, 83, 14),
    ]);
    expect(etc.read(50), 129);
    expect(io.refreshes, 1);
    expect((await run(6, 63, 76, etc: etc)).pages, isEmpty);
  });

  test('LORETALK.PAS: challenge Y changes ten tiles before reply wait, others leave gate closed', () async {
    for (final key in ['Y', 'y', 'N', '', 'X']) {
      final etc = LorePartyEtc()..[10] = 3;
      final io = TalkModeIo()..key = key;
      io.beforeWait = () =>
          expect(io.tiles.length, key.toUpperCase() == 'Y' ? 10 : 0);
      await run(6, 50, 51, etc: etc, io: io);
      expect(etc.read(30), key.toUpperCase() == 'Y' ? 1 : 0);
    }
  });

  test('LORETALK.PAS: creator and parchment mutate only after acknowledgement; default ashes have no wait', () async {
    final etc = LorePartyEtc();
    final creator = TalkModeIo();
    creator.beforeWait = () {
      expect(etc.read(43), 0);
      expect(creator.tiles, isEmpty);
    };
    await run(24, 33, 10, etc: etc, io: creator);
    expect(etc.read(43), 8);
    expect(creator.tiles, [(33, 10, 47)]);
    for (final (tx, ty) in [(10, 14), (10, 18), (10, 30), (21, 32), (21, 22)]) {
      final io = TalkModeIo();
      io.beforeWait = () => expect(io.tiles, isEmpty);
      await run(27, tx, ty, io: io);
      expect(io.pages.length, greaterThan(1));
      expect(io.tiles, [(tx, ty, 35)]);
    }
    final ignored = TalkModeIo()..choice = 0;
    await run(27, 21, 12, io: ignored);
    expect(ignored.tiles, isEmpty);
    final read = await run(27, 21, 12);
    expect(read.tiles, [(21, 12, 35)]);
    expect(read.text, contains("Durant l'estoille"));
    final ash = await run(27, 8, 8);
    expect(ash.pages, isEmpty);
    expect(ash.messages.single, contains('재로 변하였다'));
    expect(ash.tiles, [(8, 8, 35)]);
    final man = await run(27, 15, 6);
    expect(man.pages.length, 2);
    expect(
      man.tiles,
      isEmpty,
    ); // putimage(font52) changes drawing only, never map memory.
  });

  test(
    'Direct runtime needs no JSON table, including empty/unknown events',
    () {
      for (final map in [6, 7, 9, 10, 24, 27]) {
        expect(
          LoreTalkDispatcher.resolve(
            mapId: map,
            x: 5,
            y: 5,
            context: null,
            world: LoreWorldManager.instance,
            scripts: LoreScriptEngine(),
          ).source,
          LoreTalkSource.procedure,
        );
      }
      expect(
        LoreTalkDispatcher.resolve(
          mapId: 1,
          x: 5,
          y: 5,
          context: const ScriptContext(),
          world: LoreWorldManager.instance,
          scripts: LoreScriptEngine(),
        ).source,
        LoreTalkSource.none,
      );
    },
  );
}
