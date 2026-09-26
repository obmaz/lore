import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/lore_creation.dart';
import '../theme/retro_theme.dart';
import '../models/party_member.dart';
import '../services/audio_manager.dart';
import '../services/save_manager.dart';
import '../widgets/monster_bestiary_dialog.dart';
import '../widgets/lore_guide_dialog.dart';

/// 1993년 원작 LORECRET.PAS 기반 캐릭터 생성 및 오프닝 화면
class CharacterCreationScreen extends StatefulWidget {
  final void Function(List<PartyMember> party) onGameStart;
  final void Function(SaveData loadedData)? onLoadGame;

  const CharacterCreationScreen({
    super.key,
    required this.onGameStart,
    this.onLoadGame,
  });

  @override
  State<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  /// 0: 타이틀, 1: 이름&성별, 2: 성향 문답(원작 First),
  /// 3: 40포인트 분배(Second), 4: 계급 선택(Third), 5: 동료 4명( Fourth)
  int _step = 0;

  @override
  void initState() {
    super.initState();
    // 원작 오프닝/타이틀 BGM 재생
    AudioManager.instance.playBgm(BgmTrack.title);
  }

  final TextEditingController _nameController = TextEditingController(
    text: 'Hero',
  );
  Gender _selectedGender = Gender.male;

  // 질문 응답 및 성향 데이터 (transdata[1..5])
  final List<int> _transdata = List.filled(6, 0);

  // 선택된 동료 4명 인덱스 (1..10 중)
  final Set<int> _selectedCompanions = {
    1,
    3,
    5,
    7,
  }; // 기본값: Hercules, Merlin, Genius Kie, Regulus

  // 원작 LORECRET.PAS 데이터 (assets/data/creation.json / 내장 폴백)
  LoreCreationData get _data => LoreCreationData.instance;

  /// 문항 진행용 상태.
  int _qIndex = 0;

  /// `First` 결과 (성향 테스트로 정해지는 5개 능력치).
  int _strength = 0;
  int _mentality = 0;
  int _concentration = 0;
  int _endurance = 0;
  int _resistanceStat = 0;

  /// `Second` 40포인트 분배 결과.
  int _agility = 0;
  int _accuracy = 0;
  int _luck = 0;
  int _pointsLeft = 40;

  /// `Third` 에서 실제로 선택한 계급.
  PlayerClass? _selectedClass;

  /// `Fourth` 에서 능력치를 미리 보는 동료.
  CreationCharacter? _profileTarget;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data.loaded) return;
    _data.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// 원작 성향 문답(10문항).
  List<CreationQuestion> get _questions => _data.questions;

  /// 원작 `First` 의 스탯 환산 + 성별 보정.
  void _applyQuizResult() {
    _strength = _data.statValue(_transdata[1]);
    _mentality = _data.statValue(_transdata[2]);
    _concentration = _data.statValue(_transdata[3]);
    _endurance = _data.statValue(_transdata[4]);
    _resistanceStat = _data.statValue(_transdata[5]);

    // 원작 `j := 4;` 성별 보정 (20 상한, 남는 값은 다음 능력치로 이월).
    var j = 4;
    void add(int Function() get, void Function(int) set) {
      set(get() + j);
      if (get() <= 20) {
        j = 0;
      } else {
        j = get() - 20;
        set(20);
      }
    }

    if (_selectedGender == Gender.male) {
      add(() => _strength, (v) => _strength = v);
      add(() => _endurance, (v) => _endurance = v);
      _resistanceStat = (_resistanceStat + j).clamp(0, 20);
    } else {
      add(() => _mentality, (v) => _mentality = v);
      add(() => _concentration, (v) => _concentration = v);
      _resistanceStat = (_resistanceStat + j).clamp(0, 20);
    }
  }

  /// 원작 `First` 의 답 처리(`inc(transdata[N])`) 후 다음 단계로.
  void _answerQuestion(int choiceIndex) {
    final q = _questions[_qIndex];
    if (choiceIndex >= q.options.length) return;
    final stat = q.options[choiceIndex].stat;
    if (stat >= 1 && stat <= 5) _transdata[stat]++;

    if (_qIndex < _questions.length - 1) {
      setState(() => _qIndex++);
      return;
    }
    setState(() {
      _applyQuizResult();
      _step = 3; // 40포인트 분배(원작 Second)
    });
  }

  /// 원작 `Second` - 민첩성/정확성/행운에 40포인트를 분배한다.
  void _distribute(int slot, int delta) {
    setState(() {
      final current = switch (slot) {
        1 => _agility,
        2 => _accuracy,
        _ => _luck,
      };
      final next = current + delta;
      if (next < 0 || next > 20) return;
      if (_pointsLeft - delta < 0 || _pointsLeft - delta > 40) return;
      _pointsLeft -= delta;
      switch (slot) {
        case 1:
          _agility = next;
        case 2:
          _accuracy = next;
        default:
          _luck = next;
      }
    });
  }

  /// 원작 `Third` - 조건을 만족하는 계급만 고를 수 있다.
  List<CreationClassOption> get _availableClasses => _data.classes
      .where(
        (c) => c.satisfied(
          strength: _strength,
          mentality: _mentality,
          concentration: _concentration,
          endurance: _endurance,
          resistance: _resistanceStat,
          agility: _agility,
          accuracy: _accuracy,
          luck: _luck,
        ),
      )
      .toList();

  /// 원작 `Fourth` 끝의 파티 구성 + `Last` 초기 상태로 게임을 시작한다.
  void _finishCreation() {
    final heroName = _nameController.text.trim().isEmpty
        ? 'Hero'
        : _nameController.text.trim();

    final hero = PartyMember(
      name: heroName,
      sex: _selectedGender,
      playerClass: _selectedClass ?? _availableClasses.first.playerClass,
      strength: _strength,
      mentality: _mentality,
      concentration: _concentration,
      endurance: _endurance,
      resistance: _resistanceStat,
      agility: _agility,
      accArms: _accuracy,
      accMagic: 5,
      accEsp: 5,
      luck: _luck,
    );

    final party = <PartyMember>[hero];
    for (final id in _selectedCompanions) {
      final c = _data.characters.firstWhere((e) => e.id == id);
      party.add(c.toMember());
    }
    for (final m in party) {
      m.applyCreationInit();
    }

    widget.onGameStart(party);
  }

  /// 원작 `Profile(number)` - 동료 능력치 미리보기 문구.
  Widget _buildProfilePanel(CreationCharacter c) {
    String t(String k, int i) => _data.text('Profile', i);
    return Container(
      width: 300,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: RetroTheme.background,
        border: Border.all(color: RetroTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('Profile', 0),
            style: RetroTheme.headerFont.copyWith(
              color: RetroTheme.white,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${t('Profile', 1)}${c.name}',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.yellow,
              fontSize: 11,
            ),
          ),
          Text(
            '${t('Profile', 2)}${c.sexLabel}',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.yellow,
              fontSize: 11,
            ),
          ),
          Text(
            '${t('Profile', 3)}${c.playerClass.koreanName}',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.yellow,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          for (final entry in [
            (t('Profile', 4), c.strength),
            (t('Profile', 5), c.mentality),
            (t('Profile', 6), c.concentration),
            (t('Profile', 7), c.endurance),
            (t('Profile', 8), c.resistance),
            (t('Profile', 9), c.agility),
            (t('Profile', 10), c.accuracy),
            (t('Profile', 11), c.luck),
          ])
            Text(
              '${entry.$1}${entry.$2}',
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.lightCyan,
                fontSize: 10,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '${t('Profile', 15)}${c.endurance}',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.lightGreen,
              fontSize: 10,
            ),
          ),
          Text(
            '${t('Profile', 16)}1',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.lightGreen,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RetroTheme.panelBg,
              border: Border.all(color: RetroTheme.borderColor, width: 3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _buildCurrentStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildTitleScreen();
      case 1:
        return _buildNameScreen();
      case 2:
        return _buildQuestionScreen();
      case 3:
        return _buildDistributeScreen();
      case 4:
        return _buildClassScreen();
      case 5:
        return _buildCompanionsScreen();
      default:
        return _buildTitleScreen();
    }
  }

  // ==========================================
  // Step 0: 원작 타이틀 화면
  // ==========================================
  Widget _buildTitleScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          // 원작 Display: `또다른 지식의 성전  제 1 부`
          _data.text('Display', 0).isEmpty
              ? '또다른 지식의 성전  제 1 부'
              : _data.text('Display', 0),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: RetroTheme.yellow,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '제 1 부 (1993 - 2026 Flutter Port)',
          style: RetroTheme.dosFont.copyWith(
            fontSize: 14,
            color: RetroTheme.lightCyan,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: RetroTheme.background,
            border: Border.all(color: RetroTheme.borderColor),
          ),
          child: Column(
            children: [
              Text(
                // 원작 LORECRET.PAS:73 - `캐릭터 만들기 프로그램   제 1.5 탄`
                _data.text('Display', 1).isEmpty
                    ? '캐릭터 만들기 프로그램   제 1.5 탄'
                    : _data.text('Display', 1),
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 12,
                  color: RetroTheme.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '엔진: Flutter & Flame 2D 엔진',
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 11,
                  color: RetroTheme.lightGray,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '지도: 원작 100x100 바이너리 TOWN1.MAP 로드',
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 11,
                  color: RetroTheme.lightGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RetroTheme.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onPressed: () => setState(() => _step = 1),
              child: Text(
                '1] 새로운 주인공을 생성 시킴',
                style: RetroTheme.headerFont.copyWith(fontSize: 12),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: RetroTheme.lightCyan),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                // 기본 파티로 즉시 시작
                final defaultParty = [
                  PartyMember.createPreset(1),
                  PartyMember.createPreset(3),
                  PartyMember.createPreset(5),
                  PartyMember.createPreset(6),
                  PartyMember.createPreset(7),
                ];
                widget.onGameStart(defaultParty);
              },
              child: Text(
                '빠른 모험 시작 (기본 파티)',
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 12,
                  color: RetroTheme.lightCyan,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RetroTheme.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onPressed: _showLoadGameDialog,
              child: Text(
                '2] 이전의 게임을 재개 시킴',
                style: RetroTheme.headerFont.copyWith(fontSize: 12),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: RetroTheme.lightRed),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              // 원작 LOREHELP.PAS:272 `3] 도스로 돌아감`
              onPressed: () => SystemNavigator.pop(),
              child: Text(
                '3] 도스로 돌아감',
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 12,
                  color: RetroTheme.lightRed,
                ),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: RetroTheme.yellow),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const MonsterBestiaryDialog(),
                );
              },
              child: Text(
                '📖 몬스터 도감 (75종)',
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 12,
                  color: RetroTheme.yellow,
                ),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: RetroTheme.lightCyan),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const LoreGuideDialog(),
                );
              },
              child: Text(
                '📜 제작자 서문 & 가이드',
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 12,
                  color: RetroTheme.lightCyan,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showLoadGameDialog() {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<SaveData?>>(
        future: SaveManager.instance.getAllSlots(),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final slots = snapshot.data!;
          final hasAnySave = slots.any((s) => s != null);

          return Dialog(
            backgroundColor: RetroTheme.black,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: RetroTheme.lightMagenta, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '◆ 저장된 모험 이어하기 (LOAD GAME) ◆',
                        style: RetroTheme.headerFont.copyWith(
                          color: RetroTheme.lightMagenta,
                          fontSize: 12,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: RetroTheme.lightGray,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!hasAnySave)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '저장된 게임 데이터가 없습니다.\n먼저 새 게임을 시작하여 모험을 저장하십시오.',
                          textAlign: TextAlign.center,
                          style: RetroTheme.dosFont.copyWith(
                            color: RetroTheme.yellow,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else
                    ...List.generate(4, (index) {
                      final slotNum = index + 1;
                      final slotData = slots[index];
                      final slotTitle = SaveManager.slotNames[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: slotData != null
                                ? RetroTheme.lightCyan
                                : RetroTheme.darkGray,
                          ),
                          color: RetroTheme.background,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '슬롯 $slotNum. $slotTitle',
                                    style: RetroTheme.headerFont.copyWith(
                                      color: slotData != null
                                          ? RetroTheme.yellow
                                          : RetroTheme.lightGray,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (slotData == null)
                                    Text(
                                      '-- [ 비어 있음 (EMPTY) ] --',
                                      style: RetroTheme.dosFont.copyWith(
                                        color: RetroTheme.darkGray,
                                        fontSize: 10,
                                      ),
                                    )
                                  else ...[
                                    Text(
                                      '${slotData.mapTitle} (${slotData.playerX}, ${slotData.playerY}) | 금화: ${slotData.gold}',
                                      style: RetroTheme.dosFont.copyWith(
                                        color: RetroTheme.lightGreen,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      '일행: ${slotData.party.map((p) => p.name).join(', ')}',
                                      style: RetroTheme.dosFont.copyWith(
                                        color: RetroTheme.white,
                                        fontSize: 9,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: slotData != null
                                    ? RetroTheme.blue
                                    : RetroTheme.darkGray,
                                foregroundColor: RetroTheme.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: const Size(64, 28),
                              ),
                              onPressed: slotData == null
                                  ? null
                                  : () {
                                      Navigator.of(ctx).pop();
                                      widget.onLoadGame?.call(slotData);
                                    },
                              child: Text(
                                '불러오기',
                                style: RetroTheme.dosFont.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: RetroTheme.darkGray,
                        foregroundColor: RetroTheme.white,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
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
        },
      ),
    );
  }

  // ==========================================
  // Step 1: 이름 및 성별 입력
  // ==========================================
  Widget _buildNameScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '◆ ${_data.text('Display', 0)} ◆',
          style: RetroTheme.headerFont.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 24),
        Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          color: RetroTheme.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _data.text('Name', 0),
                style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: RetroTheme.headerFont.copyWith(fontSize: 15),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Color(0xFF000033),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _data.text('Name', 2),
                style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedGender == Gender.male
                          ? RetroTheme.blue
                          : Colors.transparent,
                      side: BorderSide(
                        color: _selectedGender == Gender.male
                            ? RetroTheme.yellow
                            : RetroTheme.darkGray,
                      ),
                    ),
                    onPressed: () =>
                        setState(() => _selectedGender = Gender.male),
                    child: Text(
                      '남성 [M]',
                      style: RetroTheme.dosFont.copyWith(
                        color: _selectedGender == Gender.male
                            ? RetroTheme.yellow
                            : RetroTheme.lightGray,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedGender == Gender.female
                          ? RetroTheme.blue
                          : Colors.transparent,
                      side: BorderSide(
                        color: _selectedGender == Gender.female
                            ? RetroTheme.yellow
                            : RetroTheme.darkGray,
                      ),
                    ),
                    onPressed: () =>
                        setState(() => _selectedGender = Gender.female),
                    child: Text(
                      '여성 [F]',
                      style: RetroTheme.dosFont.copyWith(
                        color: _selectedGender == Gender.female
                            ? RetroTheme.yellow
                            : RetroTheme.lightGray,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_data.text('Name', 1)}${_nameController.text} ${_data.text('Name', 1).isEmpty ? '' : ''}',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightGreen,
            fontSize: 11,
          ),
        ),
        Text(
          '${_data.text('Name', 3)}${_selectedGender == Gender.male ? '남성' : '여성'}',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightGreen,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: RetroTheme.blue),
          onPressed: () => setState(() => _step = 2),
          child: Text('성향 테스트 진행 ▶', style: RetroTheme.dosFont),
        ),
      ],
    );
  }

  // ==========================================
  // Step 2: 원작 10문항 성향 문답 (First)
  // ==========================================
  Widget _buildQuestionScreen() {
    if (_questions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final q = _questions[_qIndex];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '◆ ${_data.quizIntro.isNotEmpty ? _data.quizIntro[0] : ''} (${_qIndex + 1} / ${_questions.length}) ◆',
          style: RetroTheme.headerFont.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 6),
        if (_data.quizIntro.length > 1)
          Text(
            _data.quizIntro[1],
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.lightGray,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 16),
        Container(
          width: 520,
          padding: const EdgeInsets.all(16),
          color: RetroTheme.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in q.lines)
                Text(
                  line,
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.yellow,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 14),
              ...List.generate(q.options.length, (idx) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RetroTheme.panelBg,
                        alignment: Alignment.centerLeft,
                        side: const BorderSide(color: RetroTheme.borderColor),
                      ),
                      onPressed: () => _answerQuestion(idx),
                      child: Text(
                        q.options[idx].text,
                        style: RetroTheme.dosFont.copyWith(
                          color: RetroTheme.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Step 3: 원작 Second - 40포인트 분배
  // ==========================================
  Widget _buildDistributeScreen() {
    String t(int i) => _data.text('Second', i);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '◆ ${t(0)} ◆',
          style: RetroTheme.headerFont.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 10),
        Text(
          '${t(1)}$_pointsLeft',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 420,
          padding: const EdgeInsets.all(14),
          color: RetroTheme.background,
          child: Column(
            children: [
              for (final (slot, label, value) in [
                (1, t(2), _agility),
                (2, t(3), _accuracy),
                (3, t(4), _luck),
              ])
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$label $value',
                        style: RetroTheme.dosFont.copyWith(
                          color: RetroTheme.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _distribute(slot, -1),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: RetroTheme.lightRed,
                        size: 18,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _distribute(slot, 1),
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: RetroTheme.lightGreen,
                        size: 18,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _pointsLeft == 0
                ? RetroTheme.green
                : RetroTheme.darkGray,
          ),
          onPressed: _pointsLeft == 0 ? () => setState(() => _step = 4) : null,
          child: Text('계급 선택 ▶', style: RetroTheme.dosFont),
        ),
      ],
    );
  }

  // ==========================================
  // Step 3: 직업 판정 확인 및 선택
  // ==========================================
  Widget _buildClassScreen() {
    final options = _availableClasses;
    final t = _data.text('Third', 0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('◆ $t ◆', style: RetroTheme.headerFont.copyWith(fontSize: 15)),
        const SizedBox(height: 10),
        Container(
          width: 460,
          padding: const EdgeInsets.all(12),
          color: RetroTheme.background,
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final c in options)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedClass == c.playerClass
                        ? RetroTheme.blue
                        : RetroTheme.panelBg,
                    side: const BorderSide(color: RetroTheme.borderColor),
                  ),
                  onPressed: () =>
                      setState(() => _selectedClass = c.playerClass),
                  child: Text(
                    c.text,
                    style: RetroTheme.dosFont.copyWith(
                      color: _selectedClass == c.playerClass
                          ? RetroTheme.yellow
                          : RetroTheme.white,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_selectedClass != null)
          Text(
            '${_data.text('Third', 9)}${_selectedClass!.koreanName}',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.lightGreen,
              fontSize: 12,
            ),
          ),
        if (options.length < _data.classes.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '(능력치 조건을 만족하지 못한 계급은 고를 수 없습니다)',
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.lightGray,
                fontSize: 10,
              ),
            ),
          ),
        const SizedBox(height: 14),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedClass != null
                ? RetroTheme.green
                : RetroTheme.darkGray,
          ),
          onPressed: _selectedClass == null
              ? null
              : () => setState(() => _step = 5),
          child: Text(
            '${_data.text('Third', 10)} (동료 선택 ▶)',
            style: RetroTheme.dosFont,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Step 4: 동행할 4명의 동료 용사 선택
  // ==========================================
  Widget _buildCompanionsScreen() {
    String t4(int i) => _data.text('Fourth', i);
    final names = _profileTarget;
    return Column(
      children: [
        Text(t4(0), style: RetroTheme.headerFont.copyWith(fontSize: 14)),
        Text(
          t4(1),
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightCyan,
            fontSize: 12,
          ),
        ),
        Text(
          '선택: ${_selectedCompanions.length} / 4 명',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: _data.characters.length,
                  itemBuilder: (context, idx) {
                    final c = _data.characters[idx];
                    final isSelected = _selectedCompanions.contains(c.id);
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? RetroTheme.blue.withValues(alpha: 0.5)
                            : RetroTheme.background,
                        border: Border.all(
                          color: isSelected
                              ? RetroTheme.yellow
                              : RetroTheme.darkGray,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${c.name} [${c.playerClass.koreanName}]',
                              style: RetroTheme.dosFont.copyWith(
                                color: isSelected
                                    ? RetroTheme.yellow
                                    : RetroTheme.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedCompanions.remove(c.id);
                                } else if (_selectedCompanions.length < 4) {
                                  _selectedCompanions.add(c.id);
                                }
                              });
                            },
                            child: Text(
                              t4(2),
                              style: RetroTheme.dosFont.copyWith(
                                color: RetroTheme.lightGreen,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _profileTarget = c),
                            child: Text(
                              t4(3),
                              style: RetroTheme.dosFont.copyWith(
                                color: RetroTheme.lightCyan,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              if (names != null) _buildProfilePanel(names),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t4(4),
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightGray,
            fontSize: 11,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedCompanions.length == 4
                    ? RetroTheme.green
                    : RetroTheme.darkGray,
              ),
              onPressed: _selectedCompanions.length == 4
                  ? _finishCreation
                  : null,
              child: Text(
                'LORE 모험 시작하기 (${_data.initial['x'] ?? 51}, ${_data.initial['y'] ?? 31} 진입) ▶',
                style: RetroTheme.dosFont,
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: RetroTheme.darkGray,
                foregroundColor: RetroTheme.white,
              ),
              onPressed: () => setState(() {
                _selectedCompanions.clear();
                _qIndex = 0;
                for (var i = 0; i < _transdata.length; i++) {
                  _transdata[i] = 0;
                }
                _pointsLeft = 40;
                _agility = 0;
                _accuracy = 0;
                _luck = 0;
                _selectedClass = null;
                _profileTarget = null;
                _step = 1;
              }),
              child: Text(
                t4(5),
                style: RetroTheme.dosFont.copyWith(fontSize: 10),
              ),
            ),
          ],
        ),
        Text(
          t4(6),
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightRed,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
