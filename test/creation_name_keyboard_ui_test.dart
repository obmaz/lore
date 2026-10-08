import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_creation.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/character_creation_screen.dart';

// LORECRET.PAS Name through real desktop/mobile keyboard and full creation.
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
        if (call.method == 'create') {
          silence(
            'xyz.luan/audioplayers/events/${(call.arguments as Map)['playerId']}',
          );
        }
        return 1;
      },
    );
  });
  for (final size in [const Size(1280, 1000), const Size(390, 844)]) {
    for (final expected in ['a' * 15, ' a ']) {
      testWidgets(
        'native name reset, ignored erase and M/F wait reach full party: $size/$expected',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.runAsync(
            () => LoreCreationData.instance.load(force: true),
          );
          List<PartyMember>? party;
          await tester.pumpWidget(
            MaterialApp(
              home: CharacterCreationScreen(onGameStart: (p) => party = p),
            ),
          );
          Future<void> key(LogicalKeyboardKey k, {String? character}) async {
            await tester.sendKeyEvent(k, character: character);
            await tester.pump();
          }

          Future<void> letters(String text) async {
            for (final c in text.split('')) {
              await key(
                c == ' ' ? LogicalKeyboardKey.space : LogicalKeyboardKey.keyA,
                character: c,
              );
            }
          }

          String text() =>
              tester.widget<TextField>(find.byType(TextField)).controller!.text;
          await key(LogicalKeyboardKey.digit1);
          await key(LogicalKeyboardKey.capsLock);
          expect(
            tester.widget<TextField>(find.byType(TextField)).readOnly,
            false,
          );
          await key(LogicalKeyboardKey.enter); // Empty name cannot finish.
          expect(text(), '');
          await letters('aa');
          await key(LogicalKeyboardKey.backspace);
          await key(LogicalKeyboardKey.arrowLeft);
          expect(text(), 'aa');
          await key(LogicalKeyboardKey.escape);
          expect(text(), '');
          await letters('a' * 16);
          await key(LogicalKeyboardKey.enter);
          expect(text(), ''); // INC occurs before Enter's limit check.
          await letters(expected);
          await key(LogicalKeyboardKey.enter);
          expect(text(), expected);
          await key(LogicalKeyboardKey.keyX, character: 'x');
          await key(LogicalKeyboardKey.escape);
          expect(text(), expected); // Gender ReadKey discards invalid input.
          await key(LogicalKeyboardKey.keyF, character: 'f');
          expect(find.byType(TextField), findsNothing);
          for (var i = 0; i < 10; i++) {
            await key(LogicalKeyboardKey.digit1);
          }
          for (var i = 0; i < 20; i++) {
            await key(LogicalKeyboardKey.arrowRight);
          }
          await key(LogicalKeyboardKey.arrowDown);
          for (var i = 0; i < 20; i++) {
            await key(LogicalKeyboardKey.arrowRight);
          }
          await key(LogicalKeyboardKey.enter);
          await key(LogicalKeyboardKey.digit2);
          await key(LogicalKeyboardKey.enter);
          expect(find.text('선택: 0 / 4 명'), findsOneWidget);
          for (var i = 0; i < 4; i++) {
            await key(LogicalKeyboardKey.enter);
            await key(LogicalKeyboardKey.digit1);
            if (i < 3) await key(LogicalKeyboardKey.arrowDown);
          }
          await key(LogicalKeyboardKey.enter);
          expect(party, isNotNull);
          expect(party!.first.name, expected);
          expect(party!.first.sex, Gender.female);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'touch and IME name editor remains editable without DOS key mode',
    (tester) async {
      await tester.runAsync(() => LoreCreationData.instance.load(force: true));
      await tester.pumpWidget(
        MaterialApp(home: CharacterCreationScreen(onGameStart: (_) {})),
      );
      await tester.tap(find.text('1] 새로운 주인공을 생성 시킴'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '한글 영웅');
      await tester.sendKeyEvent(LogicalKeyboardKey.capsLock);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '한글 영웅',
      );
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, false);
      await tester.tap(find.text('여성 [F]'));
      await tester.tap(find.text(LoreCreationData.instance.text('Third', 10)));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
