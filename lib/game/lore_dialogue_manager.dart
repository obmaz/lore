/// 1993년 원작 LORETALK.PAS 및 LORESPEC.PAS 기반 대화 및 퀘스트 플래그 매니저
/// 4대 성/마을(6: CASTLE LORE, 7: LASTDITCH, 9: GAIA TERRA, 10: WATER FIELD)
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../logic/lore_join.dart';
import '../logic/lore_source_memory.dart';
import '../models/party_member.dart';

class LoreDialogueManager {
  static final LoreDialogueManager instance = LoreDialogueManager._internal();
  factory LoreDialogueManager() => instance;
  LoreDialogueManager._internal();

  // 1. CASTLE LORE 플래그 (맵 6)
  /// 원작 `party.etc[10]` - Lord Ahn 알현 대화 단계(0~6). `LORETALK.PAS:296`.
  int get lordAhnQuestStep => partyEtc.read(10);
  set lordAhnQuestStep(int value) => partyEtc[10] = value;
  bool metLordAhn = false;
  bool castleGateOpen = false;
  bool jrAntaresSecretFound = false;
  bool metPyramidSage = false;

  // 2. LASTDITCH 플래그 (맵 7 - party.etc[13])
  int get lastditchQuestStep => partyEtc.read(13);
  set lastditchQuestStep(int value) => partyEtc[13] = value;
  bool polarisJoined = false;

  // 3. GAIA TERRA 플래그 (맵 9 - party.etc[14])
  int get gaiaQuestStep => partyEtc.read(14);
  set gaiaQuestStep(int value) => partyEtc[14] = value;
  bool hasWaterKey = false;

  // 4. WATER FIELD 플래그 (맵 10 - party.etc[15])
  int get waterFieldQuestStep => partyEtc.read(15);
  set waterFieldQuestStep(int value) => partyEtc[15] = value;
  bool hasSwampKey = false;
  bool loreHunterJoined = false;

  // 던전 보스 격퇴 플래그
  bool bossMajorMummyDefeated = false;
  bool goldenSealFound = false;
  bool bossArchiGagoyleDefeated = false;
  bool bossHidraDefeated = false;
  bool bossHugeDragonDefeated = false;
  bool bossNecromancerDefeated = false;

  // 식량 및 기타 던전 이벤트 플래그
  bool foodTreeHarvested = false; // 맵 1 100인분 식량 나무
  bool draconianMet = false; // 맵 4 Draconian 천문학 지식

  // 원작 LORESPEC.PAS 동료 영입 / 특수 마법 플래그
  bool madJoeJoined = false; // 맵 6 (40,15) - 지하 감옥의 Mad Joe
  bool rigelJoined = false; // 맵 12 (12,48) - 사냥꾼 Rigel
  bool redAntaresJoined = false; // 맵 17 (75,52) - Red Antares
  bool spicaJoined = false; // 맵 18 (37,31) - Spica

  /// 원작 `party.etc[16] bit1` - 맵 4 (20,39)에서 Ancient Evil을 만난 상태.
  bool ancientEvilMet = false;

  /// 원작 `LORETALK.PAS` 의 `party.etc[50]`/`[30]`/`[43]` 비트 상태.
  ///
  ///  - `menaceInfoGiven`        = etc[50] bit5 (맵 6 (51,72) 피라밋 안내)
  ///  - `weaponRoomVisited`      = etc[50] bit4 (맵 6 무기고 방문)
  ///  - `loreChallengeAccepted`  = etc[30] bit1 (맵 6 (50,51) 도전 수락)
  ///  - `loreChallengeBlessed`   = etc[30] bit2 (맵 6 (51,87) 성문 축복)
  ///  - `programmerMet`          = etc[43] bit4 (맵 24 (33,10) 안 영기)
  bool menaceInfoGiven = false;
  bool weaponRoomVisited = false;
  bool loreChallengeAccepted = false;
  bool loreChallengeBlessed = false;
  bool programmerMet = false;

  /// 원작 `LORENT.PAS`/`LORESPEC.PAS` 후반부 상태 비트.
  ///
  ///  - `frostDragonDefeated`      = etc[44] bit1 (EVIL CONCENTRATION 입구 수문장)
  ///  - `dungeonOfEvilCleared`     = etc[44] bit2 (DUNGEON OF EVIL 입구 수문장)
  ///  - `ancientEvilSpeechGiven`   = etc[42] bit7 (IMPERIUM MINOR 입구 연출)
  ///  - `swampKeepBossDefeated`    = etc[42] bit1 (SWAMP KEEP 출구 전투)
  ///  - `evilShelterBossDefeated`  = etc[43] bit3 (LAST SHELTER 출구 전투)
  ///  - `lavaGateKeyLeft/Right`    = etc[40]/etc[41] 홀수(라바 게이트 봉인 해제)
  ///  - `lavaLeverLeft/RightPulled`= etc[45] bit7/bit8 (맵 25 레버)
  bool frostDragonDefeated = false;
  bool dungeonOfEvilCleared = false;
  bool ancientEvilSpeechGiven = false;
  bool swampKeepBossDefeated = false;
  bool evilShelterBossDefeated = false;
  bool lavaGateKeyLeft = false;
  bool lavaGateKeyRight = false;
  bool lavaLeverLeftPulled = false;
  bool lavaLeverRightPulled = false;

  /// 원작 `LOREBATT.PAS:245 CastSpecial` - 특수 마법 미습득 시 문구.
  static const String specialMagicLockedMessage = '당신에게는 아직 능력이 없다.';

  /// 원작 `party.etc[38] bit1` - Red Antares에게 "간접 공격" 6종 특수 마법 해금.
  bool specialMagicLearned = false;

  /// 원작 `party.etc[n]` 비트로 관리하던 1회성 금화 좌표 (`findgold`).
  /// 키 형식: `gold:<mapId>:<x>:<y>`
  final Set<String> collectedTreasures = {};

  /// 원작 `party.etc[N]` 바이트 배열 (N : 1..100).
  ///
  /// 원작은 `party.etc[N] and bitM` / `party.etc[N] or bitM` 로 마을·동굴의
  /// 진행 상황을 기록한다. 이름 있는 플래그는 기존 처리기를 위한 어댑터이며
  /// 원본 바이트 값과 퀘스트 단계는 이 저장소를 공유한다.
  final LorePartyEtc partyEtc = LorePartyEtc();
  final Map<String, bool> _scriptFlags = {};

  static final RegExp _etcFlagPattern = RegExp(r'^etc(\d+)_bit(\d+)$');

  static final RegExp _etcCounterFlagPattern = RegExp(r'^etc(\d+)$');

  /// `party.etc[N]`의 M번째 비트(1-based)가 켜져 있는지.
  bool etcBit(int n, int m) {
    if (m < 1 || m > 8) return false;
    return partyEtc.hasBit(n, m);
  }

  /// 원작 `party.etc[6]` - **마지막 전투의 결과**.
  ///
  ///  - `0`   승리
  ///  - `2`   도망 (`LOREBATT.PAS:1148`)
  ///  - `255` 전멸 (`LOREBATT.PAS:58`)
  ///
  /// 원작은 좌표 이벤트에서 `if party.etc[6] = 0 then`(승리 후 보상) /
  /// `= 255 then exit`(전멸) 로 갈라지므로, 같은 판정이 가능하도록 기록한다.
  int get lastBattleResult => partyEtc[6] ?? 0;

  /// 전투 결과를 기록한다(원작 `party.etc[6] := v`).
  void setBattleResult(int value) => partyEtc[6] = value;

  /// `party.etc[N] := party.etc[N] or bitM` / 비트 해제.
  void setEtcBit(int n, int m, [bool value = true]) {
    if (m < 1 || m > 8) return;
    partyEtc.setBit(n, m, value);
  }

  /// 이름 하나로 `party.etc` 비트/카운터를 읽거나 쓴다.
  /// - `etc32_bit8` → 비트 플래그
  /// - `etc5`        → 정수 카운터 (0이면 꺼진 것으로 본다)
  bool etcFlagValue(String name) {
    final bit = _etcFlagPattern.firstMatch(name);
    if (bit != null) {
      return etcBit(int.parse(bit.group(1)!), int.parse(bit.group(2)!));
    }
    final counter = _etcCounterFlagPattern.firstMatch(name);
    if (counter != null) {
      return (partyEtc[int.parse(counter.group(1)!)] ?? 0) != 0;
    }
    return false;
  }

  /// 이름 하나로 `party.etc` 비트/카운터를 설정한다.
  void setEtcFlagValue(String name, bool value) {
    final bit = _etcFlagPattern.firstMatch(name);
    if (bit != null) {
      setEtcBit(int.parse(bit.group(1)!), int.parse(bit.group(2)!), value);
      return;
    }
    final counter = _etcCounterFlagPattern.firstMatch(name);
    if (counter != null) {
      final n = int.parse(counter.group(1)!);
      if (value) {
        partyEtc[n] = (partyEtc[n] ?? 0) == 0 ? 1 : partyEtc[n]!;
      } else {
        partyEtc[n] = 0;
      }
    }
  }

  /// 원작 `LORESUB.PAS:1042 join(num, partynum)` 대기열.
  /// 대화에서 동료 영입이 확정되면 여기에 적재되고, 화면단에서 실제 파티에
  /// 추가한 뒤 [takePendingRecruits]로 비운다.
  final List<PendingRecruit> _pendingRecruits = [];

  /// 대기 중인 동료 영입 목록을 비우면서 가져간다.
  List<PendingRecruit> takePendingRecruits() {
    final recruits = List<PendingRecruit>.from(_pendingRecruits);
    _pendingRecruits.clear();
    return recruits;
  }

  // 원작 25단계 예언 목록 (LORESUB.PAS: Predict_Data)
  static const List<String> predictData = [
    'Lord Ahn 을 만날',
    'MENACE를 탐험할',
    'Lord Ahn에게 다시 돌아갈',
    'LASTDITCH로 갈',
    'LASTDITCH의 성주를 만날',
    'PYRAMID 속의 Major Mummy를 물리칠',
    'LASTDITCH의 성주에게로 돌아갈',
    'LASTDITCH의 GROUND GATE로 갈',
    'GAIA TERRA의 성주를 만날',
    'EVIL SEAL에서 황금의 봉인을 발견할',
    'GAIA TERRA의 성주에게 돌아갈',
    'QUAKE에서 ArchiGagoyle를 물리칠',
    '북동쪽의 WIVERN 동굴에 갈',
    'WATER FIELD로 갈',
    'WATER FIELD의 군주를 만날',
    'NOTICE 속의 Hidra를 물리칠',
    'LOCKUP 속의 Dragon을 물리칠',
    'GAIA TERRA 의 SWAMP GATE로 갈',
    '위쪽의 게이트를 통해 SWAMP KEEP으로 갈',
    'SWAMP 대륙에 존재하는 두개의 봉인을 풀',
    'SWAMP KEEP의 라바 게이트를 작동 시킬',
    '적의 집결지인 EVIL CONCENTRATION으로 갈',
    '숨겨진 적의 마지막 요새로 들어갈',
    '위쪽의 동굴에서 Necromancer를 만날',
    'Necromancer와 마지막 결전을 벌일',
  ];

  int get currentQuestStep {
    if (!metLordAhn) return 1;
    if (!jrAntaresSecretFound) return 2;
    if (!castleGateOpen) return 3;
    if (lastditchQuestStep == 0) return 4;
    if (lastditchQuestStep == 1 && !bossMajorMummyDefeated) return 6;
    if (lastditchQuestStep == 1 && bossMajorMummyDefeated) return 7;
    if (lastditchQuestStep >= 2 && gaiaQuestStep == 0) return 8;
    if (gaiaQuestStep == 1 && !goldenSealFound) return 10;
    if (gaiaQuestStep == 1 && goldenSealFound) return 11; // 구형 저장 호환
    if (gaiaQuestStep == 2) return 11; // 봉인을 찾고 성주에게 보고 전
    if (gaiaQuestStep >= 3 && !bossArchiGagoyleDefeated) return 12;
    if (gaiaQuestStep >= 3 && waterFieldQuestStep == 0) return 14;
    if (waterFieldQuestStep == 1 && !bossHidraDefeated) return 16;
    if (waterFieldQuestStep >= 2 && !bossHugeDragonDefeated) return 17;
    if (hasSwampKey) return 18;
    return 19;
  }

  String getProphecy() {
    final idx = currentQuestStep - 1;
    if (idx >= 0 && idx < predictData.length) {
      return '당신은 ${predictData[idx]} 것이다';
    }
    return '당신은 어떤 힘에 의해 예언을 방해 받고 있다';
  }

  Map<String, dynamic> getSaveFlags() => {
    'metLordAhn': metLordAhn,
    'castleGateOpen': castleGateOpen,
    'lordAhnQuestStep': lordAhnQuestStep,
    'jrAntaresSecretFound': jrAntaresSecretFound,
    'metPyramidSage': metPyramidSage,
    'lastditchQuestStep': lastditchQuestStep,
    'polarisJoined': polarisJoined,
    'gaiaQuestStep': gaiaQuestStep,
    'hasWaterKey': hasWaterKey,
    'waterFieldQuestStep': waterFieldQuestStep,
    'hasSwampKey': hasSwampKey,
    'loreHunterJoined': loreHunterJoined,
    'bossMajorMummyDefeated': bossMajorMummyDefeated,
    'goldenSealFound': goldenSealFound,
    'bossArchiGagoyleDefeated': bossArchiGagoyleDefeated,
    'bossHidraDefeated': bossHidraDefeated,
    'bossHugeDragonDefeated': bossHugeDragonDefeated,
    'bossNecromancerDefeated': bossNecromancerDefeated,
    'foodTreeHarvested': foodTreeHarvested,
    'draconianMet': draconianMet,
    'madJoeJoined': madJoeJoined,
    'rigelJoined': rigelJoined,
    'redAntaresJoined': redAntaresJoined,
    'spicaJoined': spicaJoined,
    'specialMagicLearned': specialMagicLearned,
    'ancientEvilMet': ancientEvilMet,
    'menaceInfoGiven': menaceInfoGiven,
    'weaponRoomVisited': weaponRoomVisited,
    'loreChallengeAccepted': loreChallengeAccepted,
    'loreChallengeBlessed': loreChallengeBlessed,
    'programmerMet': programmerMet,
    'frostDragonDefeated': frostDragonDefeated,
    'dungeonOfEvilCleared': dungeonOfEvilCleared,
    'ancientEvilSpeechGiven': ancientEvilSpeechGiven,
    'swampKeepBossDefeated': swampKeepBossDefeated,
    'evilShelterBossDefeated': evilShelterBossDefeated,
    'lavaGateKeyLeft': lavaGateKeyLeft,
    'lavaGateKeyRight': lavaGateKeyRight,
    'lavaLeverLeftPulled': lavaLeverLeftPulled,
    'lavaLeverRightPulled': lavaLeverRightPulled,
    // 1회성 보물 좌표(원작 party.etc 비트)는 불리언 플래그로 직렬화한다.
    for (final key in collectedTreasures) key: true,
    // 원작 `party.etc[N]` 비트/카운터도 그대로 보존한다.
    for (final entry in partyEtc.entries) 'etc${entry.key}': entry.value,
    'scriptFlags': Map<String, bool>.from(_scriptFlags),
  };

  Map<String, bool> getFlagsCopy() => {
    'metLordAhn': metLordAhn,
    'castleGateOpen': castleGateOpen,
    'jrAntaresSecretFound': jrAntaresSecretFound,
    'metPyramidSage': metPyramidSage,
    'polarisJoined': polarisJoined,
    'hasWaterKey': hasWaterKey,
    'hasSwampKey': hasSwampKey,
    'loreHunterJoined': loreHunterJoined,
    'bossMajorMummyDefeated': bossMajorMummyDefeated,
    'goldenSealFound': goldenSealFound,
    'bossArchiGagoyleDefeated': bossArchiGagoyleDefeated,
    'bossHidraDefeated': bossHidraDefeated,
    'bossHugeDragonDefeated': bossHugeDragonDefeated,
    'bossNecromancerDefeated': bossNecromancerDefeated,
    'foodTreeHarvested': foodTreeHarvested,
    'draconianMet': draconianMet,
    'madJoeJoined': madJoeJoined,
    'rigelJoined': rigelJoined,
    'redAntaresJoined': redAntaresJoined,
    'spicaJoined': spicaJoined,
    'specialMagicLearned': specialMagicLearned,
    'ancientEvilMet': ancientEvilMet,
    'menaceInfoGiven': menaceInfoGiven,
    'weaponRoomVisited': weaponRoomVisited,
    'loreChallengeAccepted': loreChallengeAccepted,
    'loreChallengeBlessed': loreChallengeBlessed,
    'programmerMet': programmerMet,
    'frostDragonDefeated': frostDragonDefeated,
    'dungeonOfEvilCleared': dungeonOfEvilCleared,
    'ancientEvilSpeechGiven': ancientEvilSpeechGiven,
    'swampKeepBossDefeated': swampKeepBossDefeated,
    'evilShelterBossDefeated': evilShelterBossDefeated,
    'lavaGateKeyLeft': lavaGateKeyLeft,
    'lavaGateKeyRight': lavaGateKeyRight,
    'lavaLeverLeftPulled': lavaLeverLeftPulled,
    'lavaLeverRightPulled': lavaLeverRightPulled,
    ..._scriptFlags,
    for (final key in collectedTreasures) key: true,
    // Raw bytes, including zero/unset bits, override stale legacy aliases.
    for (final entry in partyEtc.entries)
      for (var m = 1; m <= 8; m++)
        'etc${entry.key}_bit$m': ((entry.value >> (m - 1)) & 1) == 1,
    for (final entry in partyEtc.entries) 'etc${entry.key}': entry.value != 0,
    if (partyEtc.containsKey(40)) ...{
      'evilSealRoomCleared': partyEtc.hasBit(40, 1),
      'etc40_bit1': partyEtc.hasBit(40, 1),
      for (var room = 1; room <= 7; room++)
        'evilSealRoom$room': (partyEtc.read(40) >> 1) == room,
    },
    if (partyEtc.containsKey(45)) ...{
      'keep3KeyA': partyEtc.hasBit(45, 7),
      'keep3KeyB': partyEtc.hasBit(45, 8),
    },
  };

  void loadSaveFlags(
    Map<String, dynamic> flags, {
    Map<String, int>? fieldCounters,
  }) {
    final knownSaveKeys = getSaveFlags().keys.toSet();
    partyEtc.clear();
    metLordAhn = flags['metLordAhn'] == true;
    castleGateOpen = flags['castleGateOpen'] == true;
    lordAhnQuestStep = flags['lordAhnQuestStep'] as int? ?? 0;
    jrAntaresSecretFound = flags['jrAntaresSecretFound'] == true;
    metPyramidSage = flags['metPyramidSage'] == true;
    lastditchQuestStep =
        (flags['lastditchQuestStep'] as int?) ??
        (flags['bossMajorMummyDefeated'] == true ? 2 : 0);
    polarisJoined = flags['polarisJoined'] == true;
    gaiaQuestStep =
        (flags['gaiaQuestStep'] as int?) ??
        (flags['bossArchiGagoyleDefeated'] == true
            ? 3
            : (flags['goldenSealFound'] == true ? 2 : 0));
    hasWaterKey = flags['hasWaterKey'] == true;
    waterFieldQuestStep =
        (flags['waterFieldQuestStep'] as int?) ??
        (flags['bossHugeDragonDefeated'] == true
            ? 3
            : (flags['bossHidraDefeated'] == true ? 2 : 0));
    hasSwampKey = flags['hasSwampKey'] == true;
    loreHunterJoined = flags['loreHunterJoined'] == true;
    bossMajorMummyDefeated = flags['bossMajorMummyDefeated'] == true;
    goldenSealFound = flags['goldenSealFound'] == true;
    bossArchiGagoyleDefeated = flags['bossArchiGagoyleDefeated'] == true;
    bossHidraDefeated = flags['bossHidraDefeated'] == true;
    bossHugeDragonDefeated = flags['bossHugeDragonDefeated'] == true;
    bossNecromancerDefeated = flags['bossNecromancerDefeated'] == true;
    foodTreeHarvested = flags['foodTreeHarvested'] == true;
    draconianMet = flags['draconianMet'] == true;
    madJoeJoined = flags['madJoeJoined'] == true;
    rigelJoined = flags['rigelJoined'] == true;
    redAntaresJoined = flags['redAntaresJoined'] == true;
    spicaJoined = flags['spicaJoined'] == true;
    specialMagicLearned = flags['specialMagicLearned'] == true;
    ancientEvilMet = flags['ancientEvilMet'] == true;
    menaceInfoGiven = flags['menaceInfoGiven'] == true;
    weaponRoomVisited = flags['weaponRoomVisited'] == true;
    loreChallengeAccepted = flags['loreChallengeAccepted'] == true;
    loreChallengeBlessed = flags['loreChallengeBlessed'] == true;
    programmerMet = flags['programmerMet'] == true;
    frostDragonDefeated = flags['frostDragonDefeated'] == true;
    dungeonOfEvilCleared = flags['dungeonOfEvilCleared'] == true;
    ancientEvilSpeechGiven = flags['ancientEvilSpeechGiven'] == true;
    swampKeepBossDefeated = flags['swampKeepBossDefeated'] == true;
    evilShelterBossDefeated = flags['evilShelterBossDefeated'] == true;
    lavaGateKeyLeft = flags['lavaGateKeyLeft'] == true;
    lavaGateKeyRight = flags['lavaGateKeyRight'] == true;
    lavaLeverLeftPulled = flags['lavaLeverLeftPulled'] == true;
    lavaLeverRightPulled = flags['lavaLeverRightPulled'] == true;
    _scriptFlags
      ..clear()
      ..addAll(
        (flags['scriptFlags'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value == true),
            ) ??
            const <String, bool>{},
      );
    // 구형 저장 파일은 getFlagsCopy()의 동적 플래그를 최상위에 저장했다.
    for (final entry in flags.entries) {
      if (entry.value is bool &&
          !knownSaveKeys.contains(entry.key) &&
          !entry.key.startsWith('gold:') &&
          !_etcCounterFlagPattern.hasMatch(entry.key) &&
          !_etcFlagPattern.hasMatch(entry.key)) {
        _scriptFlags[entry.key] = entry.value as bool;
      }
    }
    collectedTreasures
      ..clear()
      ..addAll(
        flags.entries
            .where(
              (entry) => entry.key.startsWith('gold:') && entry.value == true,
            )
            .map((entry) => entry.key),
      );
    final etcBits = <int, int>{};
    for (final entry in flags.entries) {
      final bit = _etcFlagPattern.firstMatch(entry.key);
      if (bit == null || entry.value != true) continue;
      final n = int.parse(bit.group(1)!);
      final m = int.parse(bit.group(2)!);
      if (m >= 1 && m <= 8) {
        etcBits[n] = (etcBits[n] ?? 0) | (1 << (m - 1));
      }
    }
    for (final entry in flags.entries) {
      final counter = _etcCounterFlagPattern.firstMatch(entry.key);
      if (counter == null) continue;
      final n = int.parse(counter.group(1)!);
      final value = entry.value;
      if (value is num) {
        partyEtc[n] = value.toInt();
      } else if (value == true) {
        // 구형 불리언 etcN은 0이 아님만 뜻한다. 비트 플래그가 있으면
        // 그 비트들이 정확한 원본 값을 나타낸다.
        partyEtc[n] = etcBits[n] ?? 1;
      }
    }
    for (final entry in etcBits.entries) {
      partyEtc.putIfAbsent(entry.key, () => entry.value);
    }
    // Legacy JSON saves kept the shifted room number in named flags. Recover
    // it once; numeric raw bytes, including zero, always take precedence.
    if (flags['etc40'] is! num) {
      final savedFlags = {..._scriptFlags, ...flags};
      final rooms = [
        for (var room = 1; room <= 7; room++)
          if (savedFlags['evilSealRoom$room'] == true) room,
      ];
      final sealBit =
          savedFlags['etc40_bit1'] == true ||
              savedFlags['evilSealRoomCleared'] == true
          ? 1
          : 0;
      if (rooms.isNotEmpty || sealBit != 0) {
        partyEtc[40] =
            (rooms.isEmpty ? (partyEtc.read(40) & 254) : rooms.last << 1) |
            sealBit;
      }
    }
    if (fieldCounters != null) {
      for (final entry in LorePartyEtc.fieldSlots.entries) {
        // A legacy Boolean etc3 means only "active", not a one-step timer.
        // Its separate numeric counter is more precise; a raw number wins.
        if (flags['etc${entry.value}'] is! num &&
            fieldCounters.containsKey(entry.key)) {
          partyEtc[entry.value] = fieldCounters[entry.key]!;
        }
      }
      partyEtc.restoreFieldCounters(const {});
    }
  }

  void loadFlags(
    Map<String, dynamic> flags, {
    Map<String, int>? fieldCounters,
  }) => loadSaveFlags(flags, fieldCounters: fieldCounters);

  // =========================================================================
  // JSON 대화 테이블 (assets/data/dialogues.json)
  // =========================================================================

  List<_DialogueEntry> _jsonDialogues = [];
  bool _loadedDialogues = false;

  /// JSON 대화 테이블을 사용 중인지(테스트/디버깅용).
  bool usingJsonDialogues = false;
  String? dialoguesLoadError;

  /// `assets/data/dialogues.json`을 읽는다.
  ///
  /// JSON에 있는 좌표는 JSON 문구를 우선 사용하고, 플래그/퀘스트 분기가 필요한
  /// 대화는 기존 Dart 로직이 그대로 처리한다.
  Future<void> loadData({AssetBundle? bundle}) async {
    if (_loadedDialogues) return;
    try {
      final decoded = json.decode(
        await (bundle ?? rootBundle).loadString('assets/data/dialogues.json'),
      ) as Map<String, dynamic>;
      _jsonDialogues = (decoded['dialogues'] as List<dynamic>)
          .map((e) => _DialogueEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      usingJsonDialogues = true;
    } catch (e) {
      _jsonDialogues = [];
      usingJsonDialogues = false;
      dialoguesLoadError = e.toString();
    }
    _loadedDialogues = true;
  }

  void resetDataForTest() {
    _loadedDialogues = false;
    usingJsonDialogues = false;
    dialoguesLoadError = null;
    _jsonDialogues = [];
  }

  /// JSON 대화 테이블에서 좌표 대사를 찾는다 (`{hero}`는 주인공 이름으로 치환).
  String? _jsonDialogue(int mapId, int tx, int ty, String heroName) {
    for (final e in _jsonDialogues) {
      if (e.map == mapId && e.x == tx && e.y == ty) {
        return e.text.replaceAll('{hero}', heroName);
      }
    }
    return null;
  }

  /// JSON 스크립트(`{"flag": "이름"}`)로 플래그를 설정한다.
  ///
  /// 별도 필드가 없는 스크립트 플래그도 저장 파일에 보존한다.
  void setFlag(String name, [bool value = true]) {
    // 원작 `party.etc[N]` 비트/카운터 이름은 동적으로 처리한다.
    if (_etcFlagPattern.hasMatch(name) ||
        _etcCounterFlagPattern.hasMatch(name)) {
      setEtcFlagValue(name, value);
      return;
    }
    switch (name) {
      case 'metLordAhn':
        metLordAhn = value;
      case 'castleGateOpen':
        castleGateOpen = value;
      case 'jrAntaresSecretFound':
        jrAntaresSecretFound = value;
      case 'metPyramidSage':
        metPyramidSage = value;
      case 'polarisJoined':
        polarisJoined = value;
      case 'hasWaterKey':
        hasWaterKey = value;
      case 'hasSwampKey':
        hasSwampKey = value;
      case 'loreHunterJoined':
        loreHunterJoined = value;
      case 'bossMajorMummyDefeated':
        bossMajorMummyDefeated = value;
      case 'goldenSealFound':
        goldenSealFound = value;
      case 'bossArchiGagoyleDefeated':
        bossArchiGagoyleDefeated = value;
      case 'bossHidraDefeated':
        bossHidraDefeated = value;
      case 'bossHugeDragonDefeated':
        bossHugeDragonDefeated = value;
      case 'bossNecromancerDefeated':
        bossNecromancerDefeated = value;
      case 'foodTreeHarvested':
        foodTreeHarvested = value;
      case 'draconianMet':
        draconianMet = value;
      case 'madJoeJoined':
        madJoeJoined = value;
      case 'rigelJoined':
        rigelJoined = value;
      case 'redAntaresJoined':
        redAntaresJoined = value;
      case 'spicaJoined':
        spicaJoined = value;
      case 'specialMagicLearned':
        specialMagicLearned = value;
      case 'ancientEvilMet':
        ancientEvilMet = value;
      case 'menaceInfoGiven':
        menaceInfoGiven = value;
      case 'weaponRoomVisited':
        weaponRoomVisited = value;
      case 'loreChallengeAccepted':
        loreChallengeAccepted = value;
      case 'loreChallengeBlessed':
        loreChallengeBlessed = value;
      case 'programmerMet':
        programmerMet = value;
      case 'frostDragonDefeated':
        frostDragonDefeated = value;
      case 'dungeonOfEvilCleared':
        dungeonOfEvilCleared = value;
      case 'ancientEvilSpeechGiven':
        ancientEvilSpeechGiven = value;
      case 'swampKeepBossDefeated':
        swampKeepBossDefeated = value;
      case 'evilShelterBossDefeated':
        evilShelterBossDefeated = value;
      case 'lavaGateKeyLeft':
        lavaGateKeyLeft = value;
      case 'lavaGateKeyRight':
        lavaGateKeyRight = value;
      case 'lavaLeverLeftPulled':
        lavaLeverLeftPulled = value;
      case 'lavaLeverRightPulled':
        lavaLeverRightPulled = value;
      default:
        _scriptFlags[name] = value;
    }
  }

  // ==========================================
  // 원작 4대 성/마을(6, 7, 9, 10) 고유 대화 조회 (LORETALK.PAS)
  // ==========================================
  /// 좌표 기반 대화 조회 (원작 LORETALK.PAS `talkmode` / LORESPEC.PAS `specialevent`).
  ///
  /// [party]와 [mindReadCount]는 LORESPEC의 조건 분기(예: Spica는 독심술 사용
  /// 가능 상태에서 초능력 Lv.5 이상이어야 함)에 필요하다.
  String? getDialogue(
    int mapId,
    int tx,
    int ty,
    String heroName, {
    List<PartyMember>? party,
    int mindReadCount = 0,
  }) {
    // 1순위: JSON 대화 테이블 (assets/data/dialogues.json)
    final fromJson = _jsonDialogue(mapId, tx, ty, heroName);
    if (fromJson != null) return fromJson;

    switch (mapId) {
      case 6: // CASTLE LORE (성도)
        return _getCastleLoreDialogue(tx, ty, heroName);
      case 7: // LASTDITCH (2번 성)
        return _getLastditchDialogue(tx, ty, heroName);
      case 9: // GAIA TERRA / VALIANT PEOPLES (3번 성)
        return _getGaiaTerraDialogue(tx, ty, heroName);
      case 10: // WATER FIELD (4번 성)
        return _getWaterFieldDialogue(tx, ty, heroName);
      case 12: // T_DEN2 (LORESPEC.PAS:600 - Rigel)
        return _getDen2Dialogue(tx, ty);
      case 17: // NOTICE 동굴 (LORESPEC.PAS:1010 - Red Antares)
        return _getNoticeDenDialogue(tx, ty);
      case 18: // LOCKUP 동굴 (LORESPEC.PAS:1208 - Spica)
        return _getLockupDenDialogue(tx, ty, party, mindReadCount);
      default:
        return null;
    }
  }

  // ------------------------------------------
  // LORESPEC.PAS 잔여 좌표 이벤트 (동료 영입)
  // ------------------------------------------

  /// 맵 12 T_DEN2: `on(12,48)` - 사냥꾼 Rigel (LORESPEC.PAS:600)
  String? _getDen2Dialogue(int tx, int ty) {
    if (tx != 12 || ty != 48) return null;
    if (rigelJoined) {
      return 'Rigel: "이제 힘을 되찾았소. 함께 Necromancer를 무찌릅시다!"';
    }
    rigelJoined = true;
    _pendingRecruits.add(PendingRecruit(LoreJoin.rigel()));
    return '일행들은 심한 부상 때문에 거의 몸을 가누지 못하는 한 남자와 마주쳤다.\n'
        'Rigel: "나는 VALIANT PEOPLES의 용사였던 Rigel이오. 내가 동굴속에서 적들을 막아내는 동안 지각변동으로 인해 이런 절벽이 군데 군데 생겼소. 나는 이제 너무 지치고 많은 상처를 입어서 혼자 힘으로는 이곳을 빠져 나갈수가 없소. 나를 도와 주시오."\n'
        '(원작 선택지: 좋소, 같이 모험을 합시다 / 식량과 치료는 해결해 주겠소 / 당신을 도와줄 시간이 없소)\n'
        '★ 동료 Rigel 합류! (원작과 동일하게 hp 1의 빈사 상태로 합류합니다)';
  }

  /// 맵 17 NOTICE 동굴: `on(75,52)` - Red Antares (LORESPEC.PAS:1026~1105)
  ///
  /// 스크립트(`require.quest`)가 쓰는 퀘스트 이름 → 단계 값.
  ///
  /// 이름은 원작 `party.etc[n]` 에 대응한다:
  ///  - `lordahn`  = etc[10] (Lord Ahn 알현 단계)
  ///  - `lastditch`= etc[13] (LASTDITCH 성주 퀘스트)
  ///  - `gaia`     = etc[14] (GAIA TERRA 성주 퀘스트)
  ///  - `water`    = etc[15] (WATER FIELD 성주 퀘스트)
  ///  - `wivern`   = etc[37] (남은 Wivern 수문장 진행)
  int questStepValue(String name) {
    switch (name) {
      case 'lordahn':
        return lordAhnQuestStep;
      case 'lastditch':
        return lastditchQuestStep;
      case 'gaia':
        return gaiaQuestStep;
      case 'water':
        return waterFieldQuestStep;
      case 'wivern':
        return partyEtc[37] ?? 0;
      default:
        return 0;
    }
  }

  Map<String, int> get questSteps => {
    'lordahn': lordAhnQuestStep,
    'lastditch': lastditchQuestStep,
    'gaia': gaiaQuestStep,
    'water': waterFieldQuestStep,
    'wivern': partyEtc[37] ?? 0,
  };

  /// 스크립트의 `questStep` 스텝을 적용한다 (원작 `inc(party.etc[n])` / `:= n`).
  void applyQuestStep(String name, {int? set, int? inc}) {
    final value = set ?? (questStepValue(name) + (inc ?? 0));
    switch (name) {
      case 'lordahn':
        lordAhnQuestStep = value;
        break;
      case 'lastditch':
        lastditchQuestStep = value;
        break;
      case 'gaia':
        gaiaQuestStep = value;
        break;
      case 'water':
        waterFieldQuestStep = value;
        break;
      case 'wivern':
        partyEtc[37] = value;
        break;
    }
  }

  /// 원작은 `party.etc[38]` 비트로 2단계를 관리한다.
  /// 1단계(bit1 미설정): "간접 공격" 특수 마법 6종을 전수받는다.
  /// 2단계(bit1 설정, bit2 미설정): 영혼이 일행에 합류한다.
  String? _getNoticeDenDialogue(int tx, int ty) {
    if (tx != 75 || ty != 52) return null;

    if (!specialMagicLearned) {
      specialMagicLearned = true;
      return '갑자기 주위가 용암으로 변하면서 한 영혼이 당신앞에 나타났다.\n'
          'Red Antares: "나는 고대의 강력한 마법사였던 Red Antares의 영혼이오. 나는 그가 이 동굴을 요새화 시킬때 이미 그의 마법 능력을 지켜 보았기 때문에 그의 능력을 알수 있었소. 그래서 당신들을 위해 나의 마법중 \'간접 공격\'이란 기법을 전해 주겠소."\n'
          '1. 독 - 적을 중독 시킴   2. 기술 무력화 - 적의 특수 공격 능력 제거\n'
          '3. 방어 무력화 - 적의 방어력 감소   4. 능력 저하 - 적의 모든 능력 감소\n'
          '5. 마법 불능 - 적의 마법 능력 제거   6. 탈초인화 - 적의 초자연력 제거\n'
          '★ 이제 전투에서 특수 마법(4번 항목)을 사용할 수 있습니다!';
    }

    if (!redAntaresJoined) {
      redAntaresJoined = true;
      _pendingRecruits.add(PendingRecruit(LoreJoin.redAntares()));
      return 'Red Antares: "당신들의 결의를 보았소. 내 영혼이 당신들의 마법을 돕겠소."\n'
          '★ 동료 Red Antares 합류! (원작과 동일하게 hp 0의 상태입니다)';
    }

    return 'Red Antares의 영혼이 조용히 빛나고 있습니다.';
  }

  /// 맵 18 LOCKUP 동굴: `on(37,31)` - Spica (LORESPEC.PAS:1208)
  ///
  /// 원작은 `party.etc[5] > 0`(독심술 사용 가능) 과 파티 최고 초능력 레벨 5 이상을
  /// 요구한다. 조건을 만족하지 못하면 마음을 읽을 수 없다는 메시지만 나온다.
  String? _getLockupDenDialogue(
    int tx,
    int ty,
    List<PartyMember>? party,
    int mindReadCount,
  ) {
    if (tx != 37 || ty != 31) return null;

    if (spicaJoined) {
      return 'Spica: "저도 힘을 보태겠습니다. Necromancer를 무찌릅시다!"';
    }

    final maxEspLevel = party == null || party.isEmpty
        ? 0
        : party.map((p) => p.espLevel).reduce(max);

    if (mindReadCount <= 0 || maxEspLevel < 5) {
      return 'Spica: "당신이 나의 마음을 읽으려 하지만 아직 당신의 능력으로는 나의 마음을 끌어낼수는 없습니다."\n'
          '(원작 조건: 독심술(ESP) 사용 가능 상태에서 파티 최고 초능력 레벨 5 이상)';
    }

    spicaJoined = true;
    _pendingRecruits.add(PendingRecruit(LoreJoin.spica()));
    return '갑자기 Necromancer에게 대항 하고픈 결의가 생기는 군요.\n'
        'Spica: "나도 당신들을 도와 그를 무찌르겠습니다."\n'
        '(원작 선택지: 저도 원했던 바입니다 / 말씀은 고맙지만 사양하겠습니다)\n'
        '★ 동료 Spica 합류!';
  }

  // ------------------------------------------
  // 1. CASTLE LORE (맵 6)
  // ------------------------------------------
  String? _getCastleLoreDialogue(int tx, int ty, String heroName) {
    if (tx == 9 && ty == 64) {
      return '경비병: "당신이 모험을 시작한다면, 많은 괴물들을 만날 것이오. Serpent와 Insects와 Python은 맹독이 있으니 주의 하시기 바라오."';
    }
    if (tx == 72 && ty == 73) {
      return '마을 주민: "Orc는 가장 하급 괴물이오."';
    }
    if (tx == 58 && ty == 74) {
      return '마을 주민: "나의 부모님은 Python의 독에 의해 돌아가셨습니다. Python은 정말 위험한 존재입니다."';
    }
    if (tx == 63 && ty == 27) {
      return '학자: "단지 Lord Ahn 성주님만이 능력상으로 Necromancer에게 도전할 수 있습니다. 하지만 성주님 자신이 대립을 싫어하셔서 현재는 대항할 자가 없습니다."';
    }
    // 원작 LORETALK.PAS:191 `at(40,15)` - 지하 감옥의 Mad Joe
    // (원작은 `k := 6` 으로 6번 슬롯에 고정 합류시킨다)
    if (tx == 40 && ty == 15) {
      if (!madJoeJoined) {
        madJoeJoined = true;
        _pendingRecruits.add(
          PendingRecruit(LoreJoin.madJoe(), forcedSlotOption: 4),
        );
        return 'Mad Joe: "히히히... 위대한 용사님. 낄낄낄.. 내가 당신들의 일행에 끼이면 안될까요 ? 우히히히.."\n'
            '(원작 선택지: 그렇다면 당신을 받아들이지요 / 당신은 이곳에 그냥 있는게 낫겠소)\n'
            '★ 동료 Mad Joe 합류! (원작과 동일하게 6번 슬롯 고정)';
      }
      return 'Mad Joe: "히히히.. 이제 나도 일행이지요 ?"';
    }
    if (tx == 90 && ty == 82) {
      return '주민: "우리는 Ancient Evil을 배척하고 Lord Ahn 님을 받들어야 합니다."';
    }
    if (tx == 94 && ty == 68) {
      return '사냥꾼: "우리는 MENACE 동쪽에 있는 나무로부터 많은 식량을 얻은 적이 있습니다."';
    }
    if (tx == 19 && ty == 53) {
      return '고대 석판: "이 세계의 창시자는 문동욱 님이시며, 그는 위대한 1993년의 프로그래머입니다."';
    }
    if ((tx == 13 || tx == 18) && ty == 27) {
      return '주점 바텐더: "어서 오십시오. 여기는 LORE 주점입니다. 위스키에서 칵테일까지 마음껏 선택하십시오."';
    }
    if (tx == 10 && ty == 30) {
      return '손님: "요새 성내 무덤 쪽에서 유령이 떠돈다던데..."';
    }
    if (tx == 13 && ty == 32) {
      return '손님: "하하하, 자네도 시원하게 한잔 마셔보게나!"';
    }
    if (tx == 15 && ty == 35) {
      return '취객: "이제 Lord Ahn의 시대도 끝나가는가? 그까짓 Necromancer라는 작자에게 쩔쩔 매다니... 차라리 내가 나가서 싸우는게 낫겠다."';
    }
    if (tx == 18 && ty == 33) {
      return '주민: "Skeleton 족의 한 명이 우리와 함께 생활하려 한다는 것에 대해 어떻게 생각하십니까? 어서 그 해골을 쫓아냈으면 좋겠습니다."';
    }
    if (tx == 72 && ty == 78) {
      return '묘지기: "물러나십시오. 여기는 전사한 용사들의 유골들을 안치해 놓은 신성한 곳입니다."';
    }
    if (tx == 63 && ty == 76) {
      if (!jrAntaresSecretFound) {
        jrAntaresSecretFound = true;
        return '기사 Jr. Antares의 영혼: "나는 고대에 이곳을 지키다 죽어간 Jr. Antares요. 나의 아버지는 최강의 마법사 Red Antares였소! 동굴로 은신한 아버지를 찾아 동료로 삼으시오! 내가 숨겨둔 비밀 통로를 열어주겠소!"';
      } else {
        return '기사 Jr. Antares의 영혼: "그럼, 나는 다시 오랜 잠으로 들어가겠소..."';
      }
    }
    if (tx == 51 && ty == 72) {
      metPyramidSage = true;
      return '현자: "Necromancer에 진정으로 대항하고자 한다면, 이 성 바로 북쪽의 피라밋에 가보시오. 그곳은 바다에서 떠오른 또 다른 지식의 성전이기 때문이오!"';
    }
    if (tx == 24 && ty == 50) {
      return '소꿉친구: "힘내게, $heroName! 자네라면 충분히 Necromancer를 무찌를 수 있을 걸세. 자네만 믿겠네."';
    }
    if (tx == 50 && ty == 11) {
      return '수용소 간수: "이 안에 갇혀있는 죄수들에게는 일체 면회가 허용되지 않습니다. 나가 주십시오."';
    }
    if ((tx == 50 || tx == 52) && ty == 51) {
      if (!metLordAhn) {
        metLordAhn = true;
        return '성주 Lord Ahn: "용사들이여, 그대들의 결의를 보았다. 대륙의 평화를 위해 Necromancer를 응징해주게! 남쪽 성문을 개방하도록 명하겠노라."';
      } else {
        castleGateOpen = true;
        return '성문 수비대장: "Lord Ahn 성주님의 명령으로 남쪽 성문을 개방했습니다. 광활한 LORE 대륙으로 나아가십시오! 행운을 빕니다!"';
      }
    }
    return null;
  }

  // ------------------------------------------
  // 2. LASTDITCH (맵 7)
  // ------------------------------------------
  String? _getLastditchDialogue(int tx, int ty, String heroName) {
    if (tx == 51 && ty == 55) {
      return '주민: "LASTDITCH 성과 VALIANT PEOPLES 성은 매우 닮았다는 말이 있습니다."';
    }
    if (tx == 8 && ty == 44) {
      return '학자: "이 세계는 다섯 개의 대륙으로 되어 있다더군요."';
    }
    if (tx == 68 && ty == 35) {
      return '탐험가: "각각의 대륙에는 서로 통하는 차원의 문이 존재합니다."';
    }
    if (tx == 43 && ty == 9) {
      return '병사: "당신은 PYRAMID 안에서 쉽게 강력한 창을 발견할 수 있을 것입니다."';
    }
    if (tx == 65 && ty == 10 || (tx == 44 && ty == 34)) {
      return '주민: "GROUND GATE는 여기로부터 서쪽에 나타나곤 하며, 당신을 다른 대륙으로 인도해 줄 것입니다."';
    }
    if (tx == 14 && ty == 68) {
      return '부인: "LORE 특공대의 지휘관은 저의 남편인데 \'Lore Hunter\'라고 불렸습니다."';
    }
    if (tx == 57 && ty == 42) {
      return '노병: "Major Mummy와 두 마리의 Sphinx의 공격은 가히 치명적입니다. 단단히 대비하시오."';
    }
    if (tx == 37 && ty == 41) {
      // LORETALK.PAS:406: the entire Polaris branch is guarded by etc[13]<2.
      if (lastditchQuestStep >= 2) return null;
      if (!polarisJoined) {
        polarisJoined = true;
        // 원작 LORETALK.PAS:413 - join(9, k) + Polaris 능력치 보정
        _pendingRecruits.add(PendingRecruit(LoreJoin.polaris()));
        return '전사 Polaris: "나의 이름은 Polaris요. 당신들과 같이 PYRAMID의 Major Mummy를 물리치고 싶소! 일행으로 받아주시오! (★ 동료 Polaris 합류!)"';
      } else {
        return '전사 Polaris: "준비는 끝났소. 언제든 전장으로 나아갑시다!"';
      }
    }
    if (tx == 38 && ty == 17) {
      // LASTDITCH 성주 퀘스트
      if (lastditchQuestStep == 0) {
        lastditchQuestStep = 1;
        return 'LASTDITCH 성주: "그대가 $heroName이오? Lord Ahn 성주님께 소식을 들었소. 우리 성 북쪽의 동굴 PYRAMID에 있는 \'Major Mummy\'를 처단해 주시오! 완료하면 큰 보상을 치르겠소."';
      } else if (lastditchQuestStep == 1) {
        if (!bossMajorMummyDefeated) {
          return 'LASTDITCH 성주: "부탁하건대, 북쪽 PYRAMID의 \'Major Mummy\'를 속히 처단해 주시오."';
        } else {
          lastditchQuestStep = 2;
          return 'LASTDITCH 성주: "Major Mummy를 처치하셨군요! 그대의 성공에 경의를 표하오! (★ 일행 전원 EXP +10,000 획득!) 북동쪽의 \'GROUND GATE\'를 통해 다음 대륙 VALIANT PEOPLES로 나아가시오!"';
        }
      } else {
        return 'LASTDITCH 성주: "북동쪽의 \'GROUND GATE\' 속에 들어가면 VALIANT PEOPLES 성으로 통하게 될 것이오. 건투를 비오!"';
      }
    }
    return null;
  }

  // ------------------------------------------
  // 3. GAIA TERRA / VALIANT PEOPLES (맵 9)
  // ------------------------------------------
  String? _getGaiaTerraDialogue(int tx, int ty, String heroName) {
    if (tx == 24 && ty == 38) {
      return '주민: "EVIL SEAL의 어디엔가에 \'황금의 봉인\'이 숨겨져 있다더군요."';
    }
    if (tx == 23 && ty == 12) {
      return '전사: "황금의 갑옷이 QUAKE 동굴 안에 숨겨져 있다는 소문이 떠돌고 있습니다."';
    }
    if (tx == 28 && ty == 18) {
      return '주민: "VALIANT PEOPLES 성은 Necromancer에 대한 강한 저항 때문에 그에 의해 쑥밭이 되어 버렸습니다."';
    }
    if (tx == 30 && ty == 31) {
      return '사냥꾼: "VALIANT PEOPLES 최대의 사냥꾼 Rigel은 성을 파괴시킨 적들을 물리치기 위해 EVIL SEAL로 들어갔습니다."';
    }
    if (tx == 34 && ty == 38 || (tx == 26 && ty == 7)) {
      return '경비병: "위쪽에는 SWAMP 대륙으로 통하는 문이 있지만, 고르곤 세자매가 살고 있어 아무도 접근할 수 없습니다."';
    }
    if (tx == 15 && ty == 42) {
      return '기사: "WATER FIELD로 통하는 문은 세 마리의 Wivern이 지키고 있습니다."';
    }
    if (tx == 42 && ty == 25) {
      // GAIA TERRA 성주 퀘스트
      if (gaiaQuestStep == 0) {
        gaiaQuestStep = 1;
        return 'GAIA TERRA 성주: "만나서 반갑소! 이 대륙의 지하에 구축된 \'EVIL SEAL\'로 가서 이 대륙의 운명이 걸린 \'황금의 봉인\'을 찾아 주시오!"';
      } else if (gaiaQuestStep == 1) {
        if (!goldenSealFound) {
          return 'GAIA TERRA 성주: "한시바삐 EVIL SEAL로 가시오. 그리고 \'황금의 봉인\'을 찾아오시오!"';
        } else {
          gaiaQuestStep = 2;
          return 'GAIA TERRA 성주: "오! 황금의 봉인을 찾아 대륙을 구하셨군요! (★ 일행 전원 EXP +10,000 획득!) 그러나 아직 북동쪽 \'QUAKE\' 동굴의 보스 ArchiGagoyle과 Zombie 무리가 위협적이오. 그들을 물리쳐 주시오!"';
        }
      } else if (gaiaQuestStep == 2) {
        if (!bossArchiGagoyleDefeated) {
          return 'GAIA TERRA 성주: "QUAKE 동굴로 가서 보스 \'ArchiGagoyle\'을 물리쳐 주십시오."';
        } else {
          gaiaQuestStep = 3;
          hasWaterKey = true;
          return 'GAIA TERRA 성주: "ArchiGagoyle을 물리치다니 위대한 영웅이오! (★ 일행 전원 EXP +40,000 획득!) 여기 [Water Key]를 받으시오! WIVERN 동굴의 문을 열어 WATER FIELD 대륙으로 갈 수 있을 것이오!"';
        }
      } else {
        return 'GAIA TERRA 성주: "WIVERN 동굴의 WATER FIELD 문을 통해 다음 대륙으로 나아가십시오!"';
      }
    }
    return null;
  }

  // ------------------------------------------
  // 4. WATER FIELD (맵 10)
  // ------------------------------------------
  String? _getWaterFieldDialogue(int tx, int ty, String heroName) {
    if (tx == 11 && ty == 16) {
      return '주민: "NOTICE 동굴의 Hidra는 머리가 셋이나 달린 거대한 괴수라더군요."';
    }
    if (tx == 14 && ty == 18) {
      return '탐험가: "NOTICE 동굴은 혼란스러운 미로라서 항상 주위를 염두에 두셔야 합니다."';
    }
    if (tx == 27 && ty == 22) {
      return '학자: "LOCKUP 속의 Minotaur는 Necromancer의 부하는 아닙니다."';
    }
    if (tx == 24 && ty == 69) {
      return '노인: "LOCKUP의 보스인 Huge Dragon은 아주 거대한 용인데, 꼬리 또한 강력한 무기라 조심해야 합니다."';
    }
    if (tx == 40 && ty == 18) {
      return '주민: "고르곤 세자매인 Stheno와 Euryale는 거의 불멸의 생명체입니다."';
    }
    if (tx == 40 && ty == 56) {
      if (!loreHunterJoined) {
        loreHunterJoined = true;
        // 원작 LORETALK.PAS:623 - join(39, k) + Lore Hunter 능력치 보정
        _pendingRecruits.add(PendingRecruit(LoreJoin.loreHunter()));
        return '특공대장 Lore Hunter: "나는 LORE 특공대장 Lore Hunter요! 새로운 영웅들을 기다리고 있었소. 내가 당신의 일행에 합류하겠소! (★ 동료 Lore Hunter 합류!)"';
      } else {
        return '특공대장 Lore Hunter: "언제든 명을 내리시오. Necromancer를 끝장냅시다!"';
      }
    }
    if (tx == 25 && ty == 18) {
      // WATER FIELD 성주 퀘스트
      if (waterFieldQuestStep == 0) {
        waterFieldQuestStep = 1;
        return 'WATER FIELD 성주: "여기는 물에 잠긴 대륙의 마지막 요새요. 남서쪽 섬의 \'NOTICE\' 동굴에 가서 삼두룡 \'Hidra\'를 물리쳐 주시오!"';
      } else if (waterFieldQuestStep == 1) {
        if (!bossHidraDefeated) {
          return 'WATER FIELD 성주: "NOTICE 동굴로 가셔서 보스 \'Hidra\'를 처단해 주십시오."';
        } else {
          waterFieldQuestStep = 2;
          return 'WATER FIELD 성주: "Hidra를 물리치다니 대단한 능력이오! (★ 일행 전원 EXP +150,000 획득!) 이번에는 대륙 동쪽 \'LOCKUP\' 동굴 속의 \'Huge Dragon\'을 물리쳐 주시오!"';
        }
      } else if (waterFieldQuestStep == 2) {
        if (!bossHugeDragonDefeated) {
          return 'WATER FIELD 성주: "LOCKUP 동굴 속의 Huge Dragon을 처단해 주십시오."';
        } else {
          waterFieldQuestStep = 3;
          hasSwampKey = true;
          return 'WATER FIELD 성주: "거룡을 쓰러뜨린 위대한 영웅이여! (★ 일행 전원 EXP +300,000 획득!) 여기에 [Swamp Key]를 받으시오! GAIA TERRA의 스왐프 게이트를 열어 늪의 대륙으로 향하십시오!"';
        }
      } else {
        return 'WATER FIELD 성주: "Swamp Key로 늪의 대륙으로 가시오. 거기는 완전한 Necromancer의 소굴이오!"';
      }
    }
    return null;
  }
}

/// `assets/data/dialogues.json`의 좌표 대사 1건.
class _DialogueEntry {
  final int map;
  final int x;
  final int y;
  final String text;

  const _DialogueEntry({
    required this.map,
    required this.x,
    required this.y,
    required this.text,
  });

  factory _DialogueEntry.fromJson(Map<String, dynamic> json) => _DialogueEntry(
    map: json['map'] as int,
    x: json['x'] as int,
    y: json['y'] as int,
    text: json['text'] as String,
  );
}
