import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import 'retro_box.dart';
import 'lore_panel_frame.dart';
import '../theme/mobile_theme.dart';

/// 왼쪽 상단: 메인 뷰포트 (맵 타일 또는 전투 장면 표시용 컨테이너)
class ViewportView extends StatelessWidget {
  final Widget? content;
  final String title;
  final bool overlayTitle;
  final bool sourceReplay;

  const ViewportView({
    super.key,
    this.content,
    this.title = '',
    this.overlayTitle = false,
    this.sourceReplay = false,
  });

  @override
  Widget build(BuildContext context) {
    final panel = _buildPanel(context);
    return sourceReplay
        ? CustomPaint(
            foregroundPainter: LorePanelFramePainter(LorePanelFrame.viewport),
            child: panel,
          )
        : panel;
  }

  Widget _buildPanel(BuildContext context) {
    if (overlayTitle) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: RetroTheme.viewportBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MobileTheme.line),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ?content,
            if (title.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    color: RetroTheme.background.withValues(alpha: .65),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      title,
                      style: RetroTheme.headerFont.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return RetroBox(
      title: title.isEmpty ? null : title,
      borderColor: RetroTheme.lightBlue,
      backgroundColor: RetroTheme.viewportBg,
      padding: EdgeInsets.zero,
      child:
          content ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 48,
                  color: RetroTheme.lightBlue,
                ),
                const SizedBox(height: 12),
                Text('', style: RetroTheme.headerFont.copyWith(fontSize: 16)),
              ],
            ),
          ),
    );
  }
}
