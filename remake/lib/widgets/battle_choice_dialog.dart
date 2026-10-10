import 'package:flutter/material.dart';

import '../theme/mobile_theme.dart';
import 'mobile_content_dialog.dart';
import 'mobile_dialog_action.dart';
import 'mobile_choice_tile.dart';

class BattleChoice {
  const BattleChoice(this.label, {this.detail, this.cost, this.unavailable});
  final String label;
  final String? detail, cost, unavailable;
}

/// Returns a zero-based row, or null on close. Closing never queues a command.
Future<int?> showBattleChoiceDialog(
  BuildContext context, {
  required String title,
  required List<BattleChoice> choices,
  String? summary,
}) => showDialog<int>(
  context: context,
  builder: (ctx) => MobileContentDialog(
    title: title,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              summary,
              style: const TextStyle(color: MobileTheme.muted),
            ),
          ),
        for (var i = 0; i < choices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MobileChoiceTile(
              label: choices[i].label,
              cost: choices[i].cost,
              detail: choices[i].unavailable ?? choices[i].detail,
              onPressed: choices[i].unavailable == null
                  ? () => Navigator.pop(ctx, i)
                  : null,
            ),
          ),
      ],
    ),
    footer: MobileDialogAction(
      label: '닫기',
      secondary: true,
      onPressed: () => Navigator.pop(ctx),
    ),
  ),
);
