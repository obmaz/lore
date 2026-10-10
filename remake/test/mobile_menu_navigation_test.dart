import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/field_magic_logic.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/mobile_field_menus.dart';
import 'package:lore/widgets/mobile_menu_dialog.dart';

void main() {
  testWidgets('long choices keep back reachable with enlarged phone text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              child: const Text('열기'),
              onPressed: () => showMobileMenuDialog(
                context,
                title: '여러 줄로 표시되는 마법 선택',
                items: List.generate(
                  20,
                  (i) => MobileMenuItem(
                    '마법 ${i + 1}',
                    detail: '마법 설명과 소모 자원을 확인하세요.',
                  ),
                ),
                onSelected: (index) async {
                  selected = index;
                  return true;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    final back = find.text('돌아가기').hitTestable();
    expect(back, findsOneWidget);
    final backRect = tester.getRect(back);
    expect(backRect.bottom, lessThan(480));
    await tester.dragUntilVisible(
      find.text('마법 20'),
      find.byType(SingleChildScrollView),
      const Offset(0, -180),
    );
    expect(find.text('돌아가기').hitTestable(), findsOneWidget);
    await tester.tap(find.text('마법 20'));
    await tester.pumpAndSettle();
    expect(selected, 20);
    expect(tester.takeException(), isNull);
  });

  Widget host(Future<void> Function(BuildContext) open) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => open(context),
          child: const Text('열기'),
        ),
      ),
    ),
  );
  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).hitTestable().last);
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(360, 480), const Size(390, 844)]) {
    testWidgets(
      'cure back keeps its target parent and applies a complete path once at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final mage = PartyMember.createPreset(3)..magicLevel = 4;
        final ally = PartyMember.createPreset(1)..hp = 1;
        var executions = 0;
        List<int>? plan;
        await tester.pumpWidget(
          host((context) async {
            await MobileFieldMenus(context, [mage, ally]).cast((
              choices,
              power,
            ) async {
              executions++;
              plan = choices;
            });
          }),
        );
        await tap(tester, '열기');
        await tap(tester, mage.name);
        await tap(tester, LoreMenuText.castSpellCure);
        await tap(tester, ally.name);
        expect(find.text('돌아가기').hitTestable(), findsOneWidget);
        await tap(tester, '돌아가기');
        expect(find.text('회복 대상').hitTestable(), findsOneWidget);
        expect(executions, 0);
        expect(ally.hp, 1);
        // Hardware/system back also returns one level, keeping the caster.
        await tap(tester, ally.name);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('회복 대상').hitTestable(), findsOneWidget);
        await tap(tester, '돌아가기');
        expect(
          find.text(LoreMenuText.castSpellKind).hitTestable(),
          findsOneWidget,
        );
        await tap(tester, LoreMenuText.castSpellCure);
        await tap(tester, ally.name);
        await tap(tester, FieldMagicLogic.cureSpellNames.first);
        expect(plan, [1, 2, 2, 1]);
        expect(executions, 1);
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'difficulty back commits no partial settings and keeps the root',
    (tester) async {
      var executions = 0;
      List<int>? plan;
      await tester.pumpWidget(
        host((context) async {
          await MobileFieldMenus(context, [
            PartyMember.createPreset(1),
          ]).options((choices) async {
            executions++;
            plan = choices;
          });
        }),
      );
      await tap(tester, '열기');
      await tap(tester, LoreMenuText.optionDifficulty);
      await tap(tester, '3${LoreMenuText.optionEnemySuffix}');
      await tap(tester, '돌아가기');
      expect(find.text('동시에 만나는 적의 수').hitTestable(), findsOneWidget);
      expect(executions, 0);
      await tap(tester, '돌아가기');
      expect(find.text(LoreMenuText.optionTitle).hitTestable(), findsOneWidget);
      await tap(tester, LoreMenuText.optionDifficulty);
      await tap(tester, '4${LoreMenuText.optionEnemySuffix}');
      await tap(tester, LoreMenuText.optionEncounter2);
      expect(plan, [1, 2, 2]);
      expect(executions, 1);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nested parent stays available after Escape and closes once on completion',
    (tester) async {
      var completions = 0;
      await tester.pumpWidget(
        host((context) async {
          await showMobileMenuDialog(
            context,
            title: '부모',
            isRoot: true,
            items: const [MobileMenuItem('자식 열기')],
            onSelected: (_) => showMobileMenuDialog(
              context,
              title: '자식',
              items: const [MobileMenuItem('완료')],
              onSelected: (_) async {
                completions++;
                return true;
              },
            ),
          );
        }),
      );
      await tap(tester, '열기');
      await tap(tester, '자식 열기');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('부모').hitTestable(), findsOneWidget);
      expect(find.text('닫기').hitTestable(), findsOneWidget);
      expect(completions, 0);
      await tap(tester, '자식 열기');
      await tap(tester, '완료');
      expect(completions, 1);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
