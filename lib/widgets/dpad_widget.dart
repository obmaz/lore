import 'package:flutter/material.dart';
import '../theme/retro_theme.dart';

/// 모바일 터치 및 마우스 클릭을 지원하는 레트로 십자키 (D-Pad) 위젯
class DPadWidget extends StatelessWidget {
  final void Function(int dx, int dy) onDirectionPressed;

  const DPadWidget({
    super.key,
    required this.onDirectionPressed,
  });

  Widget _buildButton(IconData icon, String label, int dx, int dy) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onDirectionPressed(dx, dy),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: RetroTheme.panelBg,
            border: Border.all(color: RetroTheme.borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            color: RetroTheme.lightCyan,
            size: 20,
          ),
        ),
      ),
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
          _buildButton(Icons.arrow_drop_up, 'UP', 0, -1),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildButton(Icons.arrow_left, 'LEFT', -1, 0),
              const SizedBox(width: 38),
              _buildButton(Icons.arrow_right, 'RIGHT', 1, 0),
            ],
          ),
          const SizedBox(height: 2),
          _buildButton(Icons.arrow_drop_down, 'DOWN', 0, 1),
        ],
      ),
    );
  }
}
