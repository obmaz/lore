import 'package:flutter/material.dart';

import '../logic/lore_sub_text.dart';
import '../theme/retro_theme.dart';
import 'retro_box.dart';
import 'lore_panel_frame.dart';
import 'mobile_art.dart';
import '../theme/mobile_theme.dart';
import 'jrpg_battle_stage.dart';

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
  final int? classId;

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
    this.classId,
  });
}

/// LORESUB Display_Condition: seven source columns, without invented labels.
class PartyStatusView extends StatelessWidget {
  final List<PartyMemberStatus> members;
  final bool compact;
  final ValueChanged<int>? onMemberTap;

  const PartyStatusView({
    super.key,
    this.sourceReplay = false,
    required this.members,
    this.compact = false,
    this.onMemberTap,
  });
  final bool sourceReplay;

  @override
  Widget build(BuildContext context) {
    final panel = _buildPanel(context);
    return sourceReplay
        ? CustomPaint(
            foregroundPainter: LorePanelFramePainter(LorePanelFrame.party),
            child: panel,
          )
        : panel;
  }

  Widget _buildPanel(BuildContext context) {
    if (compact) {
      return Container(
        decoration: MobileTheme.card(),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '일행',
              style: TextStyle(
                color: MobileTheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 6; i++)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (_, box) {
                          final m = i < members.length ? members[i] : null;
                          final named = m != null && m.name.isNotEmpty;
                          return Semantics(
                            label: named
                                ? '${m.name}, HP ${m.hp}/${m.maxHp}, SP ${m.sp}/${m.maxSp}, ${m.condition}'
                                : '빈 자리',
                            child: InkWell(
                              onTap: named && onMemberTap != null
                                  ? () => onMemberTap!(i)
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: named
                                            ? BattleSprite(
                                                cell: partySpriteCellFor(
                                                  m.name,
                                                  m.classId ?? 1,
                                                ),
                                                enemy: false,
                                              )
                                            : const Icon(
                                                Icons.add_circle_outline,
                                                color: MobileTheme.line,
                                                size: 36,
                                              ),
                                      ),
                                    ),
                                    Text(
                                      named ? m.name : '빈 자리',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: MobileTheme.ink,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      named ? '${m.hp}/${m.maxHp}' : '—',
                                      maxLines: 1,
                                      style: const TextStyle(
                                        color: MobileTheme.ink,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: named && m.maxHp > 0
                                            ? (m.hp / m.maxHp).clamp(0, 1)
                                            : 0,
                                        minHeight: 5,
                                        color: m?.condition == 'good'
                                            ? MobileTheme.mint
                                            : MobileTheme.danger,
                                        backgroundColor: MobileTheme.line,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RetroBox(
      borderColor: RetroTheme.borderColor,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: SourceInk(
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
      ),
    );
  }
}
