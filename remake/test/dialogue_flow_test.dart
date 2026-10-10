import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_dialogue_scripts.dart';
import 'package:lore/logic/lore_dialogue_flow.dart';
import 'package:lore/logic/lore_source_memory.dart';

import 'support/talk_mode_io.dart';

class _GatedIo extends TalkModeIo {
  final pageGate = Completer<void>();
  final choiceGate = Completer<int>();
  @override
  Future<void> pressAnyKey() => pageGate.future;
  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  }) => choiceGate.future;
}

void main() {
  test('registered source definitions have valid links and choices', () {
    LoreDialogueScripts.town.validate();
    LoreDialogueScripts.waterLord.validate();
  });

  test(
    'conditions and writes use live source state after a blocked page',
    () async {
      final io = _GatedIo();
      final etc = LorePartyEtc();
      final script = LoreDialogueScript(
        id: 'live-state',
        source: 'test',
        root: DialogueSequence([
          const DialogueLine(7, 'first'),
          const DialoguePage(),
          DialogueWhen(
            (state) => state.etc.read(50) == 16,
            DialogueSequence([
              const DialogueLine(7, 'changed while waiting'),
              DialogueWriteByte(50, (state) => state.etc.read(50) | 1),
            ]),
          ),
        ]),
      );
      final done = script.run(DialogueContext(party: [], etc: etc, io: io));
      expect(io.lines, [(7, 'first')]);
      expect(etc.read(50), 0);
      etc[50] = 16;
      io.pageGate.complete();
      await done;
      expect(io.lines.last, (7, 'changed while waiting'));
      expect(etc.read(50), 17);
    },
  );

  for (final selected in [0, 1, 2]) {
    test(
      'choices run only the selected branch and stop on cancellation $selected',
      () async {
        final io = _GatedIo();
        final etc = LorePartyEtc();
        final script = LoreDialogueScript(
          id: 'choice',
          source: 'test',
          root: DialogueSequence([
            DialogueChoice(
              title: '',
              items: const ['accept', 'refuse'],
              branches: {
                1: DialogueWriteByte(50, (_) => 1),
                2: const DialogueEnd(),
              },
            ),
            const DialogueLine(7, 'after accepting'),
          ]),
        );
        final done = script.run(DialogueContext(party: [], etc: etc, io: io));
        expect(etc.read(50), 0);
        expect(io.lines, isEmpty);
        io.choiceGate.complete(selected);
        await done;
        expect(etc.read(50), selected == 1 ? 1 : 0);
        expect(io.lines, selected == 1 ? [(7, 'after accepting')] : isEmpty);
      },
    );
  }

  for (final next in [
    {0: 2},
    {0: 1, 1: 0},
  ]) {
    test('broken dialogue graph $next fails before rewards or text', () async {
      final io = TalkModeIo();
      final etc = LorePartyEtc();
      final script = LoreDialogueScript(
        id: 'broken',
        source: 'test',
        root: DialogueSequence([
          const DialogueLine(7, 'must not appear'),
          DialogueQuest(
            id: 'broken',
            byte: 10,
            next: next,
            stages: {
              0: DialogueWriteByte(10, (_) => 1),
              1: DialogueWriteByte(10, (_) => 0),
            },
          ),
        ]),
      );
      await expectLater(
        script.run(DialogueContext(party: [], etc: etc, io: io)),
        throwsStateError,
      );
      expect(io.lines, isEmpty);
      expect(etc.read(10), 0);
    });
  }
}
