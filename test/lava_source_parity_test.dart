import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_lava_logic.dart';
import 'package:lore/models/party_member.dart';

class _QueuedRandom implements Random {
  final List<int> values;
  final List<int> bounds = [];
  var index = 0;

  _QueuedRandom(this.values);

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
  final source = File('repo_source/LORE_1993_src/LOREMAIN.PAS')
      .readAsStringSync(encoding: latin1)
      .split('Procedure enter_lava;\nbegin')[1]
      .split('Procedure Move_Mode;')[0];

  test('용암은 공중 부상과 무관하게 여섯 슬롯을 원본 순서로 굴린다', () {
    expect(source, contains('j := random(40)+40 - 2*random(player[i].luck);'));
    expect(source, isNot(contains('party.etc[4]')));
    final party = [
      PartyMember.createPreset(1)..luck = 10,
      PartyMember.createPreset(2)..luck = 5,
      PartyMember.createPreset(3)
        ..name = ''
        ..luck = 4,
      for (var i = 0; i < 3; i++)
        PartyMember.createPreset(1)
          ..name = ''
          ..luck = 0,
    ];
    final random = _QueuedRandom([5, 2, 1, 0, 7, 3, 0, 0, 0]);
    expect(LoreLavaLogic.rollDamages(party, random), [41, 41, 41, 40, 40, 40]);
    expect(random.bounds, [40, 10, 40, 5, 40, 4, 40, 40, 40]);
  });

  test('용암 피해는 HP·의식·사망 상태를 원본 순서로 갱신한다', () {
    final member = PartyMember.createPreset(1)
      ..hp = 50
      ..unconscious = 0
      ..dead = 0;
    LoreLavaLogic.applyDamage(member, 60);
    expect((member.hp, member.unconscious, member.dead), (-10, 1, 0));

    member
      ..hp = 50
      ..unconscious = 1;
    LoreLavaLogic.applyDamage(member, 60);
    expect((member.hp, member.unconscious, member.dead), (-10, 1, 0));

    member
      ..hp = -1
      ..unconscious = member.endurance * member.battleLevel;
    LoreLavaLogic.applyDamage(member, 1);
    expect(member.dead, 1);

    member.dead = 29999;
    LoreLavaLogic.applyDamage(member, 60);
    expect(member.dead, 30000);
  });
}
