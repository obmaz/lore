import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter/services.dart';

import '../logic/lore_menu_text.dart';
import '../logic/lore_creation_rules.dart';
import '../logic/lore_creation_allocation.dart';
import '../logic/lore_creation_companions.dart';
import '../logic/lore_creation_name.dart';
import '../data/lore_creation.dart';
import '../theme/retro_theme.dart';
import '../models/party_member.dart';
import '../services/audio_manager.dart';
import '../services/save_manager.dart';
import '../widgets/monster_bestiary_dialog.dart';
import '../widgets/lore_guide_dialog.dart';
import '../widgets/lore_creation_animation.dart';
import '../logic/lore_creation_palette.dart';

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
  bool _displayFinished = false;
  bool _dividerFinished = false;
  final _bufferedCreationKeys = <KeyEvent>[];
  bool get _creationBlocking =>
      (_step == 1 && !_displayFinished) || (_step == 3 && !_dividerFinished);
  Timer? _classAcknowledgementTimer;
  Timer? _classErrorTimer;
  bool _classAcknowledgementReady = false;
  bool _classErrorHold = false;
  final _classAcknowledgementKeys = <KeyEvent>[];
  int _classPulseRevision = 0;

  @override
  void dispose() {
    _classAcknowledgementTimer?.cancel();
    _classErrorTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _finishPalette(bool display) {
    setState(() {
      if (display) {
        _displayFinished = true;
      } else {
        _dividerFinished = true;
      }
    });
    while (_bufferedCreationKeys.isNotEmpty && !_creationBlocking) {
      final event = _bufferedCreationKeys.removeAt(0);
      switch (_step) {
        case 1:
          _readNameEvent(event);
        case 2:
          final label = event.character ?? event.logicalKey.keyLabel;
          final answer = label.length == 1
              ? LoreCreationRules.quizChoice(label.codeUnitAt(0))
              : null;
          if (answer != null) _answerQuestion(answer);
        case 3:
          _readAllocationEvent(event);
        case 4:
          _readClassEvent(event);
        case 5:
          _readCompanionKey(event.logicalKey);
      }
    }
  }

  void _acceptClass(int id) {
    setState(() => _selectedClass = PlayerClass.fromId(id));
    _classAcknowledgementReady = false;
    _classAcknowledgementTimer?.cancel();
    _classAcknowledgementTimer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted || _step != 4) return;
      setState(() => _classAcknowledgementReady = true);
      if (_classAcknowledgementKeys.isNotEmpty) {
        final pending = List<KeyEvent>.of(_classAcknowledgementKeys);
        _classAcknowledgementKeys.clear();
        setState(() => _step = 5);
        for (final event in pending.skip(1)) {
          _readCompanionKey(event.logicalKey);
        }
      }
    });
  }

  void _rejectClass(int key) {
    final id = key - 48;
    final audible = id >= 1 && id <= 8 && _classFlags[id] != 1;
    setState(() {
      if (!audible) {
        _classPulseRevision++;
      }
      _classErrorHold = audible;
    });
    if (!audible) return;
    unawaited(AudioManager.instance.playSourceTone(100, 100));
    _classErrorTimer?.cancel();
    _classErrorTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted || _step != 4) return;
      setState(() {
        _classErrorHold = false;
        _classPulseRevision++;
      });
      if (_classKeys.isNotEmpty) _scheduleClassDrain();
    });
  }

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
  LoreCreationName _sourceName = LoreCreationName();
  bool _sourceNameActive = false;

  String get _heroName => _sourceNameActive
      ? _sourceName.text
      : (_nameController.text.trim().isEmpty
            ? 'Hero'
            : _nameController.text.trim());

  void _readNameEvent(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.capsLock ||
        key == LogicalKeyboardKey.numLock ||
        key == LogicalKeyboardKey.scrollLock) {
      return; // These hardware toggles do not enqueue a DOS ReadKey byte.
    }
    final character = event.character ?? key.keyLabel;
    final code = switch (key) {
      LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter => 13,
      LogicalKeyboardKey.escape => 27,
      LogicalKeyboardKey.backspace => 8,
      LogicalKeyboardKey.tab => 9,
      _ =>
        character.length == 1 && character.codeUnitAt(0) <= 255
            ? character.codeUnitAt(0)
            : 0,
    };
    setState(() {
      _sourceNameActive = true;
      _sourceName.readKey(code);
      _nameController.text = _sourceName.text;
      if (_sourceName.sex case final sex?) {
        _selectedGender = sex == 0 ? Gender.male : Gender.female;
        LoreCreationRules.resetQuiz(_transdata);
        _step = 2;
      }
    });
  }

  void _selectNameGender(Gender gender) {
    setState(() {
      _selectedGender = gender;
      if (_sourceNameActive && _sourceName.nameAccepted) {
        _sourceName.readKey(gender == Gender.male ? 77 : 70);
        LoreCreationRules.resetQuiz(_transdata);
        _step = 2;
      }
    });
  }

  // 질문 응답 및 성향 데이터 (transdata[1..5])
  final List<int> _transdata = List.filled(6, 0);

  // 선택된 동료 4명 인덱스 (1..10 중)
  // Fourth starts with all ten selection flags cleared. A selected companion
  // cannot be deselected; only the explicit restart clears these flags.
  LoreCreationCompanions _companions = LoreCreationCompanions();
  Set<int> get _selectedCompanions => _companions.selected;
  bool _awaitingProfileKey = false;

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
  LoreCreationAllocation _allocation = LoreCreationAllocation();
  int get _agility => _allocation.values[0];
  int get _accuracy => _allocation.values[1];
  int get _luck => _allocation.values[2];
  int get _pointsLeft => _allocation.remaining;

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
    final stats = LoreCreationRules.quizResult(_transdata, _selectedGender);
    _strength = stats[0];
    _mentality = stats[1];
    _concentration = stats[2];
    _endurance = stats[3];
    _resistanceStat = stats[4];
  }

  /// 원작 `First` 의 답 처리(`inc(transdata[N])`) 후 다음 단계로.
  void _answerQuestion(int choiceIndex) {
    final q = _questions[_qIndex];
    if (choiceIndex >= q.options.length) return;
    final stat = LoreCreationRules.questionStats[_qIndex][choiceIndex];
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
      _allocation.cursor = slot - 1;
      _allocation.readKey(0, scan: delta < 0 ? 75 : 77);
    });
  }

  /// 원작 `Third` - 조건을 만족하는 계급만 고를 수 있다.
  List<int> get _classFlags => LoreCreationRules.classFlags([
    _strength,
    _mentality,
    _concentration,
    _endurance,
    _resistanceStat,
    _agility,
    _accuracy,
    _luck,
  ]);
  List<CreationClassOption> get _availableClasses =>
      _data.classes.where((c) => _classFlags[c.playerClass.id] == 1).toList();

  void _selectClass(int key) {
    if (_selectedClass != null || _classErrorHold) return;
    final id = LoreCreationRules.selectClass(key, _classFlags);
    if (id != null) {
      _acceptClass(id);
    } else {
      _rejectClass(key);
    }
  }

  final _classKeys = <int>[];
  bool _classDrainScheduled = false;

  void _readClassEvent(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.capsLock ||
        key == LogicalKeyboardKey.numLock ||
        key == LogicalKeyboardKey.scrollLock) {
      return;
    }
    if (_selectedClass != null) {
      if (_classAcknowledgementReady) {
        setState(() => _step = 5);
      } else {
        _classAcknowledgementKeys.add(event);
      }
      return;
    }
    final scan = switch (key) {
      LogicalKeyboardKey.arrowUp => 72,
      LogicalKeyboardKey.arrowDown => 80,
      LogicalKeyboardKey.arrowLeft => 75,
      LogicalKeyboardKey.arrowRight => 77,
      _ => null,
    };
    if (scan != null) {
      _classKeys.addAll([0, scan]);
    } else {
      final text = event.character ?? key.keyLabel;
      final code = switch (key) {
        LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter => 13,
        LogicalKeyboardKey.escape => 27,
        LogicalKeyboardKey.backspace => 8,
        LogicalKeyboardKey.tab => 9,
        _ =>
          text.length == 1 && text.codeUnitAt(0) <= 255
              ? text.codeUnitAt(0)
              : 0,
      };
      _classKeys.add(code);
    }
    _scheduleClassDrain();
  }

  void _scheduleClassDrain() {
    if (_classDrainScheduled || _classErrorHold) return;
    _classDrainScheduled = true;
    // A presentation frame is the modern adapter's queue boundary, not a
    // claim of equal DOS KeyPressed polling duration or palette animation.
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _classDrainScheduled = false;
      final keys = List<int>.of(_classKeys);
      _classKeys.clear();
      if (!mounted || _step != 4 || _selectedClass != null) return;
      final id = LoreCreationRules.selectClassQueue(keys, _classFlags);
      if (id != null) {
        _acceptClass(id);
      } else if (keys.isNotEmpty) {
        _rejectClass(keys.last);
      }
    });
  }

  /// 원작 `Fourth` 끝의 파티 구성 + `Last` 초기 상태로 게임을 시작한다.
  void _finishCreation() {
    final heroName = _heroName;

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
    // Fourth scans transdata[1..10], regardless of selection order.
    for (final id in _selectedCompanions.toList()..sort()) {
      final c = _data.characters.firstWhere((e) => e.id == id);
      party.add(c.toMember());
    }
    for (final m in party) {
      m.applyCreationInit();
    }

    // Fresh Create's player6 is still a zero record in Last's initial saves.
    // Set_All calls Display_Condition only after those saves are written.
    party.add(PartyMember.zero());
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
            '${t('Profile', 3)}${LoreCreationRules.classLabel(c.playerClass.id)}',
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final panel = Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RetroTheme.panelBg,
                border: Border.all(color: RetroTheme.borderColor, width: 3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: LayoutBuilder(
                builder: (context, content) {
                  if (content.maxHeight < 480) {
                    return SingleChildScrollView(
                      child: SizedBox(height: 480, child: _buildCurrentStep()),
                    );
                  }
                  return _buildCurrentStep();
                },
              ),
            );
            if (viewport.maxWidth < 600 &&
                viewport.maxHeight > viewport.maxWidth) {
              return SizedBox.expand(child: panel);
            }
            return Center(
              child: AspectRatio(aspectRatio: 4 / 3, child: panel),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_creationBlocking) {
      final display = _step == 1;
      return LoreCreationAnimation(
        key: ValueKey(display ? 'creation-display' : 'creation-divider'),
        frames: display
            ? LoreCreationPalette.display
            : LoreCreationPalette.divider,
        onKey: _bufferedCreationKeys.add,
        onComplete: () => _finishPalette(display),
        builder: (colors) {
          if (display) {
            return Container(
              decoration: BoxDecoration(
                color: colors[1],
                border: Border.all(
                  color: colors[9] ?? loreVgaColor(0, 0, 31),
                  width: 3,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _data.text('Display', 0),
                    style: RetroTheme.headerFont.copyWith(
                      color: colors[13] ?? loreVgaColor(0, 0, 31),
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _data.text('Display', 1),
                    style: RetroTheme.dosFont.copyWith(
                      color: colors[11] ?? loreVgaColor(0, 0, 31),
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final item in [
                ('체  력', _strength),
                ('정신력', _mentality),
                ('집중력', _concentration),
                ('인내력', _endurance),
                ('저항력', _resistanceStat),
              ])
                Text('◆ ${item.$1} : ${item.$2}', style: RetroTheme.dosFont),
              const SizedBox(height: 12),
              Container(height: 2, color: colors[8]),
            ],
          );
        },
      );
    }
    switch (_step) {
      case 0:
        return _keyboardStep(_buildTitleScreen(), _readTitleKey);
      case 1:
        return _keyboardStep(
          _buildNameScreen(),
          (_) {},
          readEvent: _readNameEvent,
        );
      case 2:
        return _keyboardStep(_buildQuestionScreen(), (key) {
          final label = key.keyLabel;
          final choice = LoreCreationRules.quizChoice(
            label.length == 1 ? label.codeUnitAt(0) : 0,
          );
          if (choice != null) _answerQuestion(choice);
        });
      case 3:
        return _buildDistributeScreen();
      case 4:
        return _keyboardStep(
          LoreCreationPulse(
            key: ValueKey(_classPulseRevision),
            confirmation: _selectedClass != null,
            paused: _classErrorHold,
            builder: (color) => _buildClassScreen(color),
          ),
          (_) {},
          readEvent: _readClassEvent,
        );
      case 5:
        return _keyboardStep(_buildCompanionsScreen(), _readCompanionKey);
      default:
        return _buildTitleScreen();
    }
  }

  void _showCompanionProfile(CreationCharacter companion) {
    if (MediaQuery.sizeOf(context).width < 600) {
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final panel = Dialog(
            child: SingleChildScrollView(child: _buildProfilePanel(companion)),
          );
          return _awaitingProfileKey
              ? _keyboardStep(panel, (_) {
                  setState(() => _awaitingProfileKey = false);
                  Navigator.of(ctx).pop();
                })
              : panel;
        },
      ).then((_) {
        if (mounted && _awaitingProfileKey) {
          setState(() => _awaitingProfileKey = false);
        }
      });
    } else {
      setState(() => _profileTarget = companion);
    }
  }

  void _resetCreation({bool title = false}) {
    setState(() {
      _companions = LoreCreationCompanions();
      _qIndex = 0;
      for (var i = 0; i < _transdata.length; i++) {
        _transdata[i] = 0;
      }
      _allocation = LoreCreationAllocation();
      _selectedClass = null;
      _displayFinished = false;
      _dividerFinished = false;
      _bufferedCreationKeys.clear();
      _classAcknowledgementTimer?.cancel();
      _classErrorTimer?.cancel();
      _classAcknowledgementKeys.clear();
      _classAcknowledgementReady = false;
      _classErrorHold = false;
      _classKeys.clear();
      _profileTarget = null;
      _awaitingProfileKey = false;
      _sourceName = LoreCreationName();
      _sourceNameActive = false;
      _step = title ? 0 : 1;
    });
  }

  void _readCompanionKey(LogicalKeyboardKey key) {
    if (_awaitingProfileKey) {
      setState(() => _awaitingProfileKey = false);
      return; // LORECRET.Profile ReadKey, consumed before Fourth resumes.
    }
    final scan = switch (key) {
      LogicalKeyboardKey.arrowUp => 72,
      LogicalKeyboardKey.arrowDown => 80,
      LogicalKeyboardKey.arrowLeft => 75,
      LogicalKeyboardKey.arrowRight => 77,
      _ => null,
    };
    final label = key.keyLabel;
    final code = scan != null
        ? 0
        : key == LogicalKeyboardKey.enter
        ? 13
        : key == LogicalKeyboardKey.escape
        ? 27
        : label.length == 1
        ? label.codeUnitAt(0)
        : 0;
    late LoreCompanionInput action;
    setState(() => action = _companions.readKey(code, scan: scan ?? 0));
    switch (action) {
      case LoreCompanionInput.profile:
        _awaitingProfileKey = true;
        _showCompanionProfile(
          _data.characters.firstWhere((c) => c.id == _companions.cursor),
        );
      case LoreCompanionInput.finish:
        _finishCreation();
      case LoreCompanionInput.restart:
        _resetCreation(title: true);
      case LoreCompanionInput.none:
        break;
    }
  }

  void _readTitleKey(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    final choice = label.length == 1
        ? LoreCreationRules.quizChoice(label.codeUnitAt(0))
        : null;
    if (choice == 0) setState(() => _step = 1);
    if (choice == 1) _showLoadGameDialog();
    if (choice == 2) SystemNavigator.pop();
  }

  Widget _keyboardStep(
    Widget child,
    void Function(LogicalKeyboardKey) read, {
    void Function(KeyEvent)? readEvent,
  }) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      if ([
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.shiftRight,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.controlRight,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.altRight,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.metaRight,
      ].contains(event.logicalKey)) {
        return KeyEventResult.ignored;
      }
      if (readEvent != null) {
        readEvent(event);
      } else {
        read(event.logicalKey);
      }
      return KeyEventResult.handled;
    },
    child: child,
  );

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
              key: const ValueKey('quick-start'),
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
              child: const Icon(
                Icons.fast_forward,
                size: 18,
                color: RetroTheme.lightCyan,
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
                'Enemy data',
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
                LoreGuideDialog.titleLine,
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
                        LoreMenuText.optionLoadPrompt,
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
                  ...List.generate(4, (index) {
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
                                  slotTitle,
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
                                    '-',
                                    style: RetroTheme.dosFont.copyWith(
                                      color: RetroTheme.darkGray,
                                      fontSize: 10,
                                    ),
                                  )
                                else ...[
                                  Text(
                                    '${slotData.mapTitle}  ${LoreMenuText.viewPartyXAxis}${slotData.playerX} ${LoreMenuText.viewPartyYAxis}${slotData.playerY}  ${LoreMenuText.viewPartyGold}${slotData.gold}',
                                    style: RetroTheme.dosFont.copyWith(
                                      color: RetroTheme.lightGreen,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    slotData.party
                                        .map((p) => p.name)
                                        .join(', '),
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
                              LoreMenuText.optionResume,
                              style: RetroTheme.dosFont.copyWith(fontSize: 10),
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
              ExcludeFocus(
                excluding: _sourceNameActive,
                child: TextField(
                  readOnly: _sourceNameActive,
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
                    onPressed: () => _selectNameGender(Gender.male),
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
                    onPressed: () => _selectNameGender(Gender.female),
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
          onPressed: _sourceNameActive
              ? null
              : () => setState(() {
                  LoreCreationRules.resetQuiz(_transdata);
                  _step = 2;
                }),
          child: Text(_data.text('Third', 10), style: RetroTheme.dosFont),
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
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) => _readAllocationEvent(event),
      child: Column(
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
                            color: _allocation.cursor == slot - 1
                                ? RetroTheme.yellow
                                : RetroTheme.white,
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
            onPressed: _pointsLeft == 0
                ? () => setState(() => _step = 4)
                : null,
            child: Text(_data.text('Third', 10), style: RetroTheme.dosFont),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Step 3: 직업 판정 확인 및 선택
  // ==========================================
  KeyEventResult _readAllocationEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final scan = switch (key) {
      LogicalKeyboardKey.arrowUp => 72,
      LogicalKeyboardKey.arrowDown => 80,
      LogicalKeyboardKey.arrowLeft => 75,
      LogicalKeyboardKey.arrowRight => 77,
      _ => null,
    };
    if (scan == null && key != LogicalKeyboardKey.enter) {
      return KeyEventResult.handled;
    }
    setState(() {
      if (_allocation.readKey(scan == null ? 13 : 0, scan: scan ?? 0)) {
        _step = 4;
      }
    });
    return KeyEventResult.handled;
  }

  Widget _buildClassScreen(Color pulse) {
    final options = _data.classes;
    final t = _data.text('Third', 0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_selectedClass == null)
          Text('◆ $t ◆', style: RetroTheme.headerFont.copyWith(fontSize: 15)),
        const SizedBox(height: 10),
        if (_selectedClass == null)
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
                    onPressed: _selectedClass == null
                        ? () => _selectClass(c.playerClass.id + 48)
                        : null,
                    child: Text(
                      c.text,
                      style: RetroTheme.dosFont.copyWith(
                        color: _classFlags[c.playerClass.id] != 1
                            ? loreVgaColor(15, 15, 15)
                            : _selectedClass == c.playerClass
                            ? RetroTheme.yellow
                            : pulse,
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
            LoreCreationRules.classConfirmation(_selectedClass!.id),
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.lightGreen,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 14),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedClass != null
                ? RetroTheme.green
                : RetroTheme.darkGray,
          ),
          onPressed: _selectedClass == null || !_classAcknowledgementReady
              ? null
              : () => setState(() => _step = 5),
          child: Text(
            _data.text('Third', 10),
            style: RetroTheme.dosFont.copyWith(
              color: _selectedClass != null ? pulse : RetroTheme.darkGray,
            ),
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
        if (_companions.choosing)
          Text(
            '${_data.characters.firstWhere((c) => c.id == _companions.cursor).name}: ${t4(2)} [1] / ${t4(3)} [2]',
            style: RetroTheme.dosFont,
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
                          color: isSelected || c.id == _companions.cursor
                              ? RetroTheme.yellow
                              : RetroTheme.darkGray,
                        ),
                      ),
                      key: ValueKey('creation-companion-${c.id}'),
                      child: LayoutBuilder(
                        builder: (context, row) {
                          final label = Text(
                            '${c.name} [${c.playerClass.koreanName}]',
                            style: RetroTheme.dosFont.copyWith(
                              color: isSelected
                                  ? RetroTheme.yellow
                                  : RetroTheme.white,
                              fontSize: 12,
                            ),
                          );
                          final actions = <Widget>[
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _companions.join(c.id);
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
                              onPressed: () => _showCompanionProfile(c),
                              child: Text(
                                t4(3),
                                style: RetroTheme.dosFont.copyWith(
                                  color: RetroTheme.lightCyan,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ];
                          if (row.maxWidth < 500) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                label,
                                Wrap(children: actions),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: label),
                              ...actions,
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              if (names != null && MediaQuery.sizeOf(context).width >= 600)
                _buildProfilePanel(names),
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
        if (_companions.complete)
          Wrap(
            children: [
              Text(
                _heroName,
                style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow),
              ),
              for (final id in _selectedCompanions.toList()..sort())
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _data.characters.firstWhere((c) => c.id == id).name,
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.yellow,
                    ),
                  ),
                ),
            ],
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
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
              child: Text(_data.text('Third', 10), style: RetroTheme.dosFont),
            ),
            const SizedBox(width: 10),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: RetroTheme.darkGray,
                foregroundColor: RetroTheme.white,
              ),
              onPressed: _resetCreation,
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
