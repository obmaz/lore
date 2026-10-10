import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/retro_theme.dart';
import '../widgets/lore_select_view.dart';
import '../widgets/lore_creation_animation.dart';

/// LOREHELP.PAS Title_Menu CLI help: three Text_Fading calls then UnSound/Halt.
/// KeyPressed skips subsequent delays without consuming the pending key.
class LoreHelpScreen extends StatefulWidget {
  const LoreHelpScreen({super.key, required this.onHalt});
  final VoidCallback onHalt;
  static const fadingLines = [
    'The Codex of Another Lore  Volume #1',
    '               made by Ahn Young-Kie',
    'USAGE : LORE [option]',
  ];
  static const optionLines = [
    " options - '/g' ==> start Game immediately",
    "           '/c' ==> Create characters immediately",
    "           '/m' ==> no Music required",
  ];
  @override
  State<LoreHelpScreen> createState() => _LoreHelpScreenState();
}

class _LoreHelpScreenState extends State<LoreHelpScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _line = 0, _shade = 0, _deadline = 50;
  bool _keyPressed = false;
  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (elapsed.inMilliseconds < _deadline) return;
      while (_line < 3 && elapsed.inMilliseconds >= _deadline) {
        _shade++;
        if (_shade == 43) {
          _line++;
          _shade = 0;
        }
        if (_line == 3) {
          _ticker.stop();
          setState(() {});
          widget.onHalt();
          return;
        }
        _deadline += _keyPressed ? 0 : 50;
      }
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (!isLoreReadKeyEvent(event)) return KeyEventResult.ignored;
        _keyPressed = true;
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _keyPressed = true,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                for (var i = 0; i < 3; i++) ...[
                  if (i == 2) const SizedBox(height: 16),
                  if (i <= _line)
                    Text(
                      LoreHelpScreen.fadingLines[i],
                      style: RetroTheme.dosFont.copyWith(
                        color: i == _line
                            ? loreVgaColor(_shade, _shade, _shade)
                            : RetroTheme.ega(7),
                      ),
                    ),
                ],
                if (_line == 3) ...[
                  const SizedBox(height: 16),
                  for (final line in LoreHelpScreen.optionLines)
                    Text(
                      line,
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.ega(7),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
