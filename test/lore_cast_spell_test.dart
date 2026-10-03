import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/field_magic_logic.dart';
import 'package:lore/logic/lore_cast_spell.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/models/party_member.dart';

class _Io implements LoreCastSpellIo {
  _Io(
    this.answers, {
    this.position = 'den',
    this.mapId = 14,
    Map<(int, int), int> tiles = const {},
    this.power,
  }) : tiles = Map.of(tiles);

  final List<int> answers;
  @override
  final String position;
  @override
  final int mapId;
  final Map<(int, int), int> tiles;
  final int? power;
  final List<String> trace = [];
  @override
  int x = 20;
  @override
  int y = 20;
  @override
  int food = 100;

  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    List<(int, String)> lines = const [],
  }) async {
    trace.add('select:$title:${items.length}:${maxsum ?? items.length}');
    return answers.removeAt(0);
  }

  @override
  Future<void> talk(List<(int, String)> lines) async =>
      trace.add('talk:${lines.map((l) => '${l.$1}:${l.$2}').join('|')}');

  @override
  void message(int color, String text) => trace.add('message:$color:$text');

  @override
  void print(int color, String text) => trace.add('print:$color:$text');

  @override
  Future<int?> spacePower() async => power;

  @override
  int get xmax => 50;

  @override
  int get ymax => 50;

  @override
  int tileAt(int x, int y) => tiles[(x, y)] ?? 44;

  @override
  void setTile(int x, int y, int tile) => tiles[(x, y)] = tile;

  @override
  void moveTo(int x, int y) {
    this.x = x;
    this.y = y;
    trace.add('move:$x,$y');
  }

  @override
  void displayCondition() {}
}

/// LOREMENU.PAS `CastSpell`, `CureSpell` and `PhenominaSpell`.
void main() {
  PartyMember mage({int level = 10, int sp = 500}) =>
      PartyMember.createPreset(3)
        ..magicLevel = level
        ..sp = sp;

  group('CastSpell', () {
    test(
      'ChooseWhom lists named slots; an inactive caster gets Message',
      () async {
        final party = [
          PartyMember.createPreset(1),
          PartyMember.blank(),
          mage(),
        ];
        final io = _Io([2, 0]);
        await LoreCastSpell.run(io, party, LorePartyEtc());
        expect(io.trace.first, 'select::2:2');
        expect(io.trace[1], 'select:${LoreMenuText.castSpellKind}:3:3');
        party[2].hp = 0;
        final down = _Io([2]);
        await LoreCastSpell.run(down, party, LorePartyEtc());
        expect(down.trace.last, 'message:7:그는 마법을 사용할수있는 상태가 아닙니다');
      },
    );

    test('attack magic is refused with Talk', () async {
      final io = _Io([1, 1]);
      await LoreCastSpell.run(io, [mage()], LorePartyEtc());
      expect(io.trace.last, 'talk:7:${FieldMagicLogic.attackSpellMessage}');
    });
  });

  group('CureSpell', () {
    test('whom lists slots 1..5 (+6 when present) and 모든 사람들에게', () async {
      final io = _Io([0]);
      await LoreCastSpell.cureSpell(io, [mage()], mage());
      expect(io.trace.single, 'select:${LoreCastSpell.toWhom}:6:6');
      final six = _Io([0]);
      await LoreCastSpell.cureSpell(six, [
        for (var i = 1; i <= 6; i++) PartyMember.createPreset(i),
      ], mage());
      expect(six.trace.single, 'select:${LoreCastSpell.toWhom}:7:7');
    });

    test(
      'personal: level div 2 + 1 slots; Esc exits without the key wait',
      () async {
        final io = _Io([1, 0]);
        await LoreCastSpell.cureSpell(io, [mage(level: 4)], mage(level: 4));
        expect(io.trace.last, 'select:${LoreMenuText.phenominaSelect}:7:3');
      },
    );

    test('an empty slot target only prints its refusal (0 HP >= 0)', () async {
      final caster = mage();
      final io = _Io([3, 1]);
      await LoreCastSpell.cureSpell(io, [caster], caster);
      expect(io.trace.last, 'talk:7:는 치료할 필요가 없습니다.|7:|7:');
    });

    test(
      'etc[6] <> 0 drops the guarded refusals and SPnotEnough (hotkey C)',
      () async {
        final caster = mage();
        final quiet = _Io([3, 1]);
        await LoreCastSpell.cureSpell(quiet, [caster], caster, quiet: true);
        expect(quiet.trace.last, 'talk:7:|7:');
        final broke = mage(level: 10, sp: 0);
        final a = PartyMember.createPreset(1)..hp = 1;
        final loud = _Io([2, 1]);
        await LoreCastSpell.cureSpell(loud, [broke, a], broke);
        expect(
          loud.trace,
          contains('talk:7:${FieldMagicLogic.spNotEnoughMessage}'),
        );
        final silent = _Io([2, 1]);
        await LoreCastSpell.cureSpell(silent, [broke, a], broke, quiet: true);
        expect(silent.trace.last, 'talk:7:|7:');
        expect(silent.trace.where((t) => t.startsWith('talk')).length, 1);
        // `run` hands the party's etc[6] to CureSpell.
        final viaRun = _Io([1, 2, 3, 1]);
        await LoreCastSpell.run(viaRun, [caster], LorePartyEtc({6: 255}));
        expect(viaRun.trace.last, 'talk:7:|7:');
      },
    );

    test('group: level < 6 refuses with Talk; Esc still waits', () async {
      final low = _Io([6]);
      await LoreCastSpell.cureSpell(low, [mage(level: 5)], mage(level: 5));
      expect(
        low.trace.last,
        'talk:7:${FieldMagicLogic.strongCureNotReady(PartyMember.createPreset(3).name)}',
      );
      final esc = _Io([6, 0]);
      await LoreCastSpell.cureSpell(esc, [mage(level: 6)], mage(level: 6));
      expect(esc.trace.sublist(1), [
        'select:${LoreMenuText.phenominaSelect}:7:0',
        'talk:7:|7:',
      ]);
    });

    test(
      'SPnotEnough is a Talk in the middle of the printed results',
      () async {
        final caster = mage(level: 10, sp: 25);
        final a = PartyMember.createPreset(1)..hp = 1;
        final b = PartyMember.createPreset(5)..hp = 1;
        final io = _Io([6, 1]);
        await LoreCastSpell.cureSpell(io, [caster, a, b], caster);
        // 모두 치료: caster is full (refusal), a healed (20 SP), b: SP short.
        expect(io.trace.sublist(2), [
          'talk:7:${caster.name}는 치료할 필요가 없습니다.|15:${a.name}는 치료되어 졌습니다.|'
              '7:${FieldMagicLogic.spNotEnoughMessage}',
          'talk:7:|7:',
        ]);
      },
    );
  });

  group('PhenominaSpell', () {
    test('maxsum = level div 2 + 1 (1 below level 2, at most 8)', () async {
      for (final (level, j) in [(1, 1), (2, 2), (10, 6), (20, 8)]) {
        final io = _Io([0]);
        await LoreCastSpell.phenominaSpell(
          io,
          [],
          mage(level: level),
          LorePartyEtc(),
        );
        expect(io.trace.single, 'select:${LoreMenuText.phenominaSelect}:8:$j');
      }
    });

    test(
      'torch adds 1 to etc[1] (to 255); 2..4 set etc[4], etc[2], etc[3]',
      () async {
        final etc = LorePartyEtc({1: 3});
        final caster = mage();
        await LoreCastSpell.phenominaSpell(_Io([1]), [], caster, etc);
        expect(etc.read(1), 4);
        etc[1] = 255;
        await LoreCastSpell.phenominaSpell(_Io([1]), [], caster, etc);
        expect(etc.read(1), 255);
        for (final (k, index) in [(2, 4), (3, 2), (4, 3)]) {
          await LoreCastSpell.phenominaSpell(_Io([k]), [], caster, etc);
          expect(etc.read(index), 255);
        }
        expect(caster.sp, 500 - 1 - 1 - 5 - 10 - 20);
      },
    );

    test(
      'its SPnotEnough is a Message without 그러나, before any direction',
      () async {
        final io = _Io([5]);
        await LoreCastSpell.phenominaSpell(
          io,
          [],
          mage(sp: 24),
          LorePartyEtc(),
        );
        expect(
          io.trace.last,
          'message:7:${LoreCastSpell.phenominaSpNotEnough}',
        );
      },
    );

    test(
      'vaporize: two cells; rejected on a 0 middle cell or 52 beyond (den)',
      () async {
        final ok = _Io([5, 1]);
        final caster = mage();
        await LoreCastSpell.phenominaSpell(ok, [], caster, LorePartyEtc());
        expect(ok.trace.last, 'move:20,18');
        expect(caster.sp, 475);
        final middle = _Io([5, 1], tiles: {(20, 19): 0});
        await LoreCastSpell.phenominaSpell(middle, [], mage(), LorePartyEtc());
        expect(
          middle.trace.last,
          'message:13:${LoreMenuText.phenominaRejected}',
        );
        final beyond = _Io([5, 1], tiles: {(20, 17): 52});
        await LoreCastSpell.phenominaSpell(beyond, [], mage(), LorePartyEtc());
        expect(
          beyond.trace.last,
          'message:13:${LoreMenuText.phenominaRejected}',
        );
        final wall = _Io([5, 1], tiles: {(20, 18): 30});
        await LoreCastSpell.phenominaSpell(wall, [], mage(), LorePartyEtc());
        expect(
          wall.trace.last,
          'message:7:${LoreMenuText.phenominaVaporizeFail}',
        );
        final edge = _Io([5, 1])..y = 6;
        await LoreCastSpell.phenominaSpell(edge, [], mage(), LorePartyEtc());
        expect(edge.trace.last, startsWith('select::4'));
      },
    );

    test(
      'terrain change and space move are blocked on maps 20, 25, 26 first',
      () async {
        for (final map in [20, 25, 26]) {
          for (final k in [6, 7]) {
            final io = _Io([k], mapId: map);
            await LoreCastSpell.phenominaSpell(
              io,
              [],
              mage(sp: 0),
              LorePartyEtc(),
            );
            expect(
              io.trace.last,
              'message:13:${LoreCastSpell.phenominaBlocked}',
            );
          }
        }
        final vaporize = _Io([5, 1], mapId: 20);
        await LoreCastSpell.phenominaSpell(
          vaporize,
          [],
          mage(),
          LorePartyEtc(),
        );
        expect(vaporize.trace.last, 'move:20,18');
      },
    );

    test('terrain change writes 43 in a den, refused on 0/52', () async {
      final io = _Io([6, 3]);
      await LoreCastSpell.phenominaSpell(io, [], mage(), LorePartyEtc());
      expect(io.tiles[(21, 20)], 43);
      final town = _Io([6, 3], position: 'town');
      await LoreCastSpell.phenominaSpell(town, [], mage(), LorePartyEtc());
      expect(town.tiles[(21, 20)], 47);
      final sealed = _Io([6, 3], tiles: {(21, 20): 52});
      await LoreCastSpell.phenominaSpell(sealed, [], mage(), LorePartyEtc());
      expect(sealed.tiles[(21, 20)], 52);
    });

    test('space move: power k cells, bounds, spot and the 52 beyond', () async {
      final io = _Io([7, 3], power: 5);
      await LoreCastSpell.phenominaSpell(io, [], mage(), LorePartyEtc());
      expect(io.trace.last, 'move:25,20');
      final esc = _Io([7, 3]);
      await LoreCastSpell.phenominaSpell(esc, [], mage(), LorePartyEtc());
      expect(esc.trace.last, startsWith('select::4'));
      final far = _Io([7, 3], power: 9)..x = 40;
      await LoreCastSpell.phenominaSpell(far, [], mage(), LorePartyEtc());
      expect(
        far.trace.last,
        'message:7:${FieldMagicLogic.spaceMoveNotAllowedMessage}',
      );
      final spot = _Io([7, 3], power: 2, tiles: {(22, 20): 40});
      await LoreCastSpell.phenominaSpell(spot, [], mage(), LorePartyEtc());
      expect(
        spot.trace.last,
        'message:7:${FieldMagicLogic.spaceMoveBadSpotMessage}',
      );
      final beyond = _Io([7, 3], power: 2, tiles: {(23, 20): 52});
      await LoreCastSpell.phenominaSpell(beyond, [], mage(), LorePartyEtc());
      expect(
        beyond.trace.last,
        'message:13:${FieldMagicLogic.spaceMoveRejectedMessage}',
      );
    });

    test(
      'food: +named members up to 255, three printed lines, no key wait',
      () async {
        final party = [
          mage(),
          PartyMember.createPreset(1),
          PartyMember.blank(),
        ];
        final io = _Io([8])..food = 254;
        await LoreCastSpell.phenominaSpell(
          io,
          party,
          party.first,
          LorePartyEtc(),
        );
        expect(io.food, 255);
        expect(io.trace.sublist(1), [
          'print:15: 식량 제조 마법은 성공적으로 수행되었습니다',
          'print:15:            2 개의 식량이 증가됨',
          'print:11:      일행의 현재 식량은 255 개 입니다',
        ]);
      },
    );
  });
}
