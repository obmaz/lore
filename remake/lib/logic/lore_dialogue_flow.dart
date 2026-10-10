import '../data/lore_script.dart';
import '../models/party_member.dart';
import 'lore_dialogue_io.dart';
import 'lore_source_coordinates.dart';
import 'lore_source_memory.dart';

/// Per-interaction state. Scripts never snapshot future quest conditions or
/// enqueue rewards before the player acknowledges the preceding source page.
class DialogueContext {
  DialogueContext({
    required this.party,
    required this.etc,
    required this.io,
    this.mapId = 0,
    this.targetX = 0,
    this.targetY = 0,
    this.x = 0,
    this.y = 0,
    this.roll,
    this.continuous = false,
  });

  final List<PartyMember> party;
  final LorePartyEtc etc;
  final LoreTalkIo io;
  final int mapId, targetX, targetY, x, y;
  final int Function(int)? roll;
  final bool continuous;
  String text = '';
  String answer = '';
  bool stopped = false;

  LoreTalkModeIo get talkIo => io as LoreTalkModeIo;
  bool at(int ax, int ay) =>
      LoreSourceCoordinates.at(x, y, targetX - x, targetY - y, ax, ay);
}

/// A source-owned Dart definition, not executable JSON or screen callbacks.
class LoreDialogueScript {
  LoreDialogueScript({
    required this.id,
    required this.source,
    required this.root,
  });
  final String id;
  final String source;
  final DialogueNode root;
  bool _validated = false;

  /// Reject broken links before any dialogue or reward is executed.
  void validate() {
    if (_validated) return;
    final seen = <DialogueNode>{};
    void visit(DialogueNode node) {
      if (!seen.add(node)) return;
      switch (node) {
        case DialogueSequence():
          node.steps.forEach(visit);
        case DialogueWhen():
          visit(node.thenSteps);
          if (node.otherwise case final other?) visit(other);
        case DialogueCases():
          node.cases.values.forEach(visit);
          if (node.otherwise case final other?) visit(other);
        case DialogueQuest():
          LorePartyEtc.checkIndex(node.byte);
          for (final stage in node.stages.keys) {
            RangeError.checkValueInInterval(stage, 0, 255, 'dialogue stage');
          }
          for (final edge in node.next.entries) {
            if (!node.stages.containsKey(edge.key) ||
                !node.stages.containsKey(edge.value)) {
              throw StateError(
                'Undefined dialogue stage: ${node.id}/${edge.key} -> ${edge.value}',
              );
            }
            final path = <int>{};
            int? current = edge.key;
            while (current != null) {
              if (!path.add(current)) {
                throw StateError('Cyclic dialogue: ${node.id}/$current');
              }
              current = node.next[current];
            }
          }
          node.stages.values.forEach(visit);
        case DialogueChoice():
          for (final choice in node.branches.keys) {
            RangeError.checkValueInInterval(
              choice,
              0,
              node.items.length,
              'dialogue choice',
            );
          }
          node.branches.values.forEach(visit);
          visit(node.otherwise);
        case DialogueCall():
          visit(node.script().root);
        default:
          break;
      }
    }

    visit(root);
    _validated = true;
  }

  Future<void> run(DialogueContext state) async {
    validate();
    final pending = root.execute(state);
    if (pending != null) await pending;
  }
}

sealed class DialogueNode {
  const DialogueNode();
  // Synchronous statements remain synchronous, including pre-wait rewards.
  Future<void>? execute(DialogueContext state);
}

class DialogueSequence extends DialogueNode {
  const DialogueSequence(this.steps);
  final List<DialogueNode> steps;
  @override
  Future<void>? execute(DialogueContext state) => _executeFrom(state, 0);

  Future<void>? _executeFrom(DialogueContext state, int start) {
    for (var i = start; i < steps.length; i++) {
      if (state.stopped) return null;
      final pending = steps[i].execute(state);
      if (pending != null) return _resume(state, pending, i + 1);
    }
    return null;
  }

  Future<void> _resume(
    DialogueContext state,
    Future<void> pending,
    int start,
  ) async {
    await pending;
    final tail = _executeFrom(state, start);
    if (tail != null) await tail;
  }
}

class DialogueWhen extends DialogueNode {
  const DialogueWhen(this.condition, this.thenSteps, {this.otherwise});
  final bool Function(DialogueContext) condition;
  final DialogueNode thenSteps;
  final DialogueNode? otherwise;
  @override
  Future<void>? execute(DialogueContext state) =>
      (condition(state) ? thenSteps : otherwise)?.execute(state);
}

class DialogueCases extends DialogueNode {
  const DialogueCases(this.value, this.cases, {this.otherwise});
  final int Function(DialogueContext) value;
  final Map<int, DialogueNode> cases;
  final DialogueNode? otherwise;
  @override
  Future<void>? execute(DialogueContext state) =>
      (cases[value(state)] ?? otherwise)?.execute(state);
}

/// Explicit dialogue-only edges, separate from quest completion. Unlisted
/// stages end normally; the game must meet their original conditions first.
class DialogueQuest extends DialogueNode {
  const DialogueQuest({
    required this.id,
    required this.byte,
    required this.stages,
    this.next = const {},
  });
  final String id;
  final int byte;
  final Map<int, DialogueNode> stages;
  final Map<int, int> next;
  @override
  Future<void> execute(DialogueContext state) async {
    final visited = <int>{};
    var stage = state.etc.read(byte);
    while (!state.stopped) {
      final node = stages[stage];
      if (node == null) return; // Source CASE has no implicit fallback.
      if (!visited.add(stage)) throw StateError('Cyclic dialogue: $id/$stage');
      final pending = node.execute(state);
      if (pending != null) await pending;
      final target = next[stage];
      if (state.stopped ||
          !state.continuous ||
          target == null ||
          state.etc.read(byte) != target) {
        return;
      }
      stage = target;
    }
  }
}

class DialogueLine extends DialogueNode {
  const DialogueLine(this.color, String text) : literal = text, value = null;
  const DialogueLine.value(this.color, this.value) : literal = null;
  final int color;
  final String? literal;
  final String Function(DialogueContext)? value;
  @override
  Future<void>? execute(DialogueContext state) {
    state.io.print(color, literal ?? value!(state));
    return null;
  }
}

class DialogueHighlight extends DialogueNode {
  const DialogueHighlight(
    this.color,
    this.highlight,
    this.before,
    this.word,
    this.after,
  );
  final int color, highlight;
  final String before, word, after;
  @override
  Future<void>? execute(DialogueContext state) {
    state.talkIo.cprint(color, highlight, before, word, after);
    return null;
  }
}

class DialoguePage extends DialogueNode {
  const DialoguePage();
  @override
  Future<void> execute(DialogueContext state) async {
    await state.io.pressAnyKey();
    if (!state.io.isOpen) state.stopped = true;
  }
}

class DialogueEnd extends DialogueNode {
  const DialogueEnd();
  @override
  Future<void>? execute(DialogueContext state) {
    state.stopped = true;
    return null;
  }
}

class DialogueClear extends DialogueNode {
  const DialogueClear();
  @override
  Future<void>? execute(DialogueContext state) {
    state.io.clear();
    return null;
  }
}

class DialogueRefresh extends DialogueNode {
  const DialogueRefresh();
  @override
  Future<void>? execute(DialogueContext state) {
    state.talkIo.refresh();
    return null;
  }
}

class DialogueRemember extends DialogueNode {
  const DialogueRemember(this.value);
  final String Function(DialogueContext) value;
  @override
  Future<void>? execute(DialogueContext state) {
    state.text = value(state);
    return null;
  }
}

class DialogueWriteByte extends DialogueNode {
  const DialogueWriteByte(this.index, this.value);
  final int index;
  final int Function(DialogueContext) value;
  @override
  Future<void>? execute(DialogueContext state) {
    state.etc[index] = value(state);
    return null;
  }
}

class DialogueExperience extends DialogueNode {
  const DialogueExperience(this.amount);
  final int amount;
  @override
  Future<void>? execute(DialogueContext state) {
    for (final member in state.party.take(6)) {
      if (member.name.isNotEmpty) {
        member.experience = LorePascal.longint(member.experience + amount);
      }
    }
    return null;
  }
}

class DialogueTile extends DialogueNode {
  const DialogueTile(this.value);
  final (int, int, int) Function(DialogueContext) value;
  @override
  Future<void>? execute(DialogueContext state) {
    final (x, y, tile) = value(state);
    state.talkIo.setTile(x, y, tile);
    return null;
  }
}

class DialogueTiles extends DialogueNode {
  const DialogueTiles(this.x, this.y, this.lastX, this.lastY, this.tile);
  final int x, y, lastX, lastY, tile;
  @override
  Future<void>? execute(DialogueContext state) {
    for (var tx = x; tx <= lastX; tx++) {
      for (var ty = y; ty <= lastY; ty++) {
        state.talkIo.setTile(tx, ty, tile);
      }
    }
    return null;
  }
}

class DialogueLog extends DialogueNode {
  const DialogueLog(this.color, this.text);
  final int color;
  final String text;
  @override
  Future<void>? execute(DialogueContext state) {
    state.talkIo.message(color, text);
    return null;
  }
}

class DialogueRecruit extends DialogueNode {
  const DialogueRecruit(this.procedure);
  final LoreScript procedure;
  @override
  Future<void> execute(DialogueContext state) async {
    await state.talkIo.recruit(procedure);
    if (!state.io.isOpen) state.stopped = true;
  }
}

class DialogueChallenge extends DialogueNode {
  const DialogueChallenge();
  @override
  Future<void> execute(DialogueContext state) async {
    state.answer = await state.talkIo.challengeKey();
    if (!state.io.isOpen) state.stopped = true;
  }
}

class DialogueChoice extends DialogueNode {
  const DialogueChoice({
    required this.title,
    required this.items,
    required this.branches,
    this.otherwise = const DialogueEnd(),
    this.clean = false,
  });
  final String title;
  final List<String> items;
  final Map<int, DialogueNode> branches;
  final DialogueNode otherwise;
  final bool clean;
  @override
  Future<void> execute(DialogueContext state) async {
    final selected = await state.io.select(title, items, clean: clean);
    if (!state.io.isOpen) {
      state.stopped = true;
      return;
    }
    final pending = (branches[selected] ?? otherwise).execute(state);
    if (pending != null) await pending;
  }
}

class DialogueBlink extends DialogueNode {
  const DialogueBlink();
  @override
  Future<void> execute(DialogueContext state) async {
    await state.talkIo.blinkRemains(
      state.targetX - state.x,
      state.targetY - state.y,
    );
    if (!state.io.isOpen) state.stopped = true;
  }
}

class DialogueCall extends DialogueNode {
  const DialogueCall(this.script);
  final LoreDialogueScript Function() script;
  @override
  Future<void> execute(DialogueContext state) => script().run(state);
}
