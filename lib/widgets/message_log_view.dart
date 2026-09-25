import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import 'retro_box.dart';

/// 하단: 최신 메시지가 맨 위에 표시되는 도스 콘솔 텍스트 메시지 로그 뷰
class MessageLogView extends StatefulWidget {
  final List<String> logs;

  const MessageLogView({super.key, required this.logs});

  @override
  State<MessageLogView> createState() => _MessageLogViewState();
}

class _MessageLogViewState extends State<MessageLogView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant MessageLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs.length != oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // 최신 메시지가 맨 위에 위치하므로 항상 맨 위(0.0)로 스크롤
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 최신 메시지가 가장 위에 오도록 역순(reversed) 리스트 생성
    final reversedLogs = widget.logs.reversed.toList();

    return RetroBox(
      title: '▶ 콘솔 메시지 (최신 메시지 상단 표시) ◀',
      borderColor: RetroTheme.cyan,
      backgroundColor: RetroTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: reversedLogs.isEmpty
          ? Text(
              '명령을 기다리고 있습니다...',
              style: RetroTheme.logFont.copyWith(color: RetroTheme.darkGray),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: reversedLogs.length,
              itemBuilder: (context, index) {
                final text = reversedLogs[index];
                final isLatest = index == 0; // 맨 위가 최신 메시지

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLatest ? '▶ ' : '  · ',
                        style: RetroTheme.dosFont.copyWith(
                          color: isLatest
                              ? RetroTheme.yellow
                              : RetroTheme.darkGray,
                          fontSize: 12,
                          fontWeight: isLatest
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          text,
                          style: RetroTheme.logFont.copyWith(
                            color: isLatest
                                ? RetroTheme.yellow
                                : RetroTheme.lightCyan,
                            fontSize: 12,
                            fontWeight: isLatest
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
