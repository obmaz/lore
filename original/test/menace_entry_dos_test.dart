import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_encounter_logic.dart';
import 'package:lore/logic/lore_game_option.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/logic/town_logic.dart';
import 'package:lore/models/party_member.dart';

class _DifficultyIo implements LoreGameOptionIo {
  final answers = [1, 1, 1];
  @override
  Future<int> select(
    String title,
    List<String> items, {
    List<(int, String)> lines = const [],
  }) async => answers.removeAt(0);
  @override
  Future<void> message(List<(int, String)> lines) async =>
      throw StateError('Difficulty has no key wait');
  @override
  Future<void> load(int slot) async =>
      throw StateError('No load in difficulty');
  @override
  Future<void> save(int slot) async =>
      throw StateError('No save in difficulty');
  @override
  Future<void> gameOver() async =>
      throw StateError('No GameOver in difficulty');
  @override
  void displayCondition() =>
      throw StateError('No condition refresh in difficulty');
}

void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_menace_entry.json').readAsStringSync(),
  );
  test('actual victory reload recovers five unconscious members and consumes final food', () {
    final party = [
      for (final r in f['initial']['records']) PartyMember.fromJson(r),
    ];
    final random = LoreRandom(f['initial']['seed']);
    var food = f['initial']['partyRecord']['food'] as int;
    var torch = f['initial']['partyRecord']['etc'][0] as int;
    for (final rest in f['rests']) {
      final result = TownLogic.rest(party, food, torchSteps: torch);
      food = result.food;
      torch = result.torchSteps;
      expect(party.map((p) => p.toJson()).toList(), rest['wait']['records']);
      expect(
        (food, torch),
        (
          rest['wait']['partyRecord']['food'],
          rest['wait']['partyRecord']['etc'][0],
        ),
      );
      expect(random.seed, rest['wait']['seed']);
      expect(
        LoreEncounterLogic.shouldEncounter(1, TileCategory.walkable, random),
        false,
      );
      expect(random.seed, rest['afterKey']['seed']);
    }
    expect(food, 0);
    expect(party.every((p) => p.isBattleActive), true);
  });
  test(
    'source difficulty menu and 145 native moves preserve the same RNG stream',
    () async {
      final before = f['difficulty']['before'];
      final party = [
        for (final r in before['records']) PartyMember.fromJson(r),
      ];
      final etc = LorePartyEtc.fromBytes(
        List<int>.from(before['partyRecord']['etc']),
      );
      final io = _DifficultyIo();
      await LoreGameOption.run(io, party, etc);
      expect(io.answers, isEmpty);
      expect(
        etc.toBytes().toList(),
        f['difficulty']['after']['partyRecord']['etc'],
      );
      expect(
        party.map((p) => p.toJson()).toList(),
        f['difficulty']['after']['records'],
      );
      final random = LoreRandom(before['seed']);
      expect(
        LoreEncounterLogic.shouldEncounter(
          1,
          TileCategory.walkable,
          random,
          frequency: etc.read(7),
        ),
        false,
      );
      expect(random.seed, f['difficulty']['after']['seed']);
      for (final step in f['movement']) {
        expect(random.seed, step['seedBefore']);
        expect(
          LoreEncounterLogic.shouldEncounter(
            1,
            TileCategory.walkable,
            random,
            frequency: etc.read(7),
          ),
          false,
        );
        expect(random.seed, step['seedAfter']);
      }
      expect(random.seed, f['approachSave']['wait']['seed']);
    },
  );
}
