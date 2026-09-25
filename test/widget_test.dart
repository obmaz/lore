import 'package:flutter_test/flutter_test.dart';
import 'package:lore/main.dart';

void main() {
  testWidgets('Phase 2 UI: DOS layout renders properly', (WidgetTester tester) async {
    await tester.pumpWidget(const LoreApp());

    // 뷰포트, 파티원 상태창, 콘솔 메시지 타이틀 렌더링 확인
    expect(find.text('◆ 메인 뷰포트 (MAIN VIEW) ◆'), findsOneWidget);
    expect(find.text('◆ 파티원 상태 (PARTY STATUS) ◆'), findsOneWidget);
    expect(find.text('▶ 콘솔 메시지 (MESSAGE LOG) ◀'), findsOneWidget);

    // 파티원 이름 렌더링 확인
    expect(find.textContaining('Hercules'), findsOneWidget);
    expect(find.textContaining('Merlin'), findsOneWidget);
  });
}
