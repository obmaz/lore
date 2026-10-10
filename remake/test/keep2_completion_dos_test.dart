import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_town_shops.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/models/party_member.dart';

class _Io implements LoreShopIo {
  _Io(this.answers, this.gold, this.party);
  final List<int> answers;
  final List<PartyMember> party;
  @override
  int gold;
  @override
  int food = 100;
  @override
  void clear() {}
  @override
  void print(int color, String text) {}
  @override
  Future<void> pressAnyKey() async {}
  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  }) async => answers.removeAt(0);
  @override
  void displayCondition() => PartyMember.simpleDisCond(party);
}

void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_keep2_completion.json').readAsStringSync(),
  );
  final inputs = [
    for (final s in f['segments'])
      for (final b in s['trace'])
        if (b.containsKey('input')) b['input'],
  ];
  dynamic row(int n) =>
      inputs.singleWhere((r) => r['capture'] == 'lore_$n.png');
  const purchases = [
    (16763, 2, 3, 1),
    (16767, 2, 3, 2),
    (16771, 2, 3, 3),
    (16775, 2, 3, 5),
    (16779, 2, 3, 6),
    (16783, 3, 2, 1),
    (16787, 3, 2, 2),
    (16791, 3, 2, 5),
    (16795, 3, 3, 3),
    (16799, 1, 9, 2),
    (16803, 1, 7, 1),
  ];
  for (final (n, category, item, slot) in purchases) {
    test(
      'native late equipment purchase $n matches every record and gold',
      () async {
        final r = row(n), before = r['before'], after = r['after'];
        final party = [
          for (final p in before['records'])
            PartyMember.fromJson(Map<String, dynamic>.from(p)),
        ];
        final io = _Io(
          [category, item, slot, 0, 0],
          before['partyRecord']['gold'],
          party,
        );
        await LoreTownShops.weaponShop(io, party);
        expect(party.map((p) => p.toJson()).toList(), after['records']);
        expect(io.gold, after['partyRecord']['gold']);
      },
    );
  }
  test('native Draconian training17 to18 consumes no random draw', () async {
    final r = row(17189), before = r['before'], after = r['after'];
    final party = [
      for (final p in before['records'])
        PartyMember.fromJson(Map<String, dynamic>.from(p)),
    ];
    final io = _Io([6, 0], before['partyRecord']['gold'], party);
    final random = LoreRandom(before['seed']);
    await LoreTownShops.trainCenter(io, party, random);
    expect(party.map((p) => p.toJson()).toList(), after['records']);
    expect(io.gold, after['partyRecord']['gold']);
    expect(random.seed, after['seed']);
  });
}
