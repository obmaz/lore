import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import '../models/party_member.dart';
import '../services/audio_manager.dart';
import '../services/save_manager.dart';

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
  int _step = 0; // 0: 타이틀, 1: 이름&성별, 2: 성향 질문, 3: 직업 확인, 4: 동료 4명 선택

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
  int _currentQuestionIndex = 0;
  PlayerClass _determinedClass = PlayerClass.knight;

  // 선택된 동료 4명 인덱스 (1..10 중)
  final Set<int> _selectedCompanions = {
    1,
    3,
    5,
    7,
  }; // 기본값: Hercules, Merlin, Genius Kie, Regulus

  // 원작 10인 영웅 정보
  static const List<Map<String, dynamic>> companionsList = [
    {'id': 1, 'name': 'Hercules', 'class': '기사', 'desc': '힘과 인내력이 뛰어난 중기사'},
    {'id': 2, 'name': 'Titan', 'class': '기사', 'desc': '공격과 방어의 균형이 잡힌 기사'},
    {'id': 3, 'name': 'Merlin', 'class': '마법사', 'desc': '강력한 정신력의 원로 마법사'},
    {
      'id': 4,
      'name': 'Betelgeuse',
      'class': '마법사',
      'desc': '정신력과 민첩성을 겸비한 마법사',
    },
    {'id': 5, 'name': 'Genius Kie', 'class': '전사', 'desc': '무기 정확도가 가장 뛰어난 검사'},
    {'id': 6, 'name': 'Bellatrix', 'class': '전사', 'desc': '높은 저항력과 민첩성의 전사'},
    {'id': 7, 'name': 'Regulus', 'class': '전투승', 'desc': '맨손 무투술의 달인'},
    {'id': 8, 'name': 'Procyon', 'class': '사냥꾼', 'desc': '정확성과 행운이 높은 사냥꾼'},
    {'id': 9, 'name': 'Arcturus', 'class': '떠돌이', 'desc': '다방면에 능숙한 방랑자'},
    {'id': 10, 'name': 'Algol', 'class': '닌자', 'desc': '은밀하고 치명적인 암살자'},
  ];

  static const List<Map<String, dynamic>> questions = [
    {
      'question': '당신이 한 밤중에 공부하고 있을 때 밖에서 무슨 소리가 들렸다.',
      'options': [
        '1] 밖으로 나가서 알아본다 (근력)',
        '2] 그 소리가 무엇일까 생각을 한다 (정신력)',
        '3] 공부에만 열중한다 (집중력)',
      ],
      'statWeights': [1, 2, 3],
    },
    {
      'question': '체력장 오래달리기에서 한 바퀴를 남겨 놓고 거의 탈진 상태가 되었다.',
      'options': [
        '1] 힘으로 밀고 나간다 (근력)',
        '2] 정신력으로 버티며 달린다 (정신력)',
        '3] 그래도 여태까지와 마찬가지로 달린다 (인내력)',
      ],
      'statWeights': [1, 2, 4],
    },
    {
      'question': '적들에게 완전히 포위되어 승산 없이 싸우고 있다.',
      'options': [
        '1] 힘이 남아 있는 한 죽을 때까지 싸운다 (근력)',
        '2] 한 가지라도 탈출할 가능성을 찾는다 (정신력)',
        '3] 일단 싸우면서 여러 방법을 생각한다 (집중력)',
      ],
      'statWeights': [1, 2, 5],
    },
    {
      'question': '매우 복잡한 매듭을 풀어야 하는 일이 생겼다.',
      'options': [
        '1] 칼로 매듭을 잘라 버린다 (근력)',
        '2] 매듭의 끝부분부터 차근차근 훑어본다 (정신력)',
        '3] 어쨌든 계속 풀려고 손을 놀린다 (인내력)',
      ],
      'statWeights': [1, 2, 4],
    },
  ];

  void _answerQuestion(int choiceIndex) {
    final weight = questions[_currentQuestionIndex]['statWeights'][choiceIndex];
    _transdata[weight]++;

    if (_currentQuestionIndex < questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      // 4문항 완료 -> 직업 판정
      int maxScore = 0;
      int bestStat = 1;
      for (int i = 1; i <= 5; i++) {
        if (_transdata[i] > maxScore) {
          maxScore = _transdata[i];
          bestStat = i;
        }
      }

      PlayerClass pClass;
      switch (bestStat) {
        case 1:
          pClass = PlayerClass.knight;
          break;
        case 2:
          pClass = PlayerClass.mage;
          break;
        case 3:
          pClass = PlayerClass.esper;
          break;
        case 4:
          pClass = PlayerClass.warrior;
          break;
        default:
          pClass = PlayerClass.monk;
          break;
      }

      setState(() {
        _determinedClass = pClass;
        _step = 3;
      });
    }
  }

  void _finishCreation() {
    // 1. 주인공 캐릭터 생성
    final hero = PartyMember(
      name: _nameController.text.trim().isEmpty
          ? 'Hero'
          : _nameController.text.trim(),
      sex: _selectedGender,
      playerClass: _determinedClass,
      strength: 15 + _transdata[1] * 2,
      mentality: 12 + _transdata[2] * 2,
      concentration: 10 + _transdata[3] * 2,
      endurance: 15 + _transdata[4] * 2,
      resistance: 10,
      agility: 14,
      accArms: 15,
      accMagic: 10,
      accEsp: 8,
      luck: 12,
    );

    // 2. 선택된 동료 4명 생성
    final party = <PartyMember>[hero];
    for (final compId in _selectedCompanions) {
      party.add(PartyMember.createPreset(compId));
    }

    widget.onGameStart(party);
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
        return _buildClassScreen();
      case 4:
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
        const Text(
          '또 다른 지식의 성전',
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
                '원작: 안 영 기 (1993년 Borland Pascal 6.0)',
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
                '새 게임 시작 (캐릭터 만들기)',
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
                '💾 저장된 모험 이어하기',
                style: RetroTheme.headerFont.copyWith(fontSize: 12),
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
                        icon: const Icon(Icons.close, size: 16, color: RetroTheme.lightGray),
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
                            color: slotData != null ? RetroTheme.lightCyan : RetroTheme.darkGray,
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
                                      color: slotData != null ? RetroTheme.yellow : RetroTheme.lightGray,
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
                                backgroundColor: slotData != null ? RetroTheme.blue : RetroTheme.darkGray,
                                foregroundColor: RetroTheme.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                style: RetroTheme.dosFont.copyWith(fontSize: 10),
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
                      child: Text('닫기', style: RetroTheme.dosFont.copyWith(fontSize: 11)),
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
          '◆ 주인공의 이름과 성별을 정해주십시오 ◆',
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
                '당신의 이름은 :',
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
                '당신의 성별은 :',
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
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: RetroTheme.blue),
          onPressed: () => setState(() => _step = 2),
          child: Text('성향 테스트 진행 ▶', style: RetroTheme.dosFont),
        ),
      ],
    );
  }

  // ==========================================
  // Step 2: 원작 4대 성향 문답 테스트
  // ==========================================
  Widget _buildQuestionScreen() {
    final q = questions[_currentQuestionIndex];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '◆ 성향 문답 테스트 (${_currentQuestionIndex + 1} / 4) ◆',
          style: RetroTheme.headerFont.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 8),
        Text(
          '자신에게 맞는 답을 소신있게 선택해 주십시오.',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightGray,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: 480,
          padding: const EdgeInsets.all(16),
          color: RetroTheme.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q['question'],
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.yellow,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(3, (idx) {
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
                        q['options'][idx],
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
  // Step 3: 직업 판정 확인 및 선택
  // ==========================================
  Widget _buildClassScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '◆ 성향 분석 결과 ◆',
          style: RetroTheme.headerFont.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 16),
        Container(
          width: 420,
          padding: const EdgeInsets.all(16),
          color: RetroTheme.background,
          child: Column(
            children: [
              Text(
                '${_nameController.text}님의 추천 계급은',
                style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightGray),
              ),
              const SizedBox(height: 8),
              Text(
                '★ ${_determinedClass.koreanName} ★',
                style: RetroTheme.headerFont.copyWith(
                  fontSize: 22,
                  color: RetroTheme.yellow,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '원하시면 다른 직업으로 변경하여 모험을 시작할 수 있습니다.',
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 11,
                  color: RetroTheme.lightCyan,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButton<PlayerClass>(
                value: _determinedClass,
                dropdownColor: RetroTheme.panelBg,
                items: PlayerClass.values.take(8).map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(c.koreanName, style: RetroTheme.dosFont),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _determinedClass = val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: RetroTheme.blue),
          onPressed: () => setState(() => _step = 4),
          child: Text('동행할 4명의 동료 용사 선택 ▶', style: RetroTheme.dosFont),
        ),
      ],
    );
  }

  // ==========================================
  // Step 4: 동행할 4명의 동료 용사 선택
  // ==========================================
  Widget _buildCompanionsScreen() {
    return Column(
      children: [
        Text(
          '◆ 동행할 4명의 동료 용사를 골라주십시오 ◆',
          style: RetroTheme.headerFont.copyWith(fontSize: 15),
        ),
        Text(
          '선택된 동료: ${_selectedCompanions.length} / 4 명',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: companionsList.length,
            itemBuilder: (context, idx) {
              final c = companionsList[idx];
              final id = c['id'] as int;
              final isSelected = _selectedCompanions.contains(id);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? RetroTheme.blue.withValues(alpha: 0.5)
                      : RetroTheme.background,
                  border: Border.all(
                    color: isSelected ? RetroTheme.yellow : RetroTheme.darkGray,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            if (_selectedCompanions.length < 4) {
                              _selectedCompanions.add(id);
                            }
                          } else {
                            _selectedCompanions.remove(id);
                          }
                        });
                      },
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${c['name']} [${c['class']}]',
                        style: RetroTheme.dosFont.copyWith(
                          color: isSelected
                              ? RetroTheme.yellow
                              : RetroTheme.white,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        c['desc'],
                        style: RetroTheme.dosFont.copyWith(
                          fontSize: 11,
                          color: RetroTheme.lightGray,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedCompanions.length == 4
                ? RetroTheme.green
                : RetroTheme.darkGray,
          ),
          onPressed: _selectedCompanions.length == 4 ? _finishCreation : null,
          child: Text(
            'LORE 모험 시작하기 (성내 광장 51, 31 진입) ▶',
            style: RetroTheme.dosFont,
          ),
        ),
      ],
    );
  }
}
