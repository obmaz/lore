import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/field_magic_logic.dart';
import 'package:lore/logic/lore_ent_procedures.dart';
import 'package:lore/models/party_member.dart';

void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_archi_continuation.json').readAsStringSync(),
  );
  final inputs = [
    for (final s in f['segments'])
      for (final b in s['trace'])
        if (b.containsKey('input')) b['input'],
  ];
  dynamic row(int n) =>
      inputs.singleWhere((r) => r['capture'] == 'lore_$n.png');
  List<PartyMember> members(dynamic s) => [
    for (final p in s['records'])
      PartyMember.fromJson(Map<String, dynamic>.from(p)),
  ];
  test(
    'native ArchiDraconian prebattle strike preserves all other records',
    () {
      final r = row(18582);
      final p = members(r['before']);
      expect(LoreEntProcedures.strikeDraconianBeforeDungeon(p), isTrue);
      expect(p.map((p) => p.toJson()).toList(), r['after']['records']);
      expect(r['before']['seed'], r['after']['seed']);
    },
  );
  test('native battle whole cure of dead30000 preserves signed16 costs and all fields', () {
    final r = row(18602);
    final p = members(r['before']);
    final caster = p[3], target = p[5];
    FieldMagicLogic.revitalizeOne(caster, target, inBattle: true);
    FieldMagicLogic.consciousOne(caster, target, inBattle: true);
    FieldMagicLogic.cureOne(caster, target, inBattle: true);
    FieldMagicLogic.healOne(caster, target, inBattle: true);
    expect(p.map((p) => p.toJson()).toList(), r['after']['records']);
    expect(caster.sp, 17782);
    expect(target.hp, 49);
    expect(r['before']['seed'], r['after']['seed']);
  });
}
