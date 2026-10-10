import 'support/source_audio_platform.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/battle_viewport_view.dart';

void main() {
  setUp(installSourceAudioPlatform);
  final f = jsonDecode(
    File('test/fixtures/dos_condition_storage.json').readAsStringSync(),
  );
  for (final scenario in [
    (11, 30, 25, 30, 24, LogicalKeyboardKey.arrowUp, 'Sphinx'),
    (17, 21, 40, 22, 40, LogicalKeyboardKey.arrowRight, 'Hidra'),
  ]) {
    testWidgets(
      '${scenario.$7} source field event reaches battle with native HP',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          LoreDialogueManager.instance.loadFlags({});
          LoreScriptEngine.instance.resetForTest();
        });
        for (final channel in [
          'xyz.luan/audioplayers',
          'xyz.luan/audioplayers.global',
        ]) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
        }
        final info = LoreWorldManager.mapRegistry[scenario.$1]!;
        final map = await LoreMapData.loadFromAsset(
          info.fileName,
          category: info.category.name,
        );
        map.setTile(scenario.$4, scenario.$5, 0);
        final hero = PartyMember.createPreset(1)..hp = 30000;
        await tester.pumpWidget(
          MaterialApp(
            home: MainGameScreen(
              sourceReplayBattle: true,
              initialSaveData: SaveData(
                slot: 1,
                slotName: 'Original boss',
                timestamp: DateTime.utc(1993),
                mapId: scenario.$1,
                mapTitle: info.title,
                playerX: scenario.$2,
                playerY: scenario.$3,
                gold: 100,
                food: 20,
                party: [hero],
                flags: const {'etc13': 1, 'etc15': 1, 'etc1': 1},
                mapTiles: map.tileSnapshot(),
              ),
            ),
          ),
        );
        final game = find.byType(GameWidget<LoreGame>);
        await tester.runAsync(
          () => tester.state<GameWidgetState<LoreGame>>(game).loaderFuture,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.sendKeyEvent(scenario.$6);
        for (
          var i = 0;
          i < 80 && find.byType(BattleViewportView).evaluate().isEmpty;
          i++
        ) {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          if (find.byType(BattleViewportView).evaluate().isNotEmpty) break;
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        }
        expect(find.byType(BattleViewportView), findsOneWidget);
        final battle = tester.widget<BattleViewportView>(
          find.byType(BattleViewportView),
        );
        // A parent rebuild while an attack is in flight must only draw HP.
        // Source ReturnCondition runs at the explicit battle phase boundary.
        final member = battle.partyMembers.first;
        member.hp = -1;
        member.unconscious = 0;
        member.dead = 0;
        battle.onPrint!(7, '');
        await tester.pump();
        expect(member.unconscious, 0);
        expect(member.dead, 0);
        final expected = (f['bosses'] as List).singleWhere(
          (r) => r['name'] == scenario.$7,
        );
        final bytes = Uint8List.fromList(List<int>.from(expected['after']));
        final hp = ByteData.sublistView(bytes).getInt16(30, Endian.little);
        final bosses = battle.enemies
            .where((e) => e.name.startsWith(scenario.$7))
            .toList();
        expect(bosses, hasLength(scenario.$7 == 'Sphinx' ? 2 : 3));
        expect([for (final e in bosses) e.hp], List.filled(bosses.length, hp));
        expect([
          for (final e in bosses) e.level,
        ], scenario.$7 == 'Sphinx' ? [4, 4] : [8, 10, 8]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
