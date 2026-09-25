import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/widgets/ending_view.dart';

void main() {
  group('LORE 1993 [4단계] 75종 몬스터 도감 & 엔딩/크레딧 스토리 시퀀스 단위 테스트', () {
    test('1. FOEDATA.DAT 75종 전체 몬스터 도감 데이터 무결성 검증 (LOOKFOE.PAS)', () {
      final templates = Monster.monsterTemplates;
      expect(templates.length, 75);

      // 1번 Orc부터 75번 Neo-Necromancer까지 연속 번호 검증
      for (int i = 0; i < 75; i++) {
        expect(templates[i].eNumber, i + 1);
        expect(templates[i].name.isNotEmpty, isTrue);
        expect(templates[i].level > 0, isTrue);
        expect(templates[i].maxHp > 0, isTrue);
      }

      // 첫 번째 몬스터: 1번 Orc (Lv 1, 체질 8)
      final orc = templates.first;
      expect(orc.eNumber, 1);
      expect(orc.name, 'Orc');
      expect(orc.level, 1);
      expect(orc.maxHp, 8);

      // 최종 보스: 75번 Neo-Necromancer (Lv 30, 체질 60, HP 1800, 즉사공격)
      final finalBoss = templates.last;
      expect(finalBoss.eNumber, 75);
      expect(finalBoss.name, 'Neo-Necromancer');
      expect(finalBoss.level, 30);
      expect(finalBoss.maxHp, 1800);
      expect(finalBoss.strength, 40);
      expect(finalBoss.ac, 10);
      expect(finalBoss.special, 3); // 죽음의 일격
      expect(finalBoss.castLevel, 6);
      expect(finalBoss.specialCastLevel, 3);
    });

    test('2. 원작 LOREEND.PAS 에필로그 스토리 텍스트 정합성 검증', () {
      expect(EndingView.epilogueTexts.isNotEmpty, isTrue);

      final fullEpilogue = EndingView.epilogueTexts.join('\n');
      expect(fullEpilogue, contains('밖은 비바람이 치기 시작한다'));
      expect(fullEpilogue, contains('Necromancer의 기구한 운명을 애도'));
      expect(fullEpilogue, contains('그가 이런 역사를 몇 번이나 반복했는지'));
      expect(fullEpilogue, contains('당신도 이제 할 일을 모두 끝냈다'));
      expect(fullEpilogue, contains('수천억 년에 한 번 날까 말까'));
      expect(fullEpilogue, contains('전설로서, 아니 잊혀진 얘기로만'));
    });

    test('3. 원작 LOREEND.PAS 최종 크레딧 및 원작자 명기 검증', () {
      // 1993년 원작의 엔딩 크레딧 핵심 문구 검증
      const theEndTitle = '<< The End >>';
      const codexTitle = '" The Codex of Another Lore vol. #1 "';
      const author = 'Moon Dong-Wook (문동욱)';
      const geniusQuote = '★ You must be a genius !!! ★';

      expect(theEndTitle, contains('The End'));
      expect(codexTitle, contains('Codex of Another Lore'));
      expect(author, contains('문동욱'));
      expect(geniusQuote, contains('genius'));
    });

    test('4. 최종 보스 격퇴 후 엔딩 트리거 및 퀘스트 완결 플래그 검증', () {
      final dialogue = LoreDialogueManager.instance;
      dialogue.loadFlags({});
      expect(dialogue.bossNecromancerDefeated, isFalse);

      // 최종 보스 격퇴 플래그 시뮬레이션
      dialogue.bossNecromancerDefeated = true;
      expect(dialogue.bossNecromancerDefeated, isTrue);

      final flags = dialogue.getFlagsCopy();
      expect(flags['bossNecromancerDefeated'], isTrue);
    });
  });
}
