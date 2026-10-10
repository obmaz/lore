import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_batt_text.dart';
import 'package:lore/logic/lore_sub_text.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/widgets/battle_viewport_view.dart';

import 'support/battle_keys.dart';

class _Max implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => .999;
}

void main() {
  testWidgets(
    'source six-slot selection, leader auto-follow and repeated rounds',
    (tester) async {
      final source = String.fromCharCodes(
        File('repo_source/LORE_1993_src/LOREBATT.PAS').readAsBytesSync(),
      );
      expect(source, contains('for person := 1 to 6 do'));
      expect(source, contains('autobattle := TRUE'));
      for (final auto in [false, true]) {
        for (var mask = auto ? 1 : 0; mask < 64; mask += auto ? 2 : 1) {
          final party = [
            for (var i = 0; i < 7; i++)
              PartyMember.createPreset(1)
                ..name = i == 6
                    ? 'Scratch'
                    : ((mask & (1 << i)) != 0 ? 'Slot${i + 1}' : '')
                ..hp = 10000
                ..sp = 0,
          ];
          final logs = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: BattleViewportView(
                  sourceReplay: true,
                  key: ValueKey('$auto:$mask'),
                  partyMembers: party,
                  enemies: [Monster.create(1)..hp = 30000],
                  random: _Max(),
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
          final actors = [
            for (var i = 0; i < 6; i++)
              if ((mask & (1 << i)) != 0) party[i],
          ];
          if (auto) {
            await tester.tap(find.byKey(const ValueKey('battle-cmd-7')));
            await tester.pump();
          } else {
            for (final actor in actors) {
              expect(
                find.text('${actor.name}${LoreBattText.battleMode}'),
                findsOneWidget,
              );
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pump();
            }
          }
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(logs.any((s) => s.contains('Scratch')), isFalse);
          if (!auto) {
            expect(logs, [
              for (final actor in actors) '${actor.name}는 잠시 주저했다',
            ]);
          } else {
            expect(
              logs
                  .where((s) => s.startsWith('Slot'))
                  .map((s) => s.substring(0, 5)),
              actors.map((p) => p.name),
            );
          }
          expect(find.text(LoreSubText.pressAnyKey), findsOneWidget);
          await pressBattleKey(tester);
          await tester.pump();
          await pressBattleKey(tester);
          if (actors.isEmpty) {
            expect(find.byKey(const ValueKey('battle-cmd-1')), findsOneWidget);
            expect(
              tester
                  .widget<ElevatedButton>(
                    find.byKey(const ValueKey('battle-cmd-1')),
                  )
                  .onPressed,
              isNull,
            );
            continue;
          }
          expect(
            find.text('${actors.first.name}${LoreBattText.battleMode}'),
            findsOneWidget,
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (var state = 0; state < 4; state++) {
    testWidgets(
      'enemy-first result $state waits for ReadKey with defeat priority',
      (tester) async {
        final hero = PartyMember.createPreset(1)
          ..hp = (state & 1) != 0 ? 10000 : 0;
        final enemy = Monster.create(1)..isUnconscious = (state & 2) == 0;
        final results = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BattleViewportView(
                sourceReplay: true,
                partyMembers: [hero],
                enemies: [enemy],
                random: _Max(),
                enemyFirst: true,
                espAccessGranted: false,
                onLog: (_) {},
                onVictory: (_) => results.add('win'),
                onTelepathyJoin: (_) {},
                onDefeat: () => results.add('lose'),
                onRunAway: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(results, isEmpty);
        await pressBattleKey(tester);
        expect(
          results,
          (state & 1) == 0 ? ['lose'] : ((state & 2) == 0 ? ['win'] : []),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
