import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// BattleMode's `PressAnyKey` / `c := ReadKey` waits: any key continues.
Future<void> pressBattleKey(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.space);
  await tester.pump(const Duration(milliseconds: 200));
}
