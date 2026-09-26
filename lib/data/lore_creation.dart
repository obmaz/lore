import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/party_member.dart';
import 'lore_creation_data.dart';

/// 원작 `LORECRET.PAS` 캐릭터 생성 데이터(설문·동료·계급 조건) 로더.
///
/// `assets/data/creation.json` 을 우선 사용하고, 없으면
/// `lib/data/lore_creation_data.dart` 의 내장 표(원문 그대로)로 폴백한다.
class LoreCreationData {
  static final LoreCreationData instance = LoreCreationData._internal();
  factory LoreCreationData() => instance;
  LoreCreationData._internal();

  bool loaded = false;
  bool usingJson = false;
  String? loadError;

  List<CreationCharacter> characters = [];
  List<CreationQuestion> questions = [];
  List<String> quizIntro = [];
  List<CreationClassOption> classes = [];
  Map<String, List<String>> texts = {};
  Map<int, int> statMap = {};
  int statMapDefault = 10;
  Map<String, int> initial = {};
  List<String> characterNames = [];

  void resetDataForTest() {
    loaded = false;
    usingJson = false;
    loadError = null;
  }

  Future<void> load({AssetBundle? bundle, bool force = false}) async {
    if (loaded && !force) return;
    loaded = true;
    try {
      final raw = await (bundle ?? rootBundle).loadString(
        'assets/data/creation.json',
      );
      final data = json.decode(raw) as Map<String, dynamic>;
      _fromMap(data);
      usingJson = true;
    } catch (e) {
      loadError = e.toString();
      usingJson = false;
      _fromBuiltIn();
    }
  }

  void _fromMap(Map<String, dynamic> data) {
    characters = (data['characters'] as List<dynamic>)
        .map((e) => CreationCharacter.fromJson(e as Map<String, dynamic>))
        .toList();
    questions = (data['questions'] as List<dynamic>)
        .map((e) => CreationQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
    quizIntro = (data['quizIntro'] as List<dynamic>? ?? const [])
        .cast<String>();
    classes = (data['classes'] as List<dynamic>)
        .map((e) => CreationClassOption.fromJson(e as Map<String, dynamic>))
        .toList();
    texts = (data['texts'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
    );
    statMap = (data['statMap'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(int.parse(k), v as int),
    );
    statMapDefault = data['statMapDefault'] as int? ?? 10;
    initial = (data['initial'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as int),
    );
    characterNames = characters.map((c) => c.name).toList();
  }

  void _fromBuiltIn() {
    characters = kCreationCharacters
        .map((e) => CreationCharacter.fromJson(e.cast<String, dynamic>()))
        .toList();
    questions = kCreationQuestions
        .map((e) => CreationQuestion.fromJson(e.cast<String, dynamic>()))
        .toList();
    quizIntro = kCreationQuizIntro;
    classes = kCreationClasses
        .map((e) => CreationClassOption.fromJson(e.cast<String, dynamic>()))
        .toList();
    texts = kCreationTexts;
    statMap = kCreationStatMap;
    statMapDefault = kCreationStatMapDefault;
    initial = kCreationInitial;
    characterNames = characters.map((c) => c.name).toList();
  }

  /// 스탯 번호(1..5) → 값 (원작 `First` 끝의 환산표).
  ///
  /// 0→5, 1→7, 2→11, 3→14, 4→17, 5→19, 6→20, 그 외 10.
  int statValue(int count) => statMap[count] ?? statMapDefault;

  /// 문구 조회(없으면 빈 문자열).
  String text(String group, int index) {
    final list = texts[group] ?? const <String>[];
    if (index < 0 || index >= list.length) return '';
    return list[index];
  }
}

/// 원작 `Character`/`CharacterName` 표의 한 사람.
class CreationCharacter {
  final int id;
  final String name;
  final Gender sex;
  final PlayerClass playerClass;
  final int strength;
  final int mentality;
  final int concentration;
  final int endurance;
  final int resistance;
  final int agility;
  final int accuracy;
  final int luck;

  const CreationCharacter({
    required this.id,
    required this.name,
    required this.sex,
    required this.playerClass,
    required this.strength,
    required this.mentality,
    required this.concentration,
    required this.endurance,
    required this.resistance,
    required this.agility,
    required this.accuracy,
    required this.luck,
  });

  factory CreationCharacter.fromJson(Map<String, dynamic> json) =>
      CreationCharacter(
        id: json['id'] as int,
        name: json['name'] as String,
        sex: (json['sex'] as String?) == 'female' ? Gender.female : Gender.male,
        playerClass: PlayerClass.fromId(json['class'] as int),
        strength: json['strength'] as int,
        mentality: json['mentality'] as int,
        concentration: json['concentration'] as int,
        endurance: json['endurance'] as int,
        resistance: json['resistance'] as int,
        agility: json['agility'] as int,
        accuracy: json['accuracy'] as int,
        luck: json['luck'] as int,
      );

  String get sexLabel => sex == Gender.female ? '여성' : '남성';

  /// 원작 `join`과 같은 방식으로 파티원을 만든다(동료 4명).
  PartyMember toMember() => PartyMember(
    name: name,
    sex: sex,
    playerClass: playerClass,
    strength: strength,
    mentality: mentality,
    concentration: concentration,
    endurance: endurance,
    resistance: resistance,
    agility: agility,
    accArms: accuracy,
    accMagic: playerClass == PlayerClass.mage ? accuracy : 5,
    accEsp: playerClass == PlayerClass.esper ? accuracy : 5,
    luck: luck,
    hp: endurance,
    sp: mentality,
    espLevel: concentration,
  );
}

/// 원작 성향 문답 한 문항.
class CreationQuestion {
  final List<String> lines;
  final List<({String text, int stat})> options;

  const CreationQuestion({required this.lines, required this.options});

  factory CreationQuestion.fromJson(Map<String, dynamic> json) =>
      CreationQuestion(
        lines: (json['lines'] as List<dynamic>).cast<String>(),
        options: (json['options'] as List<dynamic>)
            .map(
              (e) => (
                text: (e as Map<String, dynamic>)['text'] as String,
                stat: e['stat'] as int,
              ),
            )
            .toList(),
      );
}

/// 원작 `Third` 의 계급 항목(원문 조건 문자열 포함).
class CreationClassOption {
  final PlayerClass playerClass;
  final String text;
  final String condition;

  const CreationClassOption({
    required this.playerClass,
    required this.text,
    required this.condition,
  });

  factory CreationClassOption.fromJson(Map<String, dynamic> json) =>
      CreationClassOption(
        playerClass: PlayerClass.fromId(json['class'] as int),
        text: json['text'] as String,
        condition: json['condition'] as String? ?? '',
      );

  /// 원작 조건식(`if (strength>13)and(endurance>13)...`)을 평가한다.
  bool satisfied({
    required int strength,
    required int mentality,
    required int concentration,
    required int endurance,
    required int resistance,
    required int agility,
    required int accuracy,
    required int luck,
  }) {
    final stats = {
      'strength': strength,
      'mentality': mentality,
      'concentration': concentration,
      'endurance': endurance,
      'resistance': resistance,
      'agility': agility,
      'accuracy': accuracy,
      'luck': luck,
    };
    // 8] 떠돌이는 원작에서 무조건 선택 가능하다(`transdata[8] := 1`).
    if (playerClass == PlayerClass.vagrant) return true;
    final matches = RegExp(
      r'(\w+)(?:\[\d\])?\s*(>=|<=|>|<|=)\s*(\d+)',
    ).allMatches(condition);
    if (matches.isEmpty) return false;
    for (final m in matches) {
      final stat = m.group(1)!;
      final op = m.group(2)!;
      final value = int.parse(m.group(3)!);
      final actual = stats[stat];
      if (actual == null) return false;
      final ok = switch (op) {
        '>' => actual > value,
        '>=' => actual >= value,
        '<' => actual < value,
        '<=' => actual <= value,
        _ => actual == value,
      };
      if (!ok) return false;
    }
    return true;
  }
}
