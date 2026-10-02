import 'package:lore/logic/lore_source_memory.dart';

/// Run on both the Dart VM and optimized JavaScript (Node), without Flutter's
/// browser harness, to catch backend-specific bitwise and signed arithmetic.
void main() {
  void check(Object actual, Object expected, String label) {
    if (actual != expected) {
      throw StateError('$label: expected $expected, got $actual');
    }
  }

  check(LorePascal.byte(-1), 255, 'byte underflow');
  check(LorePascal.byte(256), 0, 'byte overflow');
  check(LorePascal.word(-1), 65535, 'word underflow');
  check(LorePascal.integer(32768), -32768, 'integer positive boundary');
  check(LorePascal.integer(-32769), 32767, 'integer negative boundary');
  check(
    LorePascal.longint(2147483648),
    -2147483648,
    'longint positive boundary',
  );
  check(
    LorePascal.longint(-2147483649),
    2147483647,
    'longint negative boundary',
  );
  check(LorePascal.div(-7, 3), -2, 'negative div');
  check(LorePascal.mod(-7, 3), -1, 'negative mod');

  final etc = LorePartyEtc();
  for (var value = 0; value < 256; value++) {
    etc[45] = value;
    etc.setBit(45, 7);
    check(etc.read(45), value | 64, 'lever A $value');
    etc.setBit(45, 8);
    check(etc.read(45), value | 192, 'both levers $value');
    etc.setBit(45, 8, false);
    check(etc.read(45), (value | 64) & 127, 'clear high bit $value');
  }
  for (var index = 1; index <= 100; index++) {
    etc[index] = index + 200;
  }
  final restored = LorePartyEtc.fromBytes(etc.toBytes());
  for (var index = 1; index <= 100; index++) {
    check(restored.read(index), (index + 200) & 255, 'slot $index');
  }
  // CLI output must also work in the JavaScript verification runner.
  // ignore: avoid_print
  print(
    'LORE source memory: storage boundaries, div/mod, 256 bit states, 100 slots passed.',
  );
}
