import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _hex(String raw) => Uint8List.fromList([
  for (var i = 0; i < raw.length; i += 2)
    int.parse(raw.substring(i, i + 2), radix: 16),
]);

PartyMember _record(List<dynamic> raw) {
  final data = ByteData.sublistView(Uint8List.fromList(raw.cast<int>()));
  int word(int offset) => data.getInt16(offset, Endian.little);
  return PartyMember(
    name: ascii.decode(raw.skip(1).take(raw[0]).cast<int>().toList()),
    sex: Gender.values[raw[18]],
    playerClass: PlayerClass.fromId(raw[19]),
    strength: raw[20],
    mentality: raw[21],
    concentration: raw[22],
    endurance: raw[23],
    resistance: raw[24],
    agility: raw[25],
    accArms: raw[26],
    accMagic: raw[27],
    accEsp: raw[28],
    luck: raw[29],
    poison: raw[30],
    unconscious: word(31),
    dead: word(33),
    hp: word(35),
    sp: word(37),
    esp: word(39),
    battleLevel: raw[41],
    magicLevel: raw[42],
    espLevel: raw[43],
    ac: raw[44],
    experience: data.getInt32(45, Endian.little),
    weapon: raw[49],
    shield: raw[50],
    armor: raw[51],
    weaPower: raw[52],
    shiPower: raw[53],
    armPower: raw[54],
  );
}

/// LORESUB.PAS:1655,1675: successful cold/warm Load resource paths.
/// Resource errors, cold UI record restoration and BGI output remain separate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = jsonDecode(
    File('test/fixtures/dos_load_phases.json').readAsStringSync(),
  );
  setUp(() {
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
  });
  tearDown(() {
    LoreDialogueManager.instance.loadFlags({});
    LoreScriptEngine.instance.resetForTest();
  });
  test('108 complete native Load map results match actual asset and snapshot owners', () async {
    expect(native['cases'], hasLength(108));
    final game = LoreGame();
    for (final row in native['cases']) {
      final mapId = row['mapId'] as int;
      final record = native['mapRecords'][row['mapRecord']];
      final expected = _hex(record['tilesHex']);
      final coldSaved = row['saved'] == true && row['warm'] == false;
      await game.loadMapById(
        mapId,
        startX: 5,
        startY: 6,
        mapTiles: coldSaved ? expected : null,
      );
      expect(game.currentMap!.tileSnapshot(), expected, reason: '$row');
      expect(
        (game.currentMap!.xmax, game.currentMap!.ymax),
        (record['width'], record['height']),
      );
      expect(
        game.currentMap!.category,
        ['town', 'ground', 'den', 'keep'][row['position']],
      );
      expect(LoreWorldManager.mapRegistry[mapId]!.fileName, row['mapName']);
      expect((game.playerX, game.playerY), (5, 6));
      if (coldSaved) {
        expect(game.currentMap!.getTile(1, 1), 42);
        // A subsequent warm Load drops the persisted snapshot, as in DOS.
        await game.loadMapById(mapId, startX: 5, startY: 6);
        final warm = (native['cases'] as List).singleWhere(
          (r) => r['mapId'] == mapId && r['warm'] == true && r['saved'] == true,
        );
        expect(
          game.currentMap!.tileSnapshot(),
          _hex(native['mapRecords'][warm['mapRecord']]['tilesHex']),
        );
      }
    }
  });
  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    for (final warm in [false, true]) {
      for (final saved in [false, true]) {
        testWidgets(
          'native records survive actual Load and resave: $size/$warm/$saved',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final row = (native['cases'] as List).singleWhere(
              (r) =>
                  r['mapId'] == 14 && r['warm'] == warm && r['saved'] == saved,
            );
            final raw = (warm ? row['beforeParty'] : row['fileParty']) as List;
            final records = warm
                ? native['memoryPlayers']
                : native['filePlayers'];
            final snapshot = _hex(
              native['mapRecords'][row['mapRecord']]['tilesHex'],
            );
            await tester.pumpWidget(
              MaterialApp(
                home: MainGameScreen(
                  initialSaveData: SaveData(
                    slot: 1,
                    slotName: SaveManager.slotNames[0],
                    timestamp: DateTime.utc(1993),
                    mapId: 14,
                    mapTitle: 'DEN1',
                    playerX: 5,
                    playerY: 6,
                    gold: ByteData.sublistView(
                      Uint8List.fromList(raw.cast<int>()),
                    ).getInt32(4, Endian.little),
                    food: raw[3],
                    party: [for (final r in records) _record(r)],
                    flags: {for (var i = 1; i <= 100; i++) 'etc$i': raw[7 + i]},
                    mapTiles: saved && !warm ? snapshot : const [],
                  ),
                ),
              ),
            );
            final finder = find.byType(GameWidget<LoreGame>);
            await tester.runAsync(
              () =>
                  tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
            );
            await tester.pump(const Duration(milliseconds: 500));
            final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
            if (warm) {
              final chara = game.charaFont;
              await tester.runAsync(
                () => game.loadMapById(14, startX: 5, startY: 6),
              );
              await tester.pump();
              expect(identical(game.charaFont, chara), isTrue);
            }
            expect(game.currentMap!.tileSnapshot(), snapshot);
            expect(
              [for (final p in game.partyProvider!()) p.toJson()],
              [
                for (final r in (row['afterPlayers'] as List).take(6))
                  _record(r).toJson(),
              ],
            );
            final after = row['afterParty'] as List;
            for (var i = 1; i <= 100; i++) {
              expect(
                LoreDialogueManager.instance.partyEtc.read(i),
                after[7 + i],
              );
            }
            Future<void> settle() async {
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
            }

            await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
            await settle();
            await tester.tap(find.text(LoreMenuText.optionSave));
            await settle();
            await tester.tap(find.text(SaveManager.slotNames[0]));
            await settle();
            final result = (await SaveManager.instance.loadGame(1))!;
            expect(result.gold, warm ? 777 : 1000);
            expect(result.food, after[3]);
            expect(result.mapTiles, snapshot);
            expect(
              [for (final p in result.party) p.toJson()],
              [
                for (final r in (row['afterPlayers'] as List).take(6))
                  _record(r).toJson(),
              ],
            );
          },
        );
      }
    }
  }
}
