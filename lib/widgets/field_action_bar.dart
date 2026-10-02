import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';

/// Field commands outside the map, with touch targets in either orientation.
class FieldActionBar extends StatelessWidget {
  final Axis axis;
  final VoidCallback onMenu;
  final VoidCallback onStatus;
  final VoidCallback onExtrasense;

  const FieldActionBar({
    super.key,
    required this.axis,
    required this.onMenu,
    required this.onStatus,
    required this.onExtrasense,
  });

  Widget _button(
    String name,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return OutlinedButton(
      key: ValueKey('field-action-$name'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: RetroTheme.panelBg,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 44),
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(label, style: RetroTheme.dosFont.copyWith(color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _button('menu', '메뉴', RetroTheme.white, onMenu),
      _button('status', '상태', RetroTheme.white, onStatus),
      _button('extrasense', '초감각', RetroTheme.white, onExtrasense),
    ];
    if (axis == Axis.vertical) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buttons[0],
                const SizedBox(height: 4),
                buttons[1],
                const SizedBox(height: 4),
                buttons[2],
              ],
            ),
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: buttons[0]),
        const SizedBox(width: 4),
        Expanded(child: buttons[1]),
        const SizedBox(width: 4),
        Expanded(child: buttons[2]),
      ],
    );
  }
}
