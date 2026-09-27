import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_swamp_logic.dart';
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
  test('늪은 빈 슬롯까지 여섯 번 굴리고 이름 있는 대원만 중독시킨다', () {
    final source = File('repo_source/LORE_1993_src/LOREMAIN.PAS')
        .readAsStringSync(encoding: latin1)
        .split('Procedure enter_swamp;\nbegin')[1]
        .split('Procedure enter_lava;')[0];
    expect(
      source,
      contains("if random(20)+1 >= player[i].luck then m[i] := '!';"),
    );
    expect(source, contains("if (name<>'') and (m[person]='!') then begin"));

    final party = [
      PartyMember.createPreset(1)..luck = 10,
      PartyMember.createPreset(2)..luck = 20,
      PartyMember.createPreset(3)
        ..name = ''
        ..luck = 1,
      PartyMember.createPreset(4)..luck = 4,
      PartyMember.createPreset(5)..luck = 4,
      PartyMember.createPreset(6)..luck = 5,
    ];
    final random = _QueuedRandom([0, 19, 1, 2, 3, 4]);
    expect(LoreSwampLogic.rollPoisonedSlots(party, random), [1, 4, 5]);
    expect(random.bounds, [20, 20, 20, 20, 20, 20]);
    expect(LoreSwampLogic.applyPoison(party[1]), isTrue);
    expect(party[1].poison, 1);
    expect(LoreSwampLogic.applyPoison(party[1]), isFalse);
  });
}
