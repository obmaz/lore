import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import 'retro_box.dart';
import 'lore_source_text.dart';

/// 하단 콘솔: 이전 메시지부터 최신 메시지까지 순서대로 표시한다.
class MessageLogView extends StatefulWidget {
  final List<String> logs;
  final int revision;
  final List<int> colors;

  const MessageLogView({
    super.key,
    required this.logs,
    required this.revision,
    this.colors = const [],
  });

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
      borderColor: RetroTheme.cyan,
      backgroundColor: RetroTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: widget.logs.isEmpty
          ? Text(
              '',
              style: RetroTheme.logFont.copyWith(color: RetroTheme.darkGray),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: widget.logs.length,
              itemBuilder: (context, index) {
                final text = widget.logs[index];
                final color = index < widget.colors.length
                    ? widget.colors[index]
                    : 7;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: loreSourceText(
                    text,
                    RetroTheme.logFont.copyWith(
                      color: RetroTheme.ega(color),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
