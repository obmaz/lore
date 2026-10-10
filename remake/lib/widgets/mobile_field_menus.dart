import 'package:flutter/material.dart';

import '../logic/field_magic_logic.dart';
import '../logic/lore_cast_spell.dart';
import '../logic/lore_game_option.dart';
import '../logic/lore_menu_text.dart';
import '../logic/lore_sub_text.dart';
import '../models/party_member.dart';
import '../services/save_manager.dart';
import 'lore_select_view.dart';
import 'mobile_menu_dialog.dart';

/// Gather a complete choice path before calling its source procedure once.
/// Back changes only navigation; no replay of spells, saves or state mutation.
class MobileFieldMenus {
  MobileFieldMenus(this.context, this.party);
  final BuildContext context;
  final List<PartyMember> party;
  List<PartyMember> get named =>
      party.take(6).where((p) => p.name.isNotEmpty).toList();

  Future<bool> _espKinds(
    PartyMember member,
    Future<bool> Function(int) select,
  ) => showMobileMenuDialog(
    context,
    title: '${member.name} · 초감각',
    items: [
      const MobileMenuItem('투시', detail: 'ESP 10 · 주변 지도의 숨겨진 공간을 살펴봅니다.'),
      const MobileMenuItem('예언', detail: 'ESP 5 · 다음 모험의 단서를 확인합니다.'),
      const MobileMenuItem(
        '독심',
        detail: 'ESP 20 필요 · 사용 후 만나는 인물과 대화하면 마음을 읽습니다.',
      ),
      MobileMenuItem(
        '천리안',
        detail: 'ESP ${member.espLevel * 5} · 방향을 고르고 지도를 한 칸씩 살펴봅니다.',
      ),
      MobileMenuItem(
        LoreMenuText.espNames[4],
        detail: '전투 중에 사용하는 초감각입니다.',
        enabled: false,
      ),
    ],
    onSelected: select,
  );

  Future<bool> _menu(
    String title,
    List<String> items,
    Future<bool> Function(int) select, {
    bool isRoot = false,
    int? maxsum,
  }) => showMobileMenuDialog(
    context,
    title: title,
    isRoot: isRoot,
    items: [
      for (var i = 0; i < items.length; i++)
        MobileMenuItem(items[i], enabled: maxsum == null || i < maxsum),
    ],
    onSelected: select,
  );

  Future<bool> cast(
    Future<void> Function(List<int>, int?) execute, {
    bool isRoot = true,
  }) async {
    List<int>? choices;
    int? selectedPower;
    final completed = await showMobileMenuDialog(
      context,
      title: '마법을 사용할 일행',
      isRoot: isRoot,
      items: [
        for (final p in named)
          MobileMenuItem(p.name, enabled: p.isBattleActive),
      ],
      onSelected: (who) => _menu(
        LoreMenuText.castSpellKind,
        const [
          LoreMenuText.castSpellAttack,
          LoreMenuText.castSpellCure,
          LoreMenuText.castSpellPhenomina,
        ],
        (kind) async {
          final caster = named[who - 1];
          if (kind == 1) {
            choices = [who, kind];
            return true;
          }
          if (kind == 2) {
            final plan = await cure(caster, isRoot: false);
            if (plan == null) return false;
            choices = [who, kind, ...plan];
            return true;
          }
          final level = caster.magicLevel;
          return _menu('변화 마법', FieldMagicLogic.phenominaSpellNames, (
            spell,
          ) async {
            Future<bool> finish(List<int> path, [int? power]) async {
              choices = [who, kind, spell, ...path];
              selectedPower = power;
              return true;
            }

            if (spell < 5 || spell > 7) return finish([]);
            return _menu('방향 선택', const ['북쪽', '남쪽', '동쪽', '서쪽'], (
              direction,
            ) async {
              if (spell != 7) return finish([direction]);
              final power = await showLoreSpacePowerDialog(context);
              if (power == null) return false;
              return finish([direction], power);
            });
          }, maxsum: level > 1 ? (level ~/ 2 + 1).clamp(0, 8) : 1);
        },
      ),
    );
    if (completed && choices != null) await execute(choices!, selectedPower);
    return completed;
  }

  Future<List<int>?> cure(PartyMember caster, {bool isRoot = true}) async {
    List<int>? plan;
    final sourceEveryone = party.length >= 6 && party[5].name.isNotEmpty
        ? 7
        : 6;
    final targets = [
      for (var i = 0; i < sourceEveryone - 1 && i < party.length; i++)
        if (party[i].name.isNotEmpty) i,
    ];
    final completed = await showMobileMenuDialog(
      context,
      title: '회복 대상',
      isRoot: isRoot,
      items: [
        for (final index in targets)
          MobileMenuItem(
            party[index].name,
            detail: 'HP ${party[index].hp}/${party[index].maxHp}',
          ),
        MobileMenuItem(
          LoreCastSpell.everyone,
          enabled: FieldMagicLogic.groupCureSlots(caster.magicLevel) > 0,
          detail: FieldMagicLogic.groupCureSlots(caster.magicLevel) > 0
              ? null
              : '마법 레벨 8부터 사용 가능',
        ),
      ],
      onSelected: (target) async {
        final everyone = target > targets.length;
        final whom = everyone ? sourceEveryone : targets[target - 1] + 1;
        return _menu(
          everyone ? '일행 전체 회복' : '${party[whom - 1].name} · 회복',
          everyone
              ? FieldMagicLogic.cureAllSpellNames
              : FieldMagicLogic.cureSpellNames,
          (spell) async {
            plan = [whom, spell];
            return true;
          },
          maxsum: everyone
              ? FieldMagicLogic.groupCureSlots(caster.magicLevel)
              : (caster.magicLevel ~/ 2 + 1).clamp(0, 7),
        );
      },
    );
    return completed ? plan : null;
  }

  Future<bool> extrasense(
    Future<void> Function(List<int>) execute, {
    bool isRoot = true,
  }) async {
    List<int>? choices;
    final completed = await showMobileMenuDialog(
      context,
      title: '초능력을 사용할 일행',
      isRoot: isRoot,
      items: [
        for (final p in named)
          MobileMenuItem(p.name, enabled: p.isBattleActive),
      ],
      onSelected: (who) => _espKinds(named[who - 1], (kind) async {
        if (kind != 4) {
          choices = [who, kind];
          return true;
        }
        return _menu('천리안 방향', const ['북쪽', '남쪽', '동쪽', '서쪽'], (
          direction,
        ) async {
          choices = [who, kind, direction];
          return true;
        });
      }),
    );
    if (completed && choices != null) await execute(choices!);
    return completed;
  }

  /// Keep the selected party member when using ESP from their detail page.
  Future<List<int>?> prepareExtrasense(int memberIndex) async {
    final member = party[memberIndex];
    if (!member.isBattleActive || member.name.isEmpty) return null;
    final who = named.indexOf(member) + 1;
    if (who < 1) return null;
    List<int>? choices;
    final completed = await _espKinds(member, (kind) async {
      if (kind != 4) {
        choices = [who, kind];
        return true;
      }
      return _menu('천리안 방향', const ['북쪽', '남쪽', '동쪽', '서쪽'], (direction) async {
        choices = [who, kind, direction];
        return true;
      });
    });
    return completed ? choices : null;
  }

  Future<bool> options(
    Future<void> Function(List<int>) execute, {
    bool isRoot = true,
  }) async {
    List<int>? selected;
    final completed = await _menu(
      LoreMenuText.optionTitle,
      const [
        LoreMenuText.optionDifficulty,
        LoreMenuText.optionOrder,
        LoreMenuText.optionRemove,
        LoreMenuText.optionResume,
        LoreMenuText.optionSave,
        LoreMenuText.optionQuit,
      ],
      (kind) async {
        Future<bool> finish(List<int> choices) async {
          selected = [kind, ...choices];
          return true;
        }

        switch (kind) {
          case 1:
            return _menu(
              '동시에 만나는 적의 수',
              [
                for (var i = 3; i <= 7; i++)
                  '$i${LoreMenuText.optionEnemySuffix}',
              ],
              (count) => _menu(LoreMenuText.optionEncounterPrompt, const [
                LoreMenuText.optionEncounter1,
                LoreMenuText.optionEncounter2,
                LoreMenuText.optionEncounter3,
                LoreMenuText.optionEncounter4,
                LoreMenuText.optionEncounter5,
              ], (frequency) => finish([count, frequency])),
            );
          case 2:
            final names = LoreGameOption.slotNames(party, 2, 5);
            return _menu(
              '순서를 바꿀 일행',
              names,
              (first) => _menu(
                '자리를 교환할 일행',
                names,
                (second) => finish([first, second]),
              ),
            );
          case 3:
            return _menu(
              '일행에서 제외할 인물',
              LoreGameOption.slotNames(party, 2, 6),
              (member) => finish([member]),
            );
          case 4 || 5:
            final saved = await SaveManager.instance.getAllSlots();
            if (!context.mounted) return false;
            final items = <MobileMenuItem>[
              for (var i = 0; i < 4; i++)
                MobileMenuItem(
                  SaveManager.slotNames[i],
                  detail: _saveDetail(saved[i]),
                  enabled: kind == 5 || saved[i] != null,
                ),
            ];
            return showMobileMenuDialog(
              context,
              title: kind == 4
                  ? LoreSubText.selectLoadGame
                  : LoreMenuText.optionLoadPrompt,
              items: items,
              onSelected: (slot) => finish([slot + 1]),
            );
          default:
            return finish([]);
        }
      },
      isRoot: isRoot,
    );
    if (completed && selected != null) await execute(selected!);
    return completed;
  }

  String _formatSaveTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _saveDetail(SaveData? save) {
    if (save == null) return '비어 있음';
    final names = save.party
        .where((p) => p.name.isNotEmpty)
        .map((p) => p.name)
        .join(', ');
    return '${save.mapTitle} · ${_formatSaveTime(save.timestamp)}\n$names';
  }
}
