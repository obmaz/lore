import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _images = <String, Future<ui.Image>>{};
final _decoded = <String, ui.Image>{};

Future<ui.Image> loadAtlasArt(String path) =>
    _images.putIfAbsent(path, () async {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return _decoded[path] = frame.image;
    });

/// A uniform transparent atlas. Fill both dimensions even inside a loose Row.
class AtlasArt extends StatelessWidget {
  const AtlasArt({
    super.key,
    required this.path,
    required this.cell,
    required this.columns,
    required this.rows,
  });
  final String path;
  final int cell, columns, rows;

  Widget _paint(ui.Image image) => SizedBox.expand(
    child: CustomPaint(painter: _AtlasPainter(image, cell, columns, rows)),
  );

  @override
  Widget build(BuildContext context) {
    final cached = _decoded[path];
    return ExcludeSemantics(
      child: cached != null
          ? _paint(cached)
          : FutureBuilder<ui.Image>(
              future: loadAtlasArt(path),
              builder: (_, snapshot) => snapshot.hasData
                  ? _paint(snapshot.data!)
                  : const Center(child: Icon(Icons.image_outlined)),
            ),
    );
  }
}

class _AtlasPainter extends CustomPainter {
  _AtlasPainter(this.image, this.cell, this.columns, this.rows);
  final ui.Image image;
  final int cell, columns, rows;

  @override
  void paint(Canvas canvas, Size size) {
    final source = Rect.fromLTWH(
      (cell % columns) * image.width / columns,
      (cell ~/ columns) * image.height / rows,
      image.width / columns,
      image.height / rows,
    );
    final fit = applyBoxFit(BoxFit.contain, source.size, size);
    canvas.drawImageRect(
      image,
      source,
      Alignment.center.inscribe(fit.destination, Offset.zero & size),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_AtlasPainter old) =>
      old.image != image ||
      old.cell != cell ||
      old.columns != columns ||
      old.rows != rows;
}
