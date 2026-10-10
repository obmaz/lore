import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_data.dart';
import 'package:lore/models/item.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/spell.dart';

/// 로더 폴백 검증용: 어떤 에셋도 찾지 못하는 번들.
class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw Exception('asset not found');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JSON 데이터 계층 (assets/data/*.json)', () {
    setUp(() => LoreData.instance.resetForTest());
    tearDown(() => LoreData.instance.resetForTest());

    test('1. JSON을 로드하면 내장 원작 테이블과 완전히 일치한다', () async {
      await LoreData.instance.load();

      expect(
        LoreData.instance.usingJson,
        isTrue,
        reason: 'JSON 로드 실패: ${LoreData.instance.loadError}',
      );

      // 몬스터 75종 전수 교차 검증 (JSON == 내장 테이블)
      final jsonMonsters = LoreData.instance.monsters;
      expect(jsonMonsters.length, 75);
      for (var i = 0; i < 75; i++) {
        final a = jsonMonsters[i];
        final b = Monster.monsterTemplates[i];
        final label = 'monster #${i + 1} (${b.name})';
        expect(a.name, b.name, reason: label);
        expect(a.strength, b.strength, reason: label);
        expect(a.mentality, b.mentality, reason: label);
        expect(a.endurance, b.endurance, reason: label);
        expect(a.resistance, b.resistance, reason: label);
        expect(a.agility, b.agility, reason: label);
        expect(a.accArms, b.accArms, reason: label);
        expect(a.accMagic, b.accMagic, reason: label);
        expect(a.ac, b.ac, reason: label);
        expect(a.special, b.special, reason: label);
        expect(a.castLevel, b.castLevel, reason: label);
        expect(a.specialCastLevel, b.specialCastLevel, reason: label);
        expect(a.level, b.level, reason: label);
        expect(a.eNumber, b.eNumber, reason: label);
      }

      // 아이템 (무기/방패/갑옷)
      expect(LoreData.instance.weapons.length, Item.weapons.length);
      expect(LoreData.instance.shields.length, Item.shields.length);
      expect(LoreData.instance.armors.length, Item.armors.length);
      for (var i = 0; i < Item.weapons.length; i++) {
        expect(LoreData.instance.weapons[i].name, Item.weapons[i].name);
        expect(LoreData.instance.weapons[i].power, Item.weapons[i].power);
        expect(LoreData.instance.weapons[i].price, Item.weapons[i].price);
        expect(LoreData.instance.weapons[i].type, ItemType.weapon);
      }
      for (var i = 0; i < Item.shields.length; i++) {
        expect(LoreData.instance.shields[i].power, Item.shields[i].power);
        expect(LoreData.instance.shields[i].price, Item.shields[i].price);
      }
      for (var i = 0; i < Item.armors.length; i++) {
        expect(LoreData.instance.armors[i].power, Item.armors[i].power);
        expect(LoreData.instance.armors[i].price, Item.armors[i].price);
      }

      // 마법 45종
      expect(LoreData.instance.spells.length, Spell.allSpells.length);
      for (var i = 0; i < Spell.allSpells.length; i++) {
        final a = LoreData.instance.spells[i];
        final b = Spell.allSpells[i];
        expect(a.name, b.name, reason: 'spell #${i + 1}');
        expect(a.category, b.category, reason: 'spell #${i + 1}');
        expect(a.baseSp, b.baseSp, reason: 'spell #${i + 1}');
      }

      // 맵 27종
      expect(LoreData.instance.maps.length, 27);
      expect(LoreData.instance.map(6)!.fileName, 'TOWN1');
      expect(LoreData.instance.map(17)!.fileName, 'DEN4');
    });

    test('2. 편의 조회 API가 도감/장비/마법 ID로 정확히 찾는다', () async {
      await LoreData.instance.load();

      expect(LoreData.instance.monster(1).name, 'Orc');
      expect(LoreData.instance.monster(75).eNumber, 75);
      expect(LoreData.instance.weapon(9).name, '화염검');
      expect(LoreData.instance.shield(5).power, 5);
      expect(LoreData.instance.armor(5).power, 6);
      expect(LoreData.instance.spell(45).category, SpellCategory.esp);
      expect(LoreData.instance.map(6)!.category.name, 'town');
    });

    test('3. 에셋이 없으면 내장 원작 테이블로 안전하게 폴백한다', () async {
      await LoreData.instance.load(bundle: _MissingBundle());

      expect(LoreData.instance.usingJson, isFalse);
      expect(LoreData.instance.loadError, isNotNull);
      // 폴백 데이터로도 게임이 동작한다
      expect(LoreData.instance.monsters.length, 75);
      expect(LoreData.instance.weapons, Item.weapons);
      expect(LoreData.instance.spells, Spell.allSpells);
      expect(LoreData.instance.monster(1).name, 'Orc');
      expect(LoreData.instance.map(6)!.fileName, 'TOWN1');
    });
  });
}
