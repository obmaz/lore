import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/models/item.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/spell.dart';

/// 데이터 내보내기 도구 (JSON 데이터화).
///
/// 게임 코드에 하드코딩된 원작 데이터를 `assets/data/*.json`으로 추출한다.
/// **기본 실행에서는 건너뛰고**, 데이터를 갱신할 때만 아래처럼 실행한다.
///
/// ```sh
/// flutter test test/tools/export_data_test.dart --dart-define=EXPORT_DATA=true
/// ```
///
/// 내보내는 파일:
/// - `assets/data/monsters.json` : 원작 FOEDATA 75종 몬스터 템플릿
/// - `assets/data/items.json`    : 무기 10종 / 방패 6종 / 갑옷 6종
/// - `assets/data/spells.json`   : 45종 마법 체계
/// - `assets/data/maps.json`     : 27개 맵 메타데이터
void main() {
  const enabled = bool.fromEnvironment('EXPORT_DATA');

  test('원작 데이터를 assets/data/*.json 으로 내보낸다', () {
    final dir = Directory('assets/data')..createSync(recursive: true);

    void write(String name, Map<String, dynamic> json) {
      final file = File('${dir.path}/$name');
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
      // ignore: avoid_print
      print('wrote ${file.path} (${file.lengthSync()} bytes)');
    }

    // 1. 몬스터 75종
    write('monsters.json', {
      'version': 1,
      'source': 'FOEDATA.DAT / LORESUB.PAS enemydata1',
      'monsters': Monster.monsterTemplates
          .map(
            (m) => {
              'eNumber': m.eNumber,
              'name': m.name,
              'strength': m.strength,
              'mentality': m.mentality,
              'endurance': m.endurance,
              'resistance': m.resistance,
              'agility': m.agility,
              'accArms': m.accArms,
              'accMagic': m.accMagic,
              'ac': m.ac,
              'special': m.special,
              'castLevel': m.castLevel,
              'specialCastLevel': m.specialCastLevel,
              'level': m.level,
            },
          )
          .toList(),
    });

    // 2. 아이템 (무기/방패/갑옷)
    List<Map<String, dynamic>> items(List<Item> list) => list
        .map(
          (i) => {
            'id': i.id,
            'name': i.name,
            'power': i.power,
            'price': i.price,
          },
        )
        .toList();
    write('items.json', {
      'version': 1,
      'source': 'LORESUB.PAS Weapon_Shop',
      'weapons': items(Item.weapons),
      'shields': items(Item.shields),
      'armors': items(Item.armors),
    });

    // 3. 마법 45종
    write('spells.json', {
      'version': 1,
      'source': 'LORESUB.PAS ReturnMagic (727-775)',
      'spells': Spell.allSpells
          .map(
            (s) => {
              'id': s.id,
              'name': s.name,
              'category': s.category.name,
              'description': s.description,
              'baseSp': s.baseSp,
            },
          )
          .toList(),
    });

    // 4. 맵 메타데이터 (27개)
    write('maps.json', {
      'version': 1,
      'source': 'LORESUB.PAS Load (맵/파일 대응표) + LOREENT.PAS',
      'maps': LoreWorldManager.mapRegistry.values
          .map(
            (m) => {
              'mapId': m.mapId,
              'fileName': m.fileName,
              'title': m.title,
              'category': m.category.name,
              'bgmTrack': m.bgmTrack.name,
              'fontName': m.fontName,
            },
          )
          .toList(),
    });

    expect(File('${dir.path}/monsters.json').existsSync(), isTrue);
    expect(File('${dir.path}/items.json').existsSync(), isTrue);
    expect(File('${dir.path}/spells.json').existsSync(), isTrue);
    expect(File('${dir.path}/maps.json').existsSync(), isTrue);
  }, skip: !enabled);
}
