import 'package:flutter/material.dart';

import '../models/party_member.dart';
import '../logic/lore_sub_text.dart';
import '../theme/mobile_theme.dart';
import 'mobile_art.dart';
import 'jrpg_battle_stage.dart';
import 'equipment_art.dart';

/// Read-only presentation of the same party records; spells use the existing
/// source command callback rather than a new rules/UI execution path.
class MobilePartyView extends StatefulWidget {
  const MobilePartyView({
    super.key,
    required this.party,
    required this.onCast,
    this.initialIndex = 0,
    this.showFooterActions = true,
    this.scrollable = true,
    this.onExtrasense,
  });
  final List<PartyMember> party;
  final VoidCallback onCast;
  final int initialIndex;
  final bool showFooterActions;
  final bool scrollable;
  final Future<void> Function(int memberIndex)? onExtrasense;
  @override
  State<MobilePartyView> createState() => _MobilePartyViewState();
}

class _MobilePartyViewState extends State<MobilePartyView> {
  int _index = 0;
  int _tab = 0;
  bool _usingExtrasense = false;

  @override
  void initState() {
    super.initState();
    _index = widget.party
        .take(widget.initialIndex)
        .where((p) => p.name.isNotEmpty)
        .length;
  }

  Widget _bar(String label, int value, int maximum, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(
            label,
            style: const TextStyle(color: MobileTheme.muted, fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: maximum > 0 ? (value / maximum).clamp(0, 1) : 0,
              color: color,
              backgroundColor: MobileTheme.line,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$value/$maximum',
          style: const TextStyle(
            color: MobileTheme.ink,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _equipment(String title, EquipmentKind kind, int id, double width) =>
      SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: MobileTheme.card(),
          child: Column(
            children: [
              Text(title, style: const TextStyle(color: MobileTheme.muted)),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                width: 100,
                child: EquipmentArt(kind: kind, id: id),
              ),
              const SizedBox(height: 10),
              Text(
                equipmentLabel(kind, id),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MobileTheme.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final named = widget.party.take(6).where((p) => p.name.isNotEmpty).toList();
    if (named.isEmpty) return const Center(child: Text('빈 일행'));
    final p = named[_index.clamp(0, named.length - 1)];
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 88,
            child: Row(
              children: [
                for (var i = 0; i < 6; i++)
                  Expanded(
                    child: i >= named.length
                        ? const Icon(
                            Icons.add_circle_outline,
                            color: MobileTheme.line,
                            size: 38,
                          )
                        : InkWell(
                            onTap: () => setState(() => _index = i),
                            child: Container(
                              decoration: MobileTheme.card(
                                selected: i == _index,
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.all(3),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: BattleSprite(
                                      cell: partySpriteCell(named[i]),
                                    ),
                                  ),
                                  Text(
                                    named[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: MobileTheme.ink,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: MobileTheme.card(),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 160,
                    child: BattleSprite(cell: partySpriteCell(p)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          color: MobileTheme.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${LoreSubText.classLabel(p.playerClass.id)} · Lv.${p.battleLevel}',
                        style: const TextStyle(
                          color: MobileTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        switch (p.condition) {
                          'dead' => '사망',
                          'unconscious' => '의식불명',
                          'poisoned' => '중독',
                          _ => '정상',
                        },
                        style: const TextStyle(
                          color: MobileTheme.mint,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _bar('HP', p.hp, p.maxHp, MobileTheme.mint),
                      _bar('SP', p.sp, p.maxSp, MobileTheme.blue),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: _tab == i
                          ? MobileTheme.mintLight
                          : MobileTheme.surface,
                      foregroundColor: MobileTheme.ink,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => setState(() => _tab = i),
                    child: Text(
                      ['상태', '장비', '마법', '초감각'][i],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_tab == 0) _stats(p),
          if (_tab == 1)
            LayoutBuilder(
              builder: (_, constraints) {
                final columns = constraints.maxWidth >= 420 ? 3 : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _equipment('무기', EquipmentKind.weapon, p.weapon, width),
                    _equipment('방패', EquipmentKind.shield, p.shield, width),
                    _equipment('갑옷', EquipmentKind.armor, p.armor, width),
                  ],
                );
              },
            ),
          if (_tab == 2)
            Container(
              decoration: MobileTheme.card(),
              padding: const EdgeInsets.all(16),
              child: Text(
                '마법 레벨 ${p.magicLevel}\n초능력 레벨 ${p.espLevel}\n초능력 ${p.esp}',
                style: const TextStyle(
                  color: MobileTheme.ink,
                  fontSize: 16,
                  height: 1.8,
                ),
              ),
            ),
          const SizedBox(height: 14),
          if (_tab == 3)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: MobileTheme.card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '초능력 ${p.esp} · 레벨 ${p.espLevel}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '선택한 일행의 투시·예지·독심술·천리안을 사용합니다.',
                    style: TextStyle(color: MobileTheme.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (widget.onExtrasense != null)
                    FilledButton.tonal(
                      onPressed: !p.isBattleActive || _usingExtrasense
                          ? null
                          : () async {
                              setState(() => _usingExtrasense = true);
                              try {
                                await widget.onExtrasense!(
                                  widget.party.indexOf(p),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _usingExtrasense = false);
                                }
                              }
                            },
                      child: const Text('초감각 사용'),
                    )
                  else
                    const Text(
                      '탐험 중 일행 화면에서 사용할 수 있습니다.',
                      style: TextStyle(color: MobileTheme.muted, fontSize: 12),
                    ),
                ],
              ),
            ),
          if (widget.showFooterActions)
            Row(
              children: [
                Expanded(
                  child: ArtButton(
                    art: 'save-book',
                    label: '마법 사용',
                    primary: true,
                    horizontal: true,
                    onPressed: widget.onCast,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    return widget.scrollable ? SingleChildScrollView(child: content) : content;
  }

  Widget _stats(PartyMember p) {
    final values = <(String, int)>[
      ('힘', p.strength),
      ('체질', p.endurance),
      ('지력', p.mentality),
      ('집중력', p.concentration),
      ('민첩', p.agility),
      ('방어', p.ac),
      ('무기 명중', p.accArms),
      ('마법 명중', p.accMagic),
      ('초능력 명중', p.accEsp),
      ('저항', p.resistance),
      ('행운', p.luck),
      ('경험치', p.experience),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            Container(
              width: (constraints.maxWidth - 8) / 2,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: MobileTheme.card(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value.$1,
                      style: const TextStyle(
                        color: MobileTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${value.$2}',
                      style: const TextStyle(
                        color: MobileTheme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
