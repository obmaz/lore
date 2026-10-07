import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/script_world_reducer.dart';

import 'support/legacy_json_fixture_engine.dart';

void main() {
  test(
    'native Crab King completion bit precedes the color15 acknowledgement',
    () {
      final f = jsonDecode(
        File('test/fixtures/dos_evil_god_success.json').readAsStringSync(),
      );
      final inputs = [
        for (final s in f['segments'])
          for (final b in s['trace']) b.values.single,
      ];
      final won = inputs.singleWhere(
        (v) =>
            v['before']['partyRecord']['etc'][39] == 14 &&
            v['after']['partyRecord']['etc'][39] == 15,
      );
      final run = LoreSpecProcedures.map19(
        38,
        6,
        const ScriptContext(sourceEtc: {40: 14}),
        LegacyJsonFixtureEngine(),
      )!;
      final pending = run.continueAfterBattle();
      final progress = ScriptWorldReducer.applyProgress(
        const ScriptProgressState(flags: {}, quests: {}, sourceEtc: {40: 14}),
        pending.outcome,
      );
      expect(progress.sourceEtc[40], won['after']['partyRecord']['etc'][39]);
      expect(pending.hasPendingScene, isTrue);
      expect(pending.pendingScene!.lineColors, {0: 15, 1: 15, 2: 15});
      expect(f['saves']['sealed']['partyRecord']['etc'][39], 15);
      expect(
        won['after']['partyRecord']['gold'] -
            won['before']['partyRecord']['gold'],
        105917,
      );
    },
  );
}
