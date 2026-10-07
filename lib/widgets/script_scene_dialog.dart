import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/lore_script.dart';
import 'lore_select_view.dart';
import '../logic/lore_source_speech.dart';
import '../models/monster.dart';
import '../theme/retro_theme.dart';

/// Native display/acknowledgement adapter for source PressAnyKey and talk('').
class ScriptSceneDialog extends StatelessWidget {
  final ScriptScene scene;
  final List<(int, String)> prefixLines;
  final List<Monster> actors;
  final ValueChanged<LogicalKeyboardKey>? onKeyAcknowledged;

  const ScriptSceneDialog({
    super.key,
    required this.scene,
    this.prefixLines = const [],
    required this.actors,
    this.onKeyAcknowledged,
  });

  @override
  Widget build(BuildContext context) => LoreMessageDialog(
    acknowledgementKey: const ValueKey('script-scene-continue'),
    onKeyAcknowledged: onKeyAcknowledged,
    lines: [
      ...prefixLines,
      for (final line in scene.lines)
        (LoreSourceSpeech.lines[line]?.color ?? 7, line),
      if (scene.lines.isNotEmpty &&
          LoreSourceSpeech.lines[scene.lines.last]?.blank == true)
        (7, ''),
    ],
    leading: [
      for (final actor in actors)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            actor.name,
            style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan),
          ),
        ),
    ],
  );
}
