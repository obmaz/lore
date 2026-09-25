import 'package:flutter/material.dart';

import '../logic/town_logic.dart';
import '../models/item.dart';
import '../models/party_member.dart';
import '../theme/retro_theme.dart';

/// 1993년 원작 LORESUB.PAS 마을 시설(무기점/훈련소/병원)의 각 항목을
/// 표현하는 공용 행 위젯. `TownDialog`와 `TownFacilitiesDialog`가
/// 완전히 동일한 원작 규칙/가격/문구를 보여주도록 보장한다.

/// 무기/방패/갑옷 상점의 아이템 1행 (원작 `Weapon_Shop`).
class TownShopRow extends StatelessWidget {
  final Item item;
  final List<PartyMember> party;
  final void Function(Item item, PartyMember member) onBuy;

  const TownShopRow({
    super.key,
    required this.item,
    required this.party,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final isWeapon = item.type == ItemType.weapon;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: RetroTheme.background,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              '${item.name} (위력:${item.power})',
              style: RetroTheme.dosFont.copyWith(fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '금 ${item.price}',
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.yellow,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: DropdownButton<PartyMember>(
              isExpanded: true,
              hint: Text(
                '누가 사용?',
                style: RetroTheme.dosFont.copyWith(fontSize: 11),
              ),
              dropdownColor: RetroTheme.panelBg,
              items: party.map((m) {
                final blocked = isWeapon && m.playerClass == PlayerClass.monk;
                return DropdownMenuItem(
                  value: m,
                  child: Text(
                    blocked
                        ? '${m.name} (전투승-무기불가)'
                        : '${m.name} (${m.playerClass.koreanName})',
                    style: RetroTheme.dosFont.copyWith(
                      fontSize: 11,
                      color: blocked ? RetroTheme.darkGray : RetroTheme.white,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (member) {
                if (member != null) onBuy(item, member);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 병원 1인용 치료 UI (원작 `Hospital`의 4가지 치료: 상처/독/의식/부활).
class TownHospitalRow extends StatelessWidget {
  final PartyMember member;
  final int gold;
  final void Function(PartyMember member, Treatment treatment) onTreat;

  const TownHospitalRow({
    super.key,
    required this.member,
    required this.gold,
    required this.onTreat,
  });

  static const List<(Treatment, String)> _treatments = [
    (Treatment.wounds, '상처를 치료'),
    (Treatment.poison, '독을 제거'),
    (Treatment.consciousness, '의식의 회복'),
    (Treatment.revive, '부활'),
  ];

  @override
  Widget build(BuildContext context) {
    final conditionLabel = member.isDead
        ? '사망'
        : member.isUnconscious
        ? '의식불명'
        : member.isPoisoned
        ? '중독'
        : '양호';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: RetroTheme.panelBg,
        border: Border.all(color: RetroTheme.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${member.name} (${member.playerClass.koreanName} Lv.${member.battleLevel})',
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.white,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                'HP: ${member.hp}/${member.maxHp} · $conditionLabel',
                style: RetroTheme.dosFont.copyWith(
                  color: member.isDead
                      ? RetroTheme.lightRed
                      : (member.isUnconscious || member.isPoisoned
                            ? RetroTheme.yellow
                            : RetroTheme.lightGreen),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: _treatments.map((t) {
              final canTreat = TownLogic.canTreat(member, t.$1);
              final cost = TownLogic.treatmentCost(member, t.$1);
              final canAfford = gold >= cost;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canTreat && canAfford
                      ? RetroTheme.green
                      : RetroTheme.darkGray,
                  foregroundColor: RetroTheme.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: const Size(76, 24),
                ),
                onPressed: canTreat && canAfford
                    ? () => onTreat(member, t.$1)
                    : null,
                child: Text(
                  canTreat ? '${t.$2} (${cost}G)' : t.$2,
                  style: RetroTheme.dosFont.copyWith(fontSize: 10),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 군사 훈련소 파티원 1인 행 (원작 `Train_Center`).
class TownTrainRow extends StatelessWidget {
  final PartyMember member;
  final int gold;
  final void Function(PartyMember member, TrainOffer offer) onTrain;

  const TownTrainRow({
    super.key,
    required this.member,
    required this.gold,
    required this.onTrain,
  });

  @override
  Widget build(BuildContext context) {
    final offer = TownLogic.evaluateTraining(member);
    final goldShort = offer.goldShortage(gold);
    final isMaxLevel = member.battleLevel >= 20;
    final canTrain = offer.canTrain && goldShort == 0;
    final nextLevelExp = TownLogic.expRequiredForLevel(
      member.battleLevel < 20 ? member.battleLevel + 1 : 20,
    );

    final String desc;
    if (isMaxLevel) {
      desc = TownLogic.trainMaxLevel;
    } else if (offer.canTrain) {
      desc = goldShort > 0
          ? '${TownLogic.notEnoughMoney} (금 $goldShort개가 더 필요합니다)'
          : '경험치 ${member.experience} / ${offer.requiredExp} → Lv.${offer.targetLevel} 승급 가능';
    } else {
      desc =
          '${TownLogic.trainNotEnoughExp} '
          '경험치가 $nextLevelExp 이상이어야 합니다. (현재: ${member.experience})';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      padding: const EdgeInsets.all(4),
      color: RetroTheme.panelBg,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${member.name} (${member.playerClass.koreanName} Lv.${member.battleLevel})',
                  style: RetroTheme.dosFont.copyWith(
                    color: offer.canTrain
                        ? RetroTheme.yellow
                        : RetroTheme.white,
                    fontSize: 11,
                  ),
                ),
                Text(
                  desc,
                  style: RetroTheme.dosFont.copyWith(
                    color: offer.canTrain && canTrain
                        ? RetroTheme.lightGreen
                        : RetroTheme.lightGray,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canTrain
                  ? RetroTheme.yellow
                  : RetroTheme.darkGray,
              foregroundColor: RetroTheme.black,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: const Size(70, 26),
            ),
            onPressed: canTrain ? () => onTrain(member, offer) : null,
            child: Text(
              isMaxLevel
                  ? '최고레벨'
                  : (offer.canTrain
                        ? 'Lv.${offer.targetLevel} 승급 (${offer.cost}G)'
                        : '경험치 부족'),
              style: RetroTheme.dosFont.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
