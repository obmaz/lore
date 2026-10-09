import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/logic/lore_menu_text.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:lore/widgets/dpad_widget.dart';
import 'package:lore/widgets/game_over_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoRandom implements Random {
  int calls = 0;
  @override
  int nextInt(int max) {
    calls++;
    throw StateError('failed Load consumed RNG');
  }

  @override
  bool nextBool() => throw StateError('failed Load consumed RNG');
  @override
  double nextDouble() => throw StateError('failed Load consumed RNG');
}

/// LORESUB.PAS:1661,1666: original party/player IO error conditions and arguments.
/// JSON logical-record faults use native ErrorMessage labels, not binary partial
/// pre-Halt memory writes. Legacy short lists are valid adapters, not DOS EOF.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = jsonDecode(
    File('test/fixtures/dos_load_record_errors.json').readAsStringSync(),
  );
  SaveData save(int slot, {bool dead = false}) => SaveData(
    slot: slot,
    slotName: SaveManager.slotNames[slot - 1],
    timestamp: DateTime.utc(1993),
    mapId: 1,
    mapTitle: 'GROUND1',
    playerX: 50,
    playerY: 50,
    gold: 777,
    food: 20,
    party: [
      for (var i = 1; i <= 6; i++)
        PartyMember.createPreset(1)
          ..name = 'MEM$i'
          ..dead = dead ? 1 : 0,
    ],
    flags: const {},
    mapWidth: 100,
    mapHeight: 100,
    mapTiles: List.filled(10000, 44),
  );
  String? corrupt(Map row) {
    final raw = save(row['slot']).toJson();
    if ((row['target'] as String).startsWith('party')) {
      if (row['mode'] == 'missing') return null;
      final text = jsonEncode(raw);
      return text.substring(0, text.length - 1);
    }
    if (row['mode'] == 'missing') {
      raw.remove('party');
    } else {
      (raw['party'] as List).last.remove('armPower');
    }
    return jsonEncode(raw);
  }

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    void silence(String name) => messenger.setMockStreamHandler(
      EventChannel(name),
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
  tearDown(() => LoreDialogueManager.instance.loadFlags({}));
  test('16 native party/player failure labels and need flags match actual storage reader', () async {
    expect(native['cases'], hasLength(16));
    for (final row in native['cases']) {
      final raw = corrupt(Map.from(row));
      final key = 'lore_save_slot_${row['slot']}';
      SharedPreferences.setMockInitialValues({key: ?raw});
      final result = await SaveManager.instance.readGame(row['slot']);
      expect(result.data, isNull);
      expect(result.failure!.fileName, row['error']['name']);
      expect(result.failure!.needCreate, row['error']['need']);
      expect(await SaveManager.instance.loadGame(row['slot']), isNull);
      expect((await SharedPreferences.getInstance()).getString(key), raw);
    }
  });
  test('every current player field is required, but legacy defaults and short lists remain explicit', () async {
    final fields = PartyMember.zero().toJson().keys;
    for (var slot = 0; slot < 6; slot++) {
      for (final field in fields) {
        final raw = save(2).toJson();
        (raw['party'] as List)[slot].remove(field);
        SharedPreferences.setMockInitialValues({
          'lore_save_slot_2': jsonEncode(raw),
        });
        expect(
          (await SaveManager.instance.readGame(2)).failure!.fileName,
          'player2.dat',
        );
      }
    }
    for (final version in [null, 1, 2]) {
      final raw = save(2).toJson()..['schemaVersion'] = version;
      raw['party'] = [
        {'name': 'Legacy'},
      ];
      SharedPreferences.setMockInitialValues({
        'lore_save_slot_2': jsonEncode(raw),
      });
      final result = await SaveManager.instance.readGame(2);
      expect(result.failure, isNull);
      expect(result.data!.party.single.name, 'Legacy');
    }
    for (final count in [0, 1, 5, 6]) {
      final raw = save(2).toJson();
      raw['party'] = (raw['party'] as List).take(count).toList();
      SharedPreferences.setMockInitialValues({
        'lore_save_slot_2': jsonEncode(raw),
      });
      expect(
        (await SaveManager.instance.readGame(2)).data!.party,
        hasLength(count),
      );
    }
  });
  test('party errors precede player validation and selected slot ignores metadata/trailing records', () async {
    for (final field in [
      'mapId',
      'playerX',
      'playerY',
      'gold',
      'food',
      'flags',
    ]) {
      final raw = save(3).toJson()
        ..remove(field)
        ..remove('party');
      SharedPreferences.setMockInitialValues({
        'lore_save_slot_3': jsonEncode(raw),
      });
      expect(
        (await SaveManager.instance.readGame(3)).failure!.fileName,
        'party3.dat',
      );
    }
    final raw = save(4).toJson()..['slot'] = 1;
    raw['party'] = [...(raw['party'] as List), 'ignored seventh record'];
    SharedPreferences.setMockInitialValues({
      'lore_save_slot_4': jsonEncode(raw),
    });
    final result = await SaveManager.instance.readGame(4);
    expect(result.failure, isNull);
    expect(result.data!.slot, 4);
    expect(result.data!.party, hasLength(6));
  });
  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    for (final kind in ['party', 'player']) {
      testWidgets('GameOver Load $kind failure never resumes caller: $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final row = (native['cases'] as List).singleWhere(
          (r) =>
              r['slot'] == 2 &&
              r['target'] == '${kind}2.dat' &&
              r['mode'] == 'truncated',
        );
        SharedPreferences.setMockInitialValues({
          'lore_save_slot_2': corrupt(Map.from(row))!,
        });
        final rng = _NoRandom();
        var halted = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MainGameScreen(
              initialSaveData: save(1, dead: true),
              encounterRandom: rng,
              onHalt: () => halted++,
            ),
          ),
        );
        final finder = find.byType(GameWidget<LoreGame>);
        await tester.runAsync(
          () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
        );
        final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
        tester
            .widget<DPadWidget>(find.byType(DPadWidget))
            .onDirectionPressed(1, 0);
        await tester.pump();
        await tester.pump();
        expect(find.byType(GameOverView), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('lore-window-press-any-key')),
        );
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('lore-select-3')).last);
        await tester.pump();
        await tester.pump();
        expect(find.byType(HaltView), findsOneWidget);
        expect(find.text('"${kind}2.dat" not found.'), findsOneWidget);
        expect(find.text('You need to CREATE CHARACTER.'), findsOneWidget);
        expect(halted, 1);
        expect(game.tryMove(1, 0), isFalse);
        expect(rng.calls, 0);
        expect(find.byType(GameOverView), findsNothing);
        expect(find.byType(DPadWidget), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    for (final row in native['cases']) {
      testWidgets(
        'actual Resume halts for ${row['target']}/${row['mode']}: $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final raw = corrupt(Map.from(row));
          SharedPreferences.setMockInitialValues({
            'lore_save_slot_${row['slot']}': ?raw,
          });
          final rng = _NoRandom();
          var halted = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: MainGameScreen(
                initialSaveData: save(1),
                encounterRandom: rng,
                onHalt: () => halted++,
              ),
            ),
          );
          final finder = find.byType(GameWidget<LoreGame>);
          await tester.runAsync(
            () => tester.state<GameWidgetState<LoreGame>>(finder).loaderFuture,
          );
          final game = tester.widget<GameWidget<LoreGame>>(finder).game!;
          Future<void> settle() async {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }

          await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
          await settle();
          await tester.tap(find.text(LoreMenuText.optionResume));
          await settle();
          await tester.tap(find.text(SaveManager.slotNames[row['slot'] - 1]));
          await settle();
          expect(find.byType(HaltView), findsOneWidget);
          expect(
            find.text('"${row['error']['name']}" not found.'),
            findsOneWidget,
          );
          expect(find.text('You need to CREATE CHARACTER.'), findsOneWidget);
          expect(find.byType(DPadWidget), findsNothing);
          expect(halted, 1);
          expect(rng.calls, 0);
          expect(game.tryMove(1, 0), isFalse);
          final position = (game.playerX, game.playerY);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await settle();
          expect((game.playerX, game.playerY), position);
          expect(halted, 1);
          final key = 'lore_save_slot_${row['slot']}';
          expect((await SharedPreferences.getInstance()).getString(key), raw);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
