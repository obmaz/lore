/// LOREHELP.PAS: source graphics calls and short-circuit keyboard boundaries.
enum LoreTitleOp {
  fill,
  bar,
  move,
  line,
  color,
  palette,
  rgb,
  delay,
  scroll,
  ready,
  text,
}

class LoreTitleOperation {
  const LoreTitleOperation(this.op, this.values);
  final LoreTitleOp op;
  final List<int> values;
  List<Object> get trace => [op.name, ...values];
}

abstract final class LoreTitleFlow {
  static Iterable<LoreTitleOperation> box(
    int x1,
    int y1,
    int x2,
    int y2,
    int color, {
    required bool shadow,
    required bool bold,
  }) sync* {
    yield LoreTitleOperation(LoreTitleOp.fill, [1, color]);
    yield LoreTitleOperation(LoreTitleOp.bar, [x1, y1, x2, y2]);
    yield* _edges(x1, y1, x2, y2, 15, 8);
    if (bold) yield* _edges(x1 + 1, y1 + 1, x2 - 1, y2 - 1, 15, 8);
    if (shadow) {
      yield* _edges(x1 + 3, y1 + 3, x2 - 3, y2 - 3, 8, 15);
      if (bold) yield* _edges(x1 + 4, y1 + 4, x2 - 4, y2 - 4, 8, 15);
    }
  }

  static Iterable<LoreTitleOperation> _edges(
    int x1,
    int y1,
    int x2,
    int y2,
    int light,
    int dark,
  ) sync* {
    yield LoreTitleOperation(LoreTitleOp.move, [x1, y2]);
    yield LoreTitleOperation(LoreTitleOp.color, [light]);
    yield LoreTitleOperation(LoreTitleOp.line, [x1, y1]);
    yield LoreTitleOperation(LoreTitleOp.line, [x2, y1]);
    yield LoreTitleOperation(LoreTitleOp.color, [dark]);
    yield LoreTitleOperation(LoreTitleOp.line, [x2, y2]);
    yield LoreTitleOperation(LoreTitleOp.line, [x1, y2]);
  }

  static Iterable<LoreTitleOperation> messageBox(
    int x1,
    int y1,
    int x2,
    int y2,
    int color, {
    required bool shadow,
  }) sync* {
    if (shadow) {
      yield* box(x1, y1, x2, y2, 8, shadow: true, bold: false);
      yield* box(
        x1 + 2,
        y1 + 2,
        x2 - 2,
        y2 - 2,
        color,
        shadow: false,
        bold: false,
      );
    } else {
      yield* box(x1, y1, x2, y2, color, shadow: false, bold: false);
    }
    yield const LoreTitleOperation(LoreTitleOp.fill, [1, 0]);
    yield LoreTitleOperation(LoreTitleOp.bar, [x1, y2 + 1, x2, y2]);
    yield LoreTitleOperation(LoreTitleOp.bar, [x2 + 1, y1, x2, y2]);
  }

  static Iterable<LoreTitleOperation> nestedBox() sync* {
    for (var i = 0; i <= 10; i++) {
      yield* box(
        200 - i * 20,
        200 - i * 20,
        438 + i * 20,
        278 + i * 20,
        1,
        shadow: true,
        bold: true,
      );
    }
  }

  static Iterable<LoreTitleOperation> nestedMessageBox() sync* {
    for (var i = 0; i <= 10; i++) {
      yield* messageBox(
        140 - i * 10,
        160 - i * 5,
        500 + i * 10,
        250 + i * 5,
        4,
        shadow: true,
      );
    }
  }

  static Iterable<LoreTitleOperation> lift() sync* {
    for (var i = 100; i >= 40; i--) {
      final n = 100 - i;
      yield const LoreTitleOperation(LoreTitleOp.scroll, [0]);
      yield const LoreTitleOperation(LoreTitleOp.palette, [5, 5]);
      yield LoreTitleOperation(LoreTitleOp.rgb, [5, n ~/ 2, n ~/ 4, n ~/ 2]);
      yield const LoreTitleOperation(LoreTitleOp.palette, [13, 13]);
      yield LoreTitleOperation(LoreTitleOp.rgb, [13, n, n ~/ 2, n]);
      yield const LoreTitleOperation(LoreTitleOp.delay, [10]);
    }
  }

  static Iterable<LoreTitleOperation> story(bool Function() keyPressed) sync* {
    var j = 0;
    bool ready;
    do {
      j++;
      yield const LoreTitleOperation(LoreTitleOp.rgb, [2, 15, 15, 15]);
      yield const LoreTitleOperation(LoreTitleOp.rgb, [3, 0, 63, 63]);
      var temp = 0;
      do {
        temp++;
        yield const LoreTitleOperation(LoreTitleOp.scroll, [1]);
        if (temp == 1) {
          yield const LoreTitleOperation(LoreTitleOp.color, [2]);
          yield LoreTitleOperation(LoreTitleOp.text, [71, 270 - temp, j, 0]);
          if (j > 7) {
            yield const LoreTitleOperation(LoreTitleOp.color, [3]);
            yield LoreTitleOperation(LoreTitleOp.text, [
              71,
              128 + 16 - temp,
              j - 7,
              0,
            ]);
          }
        }
        yield LoreTitleOperation(LoreTitleOp.rgb, [
          2,
          16 - temp,
          15 + temp * 3,
          15 + temp * 3,
        ]);
        yield LoreTitleOperation(LoreTitleOp.rgb, [
          3,
          temp,
          63 - temp * 3,
          63 - temp * 3,
        ]);
        if (temp >= 2 && temp <= 15) {
          yield LoreTitleOperation(LoreTitleOp.delay, [j > 7 ? 110 : 150]);
        }
        if (temp >= 16) break;
        ready = keyPressed();
        yield LoreTitleOperation(LoreTitleOp.ready, [ready ? 1 : 0]);
        if (ready) break;
      } while (true);
      ready = keyPressed();
      yield LoreTitleOperation(LoreTitleOp.ready, [ready ? 1 : 0]);
      if (!ready) {
        yield const LoreTitleOperation(LoreTitleOp.color, [11]);
        yield LoreTitleOperation(LoreTitleOp.text, [71, 270 - temp, j, 0]);
        if (j > 7) {
          yield const LoreTitleOperation(LoreTitleOp.color, [8]);
          yield LoreTitleOperation(LoreTitleOp.text, [
            71,
            128 + 16 - temp,
            j - 7,
            0,
          ]);
        }
        for (var i = 1; i <= 2; i++) {
          yield const LoreTitleOperation(LoreTitleOp.scroll, [1]);
          yield const LoreTitleOperation(LoreTitleOp.delay, [200]);
        }
      }
      if (j >= 25) break;
      ready = keyPressed();
      yield LoreTitleOperation(LoreTitleOp.ready, [ready ? 1 : 0]);
    } while (!ready);
  }
}
