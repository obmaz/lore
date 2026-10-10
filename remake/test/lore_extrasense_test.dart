import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_extrasense.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/models/party_member.dart';

class _Io implements LoreExtrasenseIo {
  _Io(this.answers, {this.mapId = 6, this.keys = const []});

  final List<int> answers;
  final List<bool> keys;
  final List<String> trace = [];
  final List<(int, int)> viewed = [];
  @override
  final int mapId;
  @override
  int x = 20;
  @override
  int y = 20;
  @override
  int get xmax => 50;
  @override
  int get ymax => 50;

  @override
  Future<int> select(
    String title,
    List<String> items, {
    List<(int, String)> lines = const [],
  }) async {
    trace.add('select:$title:${items.length}:${lines.length}');
    return answers.removeAt(0);
  }

  @override
  Future<void> talk(List<(int, String)> lines) async =>
      trace.add('talk:${lines.map((l) => '${l.$1}:${l.$2}').join('|')}');

  @override
  void message(int color, String text) => trace.add('message:$color:$text');

  @override
  Future<void> seeThrough(String text) async => trace.add('see:$text');

  @override
  void clairvoyanceBegin() => trace.add('begin');

  @override
  Future<bool> clairvoyanceStep(int x, int y) async {
    viewed.add((x, y));
    return keys.length > viewed.length - 1 ? keys[viewed.length - 1] : true;
  }

  @override
  void clairvoyanceEnd() => trace.add('end');

  @override
  void displayEsp() => trace.add('esp');
}

/// LOREMENU.PAS `Extrasense` and `ReturnPredict`.
void main() {
  PartyMember esper({int esp = 100, int level = 4}) =>
      PartyMember.createPreset(3)
        ..playerClass = PlayerClass.esper
        ..esp = esp
        ..espLevel = level;

  group('Extrasense', () {
    test(
      'ChooseWhom, class gate (2,3,6 or etc[38] bit1) and the kind Select',
      () async {
        final knight = PartyMember.createPreset(1);
        var io = _Io([1]);
        await LoreExtrasense.run(io, [knight], LorePartyEtc());
        expect(io.trace, [
          'select::1:1',
          'talk:7:${LoreMenuText.espNoAbility}',
        ]);
        io = _Io([1, 0]);
        await LoreExtrasense.run(io, [knight], LorePartyEtc({38: 1}));
        expect(io.trace[1], 'select:${LoreMenuText.espKind}:5:0');
        io = _Io([1, 0]);
        await LoreExtrasense.run(io, [esper()], LorePartyEtc());
        expect(io.trace[1], 'select:${LoreMenuText.espKind}:5:0');
      },
    );

    test(
      'an inactive caster gets Message; 염력 is battle only and exits',
      () async {
        final down = esper()..hp = 0;
        var io = _Io([1]);
        await LoreExtrasense.run(io, [down], LorePartyEtc());
        expect(io.trace.last, 'message:7:그는 초감각을 사용할수있는 상태가 아닙니다');
        io = _Io([1, 5]);
        await LoreExtrasense.run(io, [esper()], LorePartyEtc());
        expect(io.trace.last, 'message:7:염력${LoreMenuText.espBattleOnly}');
      },
    );

    test('Esc on the kind select reaches DisplayESP', () async {
      final io = _Io([1, 0]);
      await LoreExtrasense.run(io, [esper()], LorePartyEtc());
      expect(io.trace, [
        'select::1:1',
        'select:${LoreMenuText.espKind}:5:0',
        'esp',
      ]);
    });

    test(
      'see-through: blocked above map 24, ESP 10, spent after the key',
      () async {
        var io = _Io([1, 1], mapId: 25);
        final caster = esper();
        await LoreExtrasense.run(io, [caster], LorePartyEtc());
        expect(io.trace.last, 'message:13:${LoreMenuText.espEvilPower}');
        expect(caster.esp, 100);
        io = _Io([1, 1]);
        await LoreExtrasense.run(io, [esper(esp: 9)], LorePartyEtc());
        expect(io.trace.last, 'message:7:${LoreMenuText.espNotEnough}');
        io = _Io([1, 1]);
        await LoreExtrasense.run(io, [caster], LorePartyEtc());
        expect(io.trace.sublist(2), [
          'see:${LoreMenuText.espSeeThrough}',
          'esp',
        ]);
        expect(caster.esp, 90);
      },
    );

    test('prophecy: ESP 5, header, blank, source sentence', () async {
      final caster = esper();
      final io = _Io([1, 2]);
      await LoreExtrasense.run(io, [caster], LorePartyEtc());
      expect(
        io.trace[2],
        'talk:7: 당신은 당신의 미래를 예언한다 ...|7:|15: # 당신은 Lord Ahn 을 만날 것이다',
      );
      expect(caster.esp, 95);
    });

    test(
      'mind reading sets etc[5] to 3; the source never spends ESP for it',
      () async {
        final etc = LorePartyEtc();
        final caster = esper();
        final io = _Io([1, 3]);
        await LoreExtrasense.run(io, [caster], etc);
        expect(io.trace[2], 'message:15:${LoreMenuText.espMindRead}');
        expect(etc.read(5), 3);
        expect(caster.esp, 100);
        final poor = _Io([1, 3]);
        await LoreExtrasense.run(poor, [esper(esp: 19)], LorePartyEtc());
        expect(poor.trace.last, 'message:7:${LoreMenuText.espNotEnough}');
      },
    );

    test(
      'clairvoyance: level steps, Esc stops, out of bounds does not wait',
      () async {
        final caster = esper(level: 3);
        var io = _Io([1, 4, 4]);
        await LoreExtrasense.run(io, [caster], LorePartyEtc());
        expect(io.viewed, [(19, 20), (18, 20), (17, 20)]);
        expect(io.trace.sublist(3), ['begin', 'end', 'esp']);
        expect(caster.esp, 100 - 15);
        io = _Io([1, 4, 1], keys: [true, false]);
        await LoreExtrasense.run(io, [esper(level: 3)], LorePartyEtc());
        expect(io.viewed, [(20, 19), (20, 18)]);
        final edge = _Io([1, 4, 1])..y = 6;
        await LoreExtrasense.run(edge, [esper(level: 3)], LorePartyEtc());
        expect(edge.viewed, [(20, 5)]);
        final cancel = _Io([1, 4, 0]);
        final spare = esper();
        await LoreExtrasense.run(cancel, [spare], LorePartyEtc());
        expect(spare.esp, 100);
        expect(cancel.trace, isNot(contains('begin')));
      },
    );

    test(
      'clairvoyance is blocked above map 24 and needs level*5 ESP',
      () async {
        var io = _Io([1, 4], mapId: 26);
        await LoreExtrasense.run(io, [esper()], LorePartyEtc());
        expect(io.trace.last, 'message:13:${LoreMenuText.espEvilPower}');
        io = _Io([1, 4]);
        await LoreExtrasense.run(io, [esper(esp: 19)], LorePartyEtc());
        expect(io.trace.last, 'message:7:${LoreMenuText.espNotEnough}');
      },
    );
  });

  group('ReturnPredict', () {
    int predict(Map<int, int> etc, [int map = 6]) =>
        LoreExtrasense.returnPredict(LorePartyEtc(etc), map);

    test('Lord Ahn steps (etc[10]) and the LASTDITCH/GAIA/WATER chain', () {
      expect(predict({}), 1);
      expect(predict({10: 3}), 2);
      expect(predict({10: 5}), 3);
      expect(predict({10: 6}), 4);
      expect(predict({10: 6}, 7), 5);
      expect(predict({10: 6, 13: 1}), 6);
      expect(predict({10: 6, 13: 3, 14: 0}), 9);
      expect(predict({10: 6, 13: 3, 14: 2}), 11);
      expect(predict({10: 6, 13: 3, 14: 6, 15: 3}), 17);
      expect(predict({10: 6, 13: 3, 14: 6, 15: 0}, 2), 13);
      expect(predict({10: 6, 13: 3, 14: 6}, 16), 14);
    });

    test('map-specific overrides and the final chain', () {
      expect(predict({}, 13), 19);
      expect(predict({40: 1}, 13), 1);
      expect(predict({15: 5}, 4), 20);
      expect(predict({15: 5, 40: 1, 41: 1}, 4), 21);
      expect(predict({}, 5), 22);
      expect(predict({15: 5}, 22), 22);
      expect(predict({15: 5}, 23), 23);
      expect(predict({15: 5}, 25), 24);
      expect(predict({15: 5}, 26), 25);
      expect(predict({10: 9}), 0);
    });
  });
}
