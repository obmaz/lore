import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/monster.dart';

void main() {
  test('Set_All loads exactly 75 source-ordered 29-byte enemy templates', () {
    final source = latin1.decode(
      File('repo_source/LORE_1993_src/LORESUB.PAS').readAsBytesSync(),
    );
    final loop = RegExp(
      r'for i := 1 to (\d+) do read\(enemyfile,enemydata\[i\]\);',
    ).firstMatch(source)!;
    final count = int.parse(loop[1]!);
    final bytes = File('repo_source/LORE_1993_runtime/FOEDATA.DAT')
        .readAsBytesSync();
    expect(bytes.length, count * 29);
    expect(Monster.monsterTemplates.length, count);
    for (var id = 1; id <= count; id++) {
      final record = bytes.sublist((id - 1) * 29, id * 29);
      final t = Monster.monsterTemplates[id - 1];
      final enemy = Monster.create(id);
      final name = latin1.decode(record.sublist(1, record[0] + 1));
      expect(t.eNumber, id);
      expect(t.name, name);
      expect(enemy.name, name);
      for (final m in [t, enemy]) {
        expect(
          [
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
          ],
          record.sublist(17),
          reason: 'template $id',
        );
      }
      final hp = (BigInt.from(record[19]) * BigInt.from(record[28]))
          .toSigned(16)
          .toInt();
      expect(enemy.hp, hp);
      expect(
        [enemy.isDead, enemy.isUnconscious, enemy.isPoisoned],
        [false, false, false],
      );
      expect(identical(t, enemy), isFalse);
      enemy.level = 0;
      expect(
        t.level,
        record[28],
        reason: 'templates remain independent from battle state',
      );
    }
  });
}
