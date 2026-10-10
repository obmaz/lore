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

import 'support/source_audio_platform.dart';

class _Gate extends InMemorySharedPreferencesStore {
  _Gate(super.values) : super.withData();
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

// LORECRET.PAS Last740: record-before-Erase, native error message and Halt.
// Original Assign/Erase/IOResult helper instructions execute; DOS delete result
// is supplied at INT21h. JSON writes represent logical records/map attachments.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installSourceAudioPlatform);
  tearDown(() => SharedPreferences.setMockInitialValues({}));
  final data = jsonDecode(
    File('test/fixtures/dos_creation_erase.json').readAsStringSync(),
  );
  Map<String, dynamic> old(int slot, {bool map = true}) => SaveData(
    slot: slot,
    slotName: 'OLD',
    timestamp: DateTime.utc(1993),
    mapId: 27,
    mapTitle: 'OLD',
    playerX: 90,
    playerY: 90,
    gold: 999,
    food: 255,
    party: [PartyMember.createPreset(1)],
    flags: const {},
    mapTiles: map ? const [47] : const [],
    mapWidth: map ? 1 : null,
    mapHeight: map ? 1 : null,
  ).toJson();
  _Gate install(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues({});
    final store = _Gate(values);
    SharedPreferencesStorePlatform.instance = store;
    return store;
  }

  Future<void> tick() => Future<void>.delayed(Duration.zero);
  for (final row in data['cases'] as List) {
    test(
      'native erase slot${row['slot']} exists${row['exists']} IO${row['error']}',
      () async {
        final slot = row['slot'] as int;
        final exists = row['exists'] as bool;
        final failed = exists && row['error'] != 0;
        final store = install({
          for (var i = 1; i <= 4; i++)
            'flutter.lore_save_slot_$i': jsonEncode(
              old(i, map: exists && i == slot),
            ),
        });
        final saving = SaveManager.instance.writeNewGame([
          PartyMember.createPreset(3),
        ], mapTitle: 'TOWN1');
        final assertion = expectLater(
          saving,
          failed
              ? throwsA(
                  isA<LoreCreationMapEraseFailure>().having(
                    (e) => e.slot,
                    'slot',
                    slot,
                  ),
                )
              : completes,
        );
        var writes = 0;
        for (var i = 1; i <= 4; i++) {
          await tick();
          expect(store.writes.length, ++writes);
          final record = jsonDecode(store.writes.last.$2);
          expect(record['mapId'], 6);
          expect(record['gold'], 2000);
          expect(record['party'], hasLength(6));
          expect(record['mapTiles'], exists && i == slot ? [47] : isEmpty);
          store.pending.last.complete(true);
          if (exists && i == slot) {
            await tick();
            expect(store.writes.length, ++writes);
            expect(jsonDecode(store.writes.last.$2)['mapTiles'], isEmpty);
            store.pending.last.complete(!failed);
            if (failed) break;
          }
        }
        await assertion;
        await tick();
        expect(store.writes.length, writes);
        final saved = (await SaveManager.instance.loadGame(slot))!;
        expect(saved.gold, 2000);
        expect(saved.mapTiles, failed ? [47] : isEmpty);
        if (failed) {
          final nativeLine = (row['trace'] as List).singleWhere(
            (op) => op[0] == 'writeLine',
          )[1];
          expect(LoreCreationMapEraseFailure.message, nativeLine);
          for (var i = slot + 1; i <= 4; i++) {
            expect((await SaveManager.instance.loadGame(i))!.gold, 999);
          }
        }
      },
    );
  }
  test('thrown map reset IO failure also retains committed records and stops later slots', () async {
    final store = install({'flutter.lore_save_slot_1': jsonEncode(old(1))});
    final saving = SaveManager.instance.writeNewGame([
      PartyMember.createPreset(3),
    ], mapTitle: 'TOWN1');
    final failure = expectLater(
      saving,
      throwsA(
        isA<LoreCreationMapEraseFailure>().having(
          (e) => e.cause,
          'cause',
          isA<FileSystemException>(),
        ),
      ),
    );
    await tick();
    store.pending.last.complete(true);
    await tick();
    store.pending.last.completeError(
      const FileSystemException('map reset denied'),
    );
    await failure;
    expect(store.writes, hasLength(2));
    final saved = (await SaveManager.instance.loadGame(1))!;
    expect(saved.gold, 2000);
    expect(saved.mapTiles, [47]);
  });
  testWidgets(
    'actual erase error clears to source red text and never starts play',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final channel in [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
      ]) {
        messenger.setMockMethodCallHandler(
          MethodChannel(channel),
          (_) async => 1,
        );
      }
      messenger.setMockStreamHandler(
        const EventChannel('xyz.luan/audioplayers.global/events'),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
      final store = install({'flutter.lore_save_slot_1': jsonEncode(old(1))});
      await tester.pumpWidget(const LoreApp());
      await tester.pump(const Duration(milliseconds: 53030));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('quick-start')));
      await tester.pump();
      expect(store.writes, hasLength(1));
      store.pending.last.complete(true);
      await tester.pump();
      expect(store.writes, hasLength(2));
      store.pending.last.complete(false);
      await tester.pump();
      await tester.pump();
      final error = find.byKey(const ValueKey('creation-storage-error'));
      expect(error, findsOneWidget);
      expect(
        tester.widget<Text>(error).data,
        LoreCreationMapEraseFailure.message,
      );
      expect(tester.widget<Text>(error).style!.color, const Color(0xFFFF5555));
      expect(find.byType(MainGameScreen), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(store.writes, hasLength(2));
      expect(find.byType(MainGameScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
