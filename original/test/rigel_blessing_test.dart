import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_rigel_blessing.dart';
import 'package:lore/models/party_member.dart';

class _FixedRandom implements Random {
  final int value;
  const _FixedRandom(this.value);

  @override
  int nextInt(int max) => value;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  test('Rigel 지원은 주인공 SP를 소진하고 운 판정 두 번에 성공한 무기만 강화한다', () {
    final hero = PartyMember.createPreset(1);
    final ally = PartyMember.createPreset(3);
    final heroPower = hero.weaPower;
    final allyPower = ally.weaPower;
    expect(hero.sp, greaterThan(0));

    applyRigelBlessing([hero, ally], const _FixedRandom(0));
    expect(hero.sp, 0);
    expect(hero.weaPower, (heroPower * 1.2).round());
    expect(ally.weaPower, (allyPower * 1.2).round());

    final unblessed = PartyMember.createPreset(1);
    final before = unblessed.weaPower;
    applyRigelBlessing([unblessed], const _FixedRandom(19));
    expect(unblessed.sp, 0);
    expect(unblessed.weaPower, before);
  });
}
