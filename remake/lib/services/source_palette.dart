import 'package:flutter/material.dart';

/// LOREMAIN.Main's Tab BIOS grayscale request, mapped to modern RGB rendering.
/// The DAC's 6-bit quantization and BIOS-specific coefficients are not emulated.
class SourcePalette extends ChangeNotifier {
  SourcePalette._();
  static final instance = SourcePalette._();
  bool _grayscale = false;
  bool get grayscale => _grayscale;

  void requestGrayscale() {
    if (_grayscale) return;
    _grayscale = true;
    notifyListeners();
  }

  void reset() {
    if (!_grayscale) return;
    _grayscale = false;
    notifyListeners();
  }

  // Modern RGB luminance, applied to the Navigator too so later modal windows
  // retain the palette conversion. This changes presentation, not game state.
  static Widget wrap(BuildContext context, Widget? child) => ListenableBuilder(
    listenable: instance,
    child: child ?? const SizedBox.shrink(),
    builder: (context, child) => ColorFiltered(
      key: const ValueKey('source-palette'),
      colorFilter: ColorFilter.matrix(
        instance.grayscale
            ? const [
                .299,
                .587,
                .114,
                0,
                0,
                .299,
                .587,
                .114,
                0,
                0,
                .299,
                .587,
                .114,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]
            : const [
                1,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ],
      ),
      child: child,
    ),
  );
}
