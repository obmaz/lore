import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import 'retro_box.dart';

class PartyMemberStatus {
  final String name;
  final int hp;
  final int maxHp;
  final int sp;
  final int maxSp;
  final int level;
  final String condition; // 'good', 'poisoned', 'unconscious', 'dead'

  const PartyMemberStatus({
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.sp,
    required this.maxSp,
    required this.level,
    this.condition = 'good',
  });
}

/// 오른쪽 상단: 파티원 상태창 (이름, HP, MP, 레벨)
class PartyStatusView extends StatelessWidget {
  final List<PartyMemberStatus> members;

  const PartyStatusView({super.key, required this.members});

  Color _getConditionColor(String cond) {
    switch (cond) {
      case 'poisoned':
        return RetroTheme.lightGreen;
      case 'unconscious':
        return RetroTheme.yellow;
      case 'dead':
        return RetroTheme.lightRed;
      default:
        return RetroTheme.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RetroBox(
      title: '◆ 파티원 상태 (PARTY STATUS) ◆',
      borderColor: RetroTheme.borderColor,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: ListView.separated(
        itemCount: members.length,
        separatorBuilder: (context, index) =>
            const Divider(color: RetroTheme.darkGray, height: 6, thickness: 1),
        itemBuilder: (context, index) {
          final m = members[index];
          final condColor = _getConditionColor(m.condition);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                // 이름 및 레벨
                Expanded(
                  flex: 5,
                  child: Text(
                    '${m.name} Lv.${m.level}',
                    style: RetroTheme.dosFont.copyWith(
                      color: condColor,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // HP
                Expanded(
                  flex: 4,
                  child: Text(
                    'HP:${m.hp}/${m.maxHp}',
                    style: RetroTheme.dosFont.copyWith(
                      color: m.hp <= (m.maxHp * 0.3)
                          ? RetroTheme.lightRed
                          : RetroTheme.lightCyan,
                      fontSize: 11,
                    ),
                  ),
                ),
                // SP (MP)
                Expanded(
                  flex: 3,
                  child: Text(
                    'SP:${m.sp}/${m.maxSp}',
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.yellow,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
