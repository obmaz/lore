import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/logic/lore_ent_procedures.dart';
import 'package:lore/models/party_member.dart';

class _SequenceRandom implements Random {
  final List<int> values;
  final List<int> bounds = [];
  var index = 0;

  _SequenceRandom(this.values);

  @override
  int nextInt(int max) {
    bounds.add(max);
    return values[index++];
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  test('최종 방 진입 후 원본의 하강 프레임은 4에서 0까지 다섯 번이다', () {
    expect(LoreEntProcedures.chamberDescentRows, [4, 3, 2, 1, 0]);
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sixth-slot Draconian is struck before the dungeon guard battle', () {
    final party = [for (var i = 1; i <= 6; i++) PartyMember.createPreset(i)];
    party[5].name = 'Draconian';
    expect(LoreEntProcedures.strikeDraconianBeforeDungeon(party), isTrue);
    expect((party[5].hp, party[5].unconscious, party[5].dead), (0, 1, 30000));

    party[5].name = 'Other';
    party[5].hp = 10;
    expect(LoreEntProcedures.strikeDraconianBeforeDungeon(party), isFalse);
    expect(party[5].hp, 10);
  });

  test('live entrance completion restores the camera and map 26 facing', () {
    final game = LoreGame(initialMapId: 25);
    game.peekAt(30, 30);
    game.playerDirection = 2;
    game.currentMapId = 26;
    LoreEntProcedures.afterMapLoadBeforeScripts(
      fromMap: 25,
      toMap: 26,
      setDirection: (direction) => game.playerDirection = direction,
    );
    game.finishEntrance();
    expect(game.playerDirection, 1);
    expect(game.isPeeking, isFalse);
  });

  test('chamber entry consumes ten ordered pairs before boss combat', () {
    final random = _SequenceRandom([4, 4, ...List.filled(18, 0)]);
    final frames = LoreEntProcedures.chamberEntryFrames(random);
    expect(frames.length, 10);
    expect(frames.first, (0, -1));
    expect(frames.last, (-4, -4));
    expect(random.bounds, List.filled(20, 9));
  });

  test('completed chamber entry faces north before restoring the view', () {
    final trace = <String>[];
    LoreEntProcedures.afterMapLoadBeforeScripts(
      fromMap: 25,
      toMap: 26,
      setDirection: (direction) => trace.add('face:$direction'),
    );
    LoreEntProcedures.finishEntrance(() => trace.add('scroll'));
    expect(trace, ['face:1', 'scroll']);

    trace.clear();
    LoreEntProcedures.afterMapLoadBeforeScripts(
      fromMap: 1,
      toMap: 6,
      setDirection: (direction) => trace.add('face:$direction'),
    );
    LoreEntProcedures.finishEntrance(() => trace.add('scroll'));
    expect(trace, ['scroll']);
  });

  test('sign displays text then opens the KEEP3 lever tile', () {
    final trace = <String>[];
    LoreEntProcedures.sign(
      mapId: 23,
      x: 25,
      y: 27,
      messageFor: (mapId, x, y) {
        trace.add('lookup:$mapId:$x:$y');
        return 'lever';
      },
      display: (message) => trace.add('display:$message'),
      setTile: (x, y, tile) => trace.add('tile:$x:$y:$tile'),
    );
    expect(trace, ['lookup:23:25:27', 'display:lever', 'tile:25:27:52']);
  });
}
