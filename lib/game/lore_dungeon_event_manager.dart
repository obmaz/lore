import '../models/monster.dart';
import '../models/party_member.dart';
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

  /// 던전/필드 좌표 인터랙션 검사 및 이벤트 실행
  DungeonEventResult? checkEvent(
    int mapId,
    int tx,
    int ty,
    List<PartyMember> party,
  ) {
    // ------------------------------------------
    // 1. 맵 1 (지상 필드): 100인분 식량 나무 (LORESPEC.PAS:28)
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
    // 2. 맵 4: Draconian의 피라미드 (LORESPEC.PAS:45..100)
    // ------------------------------------------
    if (mapId == 4 && tx == 26 && ty == 16) {
      if (!_dialogue.draconianMet) {
        _dialogue.draconianMet = true;
        return const DungeonEventResult(
          type: DungeonEventType.knowledgeGained,
          title: '학자 Draconian의 피라미드',
          message: 'Draconian: "나는 혼란스런 세상을 피해 은둔하고 있는 Draconian이오. 이 세계의 시공간 왜곡과 시그너스 X-1 블랙홀의 중력 파라독스에 의해 Necromancer가 차원의 틈을 찢고 강림한 것이오! 그를 물리칠 자는 바로 당신들이오!"',
        );
      } else {
        return const DungeonEventResult(
          type: DungeonEventType.dialogueOnly,
          title: '학자 Draconian의 서재',
          message: 'Draconian: "모든 지식의 기록을 마음에 새기고 Necromancer를 응징하시오."',
        );
      }
    }

    // ------------------------------------------
    // 3. PYRAMID 동굴: Major Mummy 보스전 (LORESPEC.PAS:531..555)
    // ------------------------------------------
    if ((mapId == 4 || mapId == 11) && tx == 30 && ty == 30) {
      if (!_dialogue.bossMajorMummyDefeated) {
        final boss = Monster(
          eNumber: 26,
          name: 'Major Mummy',
          strength: 18,
          mentality: 15,
          endurance: 20,
          resistance: 40,
          agility: 14,
          accArms: 15,
          accMagic: 14,
          ac: 4,
          special: 1, // 독 공격
          castLevel: 3,
          specialCastLevel: 0,
          level: 8,
          hp: 160,
        );
        final sphinx1 = Monster.create(8); // 호위 몬스터
        final sphinx2 = Monster.create(8);

        return DungeonEventResult(
          type: DungeonEventType.bossBattle,
          title: '미이라의 방',
          message: '당신은 미이라의 방을 발견했다! Major Mummy와 두 마리의 수호수가 관을 박차고 습격해왔다!',
          bossEnemies: [boss, sphinx1, sphinx2],
        );
      }
    }

    // ------------------------------------------
    // 4. EVIL SEAL: 황금의 봉인 해제 (LORESPEC.PAS:590)
    // ------------------------------------------
    if ((mapId == 9 || mapId == 13) && tx == 25 && ty == 25) {
      if (!_dialogue.goldenSealFound) {
        _dialogue.goldenSealFound = true;
        return const DungeonEventResult(
          type: DungeonEventType.sealBroken,
          title: '지하 신전 제단',
          message:
              '★ 당신은 눈부신 빛을 발하는 [황금의 봉인]을 찾았다! 대륙을 옭아매던 고대의 사악한 주술이 해제되었다!',
        );
      }
    }

    // ------------------------------------------
    // 5. QUAKE 동굴: ArchiGagoyle 보스전 (LORESPEC.PAS:946..960)
    // ------------------------------------------
    if (mapId == 14 && tx == 20 && ty == 20) {
      if (!_dialogue.bossArchiGagoyleDefeated) {
        final boss = Monster(
          eNumber: 42,
          name: 'ArchiGagoyle',
          strength: 22,
          mentality: 16,
          endurance: 22,
          resistance: 50,
          agility: 18,
          accArms: 18,
          accMagic: 16,
          ac: 6,
          special: 2, // 치명타 기절
          castLevel: 4,
          specialCastLevel: 1,
          level: 11,
          hp: 242,
        );
        final z1 = Monster.create(19); // Skeleton/Zombie 호위
        final z2 = Monster.create(19);

        return DungeonEventResult(
          type: DungeonEventType.bossBattle,
          title: '심연의 석굴',
          message: '당신은 석굴의 지배자 ArchiGagoyle과 두 마리의 언데드 무리를 발견했다!',
          bossEnemies: [boss, z1, z2],
        );
      }
    }

    // ------------------------------------------
    // 6. NOTICE 동굴: Hidra 삼두룡 보스전 (LORESPEC.PAS:1121..1161)
    // ------------------------------------------
    if (mapId == 17 && tx == 15 && ty == 15) {
      if (!_dialogue.bossHidraDefeated) {
        final h1 = Monster(
          eNumber: 49,
          name: "Hidra's Head 1",
          strength: 20,
          mentality: 15,
          endurance: 22,
          resistance: 40,
          agility: 18,
          accArms: 18,
          accMagic: 15,
          ac: 6,
          special: 1,
          castLevel: 3,
          specialCastLevel: 0,
          level: 13,
          hp: 286,
        );
        final h2 = Monster(
          eNumber: 49,
          name: "Hidra's Head 2",
          strength: 20,
          mentality: 15,
          endurance: 22,
          resistance: 40,
          agility: 18,
          accArms: 18,
          accMagic: 15,
          ac: 6,
          special: 1,
          castLevel: 3,
          specialCastLevel: 0,
          level: 13,
          hp: 286,
        );
        final h3 = Monster(
          eNumber: 49,
          name: "Hidra's Head 3",
          strength: 20,
          mentality: 15,
          endurance: 22,
          resistance: 40,
          agility: 18,
          accArms: 18,
          accMagic: 15,
          ac: 6,
          special: 1,
          castLevel: 3,
          specialCastLevel: 0,
          level: 13,
          hp: 286,
        );

        return DungeonEventResult(
          type: DungeonEventType.bossBattle,
          title: '호수의 소용돌이',
          message: '수면 위로 거대한 세 개의 머리를 가진 전설의 괴수 Hidra가 포효하며 솟구쳐 올랐다!',
          bossEnemies: [h1, h2, h3],
        );
      }
    }

    // ------------------------------------------
    // 7. LOCKUP 동굴: Huge Dragon 거룡 보스전 (LORESPEC.PAS:1303..1353)
    // ------------------------------------------
    if (mapId == 18 && tx == 28 && ty == 28) {
      if (!_dialogue.bossHugeDragonDefeated) {
        final dragon = Monster(
          eNumber: 65,
          name: 'Huge Dragon',
          strength: 26,
          mentality: 20,
          endurance: 25,
          resistance: 60,
          agility: 20,
          accArms: 20,
          accMagic: 18,
          ac: 8,
          special: 2, // 치명타
          castLevel: 4,
          specialCastLevel: 2,
          level: 15,
          hp: 375,
        );

        return DungeonEventResult(
          type: DungeonEventType.bossBattle,
          title: '용의 거처',
          message:
              '당신은 여기가 Huge Dragon의 거처임을 느꼈다! 붉은 화염을 내뿜는 거룡이 대지를 흔들며 내려앉았다!',
          bossEnemies: [dragon],
        );
      }
    }

    // ------------------------------------------
    // 8. 던전 보물 상자 (일반 보물 상자)
    // ------------------------------------------
    if (tx % 7 == 0 && ty % 7 == 0 && (mapId >= 11 && mapId <= 25)) {
      return const DungeonEventResult(
        type: DungeonEventType.goldGain,
        title: '고대의 보물 상자',
        message: '일행은 먼지 쌓인 궤짝 속에서 금화 250개를 발견했다!',
        goldGained: 250,
      );
    }

    return null;
  }
}
