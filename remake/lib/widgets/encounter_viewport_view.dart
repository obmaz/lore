import 'package:flutter/material.dart';

import '../logic/lore_batt_text.dart';
import '../logic/lore_encounter_logic.dart';
import '../models/monster.dart';
import '../models/party_member.dart';
import '../presentation/battle_backdrop.dart';
import '../theme/mobile_theme.dart';
import 'battle_art.dart';
import 'jrpg_battle_stage.dart';
import 'source_encounter_view.dart';

/// Encounter decisions use the same opposing formation as the battle itself.
class EncounterViewportView extends StatefulWidget {
  const EncounterViewportView({
    super.key,
    required this.enemies,
    required this.onEngage,
    required this.onFlee,
    this.party = const [],
    this.backdrop = BattleBackdrop.meadow,
    this.sourceReplay = false,
  });
  final List<Monster> enemies;
  final List<PartyMember> party;
  final VoidCallback onEngage, onFlee;
  final BattleBackdrop backdrop;
  final bool sourceReplay;

  @override
  State<EncounterViewportView> createState() => _EncounterViewportViewState();
}

class _EncounterViewportViewState extends State<EncounterViewportView> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.sourceReplay) {
      return SourceEncounterView(
        enemies: widget.enemies,
        onEngage: widget.onEngage,
        onFlee: widget.onFlee,
      );
    }
    if (widget.enemies.isEmpty) return const SizedBox.shrink();
    final compact = MediaQuery.sizeOf(context).height < 600;
    final enemy = widget.enemies[_selected.clamp(0, widget.enemies.length - 1)];
    return Container(
      color: MobileTheme.background,
      padding: EdgeInsets.all(compact ? 8 : 10),
      child: Column(
        children: [
          SizedBox(height: compact ? 0 : 10),
          Text(
            LoreBattText.encounter,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: MobileTheme.ink,
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: compact ? 2 : 6),
          Text(
            '${widget.enemies.length}명 출현 · 적을 눌러 정보를 확인하세요',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: MobileTheme.muted, fontSize: 12),
          ),
          SizedBox(height: compact ? 4 : 12),
          Expanded(
            child: JrpgBattleStage(
              party: widget.party,
              enemies: widget.enemies,
              activeParty:
                  -1, // Inspecting enemies, not choosing a party action.
              selectedEnemy: _selected,
              backdrop: widget.backdrop,
              onEnemyTap: (index) => setState(() => _selected = index),
            ),
          ),
          SizedBox(height: compact ? 4 : 10),
          Container(
            key: const ValueKey('encounter-enemy-info'),
            padding: EdgeInsets.all(compact ? 6 : 12),
            decoration: MobileTheme.card(),
            child: Row(
              children: [
                SizedBox(
                  width: compact ? 38 : 62,
                  height: compact ? 38 : 62,
                  child: BattleSprite(
                    enemy: true,
                    cell: enemySpriteCell(enemy.name),
                  ),
                ),
                SizedBox(width: compact ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${enemy.name} · Lv.${enemy.level}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: MobileTheme.ink,
                          fontSize: compact ? 13 : 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 6),
                      Text(
                        'HP ${enemy.hp}/${enemy.maxHp}   공격 ${enemy.strength}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: MobileTheme.ink,
                          fontSize: compact ? 10 : 12,
                        ),
                      ),
                      Text(
                        '방어 ${enemy.ac}   민첩 ${enemy.agility}${enemy.castLevel > 0 ? '   마법 사용' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: MobileTheme.muted,
                          fontSize: compact ? 10 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 4 : 12),
            child: Text(
              '${LoreBattText.enemyAgility} : ${LoreEncounterLogic.averageEnemyAgility(widget.enemies)}',
              style: const TextStyle(color: MobileTheme.muted, fontSize: 13),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FantasyBattleButton(
                    buttonKey: const ValueKey('encounter-engage'),
                    cell: 0,
                    label: LoreBattText.engage,
                    onPressed: widget.onEngage,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FantasyBattleButton(
                    buttonKey: const ValueKey('encounter-flee'),
                    cell: 7,
                    label: LoreBattText.flee,
                    onPressed: widget.onFlee,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
