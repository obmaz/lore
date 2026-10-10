import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';

/// LORESUB.PAS Set_All's three frames; coordinates remain source coordinates
/// and Canvas scaling adapts the frame to the existing responsive panels.
enum LorePanelFrame {
  viewport(
    Rect.fromLTRB(10, 10, 209, 209),
    14,
    14,
    19,
    19,
    200,
    200,
    205,
    205,
    15,
  ),
  party(
    Rect.fromLTRB(10, 230, 627, 341),
    14,
    234,
    19,
    239,
    618,
    332,
    622,
    337,
    10,
  ),
  message(
    Rect.fromLTRB(220, 10, 627, 209),
    224,
    14,
    229,
    19,
    618,
    200,
    622,
    205,
    15,
  );

  const LorePanelFrame(
    this.bounds,
    this.left,
    this.top,
    this.innerLeft,
    this.innerTop,
    this.innerRight,
    this.innerBottom,
    this.topRight,
    this.bottom,
    this.cornerColor,
  );
  final Rect bounds;
  final double left,
      top,
      innerLeft,
      innerTop,
      innerRight,
      innerBottom,
      topRight,
      bottom;
  final int cornerColor;
}

class LorePanelFramePainter extends CustomPainter {
  const LorePanelFramePainter(this.frame);
  final LorePanelFrame frame;
  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    canvas.save();
    canvas.scale(size.width / f.bounds.width, size.height / f.bounds.height);
    canvas.translate(-f.bounds.left, -f.bounds.top);
    final paint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    void color(int index) => paint.color = RetroTheme.ega(index);
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    color(8);
    for (var j = 0; j <= 5; j++) {
      line(
        f.innerLeft - j,
        f.innerBottom + j,
        f.innerRight + j,
        f.innerBottom + j,
      );
      line(
        f.innerRight + j,
        f.innerTop - j,
        f.innerRight + j,
        f.innerBottom + j,
      );
    }
    color(7);
    for (var j = 0; j <= 5; j++) {
      line(f.left + j, f.top + j, f.left + j, f.bottom - j);
      line(f.left + j, f.top + j, f.topRight - j, f.top + j);
    }
    line(f.innerRight, f.innerBottom, f.innerRight + 5, f.innerBottom + 5);
    color(f.cornerColor);
    line(f.left, f.top, f.innerLeft, f.innerTop);
    if (f == LorePanelFrame.viewport) {
      canvas.drawRect(const Rect.fromLTRB(12, 12, 207, 207), paint);
      canvas.drawRect(f.bounds, paint);
    } else if (f == LorePanelFrame.party) {
      canvas.drawRect(f.bounds, paint);
      color(2);
      canvas.drawRect(const Rect.fromLTRB(12, 232, 625, 339), paint);
    } else {
      canvas.drawRect(f.bounds, paint);
      canvas.drawRect(const Rect.fromLTRB(222, 12, 625, 207), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LorePanelFramePainter oldDelegate) =>
      oldDelegate.frame != frame;
}
