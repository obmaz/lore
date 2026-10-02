import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import 'retro_box.dart';

/// 왼쪽 상단: 메인 뷰포트 (맵 타일 또는 전투 장면 표시용 컨테이너)
class ViewportView extends StatelessWidget {
  final Widget? content;
  final String title;
  final bool overlayTitle;

  const ViewportView({
    super.key,
    this.content,
    this.title = '◆ 메인 뷰포트 (MAIN VIEW) ◆',
    this.overlayTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (overlayTitle) {
      return Container(
        decoration: BoxDecoration(
          color: RetroTheme.viewportBg,
          border: Border.all(color: RetroTheme.lightBlue, width: 2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ?content,
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
      title: title,
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
                Text(
                  '또 다른 지식의 성전 (1993)',
                  style: RetroTheme.headerFont.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  '뷰포트 대기 모드 (Phase 2 초기화 완료)',
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.lightGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
