import 'support/source_audio_platform.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/main.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/screens/main_game_screen.dart';
import 'package:lore/services/save_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _GateStore extends InMemorySharedPreferencesStore {
  _GateStore(super.values) : super.withData();
  final writes = <(String, String)>[];
  final pending = <Completer<bool>>[];
  @override
  Future<bool> setValue(String type, String key, Object value) {
    writes.add((key, value as String));
    final gate = Completer<bool>();
    pending.add(gate);
    return gate.future.then(
      (ok) => ok ? super.setValue(type, key, value) : false,
    );
  }
}

// LORECRET.PAS Last723/732/735: actual native cold-start six records/party,
// four durable writes before play, no stale map snapshots or quest aliases.
// Modern storage failure is observed, not claimed as native Erase/IOResult parity.
void main() {
  setUp(installSourceAudioPlatform);
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = jsonDecode(
    File('test/fixtures/dos_new_game.json').readAsStringSync(),
  );
  _GateStore install(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues({});
    final store = _GateStore(values);
    SharedPreferencesStorePlatform.instance = store;
    return store;
  }

  Future<void> tick() async {
    await Future<void>.delayed(Duration.zero);
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
  tearDown(() => SharedPreferences.setMockInitialValues({}));
  test(
    'four snapshots equal original Last, retain six slots and reset old saves',
    () async {
      final old = SaveData(
        slot: 1,
        slotName: 'Old',
        timestamp: DateTime.utc(1993),
        mapId: 27,
        mapTitle: 'Old',
        playerX: 90,
        playerY: 90,
        gold: 999999,
        food: 255,
        party: [PartyMember.createPreset(1)],
        flags: const {'etc32': 255, 'etc100': 255, 'quest': true},
        etc: const {'torchSteps': 255},
        mapTiles: const [99, 99],
        consumedScripts: const ['old'],
      );
      final store = install({
        for (var slot = 1; slot <= 4; slot++)
          'flutter.lore_save_slot_$slot': jsonEncode(old.toJson()),
      });
      final party = [
        for (final r in native['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(r)),
        PartyMember.createPreset(1)..name = 'Scratch',
      ];
      var completed = false;
      final saving = SaveManager.instance
          .writeNewGame(party, mapTitle: 'CASTLE LORE')
          .then((_) => completed = true);
      party.first.experience =
          2147483647; // No later mutation may leak into later slots.
      for (var slot = 1; slot <= 4; slot++) {
        await tick();
        expect(completed, false);
        expect(store.writes.length, slot);
        final (key, encoded) = store.writes.last;
        expect(key, 'flutter.lore_save_slot_$slot');
        final json = jsonDecode(encoded);
        expect(json['party'], native['records']);
        expect(
          [
            json['mapId'],
            json['playerX'],
            json['playerY'],
            json['food'],
            json['gold'],
          ],
          [
            native['party']['mapId'],
            native['party']['x'],
            native['party']['y'],
            native['party']['food'],
            native['party']['gold'],
          ],
        );
        for (var i = 1; i <= 100; i++) {
          expect(json['flags']['etc$i'] ?? 0, native['party']['etc'][i - 1]);
        }
        expect(json['flags'], isEmpty);
        expect(json['etc'], isEmpty);
        expect(json['mapTiles'], isEmpty);
        expect(json['consumedScripts'], isEmpty);
        store.pending.last.complete(true);
      }
      await saving;
      expect(completed, true);
      for (var slot = 1; slot <= 4; slot++) {
        final saved = (await SaveManager.instance.loadGame(slot))!;
        expect(saved.party.map((p) => p.toJson()).toList(), native['records']);
        expect(saved.mapTiles, isEmpty);
      }
    },
  );
  test(
    'failed durable write stops later slots instead of silently completing',
    () async {
      for (var fail = 1; fail <= 4; fail++) {
        final store = install({});
        final saving = SaveManager.instance.writeNewGame([
          PartyMember.createPreset(1),
        ], mapTitle: 'CASTLE LORE');
        final assertion = expectLater(saving, throwsStateError);
        for (var slot = 1; slot <= fail; slot++) {
          await tick();
          expect(store.writes.length, slot);
          store.pending.last.complete(slot != fail);
        }
        await assertion;
        await tick();
        expect(store.writes.length, fail);
      }
    },
  );
  testWidgets(
    'actual app waits for all writes and halts creation on storage failure',
    (tester) async {
      for (final failure in [false, true]) {
        final store = install({});
        await tester.pumpWidget(LoreApp(key: UniqueKey()));
        await tester.pump(const Duration(milliseconds: 53030));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const ValueKey('quick-start')));
        await tester.pump();
        expect(find.byType(MainGameScreen), findsNothing);
        expect(find.byKey(const ValueKey('creation-saving')), findsOneWidget);
        for (var slot = 1; slot <= 4; slot++) {
          expect(store.writes.length, slot);
          expect(find.byType(MainGameScreen), findsNothing);
          store.pending.last.complete(!failure);
          await tester.pump();
          if (failure) break;
        }
        await tester.pump(const Duration(milliseconds: 100));
        if (failure) {
          expect(
            find.byKey(const ValueKey('creation-storage-error')),
            findsOneWidget,
          );
          expect(find.byType(MainGameScreen), findsNothing);
          expect(store.writes.length, 1);
        } else {
          expect(find.byType(MainGameScreen), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
