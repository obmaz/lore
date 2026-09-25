/// 1993년 원작 LORETALK.PAS 및 LORESPEC.PAS 기반 대화 및 퀘스트 플래그 매니저
/// 4대 성/마을(6: CASTLE LORE, 7: LASTDITCH, 9: GAIA TERRA, 10: WATER FIELD)
class LoreDialogueManager {
  static final LoreDialogueManager instance = LoreDialogueManager._internal();
  factory LoreDialogueManager() => instance;
  LoreDialogueManager._internal();

  // 1. CASTLE LORE 플래그 (맵 6)
  bool metLordAhn = false;
  bool castleGateOpen = false;
  bool jrAntaresSecretFound = false;
  bool metPyramidSage = false;

  // 2. LASTDITCH 플래그 (맵 7 - party.etc[13])
  int lastditchQuestStep = 0; // 0: 미의뢰, 1: Major Mummy 의뢰중, 2: 격퇴 완료 보고대기, 3: 보상완료(Ground Gate 안내)
  bool polarisJoined = false;

  // 3. GAIA TERRA 플래그 (맵 9 - party.etc[14])
  int gaiaQuestStep = 0; // 0: 미의뢰, 1: 황금봉인 의뢰중, 2: 봉인완료 보고대기, 3: QUAKE의뢰, 4: 격퇴완료 보고대기, 5: Water Key 획득
  bool hasWaterKey = false;

  // 4. WATER FIELD 플래그 (맵 10 - party.etc[15])
  int waterFieldQuestStep = 0; // 0: 미의뢰, 1: Hidra 의뢰, 2: Hidra격퇴 보고대기, 3: Huge Dragon 의뢰, 4: 용격퇴 보고대기, 5: Swamp Key 획득
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
  bool draconianMet = false;      // 맵 4 Draconian 천문학 지식

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
    if (gaiaQuestStep == 1 && goldenSealFound) return 11;
    if (gaiaQuestStep >= 2 && !bossArchiGagoyleDefeated) return 12;
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
  };

  void loadSaveFlags(Map<String, dynamic> flags) {
    metLordAhn = flags['metLordAhn'] == true;
    castleGateOpen = flags['castleGateOpen'] == true;
    jrAntaresSecretFound = flags['jrAntaresSecretFound'] == true;
    metPyramidSage = flags['metPyramidSage'] == true;
    lastditchQuestStep = (flags['lastditchQuestStep'] as int?) ?? (flags['bossMajorMummyDefeated'] == true ? 2 : 0);
    polarisJoined = flags['polarisJoined'] == true;
    gaiaQuestStep = (flags['gaiaQuestStep'] as int?) ?? (flags['bossArchiGagoyleDefeated'] == true ? 3 : (flags['goldenSealFound'] == true ? 2 : 0));
    hasWaterKey = flags['hasWaterKey'] == true;
    waterFieldQuestStep = (flags['waterFieldQuestStep'] as int?) ?? (flags['bossHugeDragonDefeated'] == true ? 3 : (flags['bossHidraDefeated'] == true ? 2 : 0));
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
  }

  void loadFlags(Map<String, dynamic> flags) => loadSaveFlags(flags);

  // ==========================================
  // 원작 4대 성/마을(6, 7, 9, 10) 고유 대화 조회 (LORETALK.PAS)
  // ==========================================
  String? getDialogue(int mapId, int tx, int ty, String heroName) {
    switch (mapId) {
      case 6: // CASTLE LORE (성도)
        return _getCastleLoreDialogue(tx, ty, heroName);
      case 7: // LASTDITCH (2번 성)
        return _getLastditchDialogue(tx, ty, heroName);
      case 9: // GAIA TERRA / VALIANT PEOPLES (3번 성)
        return _getGaiaTerraDialogue(tx, ty, heroName);
      case 10: // WATER FIELD (4번 성)
        return _getWaterFieldDialogue(tx, ty, heroName);
      default:
        return null;
    }
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
      if (!polarisJoined) {
        polarisJoined = true;
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
