import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/theme/retro_theme.dart';
import 'package:lore/logic/lore_view_procedures.dart';
import 'package:lore/widgets/lore_select_view.dart';
import 'package:lore/widgets/lore_source_text.dart';

void main() {
  testWidgets(
    'QuickView header keeps SetColor(15) name and SetColor(12) conditions',
    (tester) async {
      // LOREMENU.PAS:599-602: two HPrintXY calls on the same header row.
      final header = LoreViewProcedures.quickView([]).first.$2;
      await tester.pumpWidget(
        MaterialApp(home: loreSourceText(header, RetroTheme.logFont)),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textSpan, isNotNull);
      expect(text.textSpan!.toPlainText(), header);
      final parts = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(parts.map((p) => p.style!.color), [
        RetroTheme.ega(15),
        RetroTheme.ega(12),
      ]);
      expect(parts.last.text, ' 중독 의식불명 죽음');
    },
  );

  testWidgets(
    'dynamic prophecy and training amounts retain both cPrint colors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              loreSourceText(' # 당신은 Lord Ahn 을 만날 것이다', RetroTheme.dosFont),
              loreSourceText(' 당신이 다음 레벨이 되려면 경험치가 6000', RetroTheme.dosFont),
            ],
          ),
        ),
      );
      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      for (var i = 0; i < texts.length; i++) {
        final parts = (texts[i].textSpan! as TextSpan).children!
            .cast<TextSpan>();
        expect(
          parts.map((p) => p.style!.color),
          i == 0
              ? [RetroTheme.ega(10), RetroTheme.ega(15)]
              : [RetroTheme.ega(7), RetroTheme.ega(11)],
        );
      }
      expect(texts[1].textSpan!.toPlainText(), ' 당신이 다음 레벨이 되려면 경험치가 6000');
    },
  );

  testWidgets('common speech and Select keep the source cPrint word colors', (
    tester,
  ) async {
    const text = ' 나는 LORE 성의 성주 Lord Ahn 이오.';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoreMessageDialog(lines: const [(7, text), (7, '')]),
        ),
      ),
    );
    final rendered = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && w.textSpan?.toPlainText() == text,
      ),
    );
    final spans = (rendered.textSpan! as TextSpan).children!;
    expect(spans.map((s) => s.toPlainText()).join(), text);
    expect(spans.map((s) => (s as TextSpan).style!.color), [
      RetroTheme.ega(7),
      RetroTheme.ega(11),
      RetroTheme.ega(7),
    ]);
    expect(find.text(''), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
