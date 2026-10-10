import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/dialogue_spacing.dart';
import 'package:lore/widgets/lore_source_text.dart';

void main() {
  test('spacing dictionary never changes dialogue characters', () {
    for (final entry in dialogueSpacing.entries) {
      expect(entry.value.replaceAll(RegExp(r'\s+'), ''), entry.key);
    }
  });

  testWidgets('DOS word boundaries rejoin and explicit paragraphs survive', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: loreDialogueText([
            (7, ' 당신이  한 유골 앞에 섰을때  이상한 느낌과'),
            (7, '함께 먼곳으로부터 어떤 소리가 들려왔다.'),
            (7, ''),
            (7, '성주님을 만나보십시오.'),
          ], correctSpacing: true),
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text)).textSpan!.toPlainText();
    expect(text, contains('섰을 때 이상한 느낌과 함께 먼 곳으로부터'));
    expect(text, contains('\n\n성주님을 만나 보십시오.'));
  });
}
