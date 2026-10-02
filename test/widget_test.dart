import 'package:flutter_test/flutter_test.dart';
import 'package:lore/main.dart';
import 'package:lore/widgets/dpad_widget.dart';
import 'package:lore/widgets/message_log_view.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Opening title screen and game start flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LoreApp());
    await tester.pump(const Duration(milliseconds: 100));

    // 1. 원작 타이틀 화면 렌더링 확인
    expect(find.text('또다른 지식의 성전  제 1 부'), findsOneWidget);
    expect(find.text('1] 새로운 주인공을 생성 시킴'), findsOneWidget);
    expect(find.text('빠른 모험 시작 (기본 파티)'), findsOneWidget);

    // 2. 빠른 모험 시작 버튼 클릭
    await tester.tap(find.text('빠른 모험 시작 (기본 파티)'));
    await tester.pump(const Duration(milliseconds: 200));

    // 3. 메인 게임 화면 (성내 마을 51, 31) 진입 확인
    expect(find.text('◆ 필드 탐험 모드 (FIELD VIEW 10x10) ◆'), findsOneWidget);
    expect(find.text('▶ 콘솔 메시지 ◀'), findsOneWidget);

    // 4. D-Pad 렌더링 확인
    expect(find.byType(DPadWidget), findsOneWidget);
    expect(
      tester
          .getRect(find.byType(MessageLogView))
          .contains(tester.getCenter(find.byType(DPadWidget))),
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('panel-tab-party')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('◆ 파티원 상태 (PARTY STATUS) ◆'), findsOneWidget);
  });
}
