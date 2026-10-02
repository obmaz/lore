import 'package:flutter/material.dart';

import '../logic/lore_menu_text.dart';
import '../models/party_member.dart';
import '../theme/retro_theme.dart';
import 'esp_panel.dart';

/// 1993년 원작 LOREMENU.PAS: Extrasense (초능력을 사용한다)
class EspDialog extends StatelessWidget {
  final List<PartyMember> party;
  final void Function(String message) onLog;
  final void Function(int count)? onMindReadActivated;

  const EspDialog({
    super.key,
    required this.party,
    required this.onLog,
    this.onMindReadActivated,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: RetroTheme.black,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.lightMagenta, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(14),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      LoreMenuText.selectModeEsp,
                      overflow: TextOverflow.ellipsis,
                      style: RetroTheme.headerFont.copyWith(
                        color: RetroTheme.lightMagenta,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('esp-close'),
                    icon: const Icon(Icons.close, size: 16),
                    color: RetroTheme.lightGray,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              EspPanel(
                party: party,
                onLog: onLog,
                onMindReadActivated: onMindReadActivated,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
