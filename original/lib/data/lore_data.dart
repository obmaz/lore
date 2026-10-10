/// 원작 데이터(몬스터/아이템/마법/맵)를 JSON으로 관리하는 데이터 계층.
///
/// `assets/data/*.json`을 읽어 모델 인스턴스를 만들어 준다.
/// JSON이 없거나 파싱에 실패하면 코드에 내장된 원작 테이블(Dart)을 그대로 사용하므로
/// 게임은 어떤 경우에도 동작한다(안전한 폴백).
///
/// JSON 갱신 방법:
/// ```sh
/// flutter test test/tools/export_data_test.dart --dart-define=EXPORT_DATA=true
/// ```
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../game/lore_world_manager.dart';
import '../models/item.dart';
import '../models/monster.dart';
import '../models/spell.dart';
import '../services/audio_manager.dart' show BgmTrack;

class LoreData {
  static final LoreData instance = LoreData._internal();
  LoreData._internal();

  bool _loaded = false;

  /// JSON 로드에 성공했는지 여부(테스트/디버깅용).
  bool usingJson = false;

  /// 로드 실패 시 사유(성공하면 null).
  String? loadError;

  List<Monster>? _monsters;
  List<Item>? _weapons;
  List<Item>? _shields;
  List<Item>? _armors;
  List<Spell>? _spells;
  List<MapInfo>? _maps;

  // ── 조회 (JSON 우선, 없으면 내장 원작 테이블) ──

  List<Monster> get monsters => _monsters ?? Monster.monsterTemplates;
  List<Item> get weapons => _weapons ?? Item.weapons;
  List<Item> get shields => _shields ?? Item.shields;
  List<Item> get armors => _armors ?? Item.armors;
  List<Spell> get spells => _spells ?? Spell.allSpells;
  List<MapInfo> get maps =>
      _maps ?? LoreWorldManager.mapRegistry.values.toList();

  /// 도감 번호(1..75)로 몬스터 템플릿을 만든다.
  Monster monster(int id) {
    final table = monsters;
    if (table.isEmpty) return Monster.create(id);
    final idx = (id - 1).clamp(0, table.length - 1);
    final t = table[idx];
    return Monster(
      eNumber: t.eNumber,
      name: t.name,
      strength: t.strength,
      mentality: t.mentality,
      endurance: t.endurance,
      resistance: t.resistance,
      agility: t.agility,
      accArms: t.accArms,
      accMagic: t.accMagic,
      ac: t.ac,
      special: t.special,
      castLevel: t.castLevel,
      specialCastLevel: t.specialCastLevel,
      level: t.level,
    );
  }

  Item weapon(int id) => _pick(weapons, id);
  Item shield(int id) => _pick(shields, id);
  Item armor(int id) => _pick(armors, id);

  Spell spell(int id) {
    final table = spells;
    if (table.isEmpty) return Spell.getById(id);
    final idx = (id - 1).clamp(0, table.length - 1);
    return table[idx];
  }

  MapInfo? map(int mapId) {
    for (final m in maps) {
      if (m.mapId == mapId) return m;
    }
    return LoreWorldManager.mapRegistry[mapId];
  }

  Item _pick(List<Item> table, int id) {
    for (final it in table) {
      if (it.id == id) return it;
    }
    return table.isEmpty ? Item.weapons[0] : table.first;
  }

  // ── 로딩 ──

  /// JSON 데이터를 읽는다. 이미 로드했다면 아무 것도 하지 않는다.
  Future<void> load({AssetBundle? bundle}) async {
    if (_loaded) return;
    final b = bundle ?? rootBundle;
    try {
      _monsters = _parseMonsters(await _readJson(b, 'monsters.json'));
      final items = await _readJson(b, 'items.json');
      _weapons = _parseItems(items['weapons'], ItemType.weapon);
      _shields = _parseItems(items['shields'], ItemType.shield);
      _armors = _parseItems(items['armors'], ItemType.armor);
      _spells = _parseSpells(await _readJson(b, 'spells.json'));
      _maps = _parseMaps(await _readJson(b, 'maps.json'));
      usingJson = true;
    } catch (e) {
      // 폴백: 내장 Dart 테이블 사용
      _monsters = null;
      _weapons = null;
      _shields = null;
      _armors = null;
      _spells = null;
      _maps = null;
      usingJson = false;
      loadError = e.toString();
    }
    _loaded = true;
  }

  /// 테스트에서 상태를 초기화할 때 사용한다.
  void resetForTest() {
    _loaded = false;
    usingJson = false;
    loadError = null;
    _monsters = null;
    _weapons = null;
    _shields = null;
    _armors = null;
    _spells = null;
    _maps = null;
  }

  Future<Map<String, dynamic>> _readJson(AssetBundle b, String name) async {
    final raw = await b.loadString('assets/data/$name');
    return json.decode(raw) as Map<String, dynamic>;
  }

  List<Monster> _parseMonsters(Map<String, dynamic> json) {
    final list = json['monsters'] as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return Monster(
        eNumber: m['eNumber'] as int,
        name: m['name'] as String,
        strength: m['strength'] as int,
        mentality: m['mentality'] as int,
        endurance: m['endurance'] as int,
        resistance: m['resistance'] as int,
        agility: m['agility'] as int,
        accArms: m['accArms'] as int,
        accMagic: m['accMagic'] as int,
        ac: m['ac'] as int,
        special: m['special'] as int,
        castLevel: m['castLevel'] as int,
        specialCastLevel: m['specialCastLevel'] as int,
        level: m['level'] as int,
      );
    }).toList();
  }

  List<Item> _parseItems(dynamic raw, ItemType type) {
    final list = raw as List<dynamic>;
    return list.map((e) {
      final i = e as Map<String, dynamic>;
      return Item(
        id: i['id'] as int,
        name: i['name'] as String,
        type: type,
        power: i['power'] as int,
        price: i['price'] as int,
      );
    }).toList();
  }

  List<Spell> _parseSpells(Map<String, dynamic> json) {
    final list = json['spells'] as List<dynamic>;
    return list.map((e) {
      final s = e as Map<String, dynamic>;
      return Spell(
        id: s['id'] as int,
        name: s['name'] as String,
        category: SpellCategory.values.byName(s['category'] as String),
        description: s['description'] as String,
        baseSp: s['baseSp'] as int,
      );
    }).toList();
  }

  List<MapInfo> _parseMaps(Map<String, dynamic> json) {
    final list = json['maps'] as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return MapInfo(
        mapId: m['mapId'] as int,
        fileName: m['fileName'] as String,
        title: m['title'] as String,
        category: MapCategory.values.byName(m['category'] as String),
        bgmTrack: BgmTrack.values.byName(m['bgmTrack'] as String),
        fontName: m['fontName'] as String,
      );
    }).toList();
  }
}
