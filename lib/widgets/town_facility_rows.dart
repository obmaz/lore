import 'package:flutter/material.dart';

import '../logic/town_logic.dart';
import '../models/party_member.dart';
import '../theme/retro_theme.dart';

/// 1993년 원작 LORESUB.PAS 마을 시설(무기점/훈련소/병원)의 각 항목을
/// 표현하는 공용 행 위젯. `TownFacilitiesDialog`가
/// 완전히 동일한 원작 규칙/가격/문구를 보여주도록 보장한다.

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
                  member.name,
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: _treatments.map((t) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RetroTheme.green,
                  foregroundColor: RetroTheme.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: const Size(76, 24),
                ),
                // Every choice is allowed; the refusal texts are Hospital's.
                onPressed: () => onTreat(member, t.$1),
                child: Text(
                  t.$2,
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

/// 군사 훈련소 파티원 1인 행 (원작 `Train_Center`: 인물을 고르면 판정과 출력).
class TownTrainRow extends StatelessWidget {
  final PartyMember member;
  final void Function(PartyMember member) onTrain;

  const TownTrainRow({super.key, required this.member, required this.onTrain});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('train-${member.name}'),
      dense: true,
      title: Text(
        member.name,
        style: RetroTheme.dosFont.copyWith(
          color: RetroTheme.white,
          fontSize: 12,
        ),
      ),
      onTap: () => onTrain(member),
    );
  }
}
