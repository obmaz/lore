import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:lore/theme/retro_theme.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/logic/lore_batt_text.dart';
import 'package:lore/logic/lore_sub_text.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/battle_viewport_view.dart';

/// LOREBATT.PAS BattleMode menu m[0..7] and the ReturnMessage prints.
void main() {
  Future<List<String>> open(
    WidgetTester tester,
    List<PartyMember> party,
  ) async {
    final logs = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            partyMembers: party,
            enemies: [Monster.create(1)],
            espAccessGranted: false,
            onLog: logs.add,
            onVictory: (_) {},
            onTelepathyJoin: (_) {},
            onDefeat: () {},
            onRunAway: () {},
          ),
        ),
      ),
    );
    return logs;
  }

  testWidgets('command labels are the source menu strings', (tester) async {
    final hero = PartyMember.createPreset(1)..weapon = 4;
    await open(tester, [hero]);
    String label(int n) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('battle-cmd-$n')),
            matching: find.byType(Text),
          ),
        )
        .data!;
    expect(label(1), '한 명의 적을 장검으로 공격');
    expect(label(2), '한 명의 적에게 마법 공격');
    expect(label(3), '모든 적에게 마법 공격');
    expect(label(4), '적에게 특수 마법 공격');
    expect(label(5), '일행을 치료');
    expect(label(6), '적에게 초능력 사용');
    expect(label(7), '일행에게 무조건 공격 할 것을 지시');
    hero.weapon = 1;
    await tester.pumpWidget(const SizedBox.shrink());
    final other = PartyMember.createPreset(3)..weapon = 1;
    await open(tester, [PartyMember.createPreset(1), other]);
    expect(label(1).startsWith('한 명의 적을 '), isTrue);
  });

  testWidgets(
    'a locked special spell prints ReturnMessage how 4, then refuses and spends the turn',
    (tester) async {
      LoreDialogueManager.instance.loadFlags({});
      final hero = PartyMember.createPreset(3)
        ..magicLevel = 20
        ..sp = 500;
      final other = PartyMember.createPreset(4);
      final logs = await open(tester, [hero, other]);
      await tester.tap(find.byKey(const ValueKey('battle-cmd-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lore-select-2')));
      await tester.pumpAndSettle();
      // 모두가 고른 뒤에 번호 순서로 실행된다.
      expect(logs, isEmpty);
      await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(
        logs.first,
        LoreSubText.returnMessage(
          actor: hero.name,
          how: 4,
          what: 1,
          target: 'Orc',
        ),
      );
      expect(logs[1], LoreBattText.noAbility);
    },
  );
  for (final command in [2, 3, 4]) {
    testWidgets('source menu $command has None and black unavailable rows', (
      tester,
    ) async {
      final hero = PartyMember.createPreset(3)..magicLevel = 0;
      final other = PartyMember.createPreset(4);
      await open(tester, [hero, other]);
      await tester.tap(find.byKey(ValueKey('battle-cmd-$command')));
      await tester.pumpAndSettle();
      expect(find.text('없음'), findsOneWidget);
      final firstLocked = command == 2 ? 3 : 2;
      final row = find.byKey(ValueKey('lore-select-$firstLocked'));
      final text = tester.widget<Text>(
        find.descendant(of: row, matching: find.byType(Text)),
      );
      expect(text.style!.color, RetroTheme.ega(0));
      await tester.tap(row);
      await tester.pump();
      expect(find.text('없음'), findsOneWidget);
      // Enter starts at m[1] = None; it spends this member's turn.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.text('${other.name}${LoreBattText.battleMode}'),
        findsOneWidget,
      );
    });
  }
  testWidgets('ESP retains its five choices without None', (tester) async {
    final hero = PartyMember.createPreset(3)..espLevel = 0;
    await open(tester, [hero, PartyMember.createPreset(4)]);
    await tester.tap(find.byKey(const ValueKey('battle-cmd-6')));
    await tester.pumpAndSettle();
    expect(find.text('없음'), findsNothing);
    expect(find.byKey(const ValueKey('lore-select-5')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      find.text(
        '${PartyMember.createPreset(4).name}${LoreBattText.battleMode}',
      ),
      findsOneWidget,
    );
  });
  testWidgets('negative enemy HP uses DisplayEnemies else color 10', (
    tester,
  ) async {
    final foe = Monster.create(1)..hp = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleViewportView(
            partyMembers: [PartyMember.createPreset(1)],
            enemies: [foe],
            espAccessGranted: false,
            onLog: (_) {},
            onVictory: (_) {},
            onTelepathyJoin: (_) {},
            onDefeat: () {},
            onRunAway: () {},
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('enemy-0')),
        matching: find.byType(Text),
      ),
    );
    expect(text.style!.color, RetroTheme.ega(10));
  });
  testWidgets('BattleMode ignores the seventh scratch slot', (tester) async {
    final hero = PartyMember.createPreset(1);
    final scratch = PartyMember.createPreset(3)..name = 'Scratch';
    await open(tester, [
      hero,
      for (var i = 0; i < 5; i++) PartyMember.blank(),
      scratch,
    ]);
    await tester.tap(find.byKey(const ValueKey('battle-cmd-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lore-select-1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Scratch${LoreBattText.battleMode}'), findsNothing);
    expect(tester.takeException(), isNull);
    // The six-slot round has reached the source PressAnyKey before enemies.
    expect(find.text(LoreSubText.pressAnyKey), findsOneWidget);
  });
}
