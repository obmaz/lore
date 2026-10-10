import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../logic/lore_title_flow.dart';
import '../theme/retro_theme.dart';
import 'lore_creation_animation.dart';
import 'lore_guide_dialog.dart';

/// LOREHELP's indexed drawing surface. Geometry/scroll stay in source space;
/// Flutter text and viewport scaling remain the existing presentation adapter.
class LoreTitleSurface {
  final pixels = Uint8List(640 * 480);
  final colors = List<Color>.of(RetroTheme.egaPalette);
  final labels = <(String, int, int, int)>[];
  int fill = 1, color = 15, x = 0, y = 0;
  void apply(LoreTitleOperation action) {
    final v = action.values;
    switch (action.op) {
      case LoreTitleOp.fill:
        fill = v[1];
      case LoreTitleOp.color:
        color = v[0];
      case LoreTitleOp.palette:
        break; // EGA identity selectors in this procedure.
      case LoreTitleOp.rgb:
        colors[v[0]] = loreVgaColor(v[1], v[2], v[3]);
      case LoreTitleOp.bar:
        if (v[0] > v[2] || v[1] > v[3]) break;
        for (var row = v[1].clamp(0, 479); row <= v[3].clamp(0, 479); row++) {
          pixels.fillRange(
            row * 640 + v[0].clamp(0, 639),
            row * 640 + v[2].clamp(0, 639) + 1,
            fill,
          );
        }
      case LoreTitleOp.move:
        x = v[0];
        y = v[1];
      case LoreTitleOp.line:
        // These original boxes only contain horizontal/vertical lines.
        final dx = (v[0] - x).sign, dy = (v[1] - y).sign;
        while (true) {
          if (x >= 0 && x < 640 && y >= 0 && y < 480) {
            pixels[y * 640 + x] = color;
          }
          if (x == v[0] && y == v[1]) break;
          x += dx;
          y += dy;
        }
      case LoreTitleOp.scroll:
        scroll(v[0]);
      case LoreTitleOp.text:
        final row = v[2];
        final text = row <= LoreGuideDialog.authorPreface.length
            ? LoreGuideDialog.authorPreface[row - 1]
            : '';
        write(text, v[0], v[1], color);
      case LoreTitleOp.delay:
      case LoreTitleOp.ready:
        break;
    }
  }

  void write(String text, int x, int y, int color) {
    labels.removeWhere(
      (label) => label.$1 == text && label.$2 == x && label.$3 == y,
    );
    if (text.isNotEmpty) labels.add((text, x, y, color));
  }

  void scroll(int mode) {
    if (mode != 0 && mode != 1) return;
    final first = mode == 0 ? 40 : 126, last = mode == 0 ? 180 : 290;
    for (var row = first; row <= last; row++) {
      final from = row * 640 + 72, to = (row - 1) * 640 + 72;
      pixels.setRange(to, to + 504, pixels, from);
    }
    for (var i = 0; i < labels.length; i++) {
      final label = labels[i];
      if (label.$2 >= 72 &&
          label.$2 <= 575 &&
          label.$3 + 16 > first &&
          label.$3 <= last) {
        labels[i] = (label.$1, label.$2, label.$3 - 1, label.$4);
      }
    }
    labels.removeWhere(
      (label) => label.$3 + 16 < first && label.$3 > first - 32,
    );
  }
}

class LoreTitleIntro extends StatefulWidget {
  const LoreTitleIntro({
    super.key,
    required this.onComplete,
    required this.onKey,
  });
  final VoidCallback onComplete;
  final ValueChanged<KeyEvent> onKey;
  @override
  State<LoreTitleIntro> createState() => _LoreTitleIntroState();
}

class _LoreTitleIntroState extends State<LoreTitleIntro>
    with SingleTickerProviderStateMixin {
  final surface = LoreTitleSurface();
  late final Ticker ticker;
  late final Iterator<LoreTitleOperation> operations;
  bool pressed = false;
  int deadline = 0;
  Iterable<LoreTitleOperation> _intro() sync* {
    yield const LoreTitleOperation(LoreTitleOp.rgb, [1, 15, 5, 25]);
    yield const LoreTitleOperation(LoreTitleOp.fill, [1, 1]);
    yield const LoreTitleOperation(LoreTitleOp.bar, [0, 0, 639, 479]);
    yield* LoreTitleFlow.nestedBox();
    yield const LoreTitleOperation(LoreTitleOp.rgb, [0, 0, 0, 0]);
    yield const LoreTitleOperation(LoreTitleOp.rgb, [4, 15, 15, 15]);
    yield const LoreTitleOperation(LoreTitleOp.rgb, [5, 0, 0, 0]);
    yield const LoreTitleOperation(LoreTitleOp.rgb, [13, 0, 0, 0]);
    surface.write(LoreGuideDialog.titleCaption.first, 120, 100, 5);
    surface.write(LoreGuideDialog.titleCaption.first, 118, 98, 13);
    yield* LoreTitleFlow.lift();
    for (var i = 1; i < LoreGuideDialog.titleCaption.length; i++) {
      surface.write(LoreGuideDialog.titleCaption[i], 80, 310 + i * 20, 14);
    }
    yield* LoreTitleFlow.nestedMessageBox();
    yield* LoreTitleFlow.story(() => pressed);
  }

  @override
  void initState() {
    super.initState();
    operations = _intro().iterator;
    ticker = createTicker((elapsed) {
      if (elapsed.inMilliseconds < deadline) return;
      while (elapsed.inMilliseconds >= deadline) {
        if (!operations.moveNext()) {
          ticker.stop();
          widget.onComplete();
          return;
        }
        final operation = operations.current;
        surface.apply(operation);
        if (operation.op == LoreTitleOp.delay) deadline += operation.values[0];
      }
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
          event.logicalKey == LogicalKeyboardKey.shiftRight ||
          event.logicalKey == LogicalKeyboardKey.controlLeft ||
          event.logicalKey == LogicalKeyboardKey.controlRight ||
          event.logicalKey == LogicalKeyboardKey.altLeft ||
          event.logicalKey == LogicalKeyboardKey.altRight ||
          event.logicalKey == LogicalKeyboardKey.metaLeft ||
          event.logicalKey == LogicalKeyboardKey.metaRight ||
          event.logicalKey == LogicalKeyboardKey.capsLock ||
          event.logicalKey == LogicalKeyboardKey.numLock ||
          event.logicalKey == LogicalKeyboardKey.scrollLock) {
        return KeyEventResult.ignored;
      }
      pressed = true;
      widget.onKey(event);
      return KeyEventResult.handled;
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pressed = true,
      child: Semantics(
        label: '또다른 지식의 성전 원본 오프닝',
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 640,
            height: 480,
            child: CustomPaint(
              key: const ValueKey('source-title-intro'),
              painter: _TitlePainter(surface),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TitlePainter extends CustomPainter {
  _TitlePainter(this.surface);
  final LoreTitleSurface surface;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < 480; y++) {
      var x = 0;
      while (x < 640) {
        final start = x, c = surface.pixels[y * 640 + x];
        while (x < 640 && surface.pixels[y * 640 + x] == c) {
          x++;
        }
        paint.color = surface.colors[c];
        canvas.drawRect(
          Rect.fromLTWH(
            start.toDouble(),
            y.toDouble(),
            (x - start).toDouble(),
            1,
          ),
          paint,
        );
      }
    }
    for (final label in surface.labels) {
      canvas.save();
      if (label.$3 < 310) {
        canvas.clipRect(const Rect.fromLTRB(72, 39, 576, 291));
      }
      final text = TextPainter(
        text: TextSpan(
          text: label.$1,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            height: 1,
            color: surface.colors[label.$4],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(label.$2.toDouble(), label.$3.toDouble()));
      text.dispose();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_TitlePainter oldDelegate) => true;
}
