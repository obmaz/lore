import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/widgets/script_scene_dialog.dart';

void main() {
  for (final key in [
    null,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.keyA,
  ]) {
    testWidgets(
      'scene acknowledgement via ${key?.keyLabel ?? 'touch'} resumes once without a choice',
      (tester) async {
        var acknowledgements = 0;
        const scene = ScriptScene(
          title: '안내',
          actors: [68, 67],
          lines: ['순서대로 전달되는 안내 대사'],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => ScriptSceneDialog(
                      scene: scene,
                      actors: [Monster.create(68), Monster.create(67)],
                    ),
                  );
                  acknowledgements++;
                },
                child: const Text('열기'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(find.text('순서대로 전달되는 안내 대사'), findsOneWidget);
        expect(find.text(Monster.create(68).name), findsOneWidget);
        expect(find.text(Monster.create(67).name), findsOneWidget);
        expect(acknowledgements, 0);
        if (key == null) {
          await tester.tap(find.byKey(const ValueKey('script-scene-continue')));
        } else {
          await tester.sendKeyEvent(key);
        }
        await tester.pumpAndSettle();
        expect(find.byType(ScriptSceneDialog), findsNothing);
        expect(acknowledgements, 1);
      },
    );
  }
}
