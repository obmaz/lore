import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import 'retro_box.dart';

/// 하단 콘솔: 이전 메시지부터 최신 메시지까지 순서대로 표시한다.
class MessageLogView extends StatefulWidget {
  final List<String> logs;
  final int revision;

  const MessageLogView({super.key, required this.logs, required this.revision});

  @override
  State<MessageLogView> createState() => _MessageLogViewState();
}

class _MessageLogViewState extends State<MessageLogView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToLatest(animate: false);
  }

  void _scrollToLatest({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final end = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          end,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(end);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MessageLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision) _scrollToLatest(animate: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RetroBox(
      borderColor: RetroTheme.borderColor,
      backgroundColor: RetroTheme.panelBg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: widget.logs.isEmpty
          ? Text(
              '',
              style: RetroTheme.logFont.copyWith(
                color: RetroTheme.dialogueTextColor,
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: widget.logs.length,
              itemBuilder: (context, index) {
                final text = widget.logs[index];
                final isLatest = index == widget.logs.length - 1;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLatest ? '▶ ' : '  · ',
                        style: RetroTheme.dosFont.copyWith(
                          color: RetroTheme.dialogueTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          text,
                          style: RetroTheme.logFont.copyWith(
                            color: RetroTheme.dialogueTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
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
