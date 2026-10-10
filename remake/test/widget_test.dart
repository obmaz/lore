import 'support/source_audio_platform.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/main.dart';
import 'package:lore/widgets/dpad_widget.dart';
import 'package:lore/widgets/message_log_view.dart';
import 'package:lore/widgets/mobile_party_view.dart';
import 'package:lore/widgets/browser_fullscreen_button.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(installSourceAudioPlatform);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Opening title screen and game start flow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const LoreApp());
    await tester.pump(const Duration(milliseconds: 53030));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. 원작 타이틀 화면 렌더링 확인
    expect(find.text('또 다른 지식의 성전'), findsOneWidget);
    expect(find.text('새로운 모험'), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-start')), findsOneWidget);
    expect(find.byType(BrowserFullscreenButton), findsOneWidget);

    // 2. 빠른 모험 시작 버튼 클릭
    await tester.tap(find.byKey(const ValueKey('quick-start')));
    await tester.pump(const Duration(milliseconds: 200));

    // 3. 메인 게임 화면 (성내 마을 51, 31) 진입 확인

    // 4. D-Pad 렌더링 확인
    expect(find.byType(DPadWidget), findsOneWidget);
    expect(
      tester
          .getRect(find.byType(MessageLogView))
          .contains(tester.getCenter(find.byType(DPadWidget))),
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('panel-tab-party')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(MobilePartyView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MobilePartyView),
        matching: find.text('무기 명중'),
      ),
      findsOneWidget,
    );
    expect(find.text('닫기'), findsOneWidget);
  });
}
