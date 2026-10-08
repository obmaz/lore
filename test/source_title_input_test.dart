import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_creation.dart';
import 'package:lore/logic/lore_creation_rules.dart';
import 'package:lore/screens/character_creation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// LOREHELP.PAS Title_Menu 279..300 and LORECRET.PAS Profile/CreateCharacter.
// Modern route/OS-pop adapter is tested; BGI palette and DOS Halt are not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    void silence(String name) => messenger.setMockStreamHandler(
      EventChannel(name),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    silence('xyz.luan/audioplayers.global/events');
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create')
          silence(
            'xyz.luan/audioplayers/events/${(call.arguments as Map)['playerId']}',
          );
        return 1;
      },
    );
  });
  test('Title_Menu accepts exactly source digits 1..3 for all byte keys', () {
    final source = String.fromCharCodes(
      File('repo_source/LORE_1993_src/LOREHELP.PAS').readAsBytesSync(),
    );
    expect(source, contains("if c in ['1'..'3'] then ok := true;"));
    for (var byte = 0; byte < 256; byte++) {
      expect(
        LoreCreationRules.quizChoice(byte),
        byte >= 49 && byte <= 51 ? byte - 49 : null,
      );
    }
  });
  testWidgets(
    'actual title ignores invalid keys, opens new/load and sends exit to OS',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => LoreCreationData.instance.load(force: true));
      var exits = 0, starts = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.pop') exits++;
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterCreationScreen(
              key: UniqueKey(),
              onGameStart: (_) => starts++,
            ),
          ),
        );
        await tester.pump();
      }

      Future<void> key(LogicalKeyboardKey k) async {
        await tester.sendKeyEvent(k);
        await tester.pump();
      }

      await open();
      for (final k in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.keyX,
        LogicalKeyboardKey.arrowUp,
      ]) {
        await key(k);
        expect(find.text('1] 새로운 주인공을 생성 시킴'), findsOneWidget);
        expect(starts, 0);
        expect(exits, 0);
      }
      await key(LogicalKeyboardKey.digit1);
      expect(find.byType(TextField), findsOneWidget);
      await open();
      await key(LogicalKeyboardKey.digit2);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(starts, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await open();
      await key(LogicalKeyboardKey.digit3);
      expect(exits, 1);
      expect(starts, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
