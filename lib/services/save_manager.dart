import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/party_member.dart';

class SaveData {
  static const int currentSchemaVersion = 2;

  final int slot;
  final String slotName;
  final DateTime timestamp;
  final int mapId;
  final String mapTitle;
  final int playerX;
  final int playerY;
  final int gold;
  final int food;
  final List<PartyMember> party;

  /// 진행 단계, 원본 etc 값, 이름 있는 플래그를 함께 담는다.
  final Map<String, dynamic> flags;
  final Map<String, int> etc;

  /// 원작 `saveN.map`: 저장 당시 현재 지도의 타일을 행 우선으로 보관한다.
  final List<int> mapTiles;
  final List<String> consumedScripts;

  const SaveData({
    required this.slot,
    required this.slotName,
    required this.timestamp,
    required this.mapId,
    required this.mapTitle,
    required this.playerX,
    required this.playerY,
    required this.gold,
    required this.food,
    required this.party,
    required this.flags,
    this.etc = const {},
    this.mapTiles = const [],
    this.consumedScripts = const [],
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'slot': slot,
    'slotName': slotName,
    'timestamp': timestamp.toIso8601String(),
    'mapId': mapId,
    'mapTitle': mapTitle,
    'playerX': playerX,
    'playerY': playerY,
    'gold': gold,
    'food': food,
    'party': party.map((p) => p.toJson()).toList(),
    'flags': flags,
    'etc': etc,
    'mapTiles': mapTiles,
    'consumedScripts': consumedScripts,
  };

  factory SaveData.fromJson(Map<String, dynamic> json) {
    final current = _migrateToCurrent(json);
    final partyList = (current['party'] as List<dynamic>? ?? [])
        .map((e) => PartyMember.fromJson(e as Map<String, dynamic>))
        .toList();

    return SaveData(
      slot: current['slot'] as int? ?? 1,
      slotName: current['slotName'] as String? ?? '본 게임 데이타',
      timestamp:
          DateTime.tryParse(current['timestamp'] as String? ?? '') ??
          DateTime.now(),
      mapId: current['mapId'] as int? ?? 6,
      mapTitle: current['mapTitle'] as String? ?? 'CASTLE LORE',
      playerX: current['playerX'] as int? ?? 51,
      playerY: current['playerY'] as int? ?? 31,
      gold: current['gold'] as int? ?? 2000,
      food: current['food'] as int? ?? 100,
      party: partyList,
      flags: Map<String, dynamic>.from(
        current['flags'] as Map<String, dynamic>? ?? const {},
      ),
      etc: (current['etc'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, v as int? ?? 0),
      ),
      mapTiles: (current['mapTiles'] as List<dynamic>? ?? const [])
          .map((v) => (v as num).toInt())
          .toList(),
      consumedScripts:
          (current['consumedScripts'] as List<dynamic>? ?? const [])
              .cast<String>(),
    );
  }

  static Map<String, dynamic> _migrateToCurrent(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version == null || version == 1) {
      // 기존 앱의 무버전 형식과 명시적 v1은 같은 필드를 사용한다.
      return {
        ...json,
        'schemaVersion': currentSchemaVersion,
        'etc': json['etc'] ?? const <String, int>{},
        'mapTiles': json['mapTiles'] ?? const <int>[],
        'consumedScripts': json['consumedScripts'] ?? const <String>[],
      };
    }
    if (version != currentSchemaVersion) {
      throw FormatException('지원하지 않는 저장 버전: $version');
    }
    return json;
  }
}

/// 1993년 원작 LOREMENU.PAS (GameOption: 4 슬롯 세이브/로드) 대응 매니저
class SaveManager {
  static final SaveManager instance = SaveManager._internal();
  factory SaveManager() => instance;
  SaveManager._internal();

  static const List<String> slotNames = [
    '본 게임 데이타 (Main)',
    '게임 데이타 1 (부)',
    '게임 데이타 2 (부)',
    '게임 데이타 3 (부)',
  ];

  static String _keyForSlot(int slot) => 'lore_save_slot_$slot';

  /// 슬롯에 저장 (1..4)
  Future<bool> saveGame(SaveData data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(data.toJson());
    return await prefs.setString(_keyForSlot(data.slot), jsonStr);
  }

  /// 슬롯에서 불러오기 (1..4)
  Future<SaveData?> loadGame(int slot) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyForSlot(slot));
    if (jsonStr == null) return null;
    try {
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      return SaveData.fromJson(jsonMap);
    } catch (_) {
      return null;
    }
  }

  /// 저장 데이터 존재 여부 확인
  Future<bool> hasSave(int slot) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyForSlot(slot));
  }

  /// 전체 4개 슬롯 요약 정보 확인
  Future<List<SaveData?>> getAllSlots() async {
    final List<SaveData?> list = [];
    for (int i = 1; i <= 4; i++) {
      list.add(await loadGame(i));
    }
    return list;
  }
}
