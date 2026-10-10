import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/town_logic.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/lore_guide_dialog.dart';

void main() {
  group('LORE 1993 [5단계] 군사 훈련소 & 식료품점 & 캠프/휴식 & 제작자 서문 단위 테스트', () {
    test('1. 원작 20단계 경험치 테이블 및 훈련 비용 정합성 검증 (LORESUB.PAS:1331)', () {
      // 경험치 테이블 크기 검증
      expect(PartyMember.expTable.length, 20);
      expect(PartyMember.trainingCostTable.length, 20);

      // 원작 경험치 테이블 정밀 대조
      expect(PartyMember.expTable[0], 0); // Lv 1
      expect(PartyMember.expTable[1], 1500); // Lv 2
      expect(PartyMember.expTable[2], 6000); // Lv 3
      expect(PartyMember.expTable[3], 20000); // Lv 4
      expect(PartyMember.expTable[4], 50000); // Lv 5
      expect(PartyMember.expTable[9], 1050000); // Lv 10
      expect(PartyMember.expTable[14], 2700000); // Lv 15
      expect(PartyMember.expTable[19], 5100000); // Lv 20

      // 훈련 비용 정밀 대조
      expect(PartyMember.trainingCostTable[0], 0); // Lv 1 (비용 없음)
      expect(PartyMember.trainingCostTable[1], 3); // Lv 2
      expect(PartyMember.trainingCostTable[4], 15); // Lv 5
      expect(PartyMember.trainingCostTable[9], 200); // Lv 10
      expect(PartyMember.trainingCostTable[19], 40000); // Lv 20
    });

    test('2. 경험치에 따른 달성 가능 최대 레벨 계산 정합성 검증', () {
      expect(PartyMember.getCalculatedLevel(0), 1);
      expect(PartyMember.getCalculatedLevel(1499), 1);
      expect(PartyMember.getCalculatedLevel(1500), 2);
      expect(PartyMember.getCalculatedLevel(5999), 2);
      expect(PartyMember.getCalculatedLevel(6000), 3);
      expect(PartyMember.getCalculatedLevel(19999), 3);
      expect(PartyMember.getCalculatedLevel(20000), 4);
      expect(PartyMember.getCalculatedLevel(50000), 5);
      expect(PartyMember.getCalculatedLevel(1050000), 10);
      expect(PartyMember.getCalculatedLevel(5100000), 20);
      expect(PartyMember.getCalculatedLevel(99999999), 20);
    });

    test('3. 직업별 레벨업 스탯 성장 공식 검증 (기사/마법사/전투승/반신)', () {
      // 기사 (Knight): 순수 전투 레벨만 올라감
      final knight = PartyMember(
        name: 'TestKnight',
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
        luck: 20,
        battleLevel: 1,
        magicLevel: 1,
        espLevel: 1,
        experience: 6000,
      );
      knight.trainLevelUp(3);
      expect(knight.battleLevel, 3);
      // 원작 Train_Center는 훈련소에서 HP를 회복시켜 주지 않는다.
      // (회복은 병원 Hospital 담당) 최대 HP만 endurance * level[1] 로 증가한다.
      expect(knight.hp, 15); // endurance(15) * Lv.1
      expect(knight.maxHp, 45); // endurance(15) * Lv.3
      // 마법 레벨과 ESP 레벨은 기사에게는 변하지 않음
      expect(knight.magicLevel, 1);
      expect(knight.espLevel, 1);

      // 마법사 (Mage): 마법Lv = 전투Lv, 초능력Lv = 전투Lv/2
      final mage = PartyMember(
        name: 'TestMage',
        playerClass: PlayerClass.mage,
        strength: 5,
        mentality: 17,
        concentration: 10,
        endurance: 8,
        resistance: 8,
        agility: 10,
        accArms: 5,
        accMagic: 15,
        accEsp: 8,
        luck: 15,
        battleLevel: 1,
        magicLevel: 1,
        espLevel: 1,
        experience: 50000,
      );
      mage.trainLevelUp(5);
      expect(mage.battleLevel, 5);
      expect(mage.magicLevel, 5); // 마법 레벨 = 전투 레벨
      expect(mage.espLevel, 3); // 초능력 레벨 = round(5/2)

      // 전투승 (Monk): 맨손 위력 = level * 2 + 10
      final monk = PartyMember(
        name: 'TestMonk',
        playerClass: PlayerClass.monk,
        strength: 15,
        mentality: 5,
        concentration: 10,
        endurance: 15,
        resistance: 12,
        agility: 15,
        accArms: 13,
        accMagic: 5,
        accEsp: 5,
        luck: 12,
        battleLevel: 1,
        magicLevel: 1,
        espLevel: 1,
        experience: 150000,
      );
      monk.trainLevelUp(6);
      expect(monk.battleLevel, 6);
      expect(monk.weaPower, 6 * 2 + 10); // 맨손 위력 공식 검증

      // 반신 (Demigod): 올스탯 성장, 마법/초능력Lv = 전투Lv
      final hero = PartyMember(
        name: 'TestHero',
        playerClass: PlayerClass.demigod,
        strength: 10,
        mentality: 10,
        concentration: 10,
        endurance: 10,
        resistance: 10,
        agility: 10,
        accArms: 10,
        accMagic: 10,
        accEsp: 10,
        luck: 10,
        battleLevel: 1,
        magicLevel: 1,
        espLevel: 1,
        experience: 20000,
      );
      hero.trainLevelUp(4);
      expect(hero.battleLevel, 4);
      expect(hero.magicLevel, 4);
      expect(hero.espLevel, 4);
      // 반신은 모든 스탯이 고루 올라가야 함
      expect(hero.strength, greaterThan(10));
      expect(hero.mentality, greaterThan(10));
      expect(hero.concentration, greaterThan(10));
      expect(hero.endurance, greaterThan(10));
    });

    test('4. 원작 LOREHELP.PAS 제작자 서문 및 타이틀 자막 텍스트 정합성 검증', () {
      // 서문 텍스트 검증
      expect(LoreGuideDialog.authorPreface.isNotEmpty, isTrue);
      final fullPreface = LoreGuideDialog.authorPreface.join('\n');
      expect(fullPreface, contains('LORE의 세계에 당신을 초대합니다'));
      expect(fullPreface, contains('검과 마법이 존재하며'));
      expect(fullPreface, contains('차원의 문을 이용해'));
      expect(fullPreface, contains('운명의 파문은 당신 앞에'));
      expect(fullPreface, contains('안 영기  드림'));

      // 타이틀 자막 텍스트 검증
      expect(LoreGuideDialog.titleCaption.isNotEmpty, isTrue);
      final fullCaption = LoreGuideDialog.titleCaption.join('\n');
      expect(fullCaption, contains('거친 황야의 대륙'));
      expect(fullCaption, contains('용암이 흐르는 대륙'));
      expect(fullCaption, contains('운명을 피하려 하지 마십시오'));
    });

    test('5. 캠프/휴식 시스템 규칙 검증 (LOREMENU.PAS:869 Rest)', () {
      // 1) 상처 입은 파티원: 레벨합 × 2 만큼 회복, 식량 1 소모, SP/ESP 완전 회복
      final fighter = PartyMember(
        name: 'Fighter',
        playerClass: PlayerClass.knight,
        strength: 15,
        mentality: 5,
        concentration: 5,
        endurance: 15,
        resistance: 10,
        agility: 12,
        accArms: 15,
        accMagic: 5,
        accEsp: 5,
        luck: 10,
        battleLevel: 5,
        magicLevel: 1,
        espLevel: 1,
        hp: 10, // 크게 손상됨
        sp: 0, // 마력 0
        esp: 0, // ESP 0
      );
      var outcome = TownLogic.rest([fighter], 10);
      expect(fighter.hp, 10 + (5 + 1 + 1) * 2); // 24
      expect(outcome.food, 9);
      expect(outcome.logs, contains('Fighter는 치료되었다'));
      // LOREMENU.PAS Rest: Print(15, ...) for a healed member.
      expect(outcome.lines, contains((15, 'Fighter는 치료되었다')));
      expect(fighter.sp, fighter.maxSp); // SP 완전 회복
      expect(fighter.esp, fighter.maxEsp); // ESP 완전 회복

      // 2) 만복 상태: 식량 순 소모 0 (원작은 1개 되돌려받은 뒤 다시 소모)
      final full = PartyMember(
        name: 'Full',
        playerClass: PlayerClass.knight,
        strength: 15,
        mentality: 5,
        concentration: 5,
        endurance: 15,
        resistance: 10,
        agility: 12,
        accArms: 15,
        accMagic: 5,
        accEsp: 5,
        luck: 10,
        battleLevel: 5,
      );
      outcome = TownLogic.rest([full], 10);
      expect(full.hp, full.maxHp);
      expect(outcome.food, 10);
      expect(outcome.logs, contains('Full는 모든 건강이 회복되었다'));

      // 3) 중독 파티원: "독때문에, ... 건강은 회복되지 않았다" + 식량 미소모
      final poisoned = PartyMember(
        name: 'Poisoned',
        playerClass: PlayerClass.warrior,
        strength: 10,
        mentality: 10,
        concentration: 10,
        endurance: 10,
        resistance: 10,
        agility: 10,
        accArms: 10,
        accMagic: 10,
        accEsp: 10,
        luck: 10,
        battleLevel: 3,
        hp: 10,
        poison: 1, // 중독!
      );
      expect(poisoned.isPoisoned, isTrue);
      expect(poisoned.canAct, isTrue); // 행동은 가능
      outcome = TownLogic.rest([poisoned], 10);
      expect(poisoned.hp, 10); // 회복 불가
      expect(outcome.food, 10);
      expect(
        outcome.logs.any((l) => l.startsWith('독때문에, Poisoned 그의 건강은')),
        isTrue,
      );

      // 4) 의식불명: 레벨합만큼 감소, 깨어나면 hp 1 & 식량 1 소모
      final unconscious = PartyMember(
        name: 'Unconscious',
        playerClass: PlayerClass.mage,
        strength: 5,
        mentality: 15,
        concentration: 10,
        endurance: 8,
        resistance: 8,
        agility: 10,
        accArms: 5,
        accMagic: 15,
        accEsp: 8,
        luck: 10,
        battleLevel: 5,
        magicLevel: 5,
        espLevel: 3,
        hp: 0,
        unconscious: 10,
      );
      outcome = TownLogic.rest([unconscious], 10);
      expect(unconscious.unconscious, 0); // 10 - (5+5+3)
      expect(unconscious.hp, 1);
      expect(outcome.food, 9);
      expect(outcome.logs, contains('Unconscious는 의식이 회복되었다'));

      // 5) 아직 의식이 돌아오지 않은 경우
      final stillOut = PartyMember(
        name: 'StillOut',
        playerClass: PlayerClass.mage,
        strength: 5,
        mentality: 15,
        concentration: 10,
        endurance: 8,
        resistance: 8,
        agility: 10,
        accArms: 5,
        accMagic: 15,
        accEsp: 8,
        luck: 10,
        battleLevel: 1,
        magicLevel: 1,
        espLevel: 1,
        hp: 0,
        unconscious: 30,
      );
      outcome = TownLogic.rest([stillOut], 10);
      expect(stillOut.unconscious, 27); // 30 - 3
      expect(outcome.food, 10);
      expect(outcome.logs, contains('StillOut는 여전히 의식 불명이다'));

      // 6) 식량이 0이면 체력은 회복되지 않지만 마력/초능력은 회복된다
      final starving = PartyMember(
        name: 'Starving',
        playerClass: PlayerClass.knight,
        strength: 15,
        mentality: 5,
        concentration: 5,
        endurance: 15,
        resistance: 10,
        agility: 12,
        accArms: 15,
        accMagic: 5,
        accEsp: 5,
        luck: 10,
        battleLevel: 3,
        hp: 5,
        sp: 0,
      );
      outcome = TownLogic.rest([starving], 0);
      expect(starving.hp, 5);
      expect(outcome.food, 0);
      expect(outcome.logs, contains('일행은 식량이 바닥났다'));
      expect(starving.sp, starving.maxSp);

      // 7) 사망자는 휴식으로 회복되지 않는다
      final dead = PartyMember(
        name: 'Dead',
        playerClass: PlayerClass.knight,
        strength: 15,
        mentality: 5,
        concentration: 5,
        endurance: 15,
        resistance: 10,
        agility: 12,
        accArms: 15,
        accMagic: 5,
        accEsp: 5,
        luck: 10,
        dead: 1,
        hp: 0,
      );
      outcome = TownLogic.rest([dead], 10);
      expect(outcome.logs, contains('Dead는 죽었다'));
      expect(dead.dead, 1);

      // 8) 현상계 지속 마법 처리: 횃불(etc[1]) 잔여 스텝 1 감소
      outcome = TownLogic.rest([fighter], 10, torchSteps: 20);
      expect(outcome.torchSteps, 19);
    });
  });
}
