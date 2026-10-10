import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _Dispatch extends LoreBattle {
  _Dispatch(List<PartyMember> party, this.lines, this.success)
    : super(
        party: party,
        enemy: [Monster.create(1)],
        random: Random(1),
        print: (c, s) => lines.add((c, s)),
      );
  final List<(int, String)> lines;
  final bool success;
  final calls = <String>[];
  @override
  String returnMessage(int who, int how, int what, int whom) =>
      'source:$who:$how:$what:$whom';
  @override
  void attackOne() => calls.add('AttackOne');
  @override
  void castOne() => calls.add('CastOne');
  @override
  void castAll() => calls.add('CastAll');
  @override
  void castSpecial() => calls.add('CastSpecial');
  @override
  void battleESP() => calls.add('BattleESP');
  @override
  bool runAway() {
    calls.add('RunAway');
    return success;
  }
}

// BattleMode's execute CASE and message membership. Procedures are spies:
// arithmetic inside each action is separately native-verified, not duplicated here.
void main() {
  test('all command bytes, six slots and active predicates preserve source dispatch', () {
    final source = String.fromCharCodes(
      File('repo_source/LORE_1993_src/LOREBATT.PAS').readAsBytesSync(),
    );
    final body = source.substring(
      source.indexOf('if battle[person,1] in [0,4,6..8]'),
    );
    final branches = {
      for (final m in RegExp(
        r'(\d+) : (AttackOne|CastOne|CastAll|CastSpecial|BattleESP);',
      ).allMatches(body))
        int.parse(m[1]!): m[2]!,
    };
    expect(branches.length, 5);
    expect(body, contains('7 : begin'));
    for (var who = 1; who <= 6; who++) {
      for (var state = 0; state < 16; state++) {
        for (var how = 0; how < 256; how++) {
          final party = [for (var i = 0; i < 7; i++) PartyMember.blank()];
          final actor = party[who - 1]
            ..name = (state & 1) == 0 ? 'Actor' : ''
            ..hp = (state & 2) == 0 ? 1 : 0
            ..unconscious = (state & 4) == 0 ? 0 : 1
            ..dead = (state & 8) == 0 ? 0 : 1;
          final lines = <(int, String)>[];
          final b = _Dispatch(party, lines, how.isOdd);
          b.battle[who] = [0, how, 17, 1];
          final escaped = b.executePerson(who);
          final active =
              actor.name.isNotEmpty &&
              actor.hp > 0 &&
              actor.unconscious == 0 &&
              actor.dead == 0;
          expect(
            b.calls,
            active && (branches.containsKey(how) || how == 7)
                ? [how == 7 ? 'RunAway' : branches[how]!]
                : <String>[],
          );
          expect(
            lines,
            active && {0, 4, 6, 7, 8}.contains(how)
                ? [(15, 'source:$who:$how:17:1')]
                : <(int, String)>[],
          );
          expect(escaped, active && how == 7);
        }
      }
    }
  });
}
