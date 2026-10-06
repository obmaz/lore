import 'package:flutter/material.dart';

import '../logic/lore_sub_text.dart';
import '../theme/retro_theme.dart';
import 'retro_box.dart';

class PartyMemberStatus {
  final String name;
  final int hp;
  final int maxHp;
  final int sp;
  final int maxSp;
  final int level;
  final int esp;
  final int ac;
  final String condition; // 'good', 'poisoned', 'unconscious', 'dead'

  const PartyMemberStatus({
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.sp,
    required this.maxSp,
    required this.level,
    this.esp = 0,
    this.ac = 0,
    this.condition = 'good',
  });
}

/// LORESUB Display_Condition: seven source columns, without invented labels.
class PartyStatusView extends StatelessWidget {
  final List<PartyMemberStatus> members;

  const PartyStatusView({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    return RetroBox(
      borderColor: RetroTheme.borderColor,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LORESUB Set_All: source header color 11, body color 15.
          Text(
            LoreSubText.statusHeader,
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.lightCyan,
              fontSize: 10,
            ),
          ),
          const Divider(color: RetroTheme.darkGray, height: 6, thickness: 1),
          Expanded(
            child: ListView.separated(
              itemCount: members.length,
              separatorBuilder: (context, index) => const Divider(
                color: RetroTheme.darkGray,
                height: 6,
                thickness: 1,
              ),
              itemBuilder: (context, index) {
                final m = members[index];
                final named = m.name.isNotEmpty;
                final cells = [
                  named ? m.name : 'Reserved',
                  named ? '${m.hp}' : '',
                  named ? '${m.sp}' : '',
                  named ? '${m.esp}' : '',
                  named ? '${m.ac}' : '',
                  named ? '${m.level}' : '',
                  named ? m.condition : '',
                ];
                const widths = [4, 2, 2, 2, 1, 1, 4];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      for (var i = 0; i < cells.length; i++)
                        Expanded(
                          flex: widths[i],
                          child: Text(
                            cells[i],
                            style: RetroTheme.dosFont.copyWith(
                              color: !named && i == 0
                                  ? RetroTheme.lightRed
                                  : RetroTheme.white,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
