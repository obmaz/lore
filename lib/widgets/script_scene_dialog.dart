import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/lore_script.dart';
import '../logic/lore_menu_text.dart';
import '../models/monster.dart';
import '../theme/retro_theme.dart';

/// Native display/acknowledgement adapter for source PressAnyKey and talk('').
class ScriptSceneDialog extends StatelessWidget {
  final ScriptScene scene;
  final List<Monster> actors;

  const ScriptSceneDialog({
    super.key,
    required this.scene,
    required this.actors,
  });

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: AlertDialog(
      backgroundColor: RetroTheme.black,
      title: Text(scene.title, style: RetroTheme.headerFont),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final actor in actors)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  actor.name,
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.lightCyan,
                  ),
                ),
              ),
            Text(scene.lines.join('\n'), style: RetroTheme.dosFont),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('script-scene-continue'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(LoreMenuText.viewCharPressKey, style: RetroTheme.dosFont),
        ),
      ],
    ),
  );
}
