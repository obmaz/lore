import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_game_option.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/logic/lore_sub_text.dart';
import 'package:lore/logic/lore_transient_slots.dart';
import 'package:lore/models/party_member.dart';

class _Io implements LoreGameOptionIo {
  _Io(this.answers);
  final List<int> answers;
  final List<String> trace = [];

  @override
  Future<int> select(
    String title,
    List<String> items, {
    List<(int, String)> lines = const [],
  }) async {
    trace.add('select:$title:${items.join('|')}:${lines.length}');
    return answers.removeAt(0);
  }

  @override
  Future<void> message(List<(int, String)> lines) async =>
      trace.add('message:${lines.map((l) => '${l.$1}:${l.$2}').join('|')}');

  @override
  Future<void> load(int slot) async => trace.add('load:$slot');

  @override
  Future<void> save(int slot) async => trace.add('save:$slot');

  @override
  Future<void> gameOver() async => trace.add('gameOver');

  @override
  void displayCondition() => trace.add('display');
}

/// LOREMENU.PAS `GameOption` (914-1022).
void main() {
  List<PartyMember> party() => [
    PartyMember.createPreset(1),
    PartyMember.createPreset(3),
    PartyMember.createPreset(5),
  ];

  test(
    'order menu retains a detached player7 scratch for later battle',
    () async {
      final members = party();
      final original = members[1].toJson();
      final slots = LoreTransientSlots();
      await LoreGameOption.run(
        _Io([2, 1, 2]),
        members,
        LorePartyEtc(),
        slots: slots,
      );
      expect(slots.seventhPlayer.toJson(), original);
      members[2]
        ..name = ''
        ..hp = -1;
      expect(slots.seventhPlayer.toJson(), original);
      await LoreGameOption.run(
        _Io([4, 2]),
        members,
        LorePartyEtc(),
        slots: slots,
      );
      expect(slots.seventhPlayer.toJson(), original);
    },
  );

  test('the six source items; Esc does nothing', () async {
    final io = _Io([0]);
    await LoreGameOption.run(io, party(), LorePartyEtc());
    expect(io.trace, [
      'select:${LoreMenuText.optionTitle}:'
          '${LoreMenuText.optionDifficulty}|${LoreMenuText.optionOrder}|'
          '${LoreMenuText.optionRemove}|${LoreMenuText.optionResume}|'
          '${LoreMenuText.optionSave}|${LoreMenuText.optionQuit}:0',
    ]);
  });

  test(
    '1: maxenemy := k + 2 (Esc -> 5), encounter := 6 - k (Esc -> 3)',
    () async {
      final etc = LorePartyEtc();
      final io = _Io([1, 1, 5]);
      await LoreGameOption.run(io, party(), etc);
      expect([etc.read(8), etc.read(7)], [3, 1]);
      expect(io.trace[1], startsWith('select::3 명의 적들|4 명의 적들|'));
      expect(io.trace[1], endsWith('7 명의 적들:2'));
      expect(
        io.trace[2],
        startsWith('select:${LoreMenuText.optionEncounterPrompt}:'),
      );
      await LoreGameOption.run(_Io([1, 0, 0]), party(), etc);
      expect([etc.read(8), etc.read(7)], [5, 3]);
    },
  );

  test('2: swaps whole slots 2..5, padding empty ones as Reserved', () async {
    final members = party();
    final b = members[1];
    final io = _Io([2, 1, 4]);
    await LoreGameOption.run(io, members, LorePartyEtc());
    expect(
      io.trace[1],
      'select::${b.name}|${members[2].name}|Reserved|Reserved:2',
    );
    expect(members[4], same(b));
    expect(members[1].name, '');
    expect(io.trace.last, 'display');
    final kept = party();
    await LoreGameOption.run(_Io([2, 1, 0]), kept, LorePartyEtc());
    expect(kept.map((m) => m.name), party().map((m) => m.name));
  });

  test('3: player[k].name := \'\' for slot k', () async {
    final members = party();
    await LoreGameOption.run(_Io([3, 2]), members, LorePartyEtc());
    expect(members.map((m) => m.name), [
      PartyMember.createPreset(1).name,
      PartyMember.createPreset(3).name,
      '',
    ]);
  });

  test('4/5: load and save use k - 1; save prints and waits', () async {
    var io = _Io([4, 1]);
    await LoreGameOption.run(io, party(), LorePartyEtc());
    expect(io.trace.last, startsWith('select:${LoreSubText.selectLoadGame}'));
    io = _Io([4, 3]);
    await LoreGameOption.run(io, party(), LorePartyEtc());
    expect(io.trace.last, 'load:2');
    io = _Io([5, 2]);
    await LoreGameOption.run(io, party(), LorePartyEtc());
    expect(io.trace.sublist(1), [
      'select:${LoreMenuText.optionLoadPrompt}:${LoreSubText.loadSlots.join('|')}:0',
      'save:1',
      'message:12:${LoreMenuText.optionSaving}|7:${LoreMenuText.optionSaveDone}',
    ]);
  });

  test('6: GameOver', () async {
    final io = _Io([6]);
    await LoreGameOption.run(io, party(), LorePartyEtc());
    expect(io.trace.last, 'gameOver');
  });
}
