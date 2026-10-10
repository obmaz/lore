import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_data.dart';
import 'package:lore/models/monster.dart';

List<Object> _record(Monster m) => [
  m.name,
  m.strength,
  m.mentality,
  m.endurance,
  m.resistance,
  m.agility,
  m.accArms,
  m.accMagic,
  m.ac,
  m.special,
  m.castLevel,
  m.specialCastLevel,
  m.level,
];

/// LORESUB.PAS:1804 Set_All: original 75 typed reads and template slot order.
/// Reset/Close/file errors and startup frames are not included.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = jsonDecode(
    File('test/fixtures/dos_setall_enemy_read.json').readAsStringSync(),
  );
  final records = fixture['records'] as List;
  List<Object> expected(int index) {
    final r = List<int>.from(records[index]);
    return [ascii.decode(r.sublist(1, 1 + r[0])), ...r.sublist(17)];
  }

  test('all native typed-read slots match actual battle factory and retain independent records', () {
    expect(records, hasLength(75));
    expect(fixture['ioResult'], 0);
    expect(fixture['finalIndex'], 75);
    expect(Monster.monsterTemplates, hasLength(75));
    for (var i = 0; i < 75; i++) {
      expect(fixture['reads'][i], {
        'index': i + 1,
        'target': 0x566b8 + i * 29,
        'length': 29,
        'fileOffset': i * 29,
      });
      final template = Monster.monsterTemplates[i];
      final active = Monster.create(i + 1);
      expect(_record(template), expected(i));
      expect(_record(active), expected(i));
      expect(template.eNumber, i + 1);
      expect(active.eNumber, i + 1);
      expect(
        active.hp,
        ((records[i][19] as int) * (records[i][28] as int)).toSigned(16),
      );
      expect(
        [active.isDead, active.isUnconscious, active.isPoisoned],
        [false, false, false],
      );
      active.hp = -32768;
      active.level = 0;
      active.isDead = true;
      expect(_record(template), expected(i));
      expect(_record(Monster.create(i + 1)), expected(i));
    }
  });
  test(
    'actual packaged JSON resource owner retains all 75 native records',
    () async {
      await LoreData.instance.load();
      expect(LoreData.instance.usingJson, isTrue);
      expect(LoreData.instance.monsters, hasLength(75));
      for (var i = 0; i < 75; i++) {
        expect(_record(LoreData.instance.monsters[i]), expected(i));
        final active = LoreData.instance.monster(i + 1);
        expect(_record(active), expected(i));
        expect(active.eNumber, i + 1);
        active.level = 0;
        expect(_record(LoreData.instance.monsters[i]), expected(i));
      }
    },
  );
}
