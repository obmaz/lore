import 'package:flutter/material.dart';

import '../theme/mobile_theme.dart';

class MobileArt extends StatelessWidget {
  const MobileArt(
    this.name, {
    super.key,
    this.size = 48,
    this.fit = BoxFit.contain,
  });
  final String name;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/images/ui/$name.png',
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (_, _, _) =>
          Icon(Icons.auto_awesome, size: size, color: MobileTheme.mint),
    ),
  );

  /// Art is illustrative, never an index into source records or game rules.
  static String portrait(String name, {int? classId}) {
    if (name == 'Hercules') return 'warrior';
    if (name == 'Merlin') return 'mage';
    if (name == 'Genius Kie') return 'monk';
    if (name == 'Regulus') return 'knight';
    if (classId == 2) return 'wizard';
    if (classId == 5) return 'monk';
    if (classId == 4) return 'warrior';
    return 'hero';
  }
}

class ArtButton extends StatelessWidget {
  const ArtButton({
    super.key,
    required this.art,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.semanticLabel,
    this.horizontal = false,
  });
  final String art, label;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final bool primary, horizontal;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    button: true,
    child: Material(
      color: primary ? MobileTheme.gold : MobileTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: primary ? MobileTheme.goldLine : MobileTheme.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: horizontal
                ? Row(
                    children: [
                      MobileArt(art, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: MobileTheme.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: MobileTheme.muted),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MobileArt(art, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: MobileTheme.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}

/// Keeps literal EGA Text/TextSpan metadata intact for replay, but gives source
/// text dark ink on ivory panels. Never used for the map or original endings.
class SourceInk extends StatelessWidget {
  const SourceInk({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: const ColorFilter.mode(MobileTheme.ink, BlendMode.srcIn),
    child: child,
  );
}
