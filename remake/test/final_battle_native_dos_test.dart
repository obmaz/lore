import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/field_magic_logic.dart';
import 'package:lore/logic/lore_game_option.dart';
import 'package:lore/logic/lore_transient_slots.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/models/party_member.dart';
import 'package:lore/models/monster.dart';

import 'wivern_battle_dos_test.dart' show enemyRecord;

void main() {
  test('native final seven-enemy complete enemy-first phase matches all records and RNG', () {
    final f = jsonDecode(
      File('test/fixtures/dos_final_battle_phase.json').readAsStringSync(),
    );
    final s = f['initial'], r = LoreRandom(s['seed']);
    final b = LoreBattle(
      party: [
        for (final p in s['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(p)),
      ],
      enemy: [for (final id in f['battleEnemyIds']) Monster.create(id)],
      random: r,
      print: (_, _) {},
    );
    b.enemyPhase();
    expect(r.seed, f['closed']['seed']);
    expect(b.party.map((p) => p.toJson()).toList(), f['closed']['records']);
    expect(b.enemy.map(enemyRecord).toList(), f['closed']['enemyRecords']);
  });
  test('native final order swap preserves all six 55-byte records and unsaved player7', () {
    final f = jsonDecode(
      File('test/fixtures/dos_final_party_order.json').readAsStringSync(),
    );
    final party = [
      for (final p in f['initial']['records'])
        PartyMember.fromJson(Map<String, dynamic>.from(p)),
    ];
    final slots = LoreTransientSlots();
    LoreGameOption.swap(party, 5, 2, slots: slots);
    expect(party.map((p) => p.toJson()).toList(), f['closed']['records']);
    expect(slots.seventhPlayer.toJson(), f['slot7']['record']);
  });
  test('native entire final fight, immediate whole cures, Neo death and escape match every field/RNG', () {
    final f = jsonDecode(
      File('test/fixtures/dos_final_complete_battle.json').readAsStringSync(),
    );
    final random = LoreRandom(f['entrySeed']);
    final b = LoreBattle(
      party: [
        for (final p in f['initial']['records'])
          PartyMember.fromJson(Map<String, dynamic>.from(p)),
      ],
      enemy: [for (final id in f['battleEnemyIds']) Monster.create(id)],
      random: random,
      print: (_, _) {},
    );
    void check(dynamic state, String label) {
      expect(random.seed, state['seed'], reason: '$label seed');
      expect(
        b.party.map((p) => p.toJson()).toList(),
        state['records'],
        reason: '$label party',
      );
      expect(
        b.enemy.map(enemyRecord).toList(),
        state['enemyRecords'],
        reason: '$label enemies',
      );
    }

    b.enemyPhase();
    check(f['firstClosed'], 'first enemy phase');
    for (final step in f['steps']) {
      if (step.containsKey('cure')) {
        final c = step['cure'];
        check(c['before'], c['capture']);
        final caster = b.party[c['caster'] - 1],
            target = b.party[c['target'] - 1];
        expect(c['spell'], 6);
        FieldMagicLogic.consciousOne(caster, target, inBattle: true);
        FieldMagicLogic.cureOne(caster, target, inBattle: true);
        FieldMagicLogic.healOne(caster, target, inBattle: true);
        check(c['after'], c['capture']);
      } else {
        final t = step['turn'];
        check(t['before'], t['capture']);
        for (var i = 1; i <= 6; i++) {
          b.battle[i] = [0, ...List<int>.from(t['commands'][i - 1])];
        }
        var escaped = false;
        for (var i = 1; i <= 6; i++) {
          if (b.executePerson(i)) {
            escaped = true;
            break;
          }
        }
        expect(escaped, t['runAway'], reason: t['capture']);
        if (!escaped) b.enemyPhase();
        check(t['closed'], t['capture']);
      }
    }
    expect(b.enemy[6].isDead, isTrue);
    expect(b.enemy.take(6).every((e) => !e.isDead && !e.isUnconscious), isTrue);
    expect(b.party[5].hp, 15);
  });
  test('native dead Neo escape admits farewell and only its acknowledgement enters End_Demo', () {
    final trace = jsonDecode(
      File('test/fixtures/dos_final_continuation.json').readAsStringSync(),
    );
    final fight = jsonDecode(
      File('test/fixtures/dos_final_complete_battle.json').readAsStringSync(),
    );
    final ending = jsonDecode(
      File('test/fixtures/dos_final_ending_completion.json').readAsStringSync(),
    );
    final last = fight['steps'].last['turn']['closed'];
    expect(last['partyRecord']['etc'][5], 2);
    expect(
      trace['saves']['orderReady']['files']['PLAYER1.DAT']['hex'],
      fight['initial']['players'],
    );
    var run = LoreSpecProcedures.map26(
      25,
      14,
      const ScriptContext(tileAtPlayer: 0),
      LoreScriptEngine(),
    )!.acknowledgeScene();
    run = run.continueAfterRunAway(
      defeatedEnemySlots: {
        for (var i = 0; i < 7; i++)
          if (last['enemyRecords'][i]['isDead']) i + 1,
      },
    );
    expect(run.hasPendingScene, isTrue);
    expect(run.outcome.events.any((e) => e.kind == 'endDemo'), isFalse);
    expect(run.pendingScene!.lines.length, 17);
    expect(
      run.acknowledgeScene().outcome.events.any((e) => e.kind == 'endDemo'),
      isTrue,
    );
    expect(ending['staff']['after']['sharedC'], 255);
    expect(ending['halt']['keys'], ['Escape']);
  });
}
