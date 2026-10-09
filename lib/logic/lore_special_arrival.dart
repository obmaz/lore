/// LORESPEC.PAS:2015-2030,2120-2153. Ordered source BGI operations.
/// Modern rendering merges CHARA AND/OR pairs; source coordinates stay in pixels.
class LoreArrivalOp {
  const LoreArrivalOp(this.kind, this.x, this.y, this.index, this.operation);
  final String kind;
  final int x, y, index, operation;
  const LoreArrivalOp.delay(int milliseconds)
    : this('delay', 0, 0, milliseconds, 0);
}

abstract final class LoreSpecialArrival {
  static Iterable<LoreArrivalOp> guardian(int x, int y) sync* {
    yield const LoreArrivalOp('chara', 100, 20, 51, 3);
    yield const LoreArrivalOp('chara', 100, 20, 23, 2);
    for (var j = 1; j <= 3; j++) {
      yield const LoreArrivalOp.delay(2000);
      for (var i = 0; i <= 9; i++) {
        if (i == 0 && j > 1) {
          yield LoreArrivalOp('tile', 100, (j - 1) * 20, x, y + j - 5);
        }
        yield LoreArrivalOp('tile', 100, j * 20, x, y + j - 5);
        yield LoreArrivalOp('tile', 100, (j + 1) * 20, x, y + j - 4);
        yield LoreArrivalOp('chara', 100, j * 20 + i * 2, 51, 3);
        yield LoreArrivalOp('chara', 100, j * 20 + i * 2, 23, 2);
      }
    }
  }

  static Iterable<LoreArrivalOp> finalActors(int x, int y) sync* {
    for (var j = 4; j >= 2; j--) {
      if (j < 4) {
        yield LoreArrivalOp('tile', 140, 80 - j * 20, x + 2, y - j - 1);
      }
      yield LoreArrivalOp('chara', 140, 100 - j * 20, 54, 3);
      yield LoreArrivalOp('chara', 140, 100 - j * 20, 26, 2);
      yield const LoreArrivalOp.delay(1000);
    }
    for (var j = 4; j >= 2; j--) {
      if (j < 4) {
        yield LoreArrivalOp('tile', 100, 80 - j * 20, x, y - j - 1);
      }
      yield LoreArrivalOp('chara', 100, 100 - j * 20, 53, 3);
      yield LoreArrivalOp('chara', 100, 100 - j * 20, 25, 2);
      yield const LoreArrivalOp.delay(1000);
    }
    for (var j = 1; j <= 3; j++) {
      if (j > 1) {
        yield LoreArrivalOp('tile', (j - 1) * 20, 40, x + j - 6, y - 3);
        yield LoreArrivalOp('tile', (j - 1) * 20, 60, x + j - 6, y - 2);
      }
      yield LoreArrivalOp('chara', j * 20, 40, 44, 3);
      yield LoreArrivalOp('chara', j * 20, 40, 16, 2);
      yield LoreArrivalOp('chara', j * 20, 60, 45, 3);
      yield LoreArrivalOp('chara', j * 20, 60, 17, 2);
      yield const LoreArrivalOp.delay(2000);
    }
    for (var j = 3; j <= 4; j++) {
      yield LoreArrivalOp('tile', 60, (j - 1) * 20, x - 2, y + j - 6);
      yield LoreArrivalOp('tile', 60, j * 20, x - 2, y + j - 5);
      yield LoreArrivalOp('chara', 60, j * 20, 44, 3);
      yield LoreArrivalOp('chara', 60, j * 20, 16, 2);
      yield LoreArrivalOp('chara', 60, (j + 1) * 20, 45, 3);
      yield LoreArrivalOp('chara', 60, (j + 1) * 20, 17, 2);
      yield const LoreArrivalOp.delay(2000);
    }
  }
}
