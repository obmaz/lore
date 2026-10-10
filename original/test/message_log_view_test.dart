import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/widgets/message_log_view.dart';
import 'package:lore/theme/retro_theme.dart';

void main() {
  testWidgets(
    'Message keeps source color without invented latest-line prefixes',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageLogView(logs: ['원문'], colors: [13], revision: 1),
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('원문')).style!.color,
        RetroTheme.ega(13),
      );
      expect(find.textContaining('▶'), findsNothing);
      expect(find.textContaining('·'), findsNothing);
    },
  );

  testWidgets('새 메시지가 오면 같은 길이의 로그에서도 맨 아래로 이동한다', (tester) async {
    final logs = List.generate(30, (index) => '메시지 $index');

    Widget view(int revision) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 140,
          child: MessageLogView(logs: logs, revision: revision),
        ),
      ),
    );

    await tester.pumpWidget(view(30));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    expect(find.text('메시지 29'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 250));
    await tester.pumpAndSettle();
    expect(
      scrollable.position.pixels,
      lessThan(scrollable.position.maxScrollExtent),
    );

    logs.removeAt(0);
    logs.add('새 메시지');
    await tester.pumpWidget(view(31));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    expect(find.text('새 메시지'), findsOneWidget);
  });
}
