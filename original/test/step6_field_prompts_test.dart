import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_dungeon_event_manager.dart';
import 'package:lore/logic/lore_field_logic.dart';
import 'package:lore/logic/lore_join.dart';
import 'package:lore/logic/lore_town_shops.dart';
import 'package:lore/models/party_member.dart';

/// 5단계 보강: 원작 소스에서 아직 이식되지 않았던 필드 유틸리티를 구현하며 추가한 검증.
///
/// - `LORESUB.PAS:986  wantenter`   성문/동굴 입구 진입 확인
/// - `LORESUB.PAS:999  wantexit`    마을 밖으로 나갈 때 확인
/// - `LORESUB.PAS:1012 findgold`    금화 발견
/// - `LORESUB.PAS:1144 ReturnJoinMember` 동료 합류 슬롯 선택
void main() {
  PartyMember mk(String name) => PartyMember(
    name: name,
    playerClass: PlayerClass.knight,
    strength: 15,
    mentality: 5,
    concentration: 5,
    endurance: 15,
    resistance: 10,
    agility: 12,
    accArms: 13,
    accMagic: 5,
    accEsp: 5,
    luck: 10,
  );

  group('LORE 1993 [5단계 보강] 필드 프롬프트 & 동료 슬롯 선택 단위 테스트', () {
    test('DEN7 횃불은 원작의 x=8..42, y=19..43 구역에서만 소모된다', () {
      expect(LoreFieldLogic.consumesTorch(20, 8, 19), isTrue);
      expect(LoreFieldLogic.consumesTorch(20, 42, 43), isTrue);
      expect(LoreFieldLogic.consumesTorch(20, 7, 19), isFalse);
      expect(LoreFieldLogic.consumesTorch(20, 42, 44), isFalse);
      expect(LoreFieldLogic.consumesTorch(19, 8, 19), isFalse);
    });

    test(
      '1. 성문/동굴 입구 확인 문구 검증 (LORESUB.PAS:986 wantenter / :999 wantexit)',
      () {
        expect(
          LoreFieldLogic.enterPrompt('CASTLE LORE'),
          'CASTLE LORE 에 들어가기를 원합니까 ?',
        );
        expect(LoreFieldLogic.enterPromptSuffix, ' 에 들어가기를 원합니까 ?');
        expect(LoreFieldLogic.exitPrompt, '여기서 나가기를 원합니까 ?');
        expect(LoreFieldLogic.confirmYes, '예, 그렇습니다.');
        expect(LoreFieldLogic.confirmNo, '아니오, 원하지 않습니다.');
      },
    );

    test('2. 금화 발견 연출 및 보상 검증 (LORESUB.PAS:1012 findgold)', () {
      expect(LoreFieldLogic.goldFoundMessage(5000), '당신은 금화 5000개를 발견했다.');
      expect(LoreFieldLogic.applyGoldFound(1200, 5000), 6200);
    });

    test('3. 원작 공통 메시지 문구 정합성 검증', () {
      // Johab 디코딩 원문 대조 (이전에 추측으로 넣었던 문구를 정정)
      expect(LoreFieldLogic.asYouWish, '당신이 바란다면 ...');
      expect(LoreFieldLogic.notEnoughMoney, '당신은 충분한 돈이 없습니다.');
      expect(LoreFieldLogic.thankYou, '매우 고맙습니다.');

      // 마을 시설 절차도 동일 문구를 단일 소스로 공유한다.
      expect(LoreTownShops.asYouWish, LoreFieldLogic.asYouWish);
      expect(LoreTownShops.notEnoughMoney, LoreFieldLogic.notEnoughMoney);
      expect(LoreTownShops.thankYou, LoreFieldLogic.thankYou);
    });

    test('4. 동료 합류 슬롯 선택 검증 (LORESUB.PAS:1144 ReturnJoinMember)', () {
      // 원작 파티는 1번(리더) + 2~6번 슬롯 구조이며, 리더는 교체 대상이 아니다.
      expect(LoreJoin.joinMenuPrompt, '교체 시킬 인물은 누구입니까 ?');
      expect(LoreJoin.reserveSlotLabel, '보조 일원으로 둠');
      expect(LoreJoin.joinCancelled, '당신이 바란다면 ...');

      // 파티가 5명(리더 + 동료 4명)이면 마지막 6번 슬롯은 비어 있으므로
      // 원작은 그 자리를 '보조 일원으로 둠' 라벨로 보여준다.
      final party = <PartyMember>[
        mk('Leader'),
        mk('C1'),
        mk('C2'),
        mk('C3'),
        mk('C4'),
      ];
      var labels = LoreJoin.joinMenuLabels(party);
      expect(labels, ['C1', 'C2', 'C3', 'C4', LoreJoin.reserveSlotLabel]);

      // 6번 슬롯을 선택하면 신규 합류(파티 6인).
      LoreJoin.applyJoin(party, mk('Polaris'), 4);
      expect(party.length, 6);
      expect(party.last.name, 'Polaris');

      // 파티가 가득 차면 라벨이 모두 실제 파티원 이름이 되고, 선택한 슬롯을 교체한다.
      labels = LoreJoin.joinMenuLabels(party);
      expect(labels, ['C1', 'C2', 'C3', 'C4', 'Polaris']);

      LoreJoin.applyJoin(party, mk('Lore Hunter'), 1); // 3번 슬롯 교체
      expect(party.length, 6);
      expect(party[2].name, 'Lore Hunter');
      expect(party[0].name, 'Leader'); // 리더는 그대로
      expect(party[1].name, 'C1');
      expect(party[3].name, 'C3');
    });

    test('5. LORESPEC 잔여 동료 영입 좌표 이벤트 검증', () {
      final dialogue = LoreDialogueManager.instance;
      final events = LoreDungeonEventManager.instance;
      final hero = mk('Hero');
      final party = [hero];

      // 금화 좌표 이벤트 (LORESPEC.PAS findgold) - 1회성
      dialogue.loadFlags({});
      final gold1 = events.checkEvent(9, 10, 24, party);
      expect(gold1, isNotNull);
      expect(gold1!.goldGained, 5000);
      expect(gold1.message, LoreFieldLogic.goldFoundMessage(5000));

      // 같은 좌표를 다시 밟아도 보상은 한 번뿐이다.
      expect(events.checkEvent(9, 10, 24, party), isNull);
      // 다른 좌표는 별개로 획득된다.
      expect(events.checkEvent(11, 20, 30, party)!.goldGained, 5000);
      expect(events.checkEvent(14, 6, 6, party)!.goldGained, 1000);
      expect(events.checkEvent(14, 18, 10, party)!.goldGained, 2500);
      expect(events.checkEvent(14, 31, 8, party)!.goldGained, 1500);
      // 좌표 표에 없는 위치는 금화 이벤트가 아니다.
      expect(events.checkEvent(9, 11, 24, party), isNull);
      expect(LoreDungeonEventManager.goldSites.length, 18);

      // 보물 좌표 플래그가 세이브에 직렬화/복원된다.
      final flags = dialogue.getFlagsCopy();
      expect(flags['gold:9:10:24'], isTrue);
      dialogue.loadFlags({});
      expect(dialogue.collectedTreasures, isEmpty);
      dialogue.loadFlags(flags);
      expect(dialogue.collectedTreasures, contains('gold:9:10:24'));
      expect(events.checkEvent(9, 10, 24, party), isNull); // 복원 후에도 1회성 유지
    });
  });
}
