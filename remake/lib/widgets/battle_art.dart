import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../presentation/battle_backdrop.dart';
import '../theme/mobile_theme.dart';

final _images = <String, ui.Image>{};
final _loads = <String, Future<ui.Image>>{};

Future<ui.Image> _load(String path) => _loads.putIfAbsent(path, () async {
  final data = await rootBundle.load(path);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  return _images[path] = frame.image;
});

Future<void> loadBattleScenery() async {
  await Future.wait([
    _load('assets/images/ui/battle/backgrounds.png'),
    _load('assets/images/ui/battle/buttons.png'),
  ]);
}

/// Reads a cell from the original generated sheet without re-encoding the art.
class BattleArtTile extends StatelessWidget {
  const BattleArtTile({
    super.key,
    required this.path,
    required this.cell,
    required this.columns,
    required this.rows,
    this.fit = BoxFit.cover,
    this.cropTop = 0,
  });
  final String path;
  final int cell, columns, rows;
  final BoxFit fit;
  final double cropTop;

  @override
  Widget build(BuildContext context) {
    Widget paint(ui.Image image) => ExcludeSemantics(
      child: CustomPaint(
        painter: _ArtPainter(image, cell, columns, rows, fit, cropTop),
      ),
    );
    final image = _images[path];
    if (image != null) return paint(image);
    return FutureBuilder<ui.Image>(
      future: _load(path),
      builder: (_, snapshot) => snapshot.hasData
          ? paint(snapshot.data!)
          : const ColoredBox(color: MobileTheme.mintLight),
    );
  }
}

class BattleScenery extends StatelessWidget {
  const BattleScenery({super.key, required this.backdrop});
  final BattleBackdrop backdrop;
  @override
  Widget build(BuildContext context) => BattleArtTile(
    key: ValueKey('battle-backdrop-${backdrop.name}'),
    path: 'assets/images/ui/battle/backgrounds.png',
    cell: backdrop.cell,
    columns: 4,
    rows: 2,
    // Reuse only the dry sand foreground, without ocean, for sandy ground.
    cropTop: backdrop == BattleBackdrop.sand ? .36 : 0,
  );
}

/// Real accessible/touch button; painted plaque and icon are decorative only.
class FantasyBattleButton extends StatelessWidget {
  const FantasyBattleButton({
    super.key,
    this.buttonKey,
    required this.label,
    required this.cell,
    required this.onPressed,
  });
  final Key? buttonKey;
  final String label;
  final int cell;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(
    key: buttonKey,
    style: ElevatedButton.styleFrom(
      elevation: 0,
      padding: EdgeInsets.zero,
      minimumSize: const Size(48, 48),
      backgroundColor: Colors.transparent,
      disabledBackgroundColor: Colors.transparent,
      foregroundColor: MobileTheme.ink,
      disabledForegroundColor: MobileTheme.muted,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: onPressed,
    child: Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Opacity(
              opacity: onPressed == null ? .42 : 1,
              child: BattleArtTile(
                path: 'assets/images/ui/battle/buttons.png',
                cell: cell,
                columns: 3,
                rows: 3,
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 48, right: 8),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(
    this.image,
    this.cell,
    this.columns,
    this.rows,
    this.fit,
    this.cropTop,
  );
  final ui.Image image;
  final int cell, columns, rows;
  final BoxFit fit;
  final double cropTop;
  @override
  void paint(Canvas canvas, Size size) {
    final w = image.width / columns, h = image.height / rows;
    var source = Rect.fromLTWH(
      (cell % columns) * w,
      (cell ~/ columns) * h + cropTop * h,
      w,
      h * (1 - cropTop),
    );
    if (fit == BoxFit.fill) {
      // Generated plaques have transparent row spacing. Sample only each
      // plaque, then stretch its empty middle; keep the icon/corners intact.
      const tops = [.079, .379, .680];
      const bottoms = [.330, .633, .933];
      final row = cell ~/ columns;
      source = Rect.fromLTRB(
        source.left + 1,
        tops[row] * image.height,
        source.right - 1,
        bottoms[row] * image.height,
      );
      final scale = size.height / source.height;
      final left = source.width * .45;
      final right = source.width * .10;
      final leftWidth = left * scale, rightWidth = right * scale;
      void slice(double sx, double sw, double dx, double dw) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(source.left + sx, source.top, sw, source.height),
          Rect.fromLTWH(dx, 0, dw, size.height),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }

      slice(0, left, 0, leftWidth);
      slice(
        left,
        source.width - left - right,
        leftWidth,
        size.width - leftWidth - rightWidth,
      );
      slice(source.width - right, right, size.width - rightWidth, rightWidth);
      return;
    }
    final fitted = applyBoxFit(fit, source.size, size);
    canvas.drawImageRect(
      image,
      Alignment.center.inscribe(fitted.source, source),
      Alignment.center.inscribe(fitted.destination, Offset.zero & size),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.image != image ||
      old.cell != cell ||
      old.fit != fit ||
      old.cropTop != cropTop;
}
