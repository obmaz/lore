import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/presentation/battle_presentation.dart';
import 'package:lore/presentation/battle_command_plan.dart';
import 'package:lore/presentation/battle_backdrop.dart';
import 'package:lore/theme/mobile_theme.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/jrpg_battle_stage.dart';
import 'package:lore/widgets/battle_art.dart';
import 'package:lore/widgets/encounter_viewport_view.dart';
import 'package:lore/widgets/mobile_content_dialog.dart';
import 'package:lore/widgets/mobile_party_view.dart';
import 'package:lore/widgets/party_status_view.dart';

class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadBattleArt();
    final font = FontLoader('LoreSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  final captureKey = GlobalKey();
  Widget screen(
    List<PartyMember> party,
    List<Monster> enemies, {
    void Function(int)? victory,
    BattleBackdrop backdrop = BattleBackdrop.meadow,
  }) => MaterialApp(
    theme: MobileTheme.theme,
    home: Scaffold(
      body: RepaintBoundary(
        key: captureKey,
        child: BattleViewportView(
          partyMembers: party,
          backdrop: backdrop,
          enemies: enemies,
          random: _ZeroRandom(),
          espAccessGranted: true,
          onLog: (_) {},
          onVictory: victory ?? (_) {},
          onTelepathyJoin: (_) {},
          onDefeat: () {},
          onRunAway: () {},
        ),
      ),
    ),
  );

  Future<void> preview(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('BATTLE_PREVIEW')) return;
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/verification/jrpg/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  setUp(() {
    LoreDialogueManager.instance.loadFlags({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => 1,
    );
    messenger.setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  test('feedback uses actual state deltas and does not apply them again', () {
    final hero = PartyMember.createPreset(1);
    final enemy = Monster.create(1);
    final before = BattleSnapshot([hero], [enemy]);
    enemy.hp -= 3;
    enemy.isPoisoned = true;
    hero.sp -= 2;
    hero.experience += 12;
    final event = BattleActionEvent.between(
      serial: 1,
      side: BattleSide.party,
      actor: 0,
      effect: BattleEffect.magic,
      title: '마법',
      before: before,
      after: BattleSnapshot([hero], [enemy]),
      lines: ['마법 공격'],
    );
    expect(
      event.feedback.map((f) => f.label),
      containsAll(['−3', '중독', 'SP -2', 'EXP +12']),
    );
    expect(before.enemies.single.hp, enemy.hp + 3);
    expect(hero.experience, before.party.single.experience + 12);
    expect(
      event.feedback.firstWhere((f) => f.label == '−3').kind,
      BattleFeedbackKind.damage,
    );
    expect(
      event.feedback.firstWhere((f) => f.label == 'SP -2').kind,
      BattleFeedbackKind.resource,
    );
    expect(
      event.feedback.firstWhere((f) => f.label == 'EXP +12').kind,
      BattleFeedbackKind.experience,
    );
  });

  test('command preparation respects eligibility and resets each round', () {
    final plan = BattleCommandPlan();
    plan.prepare(2);
    expect(plan.nextPending([0, 1, 2]), 0);
    plan.prepare(0);
    expect(plan.nextPending([0, 2]), isNull);
    expect(plan.nextPending([0, 1, 2]), 1);
    plan.prepare(1);
    expect(plan.preparedCount([0, 1, 2]), 3);
    plan.reset();
    expect(plan.nextPending([0, 1, 2]), 0);
  });

  testWidgets('closing magic and cure leaves the actor and records untouched', (
    tester,
  ) async {
    final party = [PartyMember.createPreset(3), PartyMember.createPreset(1)];
    final enemy = Monster.create(1);
    final records = party.map((p) => p.toJson()).toList();
    await tester.pumpWidget(screen(party, [enemy]));
    for (final command in [2, 5]) {
      await tester.tap(find.byKey(ValueKey('battle-cmd-$command')));
      await tester.pumpAndSettle();
      expect(find.text('없음'), findsNothing);
      expect(find.text('닫기'), findsOneWidget);
      if (command == 2) {
        expect(find.text('SP 1'), findsOneWidget);
        expect(find.text('마법 레벨이 부족합니다'), findsWidgets);
      }
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      final stage = tester.widget<JrpgBattleStage>(
        find.byType(JrpgBattleStage),
      );
      expect(stage.activeParty, 0);
      expect(stage.preparedParty, isEmpty);
      expect(stage.event, isNull);
      expect(party.map((p) => p.toJson()).toList(), records);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'out of order actor selection queues everyone then executes slot one',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final party = [for (var i = 1; i <= 3; i++) PartyMember.createPreset(i)];
      final enemy = Monster.create(1)..hp = 30000;
      await tester.pumpWidget(screen(party, [enemy]));
      await tester.tap(find.byKey(const ValueKey('battle-party-2')));
      await tester.pumpAndSettle();
      expect(find.byType(PartyStatusView), findsNothing);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<JrpgBattleStage>(find.byType(JrpgBattleStage))
            .activeParty,
        2,
      );
      await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
      await tester.pump();
      var stage = tester.widget<JrpgBattleStage>(find.byType(JrpgBattleStage));
      expect(stage.activeParty, 0);
      expect(stage.preparedParty, {2});
      expect(enemy.hp, 30000);
      await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
      await tester.pump();
      expect(
        tester
            .widget<JrpgBattleStage>(find.byType(JrpgBattleStage))
            .activeParty,
        1,
      );
      expect(enemy.hp, 30000);
      // Inspecting a prepared actor does not overwrite its queued command.
      await tester.tap(find.byKey(const ValueKey('battle-party-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<JrpgBattleStage>(find.byType(JrpgBattleStage))
            .activeParty,
        1,
      );
      await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
      await tester.pump();
      stage = tester.widget<JrpgBattleStage>(find.byType(JrpgBattleStage));
      expect(stage.event?.actor, 0);
      expect(stage.event?.side, BattleSide.party);
      expect(
        find.byKey(const ValueKey('battle-effect-mark-party-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('battle-effect-mark-enemy-0')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'dead foes cannot be selected but unconscious finishers remain available',
    (tester) async {
      final enemies = [
        Monster.create(1)..isDead = true,
        Monster.create(2),
        Monster.create(3)..isUnconscious = true,
      ];
      await tester.pumpWidget(screen([PartyMember.createPreset(1)], enemies));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<JrpgBattleStage>(find.byType(JrpgBattleStage))
            .selectedEnemy,
        1,
      );
      final dead = tester.widget<GestureDetector>(
        find.byKey(const ValueKey('enemy-0')),
      );
      expect(dead.onTap, isNull);
      await tester.tap(find.byKey(const ValueKey('enemy-2')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<JrpgBattleStage>(find.byType(JrpgBattleStage))
            .selectedEnemy,
        2,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in [
    const Size(360, 480),
    const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets(
      'six party and seven enemies fit and face each other at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          screen(
            [for (var i = 1; i <= 6; i++) PartyMember.createPreset(i)],
            [
              for (final id in [1, 2, 3, 17, 19, 23, 63]) Monster.create(id),
            ],
          ),
        );
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump();
        expect(
          tester.getRect(find.byKey(const ValueKey('battle-party-0'))).right,
          lessThan(tester.getRect(find.byKey(const ValueKey('enemy-0'))).left),
        );
        for (var i = 1; i <= 7; i++) {
          expect(
            tester.getSize(find.byKey(ValueKey('battle-cmd-$i'))).height,
            greaterThanOrEqualTo(48),
          );
        }
        expect(find.byKey(const ValueKey('enemy-selection-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('party-selection-0')), findsOneWidget);
        expect(find.text('대상 1'), findsNothing);
        expect(find.text('행동 1'), findsNothing);
        expect(
          find.byKey(const ValueKey('battle-selection-summary')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('enemy-4')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          tester
              .widget<JrpgBattleStage>(find.byType(JrpgBattleStage))
              .selectedEnemy,
          4,
        );
        expect(find.byKey(const ValueKey('enemy-selection-0')), findsNothing);
        final ring = find.byKey(const ValueKey('enemy-selection-4'));
        final paint = tester.widget<CustomPaint>(
          find.descendant(of: ring, matching: find.byType(CustomPaint)),
        );
        expect(
          (paint.painter! as BattleSelectionRingPainter).color,
          MobileTheme.danger,
        );
        expect(tester.getSize(ring).height, 14);
        expect(
          tester.getRect(ring).bottom,
          lessThan(
            tester.getRect(find.byKey(const ValueKey('enemy-4'))).bottom,
          ),
        );
        expect(find.byKey(const ValueKey('enemy-name-mark-4')), findsOneWidget);
        expect(find.byKey(const ValueKey('enemy-name-mark-0')), findsNothing);
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('battle-selected-target-name')),
              )
              .data,
          tester
              .widget<JrpgBattleStage>(find.byType(JrpgBattleStage))
              .enemies[4]
              .name,
        );
        expect(find.text('대상 5'), findsNothing);
        expect(find.text('대상 1'), findsNothing);
        expect(find.byType(FantasyBattleButton), findsNWidgets(7));
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.text('일행'), findsNothing);
        final stageView = tester.widget<JrpgBattleStage>(
          find.byType(JrpgBattleStage),
        );
        for (var i = 0; i < stageView.party.length; i++) {
          expect(
            find.descendant(
              of: find.byKey(ValueKey('party-hp-$i')),
              matching: find.text(
                '${stageView.party[i].hp}/${stageView.party[i].maxHp}',
              ),
            ),
            findsOneWidget,
          );
        }
        expect(
          find.byKey(const ValueKey('battle-backdrop-meadow')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await preview(tester, 'formation-${size.width.toInt()}');
        // Advancing to the next party command moves only the presentation mark.
        await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byKey(const ValueKey('party-selection-0')), findsNothing);
        expect(find.byKey(const ValueKey('party-selection-1')), findsOneWidget);
        final fleeWidth = tester
            .getSize(find.byKey(const ValueKey('battle-cmd-7')))
            .width;
        final attackWidth = tester
            .getSize(find.byKey(const ValueKey('battle-cmd-1')))
            .width;
        expect(
          fleeWidth,
          size.height <= 500 ? attackWidth : greaterThan(attackWidth),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('regional encounter and touch actions fit at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var engaged = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: MobileTheme.theme,
          home: Scaffold(
            body: RepaintBoundary(
              key: captureKey,
              child: EncounterViewportView(
                party: [
                  for (var i = 1; i <= 6; i++) PartyMember.createPreset(i),
                ],
                enemies: [for (var i = 1; i <= 7; i++) Monster.create(i)],
                backdrop: BattleBackdrop.marsh,
                onEngage: () => engaged = true,
                onFlee: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1100));
      final stage = tester.getRect(find.byType(JrpgBattleStage));
      final lastEnemy = tester.getRect(find.byKey(const ValueKey('enemy-3')));
      expect(lastEnemy.bottom, lessThanOrEqualTo(stage.bottom));
      expect(
        find.byKey(const ValueKey('battle-backdrop-marsh')),
        findsOneWidget,
      );
      for (final id in ['encounter-engage', 'encounter-flee']) {
        expect(
          tester.getSize(find.byKey(ValueKey(id))).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.tap(find.byKey(const ValueKey('enemy-4')));
      await tester.pump();
      expect(find.text('대상 5'), findsNothing);
      expect(find.byKey(const ValueKey('enemy-selection-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('party-selection-0')), findsNothing);
      expect(tester.takeException(), isNull);
      await preview(tester, 'encounter-${size.width.toInt()}');
      await tester.tap(find.byKey(const ValueKey('encounter-engage')));
      expect(engaged, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('every generated regional scene renders with the bright UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final backdrop in BattleBackdrop.values) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        screen(
          [for (var i = 1; i <= 6; i++) PartyMember.createPreset(i)],
          [Monster.create(1), Monster.create(17), Monster.create(63)],
          backdrop: backdrop,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1100));
      expect(
        find.byKey(ValueKey('battle-backdrop-${backdrop.name}')),
        findsOneWidget,
      );
      expect(find.text('${backdrop.label} · 적 진영'), findsNothing);
      expect(tester.takeException(), isNull);
      await preview(tester, 'backdrop-${backdrop.name}');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'speed cycles through 1x, 2x and 4x without changing game state',
    (tester) async {
      final hero = PartyMember.createPreset(1);
      final enemy = Monster.create(1);
      final hp = hero.hp;
      final enemyHp = enemy.hp;
      await tester.pumpWidget(screen([hero], [enemy]));
      for (final speed in [2, 4, 1]) {
        await tester.tap(find.byKey(const ValueKey('battle-speed')));
        await tester.pump();
        expect(find.text('$speed×'), findsOneWidget);
        expect(
          tester.widget<JrpgBattleStage>(find.byType(JrpgBattleStage)).duration,
          Duration(milliseconds: 1000 ~/ speed),
        );
        expect(hero.hp, hp);
        expect(enemy.hp, enemyHp);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'attacks play on stage and continue into enemy phase without a key',
    (tester) async {
      final hero = PartyMember.createPreset(1)..hp = 10000;
      final enemy = Monster.create(3)..hp = 30000;
      await tester.pumpWidget(screen([hero], [enemy]));
      await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
      await tester.pump();
      expect(
        tester
            .widget<JrpgBattleStage>(find.byType(JrpgBattleStage))
            .event
            ?.side,
        BattleSide.party,
      );
      expect(find.byKey(const ValueKey('battle-continue')), findsNothing);
      expect(find.byKey(const ValueKey('party-selection-0')), findsNothing);
      expect(find.byKey(const ValueKey('enemy-selection-0')), findsNothing);
      expect(
        find.byKey(const ValueKey('battle-selection-summary')),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(
        tester
            .widget<JrpgBattleStage>(find.byType(JrpgBattleStage))
            .event
            ?.side,
        BattleSide.enemy,
      );
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('battle-cmd-1')))
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in [const Size(360, 480), const Size(390, 844)]) {
    testWidgets(
      'short history fits content and party detail has one footer at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          screen(
            [for (var i = 1; i <= 6; i++) PartyMember.createPreset(i)],
            [Monster.create(1)],
          ),
        );
        await tester.tap(find.byTooltip('이번 전투 기록'));
        await tester.pumpAndSettle();
        expect(find.text('아직 기록이 없습니다.'), findsOneWidget);
        expect(
          tester
              .getSize(
                find
                    .descendant(
                      of: find.byType(MobileContentDialog),
                      matching: find.byType(Column),
                    )
                    .first,
              )
              .height,
          lessThan(200),
        );
        expect(find.text('닫기'), findsOneWidget);
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('battle-party-2')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MobilePartyView>(find.byType(MobilePartyView))
              .initialIndex,
          2,
        );
        expect(find.text('닫기'), findsOneWidget);
        expect(find.text('돌아가기'), findsNothing);
        final close = find.text('닫기');
        expect(tester.getRect(close).bottom, lessThan(size.height));
        expect(close.hitTestable(), findsOneWidget);
        final scroll = find
            .descendant(
              of: find.byType(MobileContentDialog),
              matching: find.byType(SingleChildScrollView),
            )
            .first;
        await tester.drag(scroll, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(close.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(close);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'single magic emits a stage spell event with source HP and SP changes',
    (tester) async {
      final hero = PartyMember.createPreset(3)..hp = 10000;
      final enemy = Monster.create(1)..hp = 30000;
      final sp = hero.sp;
      await tester.pumpWidget(screen([hero], [enemy]));
      await tester.tap(find.byKey(const ValueKey('battle-cmd-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('마법 화살'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final event = tester
          .widget<JrpgBattleStage>(find.byType(JrpgBattleStage))
          .event!;
      expect(event.effect, BattleEffect.magic);
      expect(event.title, contains('마법 화살'));
      expect(hero.sp, lessThan(sp));
      expect(
        event.feedback.any(
          (f) => f.side == BattleSide.party && f.label.startsWith('SP'),
        ),
        isTrue,
      );
      await preview(tester, 'magic');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'victory holds the reward screen and commits gold exactly once on return',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final hero = PartyMember.createPreset(1)..hp = 10000;
      final foe = Monster.create(10)..isUnconscious = true;
      var callbacks = 0;
      var gold = 0;
      await tester.pumpWidget(
        screen(
          [hero],
          [foe],
          victory: (earned) {
            callbacks++;
            gold += earned;
          },
        ),
      );
      await tester.tap(find.byKey(const ValueKey('battle-cmd-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.byKey(const ValueKey('battle-victory')), findsOneWidget);
      expect(hero.experience, greaterThan(0));
      expect(callbacks, 0);
      await preview(tester, 'victory');
      await tester.tap(find.byKey(const ValueKey('battle-result-continue')));
      await tester.tap(find.byKey(const ValueKey('battle-result-continue')));
      expect(callbacks, 1);
      expect(gold, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
