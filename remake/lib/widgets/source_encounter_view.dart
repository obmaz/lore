import 'package:flutter/material.dart';

import '../logic/lore_batt_text.dart';
import '../logic/lore_encounter_logic.dart';
import '../logic/lore_enemy_presentation.dart';
import '../models/monster.dart';
import '../theme/retro_theme.dart';

/// LOREBATT.PAS `EncounterEnemy`의 전투 전 선택 화면.
class SourceEncounterView extends StatelessWidget {
  final List<Monster> enemies;
  final VoidCallback onEngage;
  final VoidCallback onFlee;

  const SourceEncounterView({
    super.key,
    required this.enemies,
    required this.onEngage,
    required this.onFlee,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: RetroTheme.viewportBg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(LoreBattText.encounter, style: RetroTheme.headerFont),
              const SizedBox(height: 12),
              for (final enemy in enemies)
                Text(
                  '${enemy.name} (Lv.${enemy.level}, HP:${enemy.hp})',
                  style: RetroTheme.dosFont.copyWith(
                    color: enemy.isDead
                        ? Colors.transparent
                        : RetroTheme.ega(LoreEnemyPresentation.color(enemy)),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                '${LoreBattText.enemyAgility} : ${LoreEncounterLogic.averageEnemyAgility(enemies)}',
                style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    key: const ValueKey('encounter-engage'),
                    onPressed: onEngage,
                    child: Text('1. ${LoreBattText.engage}'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('encounter-flee'),
                    onPressed: onFlee,
                    child: Text('2. ${LoreBattText.flee}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
