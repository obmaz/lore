import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';

/// 90년대 도스 게임 특유의 각진 테두리와 타이틀 바를 지원하는 레트로 패널
class RetroBox extends StatelessWidget {
  final Widget child;
  final String? title;
  final Color borderColor;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;

  const RetroBox({
    super.key,
    required this.child,
    this.title,
    this.borderColor = RetroTheme.borderColor,
    this.backgroundColor = RetroTheme.panelBg,
    this.padding = const EdgeInsets.all(8.0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: borderColor.withValues(alpha: 0.35),
              child: Text(
                title!,
                style: RetroTheme.headerFont.copyWith(fontSize: 12),
              ),
            ),
          Expanded(
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}
