import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_town_shops.dart';
import 'package:lore/models/party_member.dart';

class _Io implements LoreShopIo {
  _Io(this.answers, this.gold);
  final List<int> answers;
  final List<(int, String)> lines = [];
  @override
  int gold;
  @override
  int food = 20;
  @override
  void clear() {}
  @override
  void print(int color, String text) => lines.add((color, text));
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
  void displayCondition() {}
}

// LORESUB.PAS:1358-1384,1416-1418,1504-1507. The independent original
// instruction fixture proves CASE narrowing and preservation of known local j.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_training_dispatch.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('training level CASE matches original low-word comparisons', () {
    for (final row in fixture['levels'] as List) {
      expect(
        LoreTownShops.levelForExperience(
          row['experience'],
          previousLevel: row['previousLevel'],
        ),
        row['level'],
        reason: '${row['experience']} after j=${row['previousLevel']}',
      );
    }
  });

  test('first unmatched training CASE has no invented level', () {
    expect(() => LoreTownShops.levelForExperience(-1), throwsStateError);
    expect(LoreTownShops.levelForExperience(-64036), 2);
  });

  test(
    'a CASE miss preserves j from the previous training selection',
    () async {
      final first = PartyMember.createPreset(1)..experience = 20000;
      final second = PartyMember.createPreset(1)..experience = -1;
      final io = _Io([1, 2, 0], 100);
      await LoreTownShops.trainCenter(io, [first, second], Random(1));
      expect([first.battleLevel, second.battleLevel], [4, 4]);
      expect(io.gold, 84);
    },
  );

  test(
    'insufficient XP next-level display also updates the retained j',
    () async {
      final first = PartyMember.createPreset(1)
        ..battleLevel = 5
        ..experience = 20000;
      final second = PartyMember.createPreset(1)..experience = -1;
      final io = _Io([1, 2, 0], 100);
      await LoreTownShops.trainCenter(io, [first, second], Random(1));
      expect([first.battleLevel, second.battleLevel], [5, 6]);
      expect(io.gold, 75);
    },
  );

  test('training shortfall message matches original SUB/SBB longint', () async {
    const experiences = {3: 1500, 5: 6000, 24000: 4560000};
    for (final row in fixture['shortfalls'] as List) {
      final experience = experiences[row['cost']];
      if (experience == null) continue; // level20 exits before this expression
      final hero = PartyMember.createPreset(1)..experience = experience;
      final io = _Io([1, 0], row['gold']);
      await LoreTownShops.trainCenter(io, [hero], Random(1));
      expect(io.lines, contains((7, '당신은 금 ${row['shortfall']}개가 더 필요합니다.')));
      expect(hero.battleLevel, 1);
      expect(io.gold, row['gold']);
    }
  });
}
