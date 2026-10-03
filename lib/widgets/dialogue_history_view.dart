import 'package:flutter/material.dart';

import '../logic/lore_dialogue_history.dart';
import '../theme/retro_theme.dart';
import 'retro_box.dart';

/// `이전 대화` 탭: 지나간 NPC 대사를 줄 그대로 한 덩어리씩, 오래된 것부터
/// 최신 순으로 보여 준다(원작의 대사 창과 같은 글자색 7).
class DialogueHistoryView extends StatefulWidget {
  final LoreDialogueHistory history;

  const DialogueHistoryView({super.key, required this.history});

  @override
  State<DialogueHistoryView> createState() => _DialogueHistoryViewState();
}

class _DialogueHistoryViewState extends State<DialogueHistoryView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.history.addListener(_changed);
    _toLatest(animate: false);
  }

  @override
  void didUpdateWidget(covariant DialogueHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history != widget.history) {
      oldWidget.history.removeListener(_changed);
      widget.history.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.history.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _toLatest(animate: true);
  }

  final GlobalKey _lastBlock = GlobalKey();

  /// Shows the newest speech from its first line (a long speech may be taller
  /// than the panel; the older ones stay above it).
  void _toLatest({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _lastBlock.currentContext;
      if (!mounted || context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0,
        duration: animate ? const Duration(milliseconds: 150) : Duration.zero,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.history.blocks;
    return RetroBox(
      borderColor: RetroTheme.cyan,
      backgroundColor: RetroTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: SingleChildScrollView(
        key: const ValueKey('dialogue-history-list'),
        controller: _scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < blocks.length; index++)
              Padding(
                key: index == blocks.length - 1 ? _lastBlock : null,
                padding: EdgeInsets.only(
                  bottom: index == blocks.length - 1 ? 0 : 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in blocks[index])
                      Text(
                        line,
                        style: RetroTheme.dosFont.copyWith(
                          color: RetroTheme.ega(7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
