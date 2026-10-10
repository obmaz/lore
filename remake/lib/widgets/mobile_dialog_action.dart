import 'package:flutter/material.dart';

import '../theme/mobile_theme.dart';

/// A thumb-sized action kept at the bottom edge of a mobile dialog.
class MobileDialogAction extends StatelessWidget {
  const MobileDialogAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: secondary
        ? OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: MobileTheme.ink,
              backgroundColor: MobileTheme.mintLight,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onPressed,
            child: Text(label),
          )
        : ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MobileTheme.gold,
              foregroundColor: MobileTheme.ink,
            ),
            onPressed: onPressed,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
  );
}
