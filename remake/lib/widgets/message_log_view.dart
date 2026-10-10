import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import 'retro_box.dart';
import 'lore_panel_frame.dart';
import 'lore_source_text.dart';

/// 하단 콘솔: 이전 메시지부터 최신 메시지까지 순서대로 표시한다.
class MessageLogView extends StatefulWidget {
  final List<String> logs;
  final int revision;
  final List<int> colors;
  final bool sourceReplay;

  const MessageLogView({
    super.key,
    required this.logs,
    required this.revision,
    this.colors = const [],
    this.sourceReplay = false,
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
    final panel = _buildPanel(context);
    return widget.sourceReplay
        ? CustomPaint(
            foregroundPainter: LorePanelFramePainter(LorePanelFrame.message),
            child: panel,
          )
        : panel;
  }

  Widget _buildPanel(BuildContext context) {
    return RetroBox(
      title: '메시지',
      borderColor: RetroTheme.cyan,
      backgroundColor: RetroTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: widget.logs.isEmpty
          ? Text(
              '',
              style: RetroTheme.logFont.copyWith(color: RetroTheme.darkGray),
            )
          : SingleChildScrollView(
              key: const ValueKey('message-log-list'),
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < widget.logs.length; index++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: loreSourceText(
                        widget.logs[index],
                        RetroTheme.logFont.copyWith(
                          color: RetroTheme.ega(
                            index < widget.colors.length
                                ? widget.colors[index]
                                : 7,
                          ),
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
