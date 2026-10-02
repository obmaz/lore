import 'package:flutter/material.dart';

import '../logic/lore_menu_text.dart';
import '../models/party_member.dart';
import '../theme/retro_theme.dart';

/// 1993년 원작 LOREMENU.PAS: QuickView (일행의 건강 상태를 본다)
///
/// 원작 열: `이름` / ` 중독 의식불명 죽음`, 각 인물은 이름과 세 수치만 보인다.
class QuickViewDialog extends StatelessWidget {
  final List<PartyMember> party;

  const QuickViewDialog({super.key, required this.party});

  @override
  Widget build(BuildContext context) {
    final headers = LoreMenuText.quickViewHeader.trim().split(' ');
    return Dialog(
      backgroundColor: RetroTheme.black,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.lightMagenta, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    LoreMenuText.selectModeQuick,
                    overflow: TextOverflow.ellipsis,
                    style: RetroTheme.headerFont.copyWith(
                      color: RetroTheme.lightMagenta,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('quick-view-close'),
                  icon: const Icon(Icons.close, size: 16),
                  color: RetroTheme.lightGray,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              color: RetroTheme.darkBlue,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      LoreMenuText.quickViewName,
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  for (final header in headers)
                    Expanded(
                      flex: 2,
                      child: Text(
                        header,
                        style: RetroTheme.dosFont.copyWith(
                          color: RetroTheme.lightRed,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ...party.where((p) => p.name.isNotEmpty).map((p) {
              return Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: RetroTheme.background,
                  border: Border.all(color: RetroTheme.darkGray, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        p.name,
                        style: RetroTheme.dosFont.copyWith(
                          color: RetroTheme.lightGray,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final value in [p.poison, p.unconscious, p.dead])
                      Expanded(
                        flex: 2,
                        child: Text(
                          '$value',
                          style: RetroTheme.dosFont.copyWith(
                            color: RetroTheme.lightGray,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
