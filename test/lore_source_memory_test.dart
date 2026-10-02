import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/logic/lore_source_memory.dart';

void main() {
  // LORESUB.PAS:1760-1761: Load accepts encounter 1..3 and maxenemy 3..7.
  test('legacy active Boolean must not truncate a saved timer to one step', () {
    final manager = LoreDialogueManager.instance;
    addTearDown(() => manager.loadSaveFlags({}));
    manager.loadSaveFlags(
      {'etc3': true, 'etc4': 0, 'etc7': 3},
      fieldCounters: {
        'swampWalkSteps': 29,
        'levitateSteps': 17,
        'encounterFrequency': 1,
      },
    );
    expect(manager.partyEtc.read(3), 29);
    expect(manager.partyEtc.read(4), 0);
    expect(manager.partyEtc.read(7), 3);
    expect(manager.partyEtc.read(8), 5);
    final saved =
        jsonDecode(jsonEncode(manager.getSaveFlags())) as Map<String, dynamic>;
    manager.loadFlags(saved, fieldCounters: {'swampWalkSteps': 1});
    expect(manager.partyEtc.read(3), 29);
  });
  test('field timers import missing legacy values; raw zero and current settings win', () {
    final etc = LorePartyEtc({1: 0, 3: 250, 7: 3, 8: 7});
    etc.restoreFieldCounters({
      'torchSteps': 255,
      'waterWalkSteps': 19,
      'swampWalkSteps': 1,
      'levitateSteps': 8,
      'mindReadCount': 11,
      'encounterFrequency': 1,
      'maxEnemies': 3,
    });
    expect(etc.fieldCounters(), {
      'torchSteps': 0,
      'waterWalkSteps': 19,
      'swampWalkSteps': 250,
      'levitateSteps': 8,
      'mindReadCount': 11,
      'encounterFrequency': 3,
      'maxEnemies': 7,
    });
    etc[3] = etc.read(3) - 1;
    expect(etc.fieldCounters()['swampWalkSteps'], 249);
    for (var byte = 0; byte <= 255; byte++) {
      final restored = LorePartyEtc({7: byte, 8: byte});
      restored.restoreFieldCounters({});
      expect(restored.read(7), byte >= 1 && byte <= 3 ? byte : 2);
      expect(restored.read(8), byte >= 3 && byte <= 7 ? byte : 5);
    }
  });

  test('legacy room flags migrate once; raw zero beats aliases through save and reload', () {
    final manager = LoreDialogueManager.instance;
    addTearDown(() => manager.loadSaveFlags({}));
    // A nonzero encoded room is not proof that its low seal bit is set.
    manager.loadSaveFlags({'etc40': true, 'evilSealRoom3': true});
    expect(manager.partyEtc.read(40), 6);
    manager.loadSaveFlags({
      'etc40': true,
      'evilSealRoom3': true,
      'etc40_bit1': true,
    });
    expect(manager.partyEtc.read(40), 7);
    manager.loadSaveFlags({
      'scriptFlags': {'evilSealRoom3': true, 'evilSealRoomCleared': true},
    });
    expect(manager.partyEtc.read(40), 7);
    manager.loadSaveFlags({
      'etc40': 0,
      'scriptFlags': {
        'evilSealRoom3': true,
        'evilSealRoomCleared': true,
        'etc40_bit1': true,
      },
    });
    expect(manager.partyEtc.read(40), 0);
    expect(manager.getFlagsCopy()['evilSealRoom3'], isFalse);
    expect(manager.getFlagsCopy()['evilSealRoomCleared'], isFalse);
    expect(manager.getFlagsCopy()['etc40_bit1'], isFalse);
    manager.loadSaveFlags(
      jsonDecode(jsonEncode(manager.getSaveFlags())) as Map<String, dynamic>,
    );
    expect(manager.partyEtc.read(40), 0);
  });

  test(
    'Pascal storage widths preserve unsigned bytes and signed boundaries',
    () {
      expect([LorePascal.byte(-1), LorePascal.byte(256)], [255, 0]);
      expect([LorePascal.word(-1), LorePascal.word(65536)], [65535, 0]);
      expect(
        [
          LorePascal.integer(32767),
          LorePascal.integer(32768),
          LorePascal.integer(-32769),
        ],
        [32767, -32768, 32767],
      );
      expect(
        [
          LorePascal.longint(2147483647),
          LorePascal.longint(2147483648),
          LorePascal.longint(-2147483649),
        ],
        [2147483647, -2147483648, 2147483647],
      );
    },
  );

  test('Pascal div/mod keep negative remainder semantics', () {
    for (final (a, b, quotient, remainder) in const [
      (7, 3, 2, 1),
      (-7, 3, -2, -1),
      (7, -3, -2, 1),
      (-7, -3, 2, -1),
    ]) {
      expect(LorePascal.div(a, b), quotient);
      expect(LorePascal.mod(a, b), remainder);
    }
    expect(() => LorePascal.div(1, 0), throwsA(isA<UnsupportedError>()));
  });

  test('etc uses all 100 source slots and preserves unrelated bits', () {
    final etc = LorePartyEtc();
    expect(etc.read(1), 0);
    expect(etc.read(100), 0);
    for (var value = 0; value < 256; value++) {
      for (var bit = 1; bit <= 8; bit++) {
        etc[100] = value;
        etc.setBit(100, bit);
        expect(etc.read(100), value | (1 << (bit - 1)));
        etc.setBit(100, bit, false);
        expect(etc.read(100), value & ~(1 << (bit - 1)));
      }
    }
    etc[1] = -1;
    etc[100] = 256;
    expect(etc.toBytes().length, 100);
    expect(etc.read(1), 255);
    expect(etc.read(100), 0);
    expect(etc.containsKey(100), isTrue);
    expect(() => etc[0] = 1, throwsRangeError);
    expect(() => etc.read(101), throwsRangeError);
    expect(() => etc.setBit(1, 9), throwsRangeError);
    expect(() => LorePartyEtc.fromBytes([1]), throwsFormatException);
  });

  test('all 100 raw etc bytes survive the existing save adapter', () {
    final manager = LoreDialogueManager.instance;
    addTearDown(() => manager.loadSaveFlags({}));
    final bytes = [for (var i = 0; i < 100; i++) (i * 73) & 255];
    manager.partyEtc
      ..clear()
      ..addAll(LorePartyEtc.fromBytes(bytes));
    final saved =
        jsonDecode(jsonEncode(manager.getSaveFlags())) as Map<String, dynamic>;
    manager.loadSaveFlags({});
    manager.loadSaveFlags(saved);
    expect(manager.partyEtc.toBytes(), bytes);
    expect(manager.lordAhnQuestStep, bytes[9]);
    expect(manager.lastditchQuestStep, bytes[12]);
    expect(manager.gaiaQuestStep, bytes[13]);
    expect(manager.waterFieldQuestStep, bytes[14]);
  });

  test('quest aliases read and write the same source bytes', () {
    final manager = LoreDialogueManager.instance;
    manager.loadSaveFlags({});
    addTearDown(() => manager.loadSaveFlags({}));
    manager.lordAhnQuestStep = 3;
    expect(manager.partyEtc.read(10), 3);
    manager.partyEtc[10] = 4;
    expect(manager.questSteps['lordahn'], 4);
    manager.applyQuestStep('lastditch', set: 2);
    expect(manager.partyEtc.read(13), 2);
    manager.partyEtc[14] = 5;
    expect(manager.gaiaQuestStep, 5);
    manager.waterFieldQuestStep = 3;
    expect(manager.partyEtc.read(15), 3);
    manager.loadSaveFlags({
      'lordAhnQuestStep': 6,
      'etc10': 0,
      'etc10_bit1': true,
    });
    expect(manager.lordAhnQuestStep, 0);
    expect(manager.partyEtc.read(10), 0);
  });

  test('raw zero wins over old flags and context snapshots cannot drift', () {
    final etc = LorePartyEtc({45: 0});
    final context = ScriptContext(
      sourceEtc: etc.snapshot(),
      flags: const {'etc45_bit7', 'etc45_bit8'},
    );
    etc[45] = 255;
    expect(context.etcValue(45), 0);
    expect(const ScriptContext(flags: {'etc45_bit8'}).etcValue(45), 128);
    expect(() => context.etcValue(0), throwsRangeError);
  });
}
