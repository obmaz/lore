import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';

/// 모바일 터치 및 마우스 클릭을 지원하는 레트로 십자키 (D-Pad) 위젯.
///
/// 누르는 즉시 한 칸 움직이고, [repeatDelay] 이상 계속 누르고 있으면
/// [repeatInterval] 간격으로 같은 방향 입력이 반복된다(키보드를 누르고 있을
/// 때와 같은 효과). 손을 떼거나 포인터가 취소되면 멈춘다.
class DPadWidget extends StatelessWidget {
  /// 처음 누른 뒤 반복이 시작되기까지의 시간.
  static const Duration repeatDelay = Duration(milliseconds: 350);

  /// 반복이 시작된 뒤 입력 간격.
  static const Duration repeatInterval = Duration(milliseconds: 140);

  final void Function(int dx, int dy) onDirectionPressed;

  const DPadWidget({super.key, required this.onDirectionPressed});

  Widget _buildButton(IconData icon, String label, int dx, int dy) {
    return _DPadButton(
      icon: icon,
      label: label,
      dx: dx,
      dy: dy,
      onDirectionPressed: onDirectionPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: RetroTheme.background.withValues(alpha: 0.8),
        border: Border.all(color: RetroTheme.darkGray, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(Icons.arrow_drop_up, '위로 이동', 0, -1),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildButton(Icons.arrow_left, '왼쪽으로 이동', -1, 0),
              const SizedBox(width: 44),
              _buildButton(Icons.arrow_right, '오른쪽으로 이동', 1, 0),
            ],
          ),
          const SizedBox(height: 2),
          _buildButton(Icons.arrow_drop_down, '아래로 이동', 0, 1),
        ],
      ),
    );
  }
}

class _DPadButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final int dx;
  final int dy;
  final void Function(int dx, int dy) onDirectionPressed;

  const _DPadButton({
    required this.icon,
    required this.label,
    required this.dx,
    required this.dy,
    required this.onDirectionPressed,
  });

  @override
  State<_DPadButton> createState() => _DPadButtonState();
}

class _DPadButtonState extends State<_DPadButton> {
  Timer? _timer;
  int? _pointer;
  bool _pressed = false;

  void _fire() {
    if (!mounted) return;
    widget.onDirectionPressed(widget.dx, widget.dy);
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    setState(() => _pressed = true);
    _fire();
    _timer?.cancel();
    _timer = Timer(DPadWidget.repeatDelay, () {
      _fire();
      _timer = Timer.periodic(DPadWidget.repeatInterval, (_) => _fire());
    });
  }

  void _release(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _stop();
  }

  void _stop() {
    _pointer = null;
    _timer?.cancel();
    _timer = null;
    if (mounted && _pressed) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      button: true,
      onTap: _fire,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerUp: _release,
        onPointerCancel: _release,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _pressed ? RetroTheme.borderColor : RetroTheme.panelBg,
            border: Border.all(color: RetroTheme.borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(widget.icon, color: RetroTheme.lightCyan, size: 20),
        ),
      ),
    );
  }
}
