import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import '../logic/lore_menu_text.dart';
import '../models/party_member.dart';
import '../game/lore_dialogue_manager.dart';

/// 1993년 원작 LOREMENU.PAS: Extrasense (ESP 초감각 / 정신 기술) 다이얼로그
class EspDialog extends StatefulWidget {
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
  State<EspDialog> createState() => _EspDialogState();
}

class _EspDialogState extends State<EspDialog> {
  int _selectedMemberIdx = 0;
  String? _resultText;

  @override
  Widget build(BuildContext context) {
    final member = widget.party[_selectedMemberIdx];
    final hasEspAbility =
        member.playerClass == PlayerClass.mage ||
        member.playerClass == PlayerClass.monk ||
        member.playerClass == PlayerClass.esper ||
        member.playerClass == PlayerClass.vagrant ||
        member.esp > 0;

    return Dialog(
      backgroundColor: RetroTheme.panelBg,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.borderColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 파티원 선택 탭
            Text(
              LoreMenuText.espKind,
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.yellow,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.party.asMap().entries.map((entry) {
                final isSel = entry.key == _selectedMemberIdx;
                final p = entry.value;

                return ChoiceChip(
                  label: Text(
                    p.name,
                    style: RetroTheme.dosFont.copyWith(
                      fontSize: 10,
                      color: isSel ? RetroTheme.black : RetroTheme.white,
                    ),
                  ),
                  selected: isSel,
                  selectedColor: RetroTheme.yellow,
                  backgroundColor: RetroTheme.darkBlue,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedMemberIdx = entry.key;
                        _resultText = null;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            if (!hasEspAbility) ...[
              Container(
                padding: const EdgeInsets.all(12),
                color: RetroTheme.background,
                child: Text(
                  LoreMenuText.espNoAbility,
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.lightRed,
                    fontSize: 11,
                  ),
                ),
              ),
            ] else ...[
              _espButton('투시', member.esp >= 10, () {
                setState(() {
                  member.esp -= 10;
                  _resultText = LoreMenuText.espSeeThrough;
                });
                widget.onLog(LoreMenuText.espSeeThrough);
              }),
              _espButton('예언', member.esp >= 5, () {
                final prophecy = LoreDialogueManager.instance.getProphecy();
                setState(() {
                  member.esp -= 5;
                  _resultText = prophecy;
                });
                widget.onLog(prophecy);
              }),
              _espButton('독심', member.esp >= 20, () {
                setState(() {
                  member.esp -= 20;
                  _resultText = LoreMenuText.espMindRead;
                });
                widget.onMindReadActivated?.call(3);
                widget.onLog(LoreMenuText.espMindRead);
              }),
              _espButton('천리안', member.esp >= 10, () {
                setState(() {
                  member.esp -= 10;
                  _resultText = LoreMenuText.espClairvoyanceBusy;
                });
                widget.onLog(LoreMenuText.espClairvoyanceBusy);
              }),
            ],

            if (_resultText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: RetroTheme.darkBlue,
                  border: Border.all(color: RetroTheme.lightCyan),
                ),
                child: Text(
                  _resultText!,
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.yellow,
                    fontSize: 11,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RetroTheme.darkGray,
                  foregroundColor: RetroTheme.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '닫기',
                  style: RetroTheme.dosFont.copyWith(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _espButton(String title, bool enabled, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? RetroTheme.blue : RetroTheme.darkGray,
          foregroundColor: RetroTheme.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        onPressed: enabled ? onPressed : null,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 11,
                  color: RetroTheme.yellow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
