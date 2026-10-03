import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/retro_theme.dart';

/// [LoreSelectView] in a dialog: the `Select` result, 0 for Esc. The close
/// icon is the touch equivalent of Esc.
Future<int> showLoreSelectDialog(
  BuildContext context, {
  required String title,
  required List<String> items,
  int? maxsum,
}) async {
  final k = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: RetroTheme.black,
      shape: Border.all(color: RetroTheme.lightCyan, width: 2),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              key: const ValueKey('dialog-cancel'),
              onPressed: () => Navigator.of(ctx).pop(0),
              icon: const Icon(
                Icons.close,
                size: 16,
                color: RetroTheme.lightRed,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: LoreSelectView(
                title: title,
                items: items,
                maxsum: maxsum,
                onSelected: (k) => Navigator.of(ctx).pop(k),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return k ?? 0;
}

/// `LORESUB.PAS` `Select(yinit, maxsum, total, clean, lastclean)` 의 화면 어댑터.
///
/// `m[0]`([title])은 색 12, `m[1..total]`([items]) 중 처음 [maxsum]개만 고를 수
/// 있고 나머지는 색 0으로 그린다. 커서는 1번에서 시작해 위/아래 화살표로
/// `1..maxsum` 안을 돌며(`maxsum`이 0이어도 1번은 고를 수 있다), Enter/Space는
/// 현재 번호, Esc는 0을 [onSelected]로 돌려준다. 터치/마우스로 항목을 누르면
/// 그 번호를 바로 고른다(키보드가 없는 환경의 입력 어댑터).
class LoreSelectView extends StatefulWidget {
  const LoreSelectView({
    super.key,
    required this.title,
    required this.items,
    required this.onSelected,
    int? maxsum,
  }) : maxsum = maxsum ?? items.length;

  final String title;
  final List<String> items;
  final int maxsum;
  final ValueChanged<int> onSelected;

  @override
  State<LoreSelectView> createState() => _LoreSelectViewState();
}

class _LoreSelectViewState extends State<LoreSelectView> {
  int _k = 1;
  bool _done = false;

  // `autofocus` only applies when nothing in the scope has focus; the game
  // screen's key listener always does, so the select takes focus itself.
  final FocusNode _focus = FocusNode(debugLabel: 'LoreSelect');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _choose(int k) {
    if (_done) return;
    _done = true;
    widget.onSelected(k);
  }

  void _move(int delta) {
    setState(() {
      _k += delta;
      if (_k < 1) _k = widget.maxsum;
      if (_k > widget.maxsum) _k = 1;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _choose(_k);
    } else if (key == LogicalKeyboardKey.escape) {
      _choose(0);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.title,
                style: RetroTheme.dosFont.copyWith(color: RetroTheme.ega(12)),
              ),
            ),
          for (var i = 1; i <= widget.items.length; i++)
            GestureDetector(
              key: ValueKey('lore-select-$i'),
              behavior: HitTestBehavior.opaque,
              onTap: i == 1 || i <= widget.maxsum ? () => _choose(i) : null,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 2),
                child: Text(
                  widget.items[i - 1],
                  style: RetroTheme.dosFont.copyWith(
                    color: i == _k
                        ? RetroTheme.ega(15)
                        : i > 1 && i > widget.maxsum
                        ? RetroTheme.ega(0)
                        : RetroTheme.ega(7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
