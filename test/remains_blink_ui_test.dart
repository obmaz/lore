import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_remains_blink.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/lore_select_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LORETALK.PAS seven remains FOR loops through keyboard/touch and real renderer.
void main() {
  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    for (final (tx, ty) in [
      (10, 14),
      (10, 18),
      (10, 30),
      (21, 32),
      (21, 22),
      (21, 12),
      (8, 8),
    ]) {
      testWidgets(
        'blink precedes map write and blocks field input: $size/$tx,$ty',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            LoreDialogueManager.instance.loadFlags({});
            LoreScriptEngine.instance.resetForTest();
          });
          final map = await LoreMapData.loadFromAsset(
            'PYRAMID1',
            category: 'town',
          );
          final tiles = List.filled(map.xmax * map.ymax, 44);
          tiles[(ty - 1) * map.xmax + tx - 1] = 48;
          await tester.pumpWidget(
            MaterialApp(
              home: MainGameScreen(
                initialSaveData: SaveData(
                  slot: 1,
                  slotName: 'remains',
                  timestamp: DateTime.utc(1993),
                  mapId: 27,
                  mapTitle: 'TOWN',
                  playerX: tx,
                  playerY: ty - 1,
                  gold: 2000,
                  food: 20,
                  party: [PartyMember.createPreset(1)],
                  flags: const {},
                  mapTiles: tiles,
                ),
              ),
            ),
          );
          final finder = find.byType(GameWidget<LoreGame>);
          final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
          await tester.runAsync(
            () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
          );
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump();
          // Only acknowledge the current route, not a dismissed route fading out.
          bool currentDialog() => [
            ...find.byType(LoreMessageDialog).evaluate(),
            ...find.byType(LoreSelectView).evaluate(),
          ].any((e) => ModalRoute.of(e)?.isCurrent == true);
          var acknowledgements = 0;
          while (currentDialog()) {
            expect(game.currentMap!.getTile(tx, ty), 48);
            expect(game.remainsBlinkFrame, isNull);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pump();
            await tester.pump();
            expect(++acknowledgements, lessThan(30));
          }
          final partyBefore = [
            for (final p in game.partyProvider!()) p.toJson(),
          ];
          final etcBefore = Map<int, int>.from(
            LoreDialogueManager.instance.partyEtc,
          );
          final frames = LoreRemainsBlink.frames(0, 1).toList();
          for (var i = 0; i < frames.length; i++) {
            final frame = frames[i];
            await tester.pump(Duration(milliseconds: frame.waitMilliseconds));
            if (i < frames.length - 1) {
              final shown = game.remainsBlinkFrame!;
              expect([shown.x, shown.y, shown.tile], [100, 120, frame.tile]);
              expect(game.currentMap!.getTile(tx, ty), 48);
              await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
              await tester.pump();
              expect([game.playerX, game.playerY], [tx, ty - 1]);
            }
          }
          expect(game.remainsBlinkFrame, isNull);
          expect(game.currentMap!.getTile(tx, ty), 35);
          expect(
            game.currentMap!.tileSnapshot(),
            [...tiles]..[(ty - 1) * map.xmax + tx - 1] = 35,
          );
          expect([
            for (final p in game.partyProvider!()) p.toJson(),
          ], partyBefore);
          expect(LoreDialogueManager.instance.partyEtc, etcBefore);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
