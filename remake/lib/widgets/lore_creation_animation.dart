import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../logic/lore_creation_palette.dart';

Color loreVgaColor(int r, int g, int b) =>
    Color.fromARGB(255, r * 255 ~/ 63, g * 255 ~/ 63, b * 255 ~/ 63);

/// Native Delay boundaries become elapsed ticker time, with queued keyboard
/// bytes retained until the original procedure reaches its next ReadKey.
class LoreCreationAnimation extends StatefulWidget {
  const LoreCreationAnimation({
    super.key,
    required this.frames,
    required this.builder,
    required this.onComplete,
    required this.onKey,
  });
  final List<LoreCreationPaletteFrame> frames;
  final Widget Function(Map<int, Color>) builder;
  final VoidCallback onComplete;
  final ValueChanged<KeyEvent> onKey;
  @override
  State<LoreCreationAnimation> createState() => _LoreCreationAnimationState();
}

class _LoreCreationAnimationState extends State<LoreCreationAnimation>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _colors = <int, Color>{};
  int _index = 0;
  int _deadline = 0;
  @override
  void initState() {
    super.initState();
    _colors[1] = loreVgaColor(0, 0, 31);
    _apply();
    _ticker = createTicker((elapsed) {
      if (elapsed.inMilliseconds < _deadline) return;
      while (_index < widget.frames.length &&
          elapsed.inMilliseconds >= _deadline) {
        _index++;
        if (_index == widget.frames.length) {
          _ticker.stop();
          widget.onComplete();
          return;
        }
        _apply();
      }
      setState(() {});
    })..start();
  }

  void _apply() {
    final frame = widget.frames[_index];
    for (final c in frame.colors) {
      _colors[c.$1] = loreVgaColor(c.$2, c.$3, c.$4);
    }
    _deadline += frame.milliseconds;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if ([
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.shiftRight,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.controlRight,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.altRight,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.metaRight,
        LogicalKeyboardKey.capsLock,
        LogicalKeyboardKey.numLock,
        LogicalKeyboardKey.scrollLock,
      ].contains(event.logicalKey)) {
        return KeyEventResult.ignored;
      }
      if (event is KeyDownEvent || event is KeyRepeatEvent) widget.onKey(event);
      return KeyEventResult.handled;
    },
    child: widget.builder(_colors),
  );
}

/// Third's live color7 pulse, then its color8 acknowledgement pulse.
class LoreCreationPulse extends StatefulWidget {
  const LoreCreationPulse({
    super.key,
    required this.confirmation,
    this.paused = false,
    required this.builder,
  });
  final bool confirmation;
  final bool paused;
  final Widget Function(Color) builder;
  @override
  State<LoreCreationPulse> createState() => _LoreCreationPulseState();
}

class _LoreCreationPulseState extends State<LoreCreationPulse>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  LoreCreationClassPulse _class = LoreCreationClassPulse();
  LoreCreationConfirmationPulse _confirm = LoreCreationConfirmationPulse();
  int _ticks = 0;
  int _value = 31;
  @override
  void initState() {
    super.initState();
    _value = widget.confirmation ? 15 : 31;
    _ticker = createTicker((elapsed) {
      final next =
          elapsed.inMilliseconds ~/ (widget.confirmation ? 50 : 10) + 1;
      if (next == _ticks) return;
      while (_ticks < next) {
        _ticks++;
        _value = widget.confirmation ? _confirm.next() : _class.next();
      }
      setState(() {});
    })..start();
  }

  @override
  void didUpdateWidget(covariant LoreCreationPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.confirmation != widget.confirmation) {
      _ticker.stop();
      _class = LoreCreationClassPulse();
      _confirm = LoreCreationConfirmationPulse();
      _ticks = 0;
      _value = widget.confirmation ? 15 : 31;
      _ticker.start();
    }
    if (widget.paused && !oldWidget.paused) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(loreVgaColor(_value, _value, _value));
}
