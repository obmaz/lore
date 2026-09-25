import '../models/monster.dart';
import '../models/party_member.dart';
import '../logic/lore_field_logic.dart';
import 'lore_dialogue_manager.dart';

enum DungeonEventType {
  dialogueOnly,
  foodGain,
  goldGain,
  bossBattle,
  sealBroken,
  keyObtained,
  knowledgeGained,
}

/// 원작 `LORESPEC.PAS`의 `findgold(금액)` 좌표 이벤트 1건.
///
/// 원작은 `party.etc[32/33/35]`의 비트로 "이미 주웠는지"를 판정하므로
/// 이식편에서도 좌표별로 1회만 획득할 수 있다.
class GoldSite {
  final int mapId;
  final int x;
  final int y;
  final int amount;

  const GoldSite({
    required this.mapId,
    required this.x,
    required this.y,
    required this.amount,
  });

  /// 저장 플래그 키 (원작 `party.etc[n]` 비트 대응)
  String get flagKey => 'gold:$mapId:$x:$y';
}

class DungeonEventResult {
  final DungeonEventType type;
  final String title;
  final String message;
  final int foodGained;
  final int goldGained;
  final List<Monster>? bossEnemies;

  const DungeonEventResult({
    required this.type,
    required this.title,
    required this.message,
    this.foodGained = 0,
    this.goldGained = 0,
    this.bossEnemies,
  });
}

/// 1993년 원작 LORESPEC.PAS 기반 던전 및 필드 특수 이벤트 엔진
class LoreDungeonEventManager {
  static final LoreDungeonEventManager instance =
      LoreDungeonEventManager._internal();
  factory LoreDungeonEventManager() => instance;
  LoreDungeonEventManager._internal();

  final LoreDialogueManager _dialogue = LoreDialogueManager.instance;

  /// 원작 `LORESPEC.PAS`에서 `findgold(금액)`을 호출하는 좌표 목록.
  ///
  /// - 맵 9  (TOWN4/GAIA TERRA)  : etc[35] bit1~5  → 각 5000
  /// - 맵 11 (T_DEN1/시련의 동굴 1): etc[33] bit1~7  → 각 5000
  /// - 맵 14 (DEN1/MENACE)       : etc[32] bit1~6  → 1000/2500/400/600/1500/1000
  ///
  /// (맵 11은 다른 맵이 아니고 원작 LORESPEC의 `case party.map of` 라벨을 따른다.
  ///  늪지/수중 마을이 아니라 시련의 동굴이다.)
  static const List<GoldSite> goldSites = [
    // 맵 9 (LORESPEC.PAS:356~374)
    GoldSite(mapId: 9, x: 10, y: 24, amount: 5000),
    GoldSite(mapId: 9, x: 12, y: 26, amount: 5000),
    GoldSite(mapId: 9, x: 15, y: 25, amount: 5000),
    GoldSite(mapId: 9, x: 16, y: 23, amount: 5000),
    GoldSite(mapId: 9, x: 18, y: 27, amount: 5000),
    // 맵 11 (LORESPEC.PAS:466~492)
    GoldSite(mapId: 11, x: 20, y: 30, amount: 5000),
    GoldSite(mapId: 11, x: 18, y: 36, amount: 5000),
    GoldSite(mapId: 11, x: 35, y: 32, amount: 5000),
    GoldSite(mapId: 11, x: 33, y: 36, amount: 5000),
    GoldSite(mapId: 11, x: 35, y: 14, amount: 5000),
    GoldSite(mapId: 11, x: 14, y: 16, amount: 5000),
    GoldSite(mapId: 11, x: 37, y: 12, amount: 5000),
    // 맵 14 (LORESPEC.PAS:826~858)
    GoldSite(mapId: 14, x: 6, y: 6, amount: 1000),
    GoldSite(mapId: 14, x: 18, y: 10, amount: 2500),
    GoldSite(mapId: 14, x: 6, y: 44, amount: 400),
    GoldSite(mapId: 14, x: 31, y: 30, amount: 600),
    GoldSite(mapId: 14, x: 31, y: 8, amount: 1500),
    GoldSite(mapId: 14, x: 14, y: 28, amount: 1000),
  ];

  /// 해당 좌표의 금화를 아직 줍지 않았다면 보상을 준다 (원작 findgold).
  DungeonEventResult? _checkGoldSite(int mapId, int tx, int ty) {
    for (final site in goldSites) {
      if (site.mapId != mapId || site.x != tx || site.y != ty) continue;
      if (_dialogue.collectedTreasures.contains(site.flagKey)) return null;
      _dialogue.collectedTreasures.add(site.flagKey);
      return DungeonEventResult(
        type: DungeonEventType.goldGain,
        title: '숨겨진 금화',
        message: LoreFieldLogic.goldFoundMessage(site.amount),
        goldGained: site.amount,
      );
    }
    return null;
  }

  /// 던전/필드 좌표 인터랙션 검사 및 이벤트 실행
  DungeonEventResult? checkEvent(
    int mapId,
    int tx,
    int ty,
    List<PartyMember> party,
  ) {
    // ------------------------------------------
    // 0. 원작 LORESPEC.PAS findgold 좌표 이벤트 (1회성)
    // ------------------------------------------
    final goldSite = _checkGoldSite(mapId, tx, ty);
    if (goldSite != null) return goldSite;

    // ------------------------------------------
    // 1. 맵 1 (지상 필드): 100인분 식량 발견 (LORESPEC.PAS:25~35)
    // ------------------------------------------
    if (mapId == 1 && tx == 94 && ty == 68) {
      if (!_dialogue.foodTreeHarvested) {
        _dialogue.foodTreeHarvested = true;
        return const DungeonEventResult(
          type: DungeonEventType.foodGain,
          title: '열매 맺힌 고목',
          message: '일행들은 신비로운 고목에서 100인분의 풍족한 식량을 발견했다!',
          foodGained: 100,
        );
      } else {
        return const DungeonEventResult(
          type: DungeonEventType.dialogueOnly,
          title: '열매 맺힌 고목',
          message: '우리들은 아무것도 발견할 수 없었다.',
        );
      }
    }

    // ------------------------------------------
    // 원작 LORESPEC.PAS의 나머지 좌표 이벤트(전투/보상/연출)는
    // `assets/data/scripts.json` 으로 이관했다. JSON에 해당 좌표 스크립트가
    // 있으면 이 Dart 이벤트보다 먼저 실행된다.
    //   - 맵 4 (26,16) Draconian 강의/영입, (40,18) 공간 이동
    //   - 맵 6 (51,12) 수감소 병사, (41,79) 기본 무장, 성문 Skeleton 영입
    //   - 맵 11 (y=44) 오이디푸스의 창, (y=24) 미이라의 방
    //   - 맵 12 (18,10) 황금의 봉인
    //   - 맵 14 (16,20) 황금의 방패, (25,8)/(26,8) MENACE 중심
    //   - 맵 15 (14,7)/(45,19) 황금 장비, (y=27) 보스, (y=48) 보물
    // ------------------------------------------
    return null;
  }
}
