import 'package:flutter/material.dart';

import '../models/party_member.dart';
import '../logic/lore_menu_text.dart';
import '../theme/retro_theme.dart';

class QuickStatusTable extends StatelessWidget {
  final List<PartyMember> party;
  const QuickStatusTable({super.key, required this.party});
  @override
  Widget build(BuildContext context) {
    final conditions = LoreMenuText.quickViewHeader.trim().split(' ');
    return SingleChildScrollView(
      child: Table(
        columnWidths: const {0: FlexColumnWidth(2)},
        children: [
          TableRow(
            children: [
              _cell(LoreMenuText.quickViewName, RetroTheme.white),
              for (final label in conditions) _cell(label, RetroTheme.lightRed),
            ],
          ),
          for (final member in party.where((p) => p.name.isNotEmpty))
            TableRow(
              children: [
                _cell(member.name, RetroTheme.lightGray),
                _cell('${member.poison}', RetroTheme.lightGray),
                _cell('${member.unconscious}', RetroTheme.lightGray),
                _cell('${member.dead}', RetroTheme.lightGray),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(String text, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Text(
      text,
      style: RetroTheme.dosFont.copyWith(color: color, fontSize: 11),
    ),
  );
}

class QuickViewDialog extends StatelessWidget {
  final List<PartyMember> party;
  const QuickViewDialog({super.key, required this.party});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: RetroTheme.panelBg,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: RetroTheme.borderColor, width: 2),
    ),
    child: Container(
      width: 520,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: QuickStatusTable(party: party)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ),
        ],
      ),
    ),
  );
}
