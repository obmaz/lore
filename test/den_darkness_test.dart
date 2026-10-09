import 'support/source_audio_platform.dart';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LORESUB.PAS `Scroll`: `if (position = den) and (party.etc[1] = 0)` draws a
/// black view with '어둠' instead of the map and the party.
void main() {
  setUp(installSourceAudioPlatform);
  Future<Set<int>> colors(WidgetTester tester, LoreGame game) async {
    final width = game.size.x.ceil();
    final height = game.size.y.ceil();
    return (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      game.render(Canvas(recorder));
      final image = await recorder.endRecording().toImage(width, height);
      final data = (await image.toByteData())!;
      return {
        for (var i = 0; i < data.lengthInBytes; i += 4 * 7) data.getUint32(i),
      };
    }))!;
  }

  testWidgets('a den without the torch is dark, with it the map shows', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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
    addTearDown(() {
      LoreDialogueManager.instance.loadFlags({});
      LoreScriptEngine.instance.resetForTest();
    });
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final map = await tester.runAsync(
      () => LoreMapData.loadFromAsset('T_DEN1', category: 'den'),
    );
    var start = (0, 0);
    for (var y = 6; y < 40 && start == (0, 0); y++) {
      for (var x = 6; x < 40; x++) {
        final tile = map!.getTile(x, y);
        if (map.getCategory(tile).name == 'walkable') {
          start = (x, y);
          break;
        }
      }
    }
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          initialSaveData: SaveData(
            slot: 1,
            slotName: SaveManager.slotNames.first,
            timestamp: DateTime.utc(1993),
            mapId: 11,
            mapTitle: 'T_DEN 1',
            playerX: start.$1,
            playerY: start.$2,
            gold: 100,
            food: 20,
            party: [PartyMember.createPreset(1)],
            flags: const {'etc1': 0},
            mapTiles: map!.tileSnapshot(),
          ),
        ),
      ),
    );
    final finder = find.byType(GameWidget<LoreGame>);
    final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
    await tester.runAsync(
      () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(LoreDialogueManager.instance.partyEtc.read(1), 0);
    final dark = await colors(tester, game);
    // Black and the gray of '어둠' (plus antialiasing steps), nothing else.
    expect(dark.length, lessThan(40));
    LoreDialogueManager.instance.partyEtc[1] = 1;
    final lit = await colors(tester, game);
    expect(lit.length, greaterThan(dark.length));
  });
}
