import 'package:flutter/material.dart';

import '../theme/mobile_theme.dart';
import 'mobile_art.dart';

/// Fits short content and scrolls long content, with an always-visible footer.
class MobileContentDialog extends StatelessWidget {
  const MobileContentDialog({
    super.key,
    required this.content,
    this.footer,
    this.title,
    this.maxWidth = 600,
    this.scrollContent = true,
    this.contentPadding = const EdgeInsets.all(16),
  });

  final Widget content;
  final Widget? footer;
  final String? title;
  final double maxWidth;
  final bool scrollContent;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) => Theme(
    data: MobileTheme.theme,
    child: Dialog(
      backgroundColor: MobileTheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      alignment: MediaQuery.sizeOf(context).width < 600
          ? Alignment.bottomCenter
          : Alignment.center,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: MobileTheme.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: SizedBox(
          width: maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [MobileTheme.mintLight, MobileTheme.surface],
                    ),
                    border: Border(bottom: BorderSide(color: MobileTheme.line)),
                  ),
                  child: Row(
                    children: [
                      const MobileArt('crystal', size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title!,
                          style: const TextStyle(
                            color: MobileTheme.ink,
                            fontSize: 18,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Flexible(
                child: scrollContent
                    ? Scrollbar(
                        child: SingleChildScrollView(
                          padding: contentPadding,
                          child: content,
                        ),
                      )
                    : Padding(padding: contentPadding, child: content),
              ),
              if (footer != null)
                Container(
                  decoration: const BoxDecoration(
                    color: MobileTheme.surface,
                    border: Border(top: BorderSide(color: MobileTheme.line)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
