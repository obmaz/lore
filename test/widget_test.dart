import 'package:flutter_test/flutter_test.dart';
import 'package:lore/main.dart';
import 'package:lore/widgets/dpad_widget.dart';

void main() {
  testWidgets('Opening title screen and game start flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LoreApp());
    await tester.pump(const Duration(milliseconds: 100));

    // 1. 원작 타이틀 화면 렌더링 확인
    expect(find.text('또 다른 지식의 성전'), findsOneWidget);
    expect(find.text('새 게임 시작 (캐릭터 만들기)'), findsOneWidget);
    expect(find.text('빠른 모험 시작 (기본 파티)'), findsOneWidget);

    // 2. 빠른 모험 시작 버튼 클릭
    await tester.tap(find.text('빠른 모험 시작 (기본 파티)'));
    await tester.pump(const Duration(milliseconds: 200));

    // 3. 메인 게임 화면 (성내 마을 51, 31) 진입 확인
    expect(find.text('◆ 필드 탐험 모드 (FIELD VIEW 10x10) ◆'), findsOneWidget);
    expect(find.text('◆ 파티원 상태 (PARTY STATUS) ◆'), findsOneWidget);
    expect(find.text('▶ 콘솔 메시지 (최신 메시지 상단 표시) ◀'), findsOneWidget);

    // 4. D-Pad 렌더링 확인
    expect(find.byType(DPadWidget), findsOneWidget);
  });
}
