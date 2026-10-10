import 'package:flutter/material.dart';

import '../theme/mobile_theme.dart';

/// A full-width touch target shared by field and battle choices.
class MobileChoiceTile extends StatelessWidget {
  const MobileChoiceTile({
    super.key,
    required this.label,
    required this.onPressed,
    this.detail,
    this.cost,
    this.selected = false,
    this.busy = false,
    this.labelWidget,
    this.leading,
    this.detailFontSize = 12,
    this.costFontSize = 12,
  });

  final String label;
  final String? detail, cost;
  final VoidCallback? onPressed;
  final bool selected, busy;
  final double detailFontSize, costFontSize;
  final Widget? labelWidget, leading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null || busy;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size(48, 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        foregroundColor: MobileTheme.ink,
        disabledForegroundColor: MobileTheme.muted,
        backgroundColor: selected ? MobileTheme.mintLight : MobileTheme.surface,
        disabledBackgroundColor: MobileTheme.line.withValues(alpha: .25),
        side: BorderSide(
          color: selected ? MobileTheme.mint : MobileTheme.line,
          width: selected ? 1.5 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget ??
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                if (detail != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    detail!,
                    style: TextStyle(
                      color: MobileTheme.muted,
                      fontSize: detailFontSize,
                      height: 1.45,
                    ),
                  ),
                ],
                if (cost != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    cost!,
                    style: TextStyle(
                      color: MobileTheme.mint,
                      fontSize: costFontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (busy)
            const Icon(
              Icons.hourglass_top_rounded,
              size: 18,
              color: MobileTheme.mint,
            )
          else
            Icon(
              enabled
                  ? Icons.chevron_right_rounded
                  : Icons.lock_outline_rounded,
              size: 20,
              color: enabled ? MobileTheme.mint : MobileTheme.muted,
            ),
        ],
      ),
    );
  }
}
