import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_creation.dart';
import 'package:lore/logic/lore_creation_rules.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/character_creation_screen.dart';
import 'package:lore/theme/mobile_theme.dart';

import 'support/source_audio_platform.dart';

void main() {
  setUp(installSourceAudioPlatform);
  for (final size in [
    const Size(390, 844),
    const Size(360, 480),
    const Size(320, 427),
  ]) {
    testWidgets(
      'mobile creation edits answers and selections, preserving source records at $size',
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
            theme: MobileTheme.theme,
            home: CharacterCreationScreen(
              mobilePresentation: true,
              startWithCreation: true,
              onGameStart: (value) => party = value,
            ),
          ),
        );
        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pump();
          await tester.tap(finder);
          await tester.pump();
          expect(tester.takeException(), isNull);
        }

        Finder key(String value) => find.byKey(ValueKey(value));
        final next = key('creation-next');
        if (size.height < 620) {
          expect(
            tester.getRect(key('creation-name')).bottom,
            lessThan(tester.getRect(next).top),
          );
        }
        await tester.enterText(key('creation-name'), '별빛 영웅');
        await tap(find.text('여성'));
        // Keep the footer visible while the IME occupies half the screen.
        tester.view.viewInsets = FakeViewPadding(bottom: size.height / 2);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(next).bottom, lessThanOrEqualTo(size.height / 2));
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pump();
        await tap(next);
        await tap(key('creation-answer-0'));
        await tap(find.text('이전'));
        expect(find.text('질문 1 / 10'), findsOneWidget);
        // The discarded answer must not contribute to the source stat counts.
        final answers = [1, for (var i = 1; i < 10; i++) 0];
        for (final answer in answers) {
          await tap(key('creation-answer-$answer'));
        }
        expect(find.text('능력치 배분'), findsOneWidget);
        await tap(find.text('이전'));
        expect(find.text('질문 10 / 10'), findsOneWidget);
        answers[9] = 1;
        await tap(key('creation-answer-1'));
        expect(find.text('능력치 배분'), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.descendant(
                  of: next,
                  matching: find.byType(ElevatedButton),
                ),
              )
              .onPressed,
          isNull,
        );
        // Slider touches use the same bounded source transitions as +/-.
        await tester.ensureVisible(find.byType(Slider).first);
        tester.widget<Slider>(find.byType(Slider).first).onChanged!(20);
        await tester.pump();
        final secondSlider = find.byType(Slider).at(1);
        await tester.ensureVisible(secondSlider);
        tester.widget<Slider>(secondSlider).onChanged!(20);
        await tester.pump();
        await tap(key('creation-minus-0'));
        await tap(key('creation-plus-2'));
        await tap(next);
        expect(find.text('직업 선택'), findsOneWidget);
        await tap(key('creation-class-8'));
        await tap(next);
        await tap(key('creation-select-1'));
        await tap(key('creation-profile-1'));
        expect(find.text('기사 · 남성'), findsOneWidget);
        await tap(find.text('돌아가기'));
        await tester.pumpAndSettle();
        expect(find.text('선택한 동료 1 / 4'), findsOneWidget);
        await tap(key('creation-select-1'));
        expect(find.text('선택한 동료 0 / 4'), findsOneWidget);
        for (final id in [4, 3, 2, 1]) {
          await tap(key('creation-select-$id'));
        }
        await tap(find.text('이전'));
        await tap(next);
        expect(find.text('선택한 동료 4 / 4'), findsOneWidget);
        await tap(next);
        expect(party, isNotNull);
        expect(party!.map((m) => m.name), [
          '별빛 영웅',
          'Hercules',
          'Titan',
          'Merlin',
          'Betelgeuse',
          '',
        ]);
        final counts = List<int>.filled(6, 0);
        for (var i = 0; i < answers.length; i++) {
          counts[LoreCreationRules.questionStats[i][answers[i]]]++;
        }
        final expected = LoreCreationRules.quizResult(counts, Gender.female);
        final hero = party!.first;
        expect([
          hero.strength,
          hero.mentality,
          hero.concentration,
          hero.endurance,
          hero.resistance,
        ], expected);
        expect([hero.agility, hero.accArms, hero.luck], [19, 20, 1]);
        expect(hero.playerClass, PlayerClass.vagrant);
        expect(hero.hp, hero.endurance);
        expect(hero.sex, Gender.female);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
