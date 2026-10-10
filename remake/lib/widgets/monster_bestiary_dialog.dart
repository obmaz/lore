import 'package:flutter/material.dart';

import '../data/lore_data.dart';
import '../models/monster.dart';
import '../theme/retro_theme.dart';
import '../theme/mobile_theme.dart';
import 'mobile_dialog_action.dart';

/// 원작 `LOOKFOE.PAS`가 `Foe.lst`로 쓰는 적 자료 목록(75종)을 그대로 보여 준다.
class MonsterBestiaryDialog extends StatelessWidget {
  const MonsterBestiaryDialog({super.key});

  /// `LOOKFOE.PAS`의 출력 줄들 (Pascal `x : n` 은 오른쪽 맞춤 폭 n).
  static List<String> listing(List<Monster> monsters) {
    String w(int v, int n) => '$v'.padLeft(n);
    final lines = <String>['Enemy data ========>>'];
    for (final e in monsters) {
      lines
        ..add('')
        ..add('==================================================')
        ..add('Enemy Number     : ${w(e.eNumber, 2)}')
        ..add('Enemy Name       : ${e.name}')
        ..add('Level            : ${w(e.level, 2)}')
        ..add('--------------------------------------------------')
        ..add(
          'Strength         : ${w(e.strength, 3)}    Mentality          : ${e.mentality}',
        )
        ..add(
          'Endurance        : ${w(e.endurance, 3)}    Resistance         : ${e.resistance}',
        )
        ..add('Agility          : ${w(e.agility, 3)}')
        ..add(
          'Accuracy of arms : ${w(e.accArms, 3)}    Accuracy of magic  : ${e.accMagic}',
        )
        ..add(
          'Armor Class      : ${w(e.ac, 3)}    Special Attack     : ${e.special}',
        )
        ..add(
          'Cast Level       : ${w(e.castLevel, 3)}    Special Cast Level : ${e.specialCastLevel}',
        );
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final lines = listing(LoreData.instance.monsters);
    return Dialog(
      backgroundColor: MobileTheme.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.borderColor, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 580,
        height: 380,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: lines.length,
                itemBuilder: (_, i) => Text(
                  lines[i].isEmpty ? ' ' : lines[i],
                  style: RetroTheme.dosFont.copyWith(
                    fontSize: 11,
                    height: 1.15,
                    color: MobileTheme.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            MobileDialogAction(
              key: const ValueKey('bestiary-close'),
              label: '닫기',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
