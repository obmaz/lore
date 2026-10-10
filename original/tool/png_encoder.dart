import 'dart:io';
import 'dart:typed_data';

/// 의존성 없는 최소 PNG 인코더 (도구 전용).
///
/// PNG = 매직 + IHDR + IDAT(zlib) + IEND. `dart:io`의 [ZLibCodec]으로
/// deflate 스트림을 만들고, 청크마다 CRC32를 계산한다.
Uint8List encodePng({
  required int width,
  required int height,
  required Uint8List rgba,
}) {
  final raw = BytesBuilder();
  final stride = width * 4;
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter type 0 (None)
    raw.add(Uint8List.sublistView(rgba, y * stride, (y + 1) * stride));
  }
  final idat = ZLibCodec(level: 6).encode(raw.toBytes());

  final out = BytesBuilder();
  out.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  final ihdr = BytesBuilder();
  ihdr.add(_be32(width));
  ihdr.add(_be32(height));
  ihdr.add(const [
    8,
    6,
    0,
    0,
    0,
  ]); // 8bit, RGBA, deflate, filter 0, no interlace

  out.add(_chunk('IHDR', ihdr.toBytes()));
  out.add(_chunk('IDAT', Uint8List.fromList(idat)));
  out.add(_chunk('IEND', Uint8List(0)));
  return out.toBytes();
}

List<int> _be32(int v) => [
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];

Uint8List _chunk(String type, Uint8List data) {
  final b = BytesBuilder();
  b.add(_be32(data.length));
  final typeBytes = Uint8List.fromList(type.codeUnits);
  b.add(typeBytes);
  b.add(data);
  final crcInput = BytesBuilder()
    ..add(typeBytes)
    ..add(data);
  b.add(_be32(_crc32(crcInput.toBytes())));
  return b.toBytes();
}

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
