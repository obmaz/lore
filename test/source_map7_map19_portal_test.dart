import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_field_logic.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('source exact guards, destination words and refusal decrements', () {
    final source = String.fromCharCodes(
      File('repo_source/LORE_1993_src/LORESPEC.PAS').readAsBytesSync(),
    );
    final town = source.substring(
      source.indexOf('      7 : begin'),
      source.indexOf('      8 : begin'),
    );
    final den = source.substring(
      source.indexOf('      19 : begin'),
      source.indexOf('      20 : begin'),
    );
    expect(town, contains('if x = 50 then'));
    expect(town, contains('if y = 71 then'));
    expect(den, contains('if y = 46 then'));
    final destinations = [
      for (final body in [town, den])
        ...RegExp(r'xaxis := (\d+); yaxis := (\d+); map := (\d+);')
            .allMatches(body)
            .map((m) => [int.parse(m[3]!), int.parse(m[1]!), int.parse(m[2]!)]),
    ];
    expect(destinations, [
      [8, 50, 10],
      [1, 77, 57],
      [4, 48, 58],
    ]);
    for (var x = 1; x <= 100; x++) {
      for (var y = 1; y <= 100; y++) {
        for (final map in [7, 19]) {
          final portal = LoreWorldManager.instance.findPortal(map, x, y);
          final expected = map == 7
              ? (x == 50 ? destinations[0] : (y == 71 ? destinations[1] : null))
              : (y == 46 ? destinations[2] : null);
          if (expected != null) {
            expect(
              portal == null
                  ? null
                  : [portal.targetMapId, portal.targetX, portal.targetY],
              expected,
              reason: '$map:$x:$y',
            );
          } else {
            // Ordinary building entrances are LOREENT, not these specialevent guards.
            expect(LoreWorldManager.sourceExitRejectY(map, y, x: x), isNull);
            if ((map == 7 && y > 71) || (map == 19 && y > 46)) {
              expect(portal, isNull);
            }
          }
          if (expected != null) {
            expect(
              LoreWorldManager.sourceAsksEnter(map, x, y),
              map == 7 && x == 50,
            );
            expect(
              LoreWorldManager.sourceExitRejectY(map, y, x: x),
              map == 7 && x == 50 ? y : y - 1,
            );
          }
        }
      }
    }
    expect(town, contains('dec(y); scroll(TRUE);'));
    expect(den, contains('dec(y); scroll(TRUE);'));
  });

  test('map23/25 exact exit guards independently parsed from source', () {
    final source = String.fromCharCodes(
      File('repo_source/LORE_1993_src/LORESPEC.PAS').readAsBytesSync(),
    );
    for (final map in [23, 25]) {
      final body = source.substring(
        source.indexOf('      $map : begin'),
        source.indexOf('      ${map + 1} : begin'),
      );
      final exit = RegExp(
        r'if y = (\d+) then begin\s*if wantexit then begin\s*with party do begin\s*xaxis := (\d+); yaxis := (\d+); map := (\d+);',
      ).firstMatch(body)!;
      final row = int.parse(exit[1]!);
      final destination = [
        int.parse(exit[4]!),
        int.parse(exit[2]!),
        int.parse(exit[3]!),
      ];
      expect(body, contains('dec(y); scroll(TRUE);'));
      for (var x = 1; x <= 100; x++) {
        for (var y = 1; y <= 100; y++) {
          final portal = LoreWorldManager.instance.findPortal(map, x, y);
          if (y == row) {
            expect([
              portal!.targetMapId,
              portal.targetX,
              portal.targetY,
            ], destination);
            expect(LoreWorldManager.sourceExitRejectY(map, y, x: x), y - 1);
            expect(LoreWorldManager.sourceAsksEnter(map, x, y), false);
          } else if (y > row) {
            expect(portal, isNull);
          }
        }
      }
    }
  });

  Future<LoreGame> open(
    WidgetTester tester,
    int mapId,
    int x,
    int y,
    int tx,
    int ty,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    void silence(String channel) => messenger.setMockStreamHandler(
      EventChannel(channel),
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
    final info = LoreWorldManager.mapRegistry[mapId]!;
    final file = info.fileName;
    final category = info.category.name;
    final map = await LoreMapData.loadFromAsset(file, category: category);
    // Exercise synthetic guard intersections as well as shipped doorway cells.
    map.setTile(x, y, 45);
    map.setTile(tx, ty, mapId == 7 ? 0 : 52);
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          initialSaveData: SaveData(
            slot: 1,
            slotName: 'source',
            timestamp: DateTime.utc(1993),
            mapId: mapId,
            mapTitle: file,
            playerX: x,
            playerY: y,
            gold: 100,
            food: 20,
            party: [PartyMember.createPreset(1)],
            flags: const {},
            mapTiles: map.tileSnapshot(),
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
    game.tryMove(tx - x, ty - y);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return game;
  }

  Future<void> choose(WidgetTester tester, int choice) async {
    await tester.pump(const Duration(milliseconds: 300));
    if (choice == 0) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    } else {
      await tester.tap(
        find.text(
          choice == 1 ? LoreFieldLogic.confirmYes : LoreFieldLogic.confirmNo,
        ),
      );
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  }

  for (final map in [7, 19, 23, 25]) {
    for (final choice in [0, 1, 2]) {
      testWidgets(
        'map $map exit choice $choice uses original destination/refusal',
        (tester) async {
          final y = map == 7 ? 71 : 46;
          final x = map == 7 ? 38 : 26;
          final game = await open(tester, map, x, y - 1, x, y);
          expect(find.text(LoreFieldLogic.exitPrompt), findsOneWidget);
          await choose(tester, choice);
          if (choice == 1) {
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 100));
            });
            await tester.pump();
          }
          expect(
            [game.currentMapId, game.playerX, game.playerY],
            choice == 1
                ? switch (map) {
                    7 => [1, 77, 57],
                    19 => [4, 48, 58],
                    23 => [5, 34, 15],
                    _ => [23, 25, 45],
                  }
                : [map, x, y - 1],
          );
          await finish(tester);
        },
      );
    }
  }
  for (final choice in [0, 1, 2]) {
    testWidgets(
      'map 7 gate choice $choice asks enter and keeps refused position',
      (tester) async {
        final game = await open(tester, 7, 49, 10, 50, 10);
        expect(
          find.text(LoreFieldLogic.enterPrompt('GROUND GATE')),
          findsOneWidget,
        );
        await choose(tester, choice);
        if (choice == 1) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pump();
        }
        expect([
          game.currentMapId,
          game.playerX,
          game.playerY,
        ], choice == 1 ? [8, 50, 10] : [7, 50, 10]);
        await finish(tester);
      },
    );
  }
  for (final second in [0, 1, 2]) {
    testWidgets('refused gate continues the overlapping exit IF: $second', (
      tester,
    ) async {
      final game = await open(tester, 7, 49, 71, 50, 71);
      expect(
        find.text(LoreFieldLogic.enterPrompt('GROUND GATE')),
        findsOneWidget,
      );
      await choose(tester, 2);
      expect(find.text(LoreFieldLogic.exitPrompt), findsOneWidget);
      await choose(tester, second);
      if (second == 1) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
      }
      expect([
        game.currentMapId,
        game.playerX,
        game.playerY,
      ], second == 1 ? [1, 77, 57] : [7, 50, 70]);
      await finish(tester);
    });
  }
  testWidgets(
    'accepted overlapping gate loads map 8 and skips the old exit IF',
    (tester) async {
      final game = await open(tester, 7, 49, 71, 50, 71);
      await choose(tester, 1);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect([game.currentMapId, game.playerX, game.playerY], [8, 50, 10]);
      expect(find.text(LoreFieldLogic.exitPrompt), findsNothing);
      await finish(tester);
    },
  );
  testWidgets('secret wall mutation precedes overlapping exit question', (
    tester,
  ) async {
    final game = await open(tester, 7, 29, 71, 30, 71);
    expect(find.text(LoreFieldLogic.exitPrompt), findsOneWidget);
    expect(game.currentMap!.getTile(31, 71), 45);
    await choose(tester, 0);
    expect([game.playerX, game.playerY], [30, 70]);
    await finish(tester);
  });
}
