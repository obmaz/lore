import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/theme/retro_theme.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/services/audio_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LORESUB.PAS:1636-1790, LORESPEC.PAS:826-832, LOREMAIN.PAS:205.
/// LORETALK.PAS:360-383: actual centre disk reload and Lord Ahn continuation.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_menace_return.json').readAsStringSync(),
  );
  // LORESUB.PAS Grocery/Save; LOREMENU.PAS Rest; LORETALK.PAS:406-469.
  final lastditch = jsonDecode(
    File('test/fixtures/dos_lastditch_arrival.json').readAsStringSync(),
  );
  dynamic observed(int number) => (lastditch['inputs'] as List).singleWhere(
    (input) => input['capture'] == 'lore_$number.png',
  )['after'];
  // LOREENT.PAS:159-167; LORESPEC.PAS:313-319, 493-521.
  final pyramid = lastditch['pyramid'];
  dynamic pyramidState(int number) => (pyramid['inputs'] as List).singleWhere(
    (input) => input['capture'] == 'lore_$number.png',
  )['after'];
  Future<void> tick(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<LoreGame> open(
    WidgetTester tester,
    dynamic saved,
    LoreRandom random,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      LoreDialogueManager.instance.loadFlags({});
      LoreScriptEngine.instance.resetForTest();
      LoreWorldManager.instance.resetRulesForTest();
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
    final capture = saved;
    final party = capture['partyRecord'];
    final files = Map<String, dynamic>.from(saved['files']);
    final mapFile = files.entries.singleWhere(
      (file) => file.key.startsWith('SAVE'),
    );
    final nativeMap = _hex(mapFile.value['hex']).skip(2).toList();
    await tester.pumpWidget(
      MaterialApp(
        home: MainGameScreen(
          encounterRandom: random,
          initialSaveData: SaveData(
            slot: 1,
            slotName: 'Original DOS checkpoint',
            timestamp: DateTime.utc(1993),
            mapId: party['mapId'],
            mapTitle: 'Original map',
            playerX: party['x'],
            playerY: party['y'],
            gold: party['gold'],
            food: party['food'],
            party: [
              for (final r in capture['records']) PartyMember.fromJson(r),
            ],
            flags: {
              for (var i = 0; i < 100; i++) 'etc${i + 1}': party['etc'][i],
            },
            mapTiles: nativeMap,
          ),
        ),
      ),
    );
    final finder = find.byType(GameWidget<LoreGame>);
    final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
    await tester.runAsync(
      () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
    );
    await tick(tester);
    return game;
  }

  Future<void> walk(
    WidgetTester tester,
    LoreGame game,
    List<dynamic> route,
  ) async {
    for (final key in route) {
      final (dx, dy) = switch (key) {
        'Up' => (0, -1),
        'Down' => (0, 1),
        'Left' => (-1, 0),
        'Right' => (1, 0),
        _ => throw StateError('Unknown captured key $key'),
      };
      game.tryMove(dx, dy);
      await tick(tester);
    }
  }

  void check(LoreGame game, LoreRandom random, dynamic state) {
    expect(random.seed, state['seed']);
    expect(
      game.partyProvider!().map((p) => p.toJson()).toList(),
      state['records'],
    );
    expect(LoreDialogueManager.instance.partyEtc.snapshot(), {
      for (var i = 0; i < 100; i++) i + 1: state['partyRecord']['etc'][i],
    });
  }

  Future<void> save(
    WidgetTester tester,
    LoreGame game,
    LoreRandom random,
    dynamic checkpoint,
    dynamic wait,
    dynamic afterKey,
  ) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tick(tester);
    await tester.tap(find.text(LoreMenuText.optionSave));
    await tick(tester);
    await tester.tap(find.text(SaveManager.slotNames[0]));
    await tick(tester);
    check(game, random, wait);
    final saved = (await SaveManager.instance.loadGame(1))!;
    final p = checkpoint['partyRecord'];
    expect(
      (saved.mapId, saved.playerX, saved.playerY),
      (p['mapId'], p['x'], p['y']),
    );
    expect((saved.gold, saved.food), (p['gold'], p['food']));
    expect(saved.party.map((p) => p.toJson()).toList(), checkpoint['records']);
    expect([for (var i = 1; i <= 100; i++) saved.flags['etc$i']], p['etc']);
    expect(
      saved.mapTiles,
      _hex(checkpoint['files']['SAVE1.MAP']['hex']).skip(2).toList(),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tick(tester);
    check(game, random, afterKey);
  }

  testWidgets('native Save/Rest Space acknowledgements enter SelectMode once', (
    tester,
  ) async {
    final f = jsonDecode(
      File('test/fixtures/dos_pyramid_success.json').readAsStringSync(),
    );
    dynamic phase(int n) => (f['inputs'] as List).singleWhere(
      (s) => s['capture'] == 'lore_${n.toString().padLeft(3, '0')}.png',
    )['after'];
    final random = LoreRandom(phase(388)['seed']);
    final game = await open(tester, f['successSave'], random);
    check(game, random, phase(388));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tick(tester);
    await tester.tap(find.text(LoreMenuText.optionSave));
    await tick(tester);
    await tester.tap(find.text(SaveManager.slotNames[0]));
    await tick(tester);
    check(game, random, phase(388));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tick(tester);
    check(game, random, phase(389));
    expect(find.text(LoreMenuText.selectModeRest), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tick(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tick(tester);
    check(game, random, phase(392));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tick(tester);
    check(game, random, phase(393));
    expect(find.text(LoreMenuText.selectModeRest), findsOneWidget);
    // Main checks its Space branch once: the nested Rest must not reopen it.
    await tester.tap(find.text(LoreMenuText.selectModeRest));
    await tick(tester);
    check(game, random, phase(396));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tick(tester);
    check(game, random, phase(397));
    expect(find.text(LoreMenuText.selectModeRest), findsNothing);
    for (final n in [399, 401]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tick(tester);
      check(game, random, phase(n));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, phase(n + 1));
      expect(find.text(LoreMenuText.selectModeRest), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'native LASTDITCH reward waits for acknowledgement and cannot repeat',
    (tester) async {
      final f = jsonDecode(
        File('test/fixtures/dos_pyramid_success.json').readAsStringSync(),
      );
      dynamic phase(int n) => (f['inputs'] as List).singleWhere(
        (s) => s['capture'] == 'lore_${n.toString().padLeft(3, '0')}.png',
      )['after'];
      final approach = (f['inputs'] as List).singleWhere(
        (s) => s['capture'] == 'lore_413.png',
      )['before'];
      // This is a captured RAM checkpoint, using the byte-identical actual
      // later map file. It is not asserted to be a pre-reward native disk save.
      final checkpoint = {
        'partyRecord': {
          ...Map<String, dynamic>.from(approach['partyRecord']),
          'x': 38,
          'y': 18,
        },
        'records': approach['records'],
        'files': f['lordSave']['files'],
      };
      final random = LoreRandom(approach['seed']);
      final game = await open(tester, checkpoint, random);
      check(game, random, approach);
      await walk(tester, game, ['Up']);
      check(game, random, phase(413));
      expect(LoreDialogueManager.instance.partyEtc.read(13), 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tick(tester);
      check(game, random, phase(414));
      expect(LoreDialogueManager.instance.partyEtc.read(13), 3);
      // Movement dispatch occurs after Main's Space branch, so the NPC's
      // PressAnyKey Space must not open SelectMode on this same field command.
      expect(find.text(LoreMenuText.selectModeRest), findsNothing);
      await walk(tester, game, ['Up']);
      check(game, random, phase(417));
      expect(find.textContaining('VALIANT PEOPLES'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, phase(418));
      await save(tester, game, random, f['lordSave'], phase(421), phase(422));
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'compiled Main SoundOn branch matches recorded key and audio toggle',
    () {
      final f = jsonDecode(
        File('test/fixtures/dos_main_sound.json').readAsStringSync(),
      );
      final audio = AudioManager.instance;
      final old = audio.sourceSoundEnabled;
      final mute = audio.isMuted;
      addTearDown(() => audio.sourceSoundEnabled = old);
      for (final c in f['cases']) {
        audio.sourceSoundEnabled = c['before'] == 1;
        if (c['key'] == 8) audio.toggleSourceSound();
        expect(audio.sourceSoundEnabled, c['after'] == 1);
        expect(audio.isMuted, mute);
      }
    },
  );
  final gaia = jsonDecode(
    File('test/fixtures/dos_gaia_continuation.json').readAsStringSync(),
  );
  dynamic gaiaInput(int n) =>
      [
            ...gaia['trace'] as List,
            for (final c in gaia['continuations'] ?? []) ...c['trace'] as List,
          ]
          .where((s) => s.containsKey('input'))
          .map((s) => s['input'])
          .singleWhere(
            (s) => s['capture'] == 'lore_${n.toString().padLeft(3, '0')}.png',
          );
  dynamic gaiaState(int n) => gaiaInput(n)['after'];
  dynamic ramCheckpoint(dynamic state, dynamic mapSave) => {
    'partyRecord': {
      ...Map<String, dynamic>.from(state['partyRecord']),
      'x': state['live']['x'],
      'y': state['live']['y'],
    },
    'records': state['records'],
    'files': mapSave['files'],
  };
  testWidgets(
    'native Lord reward trains four members with four RNG draws and skips capped levels',
    (tester) async {
      final before = gaiaInput(423)['before'];
      final random = LoreRandom(before['seed']);
      final game = await open(
        tester,
        ramCheckpoint(before, gaia['saves']['trained']),
        random,
      );
      check(game, random, before);
      await walk(tester, game, ['Up']);
      check(game, random, gaiaState(423));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, gaiaState(424));
      for (final (slot, n) in [
        (0, 425),
        (1, 427),
        (2, 429),
        (3, 431),
        (4, 433),
        (5, 435),
      ]) {
        for (var i = 0; i < slot; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tick(tester);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tick(tester);
        check(game, random, gaiaState(n));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tick(tester);
        check(game, random, gaiaState(n + 1));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tick(tester);
      check(game, random, gaiaState(437));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native Backspace affects source SoundOn and Rest keeps its final field RNG',
    (tester) async {
      final observations = gaia['soundChecks'] as List;
      final before = observations.first['before'];
      final random = LoreRandom(before['seed']);
      final game = await open(
        tester,
        ramCheckpoint(before, gaia['saves']['gaiaRequest']),
        random,
      );
      final audio = AudioManager.instance;
      final originalSound = audio.sourceSoundEnabled;
      addTearDown(() => audio.sourceSoundEnabled = originalSound);
      audio.sourceSoundEnabled = observations.first['beforeSound'] == 1;
      final mute = audio.isMuted;
      for (final observation in observations) {
        final key = observation['keys'][0] == 'r'
            ? LogicalKeyboardKey.keyR
            : LogicalKeyboardKey.backspace;
        await tester.sendKeyEvent(key);
        await tick(tester);
        check(game, random, observation['after']);
        expect(audio.sourceSoundEnabled, observation['afterSound'] == 1);
        expect(audio.isMuted, mute);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native GAIA request updates etc14 after final key and revisit has no reward',
    (tester) async {
      final before = gaiaInput(571)['before'];
      final random = LoreRandom(before['seed']);
      final game = await open(
        tester,
        ramCheckpoint(before, gaia['saves']['gaiaRequest']),
        random,
      );
      await walk(tester, game, ['Up']);
      check(game, random, gaiaState(571));
      expect(LoreDialogueManager.instance.partyEtc.read(14), 0);
      expect(find.textContaining('EVIL SEAL'), findsWidgets);
      // Native internal Print pagination is separate from the final talk key.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, gaiaState(580));
      expect(LoreDialogueManager.instance.partyEtc.read(14), 1);
      await save(
        tester,
        game,
        random,
        gaia['saves']['gaiaRequest'],
        gaiaState(583),
        gaiaState(584),
      );
      await walk(tester, game, ['Up']);
      check(game, random, gaiaState(585));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, gaiaState(586));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native EVIL SEAL stage changes before key and opens original map cell',
    (tester) async {
      final before = gaiaInput(828)['before'];
      final saved = ramCheckpoint(before, gaia['saves']['evilSealSuccess']);
      saved['files'] = {'SAVE1.MAP': gaia['ramMapBeforeSeal']};
      final random = LoreRandom(before['seed']);
      final game = await open(tester, saved, random);
      check(game, random, before);
      expect(game.currentMap!.getTile(18, 9), 51);
      await walk(tester, game, ['Up']);
      check(game, random, gaiaState(828));
      expect(game.currentMap!.getTile(18, 9), 0);
      expect(LoreDialogueManager.instance.partyEtc.read(14), 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, gaiaState(829));
      await save(
        tester,
        game,
        random,
        gaia['saves']['evilSealSuccess'],
        gaiaState(832),
        gaiaState(833),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native EVIL SEAL reward precedes final key then QUAKE request advances and saves',
    (tester) async {
      final before = gaiaInput(907)['before'];
      final random = LoreRandom(before['seed']);
      final game = await open(
        tester,
        ramCheckpoint(before, gaia['saves']['evilReturn']),
        random,
      );
      check(game, random, before);
      await walk(tester, game, ['Up']);
      check(game, random, gaiaState(907));
      expect(LoreDialogueManager.instance.partyEtc.read(14), 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, gaiaState(908));
      await walk(tester, game, ['Up']);
      check(game, random, gaiaState(909));
      expect(find.textContaining('QUAKE'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, gaiaState(910));
      await save(
        tester,
        game,
        random,
        gaia['saves']['evilReturn'],
        gaiaState(913),
        gaiaState(914),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native QUAKE reward precedes key, water key advances only once and saves',
    (tester) async {
      final f = jsonDecode(
        File('test/fixtures/dos_quake_continuation.json').readAsStringSync(),
      );
      final inputs = [
        for (final e in f['epochs'])
          for (final b in e['trace'])
            if (b.containsKey('input')) b['input'],
      ];
      dynamic input(int n) =>
          inputs.singleWhere((i) => i['capture'] == 'lore_$n.png');
      dynamic phase(int n) => input(n)['after'];
      final before = input(1480)['before'];
      final random = LoreRandom(before['seed']);
      final game = await open(
        tester,
        ramCheckpoint(before, f['saves']['quakeReturn']),
        random,
      );
      await walk(tester, game, ['Up']);
      check(game, random, phase(1480));
      expect(LoreDialogueManager.instance.partyEtc.read(14), 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, phase(1481));
      await save(
        tester,
        game,
        random,
        f['saves']['quakeReturn'],
        phase(1484),
        phase(1485),
      );
      await walk(tester, game, ['Up']);
      check(game, random, phase(1486));
      expect(find.textContaining('WIVERN'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, phase(1487));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native WIVERN exit and WATER FIELD request advances after final key then saves',
    (tester) async {
      final f = jsonDecode(
        File('test/fixtures/dos_wivern_continuation.json').readAsStringSync(),
      );
      final inputs = [
        for (final b in f['trace'])
          if (b.containsKey('input')) b['input'],
      ];
      dynamic input(int n) =>
          inputs.singleWhere((i) => i['capture'] == 'lore_$n.png');
      dynamic phase(int n) => input(n)['after'];
      final before = input(2072)['before'];
      final random = LoreRandom(before['seed']);
      final game = await open(
        tester,
        ramCheckpoint(before, f['saves']['wivernSuccess']),
        random,
      );
      await walk(tester, game, ['Up']);
      check(game, random, phase(2072));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.runAsync(() async {
        for (var i = 0; i < 20 && game.currentMapId != 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tick(tester);
      check(game, random, phase(2073));
      final route = (f['trace'] as List).singleWhere(
        (b) =>
            b.containsKey('walk') &&
            b['walk']['before']['partyRecord']['mapId'] == 10 &&
            b['walk']['after']['live']['x'] == 26 &&
            b['walk']['after']['live']['y'] == 18,
      )['walk'];
      await walk(tester, game, [
        for (final step in route['steps']) step['key'],
      ]);
      await walk(tester, game, ['Left']);
      check(game, random, phase(2074));
      expect(LoreDialogueManager.instance.partyEtc.read(15), 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, phase(2087));
      await walk(tester, game, ['Left']);
      check(game, random, phase(2088));
      expect(find.textContaining('NOTICE'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, phase(2089));
      await save(
        tester,
        game,
        random,
        f['saves']['waterArrival'],
        phase(2092),
        phase(2093),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native NOTICE HIDRA return grants all six 150k before final key',
    (tester) async {
      final f = jsonDecode(
        File('test/fixtures/dos_notice_continuation.json').readAsStringSync(),
      );
      final inputs = [
        for (final b in f['trace'])
          if (b.containsKey('input')) b['input'],
      ];
      dynamic input(int n) =>
          inputs.singleWhere((i) => i['capture'] == 'lore_$n.png');
      dynamic phase(int n) => input(n)['after'];
      final before = input(9310)['before'];
      final random = LoreRandom(before['seed']);
      final game = await open(
        tester,
        ramCheckpoint(before, f['saves']['hidraReturn']),
        random,
      );
      await walk(tester, game, ['Up']);
      check(game, random, phase(9310));
      expect(LoreDialogueManager.instance.partyEtc.read(15), 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, phase(9311));
      await save(
        tester,
        game,
        random,
        f['saves']['hidraReturn'],
        phase(9314),
        phase(9315),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native NOTICE teaching, MindRead and slot4 Antares preserve every record',
    (tester) async {
      final f = jsonDecode(
        File('test/fixtures/dos_notice_continuation.json').readAsStringSync(),
      );
      final inputs = [
        for (final b in f['trace'])
          if (b.containsKey('input')) b['input'],
      ];
      dynamic input(int n) =>
          inputs.singleWhere((i) => i['capture'] == 'lore_$n.png');
      dynamic phase(int n) => input(n)['after'];
      final before = input(7193)['before'];
      final saved = ramCheckpoint(before, {
        'files': {
          'SAVE1.MAP': {'hex': f['ramMaps']['beforeAntares']['hex']},
        },
      });
      final random = LoreRandom(before['seed']);
      final game = await open(tester, saved, random);
      await walk(tester, game, ['Right']);
      check(game, random, phase(7193));
      // Four explicit PressAnyKey calls; implicit Print pagination is scrolling.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tick(tester);
      }
      check(game, random, phase(7206));
      Future<void> keys(List<LogicalKeyboardKey> list) async {
        for (final key in list) {
          await tester.sendKeyEvent(key);
          await tick(tester);
        }
      }

      await keys([
        LogicalKeyboardKey.keyE,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
      ]);
      check(game, random, phase(7209));
      await keys([
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
      ]);
      check(game, random, phase(7211));
      await walk(tester, game, ['Left']);
      check(game, random, phase(7212));
      await save(
        tester,
        game,
        random,
        f['saves']['antaresJoined'],
        phase(7215),
        phase(7216),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native Antares Food8 costs30, creates six rations and continues Main once',
    (tester) async {
      final f = jsonDecode(
        File('test/fixtures/dos_notice_continuation.json').readAsStringSync(),
      );
      final inputs = [
        for (final b in f['trace'])
          if (b.containsKey('input')) b['input'],
      ];
      dynamic input(int n) =>
          inputs.singleWhere((i) => i['capture'] == 'lore_$n.png');
      final before = input(7633)['before'];
      final random = LoreRandom(before['seed']);
      final game = await open(
        tester,
        ramCheckpoint(before, f['saves']['antaresJoined']),
        random,
      );
      for (final key in [
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
        ...List.filled(7, LogicalKeyboardKey.arrowDown),
        LogicalKeyboardKey.enter,
      ]) {
        await tester.sendKeyEvent(key);
        await tick(tester);
      }
      check(game, random, input(7636)['after']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native LOCKUP Dragon return grants all six300k and Swamp Key after final key',
    (tester) async {
      final f = jsonDecode(
        File('test/fixtures/dos_lockup_continuation.json').readAsStringSync(),
      );
      final inputs = [
        for (final segment in f['segments'])
          if (segment.containsKey('trace'))
            for (final b in segment['trace'])
              if (b.containsKey('input')) b['input'],
      ];
      dynamic input(int n) =>
          inputs.singleWhere((i) => i['capture'] == 'lore_$n.png');
      dynamic phase(int n) => input(n)['after'];
      final before = input(11511)['before'];
      final random = LoreRandom(before['seed']);
      final game = await open(
        tester,
        ramCheckpoint(before, f['saves']['dragonReturn']),
        random,
      );
      await walk(tester, game, ['Up']);
      check(game, random, phase(11511));
      expect(LoreDialogueManager.instance.partyEtc.read(15), 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, phase(11512));
      await save(
        tester,
        game,
        random,
        f['saves']['dragonReturn'],
        phase(11515),
        phase(11516),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native Spica teaching and weak ESP MindRead preserve original flags, cost and save',
    (tester) async {
      final f = jsonDecode(
        File('test/fixtures/dos_lockup_continuation.json').readAsStringSync(),
      );
      final inputs = [
        for (final segment in f['segments'])
          if (segment.containsKey('trace'))
            for (final b in segment['trace'])
              if (b.containsKey('input')) b['input'],
      ];
      dynamic input(int n) =>
          inputs.singleWhere((i) => i['capture'] == 'lore_$n.png');
      dynamic phase(int n) => input(n)['after'];
      final before = input(9574)['before'];
      final random = LoreRandom(before['seed']);
      final game = await open(
        tester,
        ramCheckpoint(before, f['saves']['spicaWarning']),
        random,
      );
      await walk(tester, game, ['Up']);
      check(game, random, phase(9574));
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tick(tester);
      }
      check(game, random, phase(9578));
      for (final key in [
        LogicalKeyboardKey.keyE,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
      ]) {
        await tester.sendKeyEvent(key);
        await tick(tester);
      }
      check(game, random, phase(9581));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, phase(9582));
      await walk(tester, game, ['Down']);
      check(game, random, phase(9583));
      await save(
        tester,
        game,
        random,
        f['saves']['spicaWarning'],
        phase(9586),
        phase(9587),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual DOS centre disk reload, revisit and resave preserve all records and map bytes',
    (tester) async {
      final f = fixture['centerReload'];
      final inputs = f['inputs'];
      final random = LoreRandom(inputs[0]['after']['seed']);
      final game = await open(tester, fixture['centerSave'], random);
      check(game, random, inputs[0]['after']);
      expect((game.playerX, game.playerY), (25, 8));
      for (var i = 1; i <= 2; i++) {
        await walk(tester, game, List<dynamic>.from(inputs[i]['keys']));
        check(game, random, inputs[i]['after']);
      }
      expect((game.playerX, game.playerY), (25, 8));
      expect(find.text("여기가 `MENACE'의 중심이다."), findsNothing);
      expect(find.text('당신의 탐험은 성공적이었다.'), findsNothing);
      await save(
        tester,
        game,
        random,
        f['save'],
        inputs[5]['after'],
        inputs[6]['after'],
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual DOS grocery, four rests and disk save recover the Lord Ahn party',
    (tester) async {
      final movement = lastditch['walks']['grocery'];
      final random = LoreRandom(movement['initial']['seed']);
      final game = await open(tester, fixture['lordAhn']['save'], random);
      check(game, random, movement['initial']);
      for (final step in movement['steps']) {
        await walk(tester, game, [step['key']]);
        expect(random.seed, step['after']['seed']);
      }
      check(game, random, movement['after']);
      expect((game.playerX, game.playerY), (86, 73));
      await walk(tester, game, ['Right']);
      check(game, random, observed(109));
      await tester.tap(find.text('50 인분 : 금 500 개'));
      await tick(tester);
      check(game, random, observed(110));
      for (final number in [111, 113, 115, 117]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
        await tick(tester);
        check(game, random, observed(number));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tick(tester);
        check(game, random, observed(number + 1));
      }
      await save(
        tester,
        game,
        random,
        lastditch['readySave'],
        observed(121),
        observed(122),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual LASTDITCH save -> Lord request -> Polaris cancel/replacement -> disk save',
    (tester) async {
      final movement = lastditch['walks']['lord'];
      final random = LoreRandom(movement['initial']['seed']);
      final game = await open(tester, lastditch['arrivalSave'], random);
      check(game, random, movement['initial']);
      for (final step in movement['steps']) {
        await walk(tester, game, [step['key']]);
        expect(random.seed, step['after']['seed']);
      }
      check(game, random, movement['after']);
      expect((game.playerX, game.playerY), (38, 18));
      await walk(tester, game, ['Up']);
      check(game, random, observed(137));
      expect(LoreDialogueManager.instance.partyEtc.read(13), 0);
      expect(find.textContaining('PYRAMID'), findsWidgets);
      // DOS Scroll pages need extra keys; compare the closed procedure's
      // first wait and final PressAnyKey, not original text-page geometry.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, observed(142));
      await walk(tester, game, ['Up']);
      check(game, random, observed(143));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tick(tester);
      check(game, random, observed(144));
      for (final step in lastditch['walks']['polaris']['steps']) {
        await walk(tester, game, [step['key']]);
        expect(random.seed, step['after']['seed']);
      }
      check(game, random, lastditch['walks']['polaris']['after']);
      expect((game.playerX, game.playerY), (37, 42));
      for (final attempt in [false, true]) {
        await walk(tester, game, ['Up']);
        check(game, random, observed(attempt ? 149 : 146));
        await tester.tap(find.text('나는 당신의 제안을 받아 들이겠소'));
        await tick(tester);
        check(game, random, observed(attempt ? 150 : 147));
        if (attempt) {
          // Use the captured Select keys; the character panel also shows Merlin.
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tick(tester);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        }
        await tick(tester);
        check(game, random, observed(attempt ? 151 : 148));
        expect(game.currentMap!.getTile(37, 41), attempt ? 44 : 53);
      }
      await save(
        tester,
        game,
        random,
        lastditch['polarisSave'],
        observed(154),
        observed(155),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual LASTDITCH secret passage, PYRAMID load and save acknowledgment encounter',
    (tester) async {
      final movement = pyramid['entryMovement'];
      final random = LoreRandom(movement['initial']['seed']);
      final game = await open(tester, lastditch['polarisSave'], random);
      check(game, random, movement['initial']);
      for (final step in movement['steps']) {
        await walk(tester, game, [step['key']]);
        expect(random.seed, step['after']['seed']);
      }
      expect((game.playerX, game.playerY), (29, 8));
      for (var number = 157; number <= 166; number++) {
        final input = (pyramid['inputs'] as List).singleWhere(
          (i) => i['capture'] == 'lore_$number.png',
        );
        await walk(tester, game, List<String>.from(input['keys']));
        check(game, random, input['after']);
        if (number < 166) expect(game.currentMap!.getTile(31, 8), 45);
      }
      expect((game.playerX, game.playerY), (37, 7));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.runAsync(() async {
        for (var i = 0; i < 20 && game.currentMapId != 11; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tick(tester);
      check(game, random, pyramidState(167));
      expect((game.currentMapId, game.playerX, game.playerY), (11, 25, 45));
      await save(
        tester,
        game,
        random,
        pyramid['arrivalSave'],
        pyramidState(170),
        pyramidState(171),
      );
      expect(find.textContaining('Giant'), findsWidgets);
      // Stop at the native encounter choice; the captured Giant battle is
      // retained as provenance, not claimed as a new full battle replay.
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual PYRAMID spear cancellation, fighter rejection, knight bonus and save',
    (tester) async {
      // After the actual Giant escape, exit and reentry, native party/player
      // bytes equal this genuine earlier disk save (checked by Python).
      final random = LoreRandom(pyramidState(209)['seed']);
      final game = await open(tester, pyramid['arrivalSave'], random);
      check(game, random, pyramidState(209));
      for (final (start, choice) in [(210, -1), (215, 4), (220, 1)]) {
        if (start != 210) {
          await walk(tester, game, ['Down']);
          check(game, random, pyramidState(start - 1));
        }
        await walk(tester, game, ['Up']);
        check(game, random, pyramidState(start));
        expect((game.playerX, game.playerY), (25, 44));
        for (var number = start + 1; number <= start + 2; number++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tick(tester);
          check(game, random, pyramidState(number));
        }
        if (choice < 0) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          for (var i = 0; i < choice; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
            await tick(tester);
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        }
        await tick(tester);
        check(game, random, pyramidState(start + 3));
        expect(
          LoreDialogueManager.instance.partyEtc.read(33),
          choice == 1 ? 128 : 0,
        );
      }
      await save(
        tester,
        game,
        random,
        pyramid['spearSave'],
        pyramidState(226),
        pyramidState(227),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual DOS Castle reload -> Lord Ahn reward -> LASTDITCH hint -> revisit -> save',
    (tester) async {
      final f = fixture['lordAhn'];
      final random = LoreRandom(fixture['castleReload']['after']['seed']);
      final game = await open(tester, fixture['castleSave'], random);
      check(game, random, fixture['castleReload']['after']);
      expect((game.playerX, game.playerY), (51, 95));
      for (final step in f['movement']['steps']) {
        expect(random.seed, step['seedBefore']);
        await walk(tester, game, [step['key']]);
        expect(random.seed, step['seedAfter']);
      }
      check(game, random, f['movement']['after']);
      expect((game.playerX, game.playerY), (51, 29));
      final before = game.partyProvider!().map((p) => p.experience).toList();
      for (final (index, input) in (f['inputs'] as List).indexed) {
        check(game, random, input['before']);
        final keys = List<String>.from(input['keys']);
        if (keys.single == 'Up') {
          await walk(tester, game, keys);
        } else {
          await tester.sendKeyEvent(
            keys.single == 'Escape'
                ? LogicalKeyboardKey.escape
                : LogicalKeyboardKey.enter,
          );
          await tick(tester);
        }
        check(game, random, input['after']);
        expect((game.playerX, game.playerY), (51, 29));
        if (index == 0) {
          expect(
            tester.widget<Text>(find.text('[EXP + 1000]')).style!.color,
            RetroTheme.ega(11),
          );
          expect(LoreDialogueManager.instance.partyEtc.read(10), 5);
        }
        if (index == 2) {
          expect(LoreDialogueManager.instance.partyEtc.read(10), 5);
          expect(find.textContaining('LASTDITCH'), findsWidgets);
        }
        if (index >= 3) {
          expect(LoreDialogueManager.instance.partyEtc.read(10), 6);
        }
        expect(
          game.partyProvider!().map((p) => p.experience).toList(),
          before.map((v) => v + 1000).toList(),
        );
      }
      await save(
        tester,
        game,
        random,
        f['save'],
        f['saveInputs'][2]['after'],
        f['saveInputs'][3]['after'],
      );
      expect(tester.takeException(), isNull);
    },
  );
}

List<int> _hex(String value) => [
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
];
