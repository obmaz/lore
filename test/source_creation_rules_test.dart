import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_creation_rules.dart';
import 'package:lore/models/party_member.dart';

/// Independent ASCII game statements in LORECRET.PAS; legacy glyphs ignored.
void main() {
  final source = latin1.decode(
    File('repo_source/LORE_1993_src/LORECRET.PAS').readAsBytesSync(),
  );
  final first = source.substring(
    source.indexOf('Procedure First;'),
    source.indexOf('Procedure Second;'),
  );
  final questions =
      RegExp(
            r"Which;\s*if c = '1' then inc\(transdata\[(\d)\]\);\s*"
            r"if c = '2' then inc\(transdata\[(\d)\]\);\s*"
            r"if c = '3' then inc\(transdata\[(\d)\]\);",
          )
          .allMatches(first)
          .map((m) => [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)])
          .toList();
  final table = <int, int>{
    for (final m in RegExp(
      r'(\d)\s*:\s*transdata\[i\]\s*:=\s*(\d+)',
    ).allMatches(first))
      int.parse(m.group(1)!): int.parse(m.group(2)!),
  };
  final fallback = int.parse(
    RegExp(r'else transdata\[i\] := (\d+)').firstMatch(first)!.group(1)!,
  );

  test('Third every source conjunction mask and every byte operand', () {
    final third = source.substring(
      source.indexOf('Procedure Third;'),
      source.indexOf('Procedure Fourth;'),
    );
    const fields = [
      'strength',
      'mentality',
      'concentration',
      'endurance',
      'resistance',
      'agility',
      'accuracy[1]',
      'luck',
    ];
    final gates = RegExp(
      r'if\s+([^;]+?)\s+then begin\s+SetColor\(7\);\s+'
      r'transdata\[(\d)\] := 1;',
      caseSensitive: false,
    ).allMatches(third).toList();
    expect(gates.length, 7);
    for (final gate in gates) {
      final id = int.parse(gate.group(2)!);
      final comparisons = RegExp(r'(\w+(?:\[1\])?)\s*>\s*(\d+)')
          .allMatches(gate.group(1)!)
          .map((m) => (fields.indexOf(m.group(1)!), int.parse(m.group(2)!)))
          .toList();
      expect(comparisons, isNotEmpty);
      expect(comparisons.every((c) => c.$1 >= 0), isTrue);
      bool expected(List<int> values) =>
          comparisons.every((c) => values[c.$1] > c.$2);
      for (var mask = 0; mask < (1 << comparisons.length); mask++) {
        final values = List<int>.filled(8, 255);
        for (var i = 0; i < comparisons.length; i++) {
          final (slot, threshold) = comparisons[i];
          values[slot] = threshold + ((mask >> i) & 1);
        }
        expect(LoreCreationRules.classEligible(id, values), expected(values));
      }
      // Independent byte sweeps include irrelevant fields to catch extra gates.
      for (var field = 0; field < 8; field++) {
        for (var value = 0; value <= 255; value++) {
          final values = List<int>.filled(8, 255)..[field] = value;
          expect(LoreCreationRules.classEligible(id, values), expected(values));
        }
      }
    }
    expect(third, contains('transdata[8] := 1;'));
    for (var id = 0; id <= 255; id++) {
      if (id >= 1 && id <= 7) continue;
      for (final values in [List<int>.filled(8, 0), List<int>.filled(8, 255)]) {
        expect(LoreCreationRules.classEligible(id, values), id == 8);
      }
    }
  });

  List<int> oracle(List<int> counts, Gender gender) {
    final values = [for (var i = 1; i <= 5; i++) table[counts[i]] ?? fallback];
    final a = gender == Gender.male ? 0 : 1;
    final b = gender == Gender.male ? 3 : 2;
    // Independently distribute the four-point bonus into each remaining
    // capacity, rather than duplicating the production carry statements.
    var bonus = 4;
    for (final slot in [a, b, 4]) {
      final capacity = 20 - values[slot];
      final accepted = bonus < capacity ? bonus : capacity;
      values[slot] += accepted;
      bonus -= accepted;
    }
    return values;
  }

  test(
    'First source extraction is complete and runtime mapping is literal',
    () {
      expect(questions.length, 10);
      expect(table.length, 7);
      expect(LoreCreationRules.questionStats, questions);
      for (var count = -1; count <= 255; count++) {
        expect(LoreCreationRules.statValue(count), table[count] ?? fallback);
      }
    },
  );

  test('First every 3^10 answer path and both gender carry orders', () {
    for (var code = 0; code < 59049; code++) {
      var remaining = code;
      final counts = List<int>.filled(6, 0);
      for (final question in questions) {
        counts[question[remaining % 3]]++;
        remaining ~/= 3;
      }
      for (final gender in Gender.values) {
        expect(
          LoreCreationRules.quizResult(counts, gender),
          oracle(counts, gender),
          reason: 'answers=$code gender=$gender',
        );
      }
    }
  });

  test(
    'First carry saturation and fallback for synthetic count boundaries',
    () {
      for (var a = 0; a <= 10; a++) {
        for (var b = 0; b <= 10; b++) {
          for (var resistance = 0; resistance <= 10; resistance++) {
            final counts = [0, a, a, b, b, resistance];
            for (final gender in Gender.values) {
              expect(
                LoreCreationRules.quizResult(counts, gender),
                oracle(counts, gender),
              );
            }
          }
        }
      }
    },
  );
}
