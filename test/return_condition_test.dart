import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/party_member.dart';

/// LORESUB.PAS `ReturnCondition`: besides the text it normalizes the record.
void main() {
  PartyMember member() => PartyMember.createPreset(1)
    ..endurance = 10
    ..battleLevel = 2;

  test('hp <= 0 without unconscious becomes unconscious 1', () {
    final p = member()..hp = 0;
    expect(p.returnCondition(), 'unconscious');
    expect(p.unconscious, 1);
    p.unconscious = 5;
    p.hp = -3;
    p.returnCondition();
    expect(p.unconscious, 5);
  });

  test('unconscious above endurance * level[1] dies with dead = 1', () {
    final p = member()
      ..hp = 1
      ..unconscious = 21;
    expect(p.returnCondition(), 'dead');
    expect(p.dead, 1);
    final edge = member()
      ..hp = 1
      ..unconscious = 20;
    expect(edge.returnCondition(), 'unconscious');
    expect(edge.dead, 0);
    final already = member()
      ..hp = 1
      ..unconscious = 21
      ..dead = 7;
    already.returnCondition();
    expect(already.dead, 7);
  });

  test('dead beats unconscious beats poisoned beats good', () {
    final p = member()..hp = 5;
    expect(p.returnCondition(), 'good');
    p.poison = 1;
    expect(p.returnCondition(), 'poisoned');
    p.unconscious = 1;
    expect(p.returnCondition(), 'unconscious');
    p.dead = 1;
    expect(p.returnCondition(), 'dead');
  });

  test('an unused slot is the zero record after SimpleDisCond: dead 1', () {
    final blank = PartyMember.blank();
    expect((blank.unconscious, blank.dead, blank.hp), (1, 1, 0));
    expect(blank.returnCondition(), 'dead');
    // The zero record of Create goes through the same two steps.
    final zero = PartyMember.blank()
      ..unconscious = 0
      ..dead = 0;
    PartyMember.simpleDisCond([zero]);
    expect((zero.unconscious, zero.dead), (1, 1));
  });

  test('SimpleDisCond normalizes named and unnamed slots 1..6', () {
    final named = member()..hp = 0;
    final unnamed = member()
      ..name = ''
      ..hp = -4;
    PartyMember.simpleDisCond([named, unnamed]);
    expect((named.unconscious, unnamed.unconscious), (1, 1));
  });
}
