/// 1993년 원작 LORETALK.PAS 및 LORESPEC.PAS 기반 대화 및 퀘스트 플래그 매니저
/// 4대 성/마을(6: CASTLE LORE, 7: LASTDITCH, 9: GAIA TERRA, 10: WATER FIELD)
library;

import '../logic/lore_source_memory.dart';

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
}
