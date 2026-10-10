import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/mobile_theme.dart';

/// Fits a portrait game canvas into every device without blocking entry.
/// Ratios are height:width, from 4:3 through 19.5:9.
/// The Navigator stays mounted across rotation/resizing.
class MobileViewportGate extends StatefulWidget {
  const MobileViewportGate({super.key, required this.child});
  final Widget child;
  static Size contentSize(Size viewport) {
    if (viewport.width <= 0 || viewport.height <= 0) return Size.zero;
    if (viewport.height < viewport.width * 4 / 3) {
      return Size(viewport.height * 3 / 4, viewport.height);
    }
    if (viewport.height > viewport.width * 19.5 / 9) {
      return Size(viewport.width, viewport.width * 19.5 / 9);
    }
    return viewport;
  }

  @override
  State<MobileViewportGate> createState() => _MobileViewportGateState();
}

class _MobileViewportGateState extends State<MobileViewportGate> {
  final Set<int> _pointers = {};
  Size? _previousSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MediaQuery.sizeOf(context);
    if (_previousSize != null && next != _previousSize) {
      // A held direction must stop when its touch target moves on rotation.
      for (final pointer in _pointers.toList()) {
        GestureBinding.instance.cancelPointer(pointer);
      }
      _pointers.clear();
    }
    _previousSize = next;
  }

  EdgeInsets _canvasInsets(
    EdgeInsets insets,
    Size viewport,
    Size canvas,
    double scale,
  ) {
    final horizontalMargin = (viewport.width - canvas.width) / 2;
    final verticalMargin = (viewport.height - canvas.height) / 2;
    return EdgeInsets.fromLTRB(
      math.max(0, insets.left - horizontalMargin) / scale,
      math.max(0, insets.top - verticalMargin) / scale,
      math.max(0, insets.right - horizontalMargin) / scale,
      math.max(0, insets.bottom - verticalMargin) / scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final canvas = MobileViewportGate.contentSize(media.size);
    // Short landscape screens still need enough layout room for the controls.
    // Scale the complete canvas uniformly rather than clipping individual UI.
    final logicalWidth = math.max(320.0, canvas.width);
    final scale = canvas.width > 0 ? canvas.width / logicalWidth : 1.0;
    final logicalSize = Size(logicalWidth, canvas.height / scale);
    return ColoredBox(
      color: MobileTheme.background,
      child: Center(
        child: SizedBox(
          key: const ValueKey('mobile-game-frame'),
          width: canvas.width,
          height: canvas.height,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: logicalSize.width,
              height: logicalSize.height,
              child: MediaQuery(
                data: media.copyWith(
                  size: logicalSize,
                  padding: _canvasInsets(
                    media.padding,
                    media.size,
                    canvas,
                    scale,
                  ),
                  viewPadding: _canvasInsets(
                    media.viewPadding,
                    media.size,
                    canvas,
                    scale,
                  ),
                  viewInsets: _canvasInsets(
                    media.viewInsets,
                    media.size,
                    canvas,
                    scale,
                  ),
                  systemGestureInsets: _canvasInsets(
                    media.systemGestureInsets,
                    media.size,
                    canvas,
                    scale,
                  ),
                ),
                child: Listener(
                  onPointerDown: (e) => _pointers.add(e.pointer),
                  onPointerUp: (e) => _pointers.remove(e.pointer),
                  onPointerCancel: (e) => _pointers.remove(e.pointer),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
