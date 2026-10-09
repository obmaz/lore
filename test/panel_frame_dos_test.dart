import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/theme/retro_theme.dart';
import 'package:lore/widgets/lore_panel_frame.dart';
import 'package:lore/widgets/viewport_view.dart';
import 'package:lore/widgets/party_status_view.dart';
import 'package:lore/widgets/message_log_view.dart';

class _Calls implements Canvas {
  final calls = <List<Object>>[];
  Color? _color;
  void color(Paint paint) {
    if (_color != paint.color) {
      _color = paint.color;
      calls.add([
        'color',
        List.generate(
          16,
          (i) => RetroTheme.ega(i).toARGB32(),
        ).indexOf(paint.color.toARGB32()),
      ]);
    }
  }

  @override
  void drawLine(Offset a, Offset b, Paint paint) {
    color(paint);
    calls.add(['line', a.dx.toInt(), a.dy.toInt(), b.dx.toInt(), b.dy.toInt()]);
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    color(paint);
    calls.add([
      'rectangle',
      rect.left.toInt(),
      rect.top.toInt(),
      rect.right.toInt(),
      rect.bottom.toInt(),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// LORESUB.PAS Set_All six j=0..5 loops. Same source operations/colours on
// both native pages; scaling maps these to the existing responsive panels.
// Whole DOS glyph/framebuffer pixel identity is not asserted.
void main() {
  final native =
      jsonDecode(
            File('test/fixtures/dos_common_screen.json').readAsStringSync(),
          )['borders']
          as List;
  for (final frame in LorePanelFrame.values) {
    for (final page in [0, 1]) {
      test(
        'native ${frame.name} border page$page ordered lines and colors',
        () {
          final startLine = [
            'line',
            frame.innerLeft.toInt(),
            frame.innerBottom.toInt(),
            frame.innerRight.toInt(),
            frame.innerBottom.toInt(),
          ];
          final starts = [
            for (var i = 0; i < native.length; i++)
              if (native[i].toString() == startLine.toString()) i,
          ];
          final start = starts[page] - 1;
          var end = start;
          var rectangles = 0;
          while (rectangles < 2) {
            if (native[end][0] == 'rectangle') rectangles++;
            end++;
          }
          final canvas = _Calls();
          LorePanelFramePainter(frame).paint(canvas, frame.bounds.size);
          expect(canvas.calls, native.sublist(start, end));
          expect(canvas.calls.where((op) => op[0] == 'line').length, 26);
        },
      );
    }
  }
  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    for (final overlay in [false, true]) {
      testWidgets(
        'existing panels use native painter at $size overlay=$overlay',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Expanded(child: ViewportView(overlayTitle: overlay)),
                    const Expanded(child: PartyStatusView(members: [])),
                    const Expanded(
                      child: MessageLogView(logs: ['SOURCE'], revision: 1),
                    ),
                  ],
                ),
              ),
            ),
          );
          final frames = tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((w) => w.foregroundPainter)
              .whereType<LorePanelFramePainter>()
              .map((p) => p.frame)
              .toList();
          expect(frames, containsAll(LorePanelFrame.values));
          expect(frames.length, 3);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }
  }
}
