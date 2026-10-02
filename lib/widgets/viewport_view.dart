import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';

/// Displays the map or battle scene without an added title bar.
class ViewportView extends StatelessWidget {
  final Widget content;

  const ViewportView({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RetroTheme.viewportBg,
        border: Border.all(color: RetroTheme.borderColor, width: 2),
      ),
      child: content,
    );
  }
}
