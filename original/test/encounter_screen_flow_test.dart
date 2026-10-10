import 'support/source_audio_platform.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/battle_viewport_view.dart';
import 'package:lore/widgets/dpad_widget.dart';
import 'package:lore/widgets/encounter_viewport_view.dart';

class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

Future<void> _enterEncounter(WidgetTester tester, {required int luck}) async {
  final hero = PartyMember.createPreset(1)
    ..agility = 20
    ..luck = luck;
  final save = SaveData(
    slot: 1,
    slotName: 'encounter-test',
    timestamp: DateTime.utc(1993, 7, 25),
    mapId: 1,
    mapTitle: 'GROUND 1',
    playerX: 50,
    playerY: 50,
    gold: 2000,
    food: 20,
    party: [hero],
    flags: const {},
    mapTiles: List.filled(100 * 100, 44),
    consumedScripts: const [],
  );
  await tester.pumpWidget(
    MaterialApp(
      home: MainGameScreen(
        initialSaveData: save,
        encounterRandom: _ZeroRandom(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  final dpad = tester.widget<DPadWidget>(find.byType(DPadWidget));
  dpad.onDirectionPressed(1, 0);
  await tester.pump();
  expect(find.byType(EncounterViewportView), findsOneWidget);
  expect(find.byType(DPadWidget), findsNothing);
}

void main() {
  setUp(installSourceAudioPlatform);
  testWidgets('필드 조우에서 교전을 고르면 파티 선공 전투로 들어간다', (tester) async {
    await _enterEncounter(tester, luck: 20);
    await tester.tap(find.byKey(const ValueKey('encounter-engage')));
    await tester.pump();
    expect(find.byType(BattleViewportView), findsOneWidget);
    expect(
      tester
          .widget<BattleViewportView>(find.byType(BattleViewportView))
          .enemyFirst,
      isFalse,
    );
  });

  testWidgets('필드 조우의 전투 전 도주 성공은 필드로 복귀한다', (tester) async {
    await _enterEncounter(tester, luck: 20);
    await tester.tap(find.byKey(const ValueKey('encounter-flee')));
    await tester.pump();
    expect(find.byType(DPadWidget), findsOneWidget);
    expect(find.byType(BattleViewportView), findsNothing);
  });

  testWidgets('필드 조우의 전투 전 도주 실패는 적 선공 전투로 들어간다', (tester) async {
    await _enterEncounter(tester, luck: 0);
    await tester.tap(find.byKey(const ValueKey('encounter-flee')));
    await tester.pump();
    expect(find.byType(BattleViewportView), findsOneWidget);
    expect(
      tester
          .widget<BattleViewportView>(find.byType(BattleViewportView))
          .enemyFirst,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));
  });
}
