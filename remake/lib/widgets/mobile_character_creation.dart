import 'package:flutter/material.dart';

import '../data/lore_creation.dart';
import '../logic/lore_creation_rules.dart';
import '../models/party_member.dart';
import '../theme/mobile_theme.dart';
import 'browser_fullscreen_button.dart';
import 'jrpg_battle_stage.dart';
import 'mobile_choice_tile.dart';
import 'mobile_dialog_action.dart';

/// Touch presentation only. Creation formulas and final records stay with
/// CharacterCreationScreen and its source-backed reducers.
class MobileCharacterCreation extends StatelessWidget {
  const MobileCharacterCreation({
    super.key,
    required this.step,
    required this.data,
    required this.nameController,
    required this.gender,
    required this.questionIndex,
    required this.stats,
    required this.allocation,
    required this.remaining,
    required this.classFlags,
    required this.selectedClass,
    required this.companions,
    required this.onBack,
    required this.onNext,
    required this.onGender,
    required this.onAnswer,
    required this.onAllocate,
    required this.onClass,
    required this.onCompanion,
    required this.onProfile,
  });

  final int step, questionIndex, remaining;
  final LoreCreationData data;
  final TextEditingController nameController;
  final Gender gender;
  final List<int> stats, allocation, classFlags;
  final PlayerClass? selectedClass;
  final Set<int> companions;
  final VoidCallback onBack, onNext;
  final ValueChanged<Gender> onGender;
  final ValueChanged<int> onAnswer, onClass, onCompanion;
  final void Function(int slot, int delta) onAllocate;
  final ValueChanged<CreationCharacter> onProfile;

  static const _titles = ['이름과 성별', '나의 성향', '능력치 배분', '직업 선택', '동료 선택'];
  static const _descriptions = [
    '모험을 시작할 주인공을 소개해주세요.',
    '당신의 선택으로 주인공의 기본 능력이 정해집니다.',
    '40포인트를 나누어 주인공의 강점을 만드세요.',
    '현재 능력으로 선택할 수 있는 직업을 확인하세요.',
    '주인공과 함께할 동료 네 명을 골라주세요.',
  ];
  static const _roles = {
    1: '검과 방어에 능한 전위',
    2: '다양한 마법을 사용하는 주문술사',
    3: '초능력을 사용하는 정신 능력자',
    4: '무기와 마법을 함께 다루는 전사',
    5: '맨손으로 싸우는 무투가',
    6: '민첩함과 저항력을 갖춘 전투원',
    7: '높은 정확성을 가진 사냥꾼',
    8: '능력 조건 없이 선택하는 모험가',
  };
  static const _conditions = {
    1: '체력 14 · 인내력 14 · 민첩성 12 · 정확성 12 이상',
    2: '정신력 14 · 정확성 15 이상',
    3: '정신력 11 · 집중력 14 · 정확성 13 이상',
    4: '체력 14 · 정신력 11 · 인내력 11 · 저항력 11 · 정확성 14 이상',
    5: '체력 17 · 민첩성 14 · 정확성 12 이상',
    6: '저항력 17 · 민첩성 17 · 행운 10 이상',
    7: '정확성 19 이상',
    8: '능력 조건 없음',
  };

  @override
  Widget build(BuildContext context) {
    final ready = data.questions.isNotEmpty && data.classes.isNotEmpty;
    final canContinue =
        ready &&
        switch (step) {
          3 => remaining == 0,
          4 => selectedClass != null,
          5 => companions.length == 4,
          _ => true,
        };
    final label = switch (step) {
      1 => '성향 알아보기',
      3 => remaining == 0 ? '직업 선택하기' : '$remaining포인트를 더 배분하세요',
      4 => '동료 선택하기',
      5 =>
        companions.length == 4
            ? '모험 시작하기'
            : '동료 ${4 - companions.length}명 더 선택',
      _ => '',
    };
    return Theme(
      data: MobileTheme.theme,
      child: Scaffold(
        backgroundColor: MobileTheme.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 12, 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: MobileTheme.mint,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '새로운 모험',
                            style: TextStyle(
                              color: MobileTheme.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Text(
                          '$step / 5',
                          style: const TextStyle(
                            color: MobileTheme.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const BrowserFullscreenButton(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: List.generate(
                        5,
                        (index) => Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: index == 4 ? 0 : 5),
                            decoration: BoxDecoration(
                              color: index < step
                                  ? MobileTheme.mint
                                  : MobileTheme.line,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: ValueKey(
                        'creation-page-$step-${step == 2 ? questionIndex : 0}',
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titles[step - 1],
                            style: const TextStyle(
                              color: MobileTheme.ink,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _descriptions[step - 1],
                            style: const TextStyle(
                              color: MobileTheme.muted,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (!ready)
                            const Center(child: CircularProgressIndicator())
                          else
                            switch (step) {
                              1 => _name(
                                MediaQuery.sizeOf(context).height -
                                        MediaQuery.viewInsetsOf(context)
                                            .bottom <
                                    620,
                              ),
                              2 => _question(),
                              3 => _distribute(),
                              4 => _classes(),
                              _ => _companions(),
                            },
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                    decoration: const BoxDecoration(
                      color: MobileTheme.surface,
                      border: Border(top: BorderSide(color: MobileTheme.line)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: step == 1 ? 108 : 88,
                          child: MobileDialogAction(
                            label: step == 1 ? '시작 화면' : '이전',
                            secondary: true,
                            onPressed: onBack,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: step == 2
                              ? const Text(
                                  '답을 누르면 다음 질문으로 이어집니다.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: MobileTheme.muted,
                                    height: 1.4,
                                  ),
                                )
                              : MobileDialogAction(
                                  key: const ValueKey('creation-next'),
                                  label: label,
                                  onPressed: canContinue ? onNext : null,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _name(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!compact) ...[
        _heroBanner('당신의 이야기가 시작됩니다', '주인공의 이름은 언제든 자유롭게 입력하세요.', cell: 0),
        const SizedBox(height: 22),
      ],
      const Text(
        '주인공 이름',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: MobileTheme.ink,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        key: const ValueKey('creation-name'),
        controller: nameController,
        textInputAction: TextInputAction.done,
        style: const TextStyle(
          color: MobileTheme.ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: MobileTheme.surface,
          hintText: '이름을 입력하세요',
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: MobileTheme.line),
          ),
        ),
        onSubmitted: (_) => onNext(),
      ),
      const SizedBox(height: 22),
      const Text(
        '성별',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: MobileTheme.ink,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          for (final sex in Gender.values) ...[
            if (sex != Gender.values.first) const SizedBox(width: 10),
            Expanded(
              child: MobileChoiceTile(
                label: sex == Gender.male ? '남성' : '여성',
                selected: gender == sex,
                onPressed: () => onGender(sex),
                leading: Icon(
                  gender == sex ? Icons.check_circle : Icons.circle_outlined,
                  color: MobileTheme.mint,
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );

  Widget _question() {
    final question = data.questions[questionIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '질문 ${questionIndex + 1} / ${data.questions.length}',
          style: const TextStyle(
            color: MobileTheme.mint,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: MobileTheme.card(color: MobileTheme.mintLight),
          child: Text(
            question.lines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
            style: const TextStyle(
              color: MobileTheme.ink,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1.65,
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < question.options.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MobileChoiceTile(
              key: ValueKey('creation-answer-$index'),
              label: question.options[index].text
                  .replaceFirst(RegExp(r'^\s*\d+\]\s*'), '')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim(),
              onPressed: () => onAnswer(index),
            ),
          ),
      ],
    );
  }

  Widget _distribute() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _statSummary(),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: MobileTheme.card(color: MobileTheme.mintLight),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '배분할 포인트',
                style: TextStyle(
                  color: MobileTheme.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$remaining / 40',
              style: const TextStyle(
                color: MobileTheme.ink,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (var slot = 0; slot < 3; slot++)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: MobileTheme.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ['민첩성', '정확성', '행운'][slot],
                      style: const TextStyle(
                        color: MobileTheme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('creation-minus-$slot'),
                    tooltip: '${['민첩성', '정확성', '행운'][slot]} 줄이기',
                    onPressed: allocation[slot] > 0
                        ? () => onAllocate(slot + 1, -1)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${allocation[slot]}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: MobileTheme.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('creation-plus-$slot'),
                    tooltip: '${['민첩성', '정확성', '행운'][slot]} 늘리기',
                    onPressed: remaining > 0 && allocation[slot] < 20
                        ? () => onAllocate(slot + 1, 1)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              Text(
                ['빠르고 유연한 움직임', '공격을 정확하게 맞히는 능력', '모험에서의 행운'][slot],
                style: const TextStyle(fontSize: 13, color: MobileTheme.muted),
              ),
              Slider(
                value: allocation[slot].toDouble(),
                min: 0,
                max: 20,
                divisions: 20,
                label: '${allocation[slot]}',
                onChanged: (value) =>
                    onAllocate(slot + 1, value.round() - allocation[slot]),
              ),
            ],
          ),
        ),
      const Text(
        '각 능력에는 최대 20포인트를 넣을 수 있습니다.',
        style: TextStyle(color: MobileTheme.muted, fontSize: 13),
      ),
    ],
  );

  Widget _statSummary() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var index = 0; index < stats.length; index++)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: MobileTheme.card(),
          child: Text(
            '${['체력', '정신력', '집중력', '인내력', '저항력', '민첩성', '정확성', '행운'][index]}  ${stats[index]}',
            style: const TextStyle(
              color: MobileTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ],
  );

  Widget _classes() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (selectedClass != null) ...[
        _heroBanner(
          LoreCreationRules.classLabel(selectedClass!.id),
          _roles[selectedClass!.id]!,
          cell: partySpriteCellFor('', selectedClass!.id),
        ),
        const SizedBox(height: 16),
      ],
      _statSummary(),
      const SizedBox(height: 18),
      for (final option in [
        ...data.classes.where((c) => classFlags[c.playerClass.id] == 1),
        ...data.classes.where((c) => classFlags[c.playerClass.id] != 1),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: MobileChoiceTile(
            key: ValueKey('creation-class-${option.playerClass.id}'),
            label: LoreCreationRules.classLabel(option.playerClass.id),
            detailFontSize: 14,
            costFontSize: 13,
            detail:
                '${_roles[option.playerClass.id]}\n${_conditions[option.playerClass.id]}',
            cost: classFlags[option.playerClass.id] == 1
                ? '선택 가능'
                : '능력이 부족합니다 · 이전 단계에서 조정',
            leading: SizedBox(
              width: 54,
              height: 70,
              child: BattleSprite(
                cell: partySpriteCellFor('', option.playerClass.id),
              ),
            ),
            selected: selectedClass == option.playerClass,
            onPressed: classFlags[option.playerClass.id] == 1
                ? () => onClass(option.playerClass.id)
                : null,
          ),
        ),
    ],
  );

  Widget _companions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: MobileTheme.card(color: MobileTheme.mintLight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '선택한 동료 ${companions.length} / 4',
              style: const TextStyle(
                color: MobileTheme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              companions.isEmpty
                  ? '선택한 동료를 다시 누르면 선택을 해제합니다.'
                  : data.characters
                        .where((c) => companions.contains(c.id))
                        .map((c) => c.name)
                        .join(' · '),
              style: const TextStyle(
                color: MobileTheme.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      for (final companion in data.characters)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: MobileChoiceTile(
                  key: ValueKey('creation-select-${companion.id}'),
                  label: companion.name,
                  detail: LoreCreationRules.classLabel(
                    companion.playerClass.id,
                  ),
                  leading: SizedBox(
                    width: 62,
                    height: 82,
                    child: BattleSprite(
                      cell: partySpriteCell(companion.toMember()),
                    ),
                  ),
                  selected: companions.contains(companion.id),
                  onPressed:
                      companions.contains(companion.id) || companions.length < 4
                      ? () => onCompanion(companion.id)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: ValueKey('creation-profile-${companion.id}'),
                tooltip: '${companion.name} 능력 보기',
                onPressed: () => onProfile(companion),
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _heroBanner(String title, String detail, {required int cell}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [MobileTheme.mintLight, MobileTheme.surface],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MobileTheme.line),
        ),
        child: Row(
          children: [
            SizedBox(width: 80, height: 110, child: BattleSprite(cell: cell)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: MobileTheme.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: MobileTheme.muted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
