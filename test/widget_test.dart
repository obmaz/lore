import 'package:flutter_test/flutter_test.dart';
import 'package:lore/main.dart';
import 'package:lore/widgets/dpad_widget.dart';

void main() {
  testWidgets('Phase 4 & 5 UI: Field viewport, DPad, and status render properly', (WidgetTester tester) async {
    await tester.pumpWidget(const LoreApp());
    await tester.pump(const Duration(milliseconds: 100));

    // 뷰포트 타이틀, 파티원 상태창, 콘솔 메시지 타이틀 렌더링 확인
    expect(find.text('◆ 필드 탐험 모드 (FIELD VIEW 10x10) ◆'), findsOneWidget);
    expect(find.text('◆ 파티원 상태 (PARTY STATUS) ◆'), findsOneWidget);
    expect(find.text('▶ 콘솔 메시지 (MESSAGE LOG) ◀'), findsOneWidget);

    // 파티원 이름 렌더링 확인
    expect(find.textContaining('Hercules'), findsOneWidget);
    expect(find.textContaining('Merlin'), findsOneWidget);

    // D-Pad 조작 위젯 렌더링 확인
    expect(find.byType(DPadWidget), findsOneWidget);
  });
}
