import 'package:flutter/material.dart';
import '../theme/retro_theme.dart';
import 'retro_box.dart';

/// 하단: 3~4줄 분량의 도스 콘솔 텍스트 메시지 로그 스크롤 영역
class MessageLogView extends StatefulWidget {
  final List<String> logs;

  const MessageLogView({
    super.key,
    required this.logs,
  });

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
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
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
    return RetroBox(
      title: '▶ 콘솔 메시지 (MESSAGE LOG) ◀',
      borderColor: RetroTheme.cyan,
      backgroundColor: RetroTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: widget.logs.isEmpty
          ? Text(
              '명령을 기다리고 있습니다...',
              style: RetroTheme.logFont.copyWith(color: RetroTheme.darkGray),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: widget.logs.length,
              itemBuilder: (context, index) {
                final text = widget.logs[index];
                final isLast = index == widget.logs.length - 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ' > ',
                        style: RetroTheme.dosFont.copyWith(
                          color: isLast ? RetroTheme.yellow : RetroTheme.darkGray,
                          fontSize: 12,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          text,
                          style: RetroTheme.logFont.copyWith(
                            color: isLast ? RetroTheme.white : RetroTheme.lightCyan,
                            fontSize: 12,
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
