import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/party_member.dart';
import '../logic/lore_save_party.dart';
import '../logic/lore_load_failure.dart';

/// LORECRET.Last IOResult after Erase: the program cannot enter gameplay.
class LoreCreationMapEraseFailure implements Exception {
  const LoreCreationMapEraseFailure(this.slot, {this.cause});
  final int slot;
  final Object? cause;
  static const message = 'Can\'t delete " Save?.map ".';
  @override
  String toString() => message;
}

class SaveData {
  static const int currentSchemaVersion = 3;

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

  /// Native SaveN.map includes its own two-byte dimensions. Older Flutter
  /// saves omitted this header and still require the canonical map adapter.
  final int? mapWidth;
  final int? mapHeight;
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
    this.mapWidth,
    this.mapHeight,
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
    'mapWidth': mapWidth,
    'mapHeight': mapHeight,
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
      mapWidth: current['mapWidth'] as int?,
      mapHeight: current['mapHeight'] as int?,
      consumedScripts:
          (current['consumedScripts'] as List<dynamic>? ?? const [])
              .cast<String>(),
    );
  }

  static Map<String, dynamic> _migrateToCurrent(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version == null || version == 1 || version == 2) {
      // Old snapshots have no dimensions; retain their base-map adapter.
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

class SaveReadResult {
  final SaveData? data;
  final LoreLoadFailure? failure;
  const SaveReadResult.loaded(SaveData value) : data = value, failure = null;
  const SaveReadResult.failed(LoreLoadFailure value)
    : data = null,
      failure = value;
}

class _SaveRecordError implements Exception {
  final String kind;
  final Object cause;
  const _SaveRecordError(this.kind, this.cause);
}

/// 1993년 원작 LOREMENU.PAS (GameOption: 4 슬롯 세이브/로드) 대응 매니저
class SaveManager {
  static final SaveManager instance = SaveManager._internal();
  factory SaveManager() => instance;
  SaveManager._internal();

  static const List<String> slotNames = [
    '본 게임 데이타',
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
    return (await readGame(slot)).data;
  }

  /// The modern JSON file contains three logical source records: party info,
  /// six players and optional SaveN.map. Preserve their source failure labels.
  /// Legacy short lists/defaults remain a separate adapter, not truncated DOS IO.
  Future<SaveReadResult> readGame(int slot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyForSlot(slot));
      if (jsonStr == null) {
        return SaveReadResult.failed(
          LoreLoadFailure('party$slot.dat', needCreate: true),
        );
      }
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      return SaveReadResult.loaded(_readSourceRecords(jsonMap, slot));
    } on _SaveRecordError catch (e) {
      return SaveReadResult.failed(
        LoreLoadFailure(
          e.kind == 'save' ? 'save$slot.map' : '${e.kind}$slot.dat',
          needCreate: e.kind != 'save',
          cause: e.cause,
        ),
      );
    } catch (e) {
      return SaveReadResult.failed(
        LoreLoadFailure('party$slot.dat', needCreate: true, cause: e),
      );
    }
  }

  SaveData _readSourceRecords(Map<String, dynamic> raw, int slot) {
    final current = raw['schemaVersion'] == SaveData.currentSchemaVersion;
    if (current) {
      for (final field in ['mapId', 'playerX', 'playerY', 'gold', 'food']) {
        if (raw[field] is! int) {
          throw FormatException('missing/invalid party field: $field');
        }
      }
      if (raw['flags'] is! Map) {
        throw const FormatException('missing/invalid party flags');
      }
    }
    final members = <PartyMember>[];
    try {
      final rows = raw['party'];
      if (current && rows is! List) {
        throw const FormatException('missing player records');
      }
      final shape = PartyMember.zero().toJson();
      for (final row in (rows as List<dynamic>? ?? const []).take(6)) {
        final record = row as Map<String, dynamic>;
        if (current) {
          for (final field in shape.entries) {
            if (field.value is String
                ? record[field.key] is! String
                : record[field.key] is! int) {
              throw FormatException(
                'missing/invalid player field: ${field.key}',
              );
            }
          }
        }
        members.add(PartyMember.fromJson(record));
      }
    } catch (e) {
      throw _SaveRecordError('player', e);
    }
    try {
      for (final field in ['mapWidth', 'mapHeight']) {
        if (raw[field] != null && raw[field] is! int) {
          throw FormatException('invalid saved MAP header: $field');
        }
      }
      final tiles = raw['mapTiles'];
      if (tiles != null && (tiles is! List || tiles.any((v) => v is! num))) {
        throw const FormatException('invalid saved MAP payload');
      }
    } catch (e) {
      throw _SaveRecordError('save', e);
    }
    // Source reads only six player records, never trailing scratch/file data.
    // The selected slot, not untrusted JSON metadata, owns saveN.map's name.
    return SaveData.fromJson({
      ...raw,
      'slot': slot,
      'party': [for (final p in members) p.toJson()],
    });
  }

  /// LORECRET.PAS `Last`: the new party starts in map 6 (51,31) with food 20,
  /// gold 2000 and `etc[1..100] := 0`, and is written to all four slots
  /// (`party1..4.dat`, `player1..4.dat`; `Save1..4.map` are erased, so the
  /// original maps load). The JSON is built before the first await so later
  /// play cannot change what is written.
  Future<void> writeNewGame(
    List<PartyMember> party, {
    required String mapTitle,
  }) async {
    final now = DateTime.now();
    final sourceParty = LoreSaveParty.snapshot(party);
    final encoded = [
      for (var slot = 1; slot <= 4; slot++)
        jsonEncode(
          SaveData(
            slot: slot,
            slotName: slotNames[slot - 1],
            timestamp: now,
            mapId: 6,
            mapTitle: mapTitle,
            playerX: 51,
            playerY: 31,
            gold: 2000,
            food: 20,
            party: sourceParty,
            flags: const {},
          ).toJson(),
        ),
    ];
    final prefs = await SharedPreferences.getInstance();
    for (var slot = 1; slot <= 4; slot++) {
      final finalRecord = encoded[slot - 1];
      final previous = prefs.getString(_keyForSlot(slot));
      Map<String, dynamic>? old;
      if (previous != null) {
        // Last replaces records without reading obsolete map contents.
        // Undecodable combined JSON has no readable map attachment to retain.
        try {
          final value = jsonDecode(previous);
          if (value is Map<String, dynamic>) old = value;
        } on FormatException {
          old = null;
        }
      }
      final oldMap = old?['mapTiles'];
      final hasOldMap = oldMap is List && oldMap.isNotEmpty;
      final record = hasOldMap
          ? jsonEncode({
              ...jsonDecode(finalRecord) as Map<String, dynamic>,
              'mapTiles': oldMap,
              'mapWidth': old?['mapWidth'],
              'mapHeight': old?['mapHeight'],
            })
          : finalRecord;
      // Party/player are durable before the optional Erase(SaveN.map).
      if (!await prefs.setString(_keyForSlot(slot), record)) {
        try {
          await prefs.reload();
        } finally {
          throw StateError('Failed to write new-game slot $slot');
        }
      }
      if (hasOldMap) {
        Object? cause;
        var erased = false;
        try {
          erased = await prefs.setString(_keyForSlot(slot), finalRecord);
        } catch (error) {
          cause = error;
        }
        if (!erased) {
          // SharedPreferences updates its cache before durable completion.
          // Restore the committed record/map state before the native Halt.
          try {
            await prefs.reload();
          } finally {
            throw LoreCreationMapEraseFailure(slot, cause: cause);
          }
        }
      }
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
