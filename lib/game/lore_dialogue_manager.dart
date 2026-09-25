/// 1993년 원작 LORETALK.PAS 및 LORESPEC.PAS 기반 대화 및 퀘스트 플래그 매니저
class LoreDialogueManager {
  static final LoreDialogueManager instance = LoreDialogueManager._internal();
  factory LoreDialogueManager() => instance;
  LoreDialogueManager._internal();

  // 퀘스트 플래그들 (원작 party.etc 에 대응)
  bool metLordAhn = false;
  bool castleGateOpen = false;
  bool jrAntaresSecretFound = false;
  bool metPyramidSage = false;

  Map<String, bool> getFlagsCopy() => {
    'metLordAhn': metLordAhn,
    'castleGateOpen': castleGateOpen,
    'jrAntaresSecretFound': jrAntaresSecretFound,
    'metPyramidSage': metPyramidSage,
  };

  void loadFlags(Map<String, bool> flags) {
    metLordAhn = flags['metLordAhn'] ?? false;
    castleGateOpen = flags['castleGateOpen'] ?? false;
    jrAntaresSecretFound = flags['jrAntaresSecretFound'] ?? false;
    metPyramidSage = flags['metPyramidSage'] ?? false;
  }

  /// CASTLE LORE 성내 마을(TOWN1, 맵 6) NPC 대화 조회
  String? getDialogue(int mapId, int tx, int ty, String heroName) {
    if (mapId == 6) { // CASTLE LORE
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
      if (tx == 19 && ty == 53) {
        return '고대 석판: "이 세계의 창시자는 안영기 님이시며, 그는 위대한 프로그래머입니다."';
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
          return '성주 Lord Ahn: "용사들이여, 그대들의 결의를 보았다. 대륙의 평화를 위해 Necromancer를 응징해주게! 성문을 개방하도록 명하겠노라."';
        } else {
          castleGateOpen = true;
          return '성문 수비대장: "Lord Ahn 성주님의 명령으로 남쪽 성문을 개방했습니다. 광활한 LORE 대륙으로 나아가십시오! 행운을 빕니다!"';
        }
      }
    }
    return null;
  }
}
