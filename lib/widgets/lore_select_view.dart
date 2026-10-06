import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/lore_sub_text.dart';
import '../theme/retro_theme.dart';
import 'lore_source_text.dart';

/// [LoreSelectView] in a dialog: the `Select` result, 0 for Esc. The close
/// icon is the touch equivalent of Esc.
///
/// [lines] are the `HPrintXY` texts the caller printed above the select
/// (`Select(.., clean = FALSE, ..)` keeps them), as (color, text).
Future<int> showLoreSelectDialog(
  BuildContext context, {
  required String title,
  required List<String> items,
  int? maxsum,
  List<(int, String)> lines = const [],
}) async {
  final k = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: RetroTheme.panelBg,
      shape: Border.all(color: RetroTheme.lightCyan, width: 2),
      child: SingleChildScrollView(
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
              for (final (color, text) in lines)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: loreSourceText(
                      text,
                      RetroTheme.dosFont.copyWith(color: RetroTheme.ega(color)),
                    ),
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
    ),
  );
  return k ?? 0;
}

/// Texts printed in the window followed by `PressAnyKey`
/// (`아무키나 누르십시오 ...`); any key or a tap closes it.
Future<void> showLoreMessageDialog(
  BuildContext context, {
  required List<(int, String)> lines,
  bool transparentBarrier = false,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: transparentBarrier ? Colors.transparent : null,
  builder: (ctx) => LoreMessageDialog(lines: lines),
);

class LoreMessageDialog extends StatefulWidget {
  const LoreMessageDialog({
    super.key,
    required this.lines,
    this.leading = const [],
    this.acknowledgementKey,
  });

  final List<(int, String)> lines;
  final List<Widget> leading;
  final Key? acknowledgementKey;

  @override
  State<LoreMessageDialog> createState() => LoreMessageDialogState();
}

class LoreMessageDialogState extends State<LoreMessageDialog> {
  final FocusNode _focus = FocusNode(debugLabel: 'PressAnyKey');
  bool _closed = false;

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

  void _close() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      _close();
      return KeyEventResult.handled;
    },
    child: Dialog(
      backgroundColor: RetroTheme.panelBg,
      shape: Border.all(color: RetroTheme.lightCyan, width: 2),
      child: GestureDetector(
        key: const ValueKey('lore-press-any-key'),
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Padding(
          padding: const EdgeInsets.all(16),
          // A long speech may be taller than a short screen: it scrolls.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...widget.leading,
                for (final (color, text) in widget.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: loreSourceText(
                      text,
                      RetroTheme.dosFont.copyWith(color: RetroTheme.ega(color)),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  key: widget.acknowledgementKey,
                  LoreSubText.pressAnyKey,
                  style: RetroTheme.dosFont.copyWith(color: RetroTheme.ega(14)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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

/// PhenominaSpell 7's power input: `당신의 공간 이동력을 지정` and
/// `## k000 공간 이동력` with k from 5; Left/Down lower and Up/Right raise it
/// within 1..9, Enter returns k and Esc null. The +/- and ✓/✕ icons are the
/// touch equivalents of those keys.
Future<int?> showLoreSpacePowerDialog(BuildContext context) => showDialog<int>(
  context: context,
  barrierDismissible: false,
  builder: (ctx) => const _SpacePowerDialog(),
);

class _SpacePowerDialog extends StatefulWidget {
  const _SpacePowerDialog();

  @override
  State<_SpacePowerDialog> createState() => _SpacePowerDialogState();
}

class _SpacePowerDialogState extends State<_SpacePowerDialog> {
  final FocusNode _focus = FocusNode(debugLabel: 'SpacePower');
  int _k = 5;

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

  void _step(int j) {
    final k = _k + j;
    if (k < 1 || k > 9) return;
    setState(() => _k = k);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _step(-1);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowRight) {
      _step(1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      Navigator.of(context).pop(_k);
    } else if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    autofocus: true,
    onKeyEvent: _onKey,
    child: Dialog(
      backgroundColor: RetroTheme.panelBg,
      shape: Border.all(color: RetroTheme.lightCyan, width: 2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '당신의 공간 이동력을 지정',
              style: RetroTheme.dosFont.copyWith(color: RetroTheme.ega(11)),
            ),
            const SizedBox(height: 8),
            Text.rich(
              key: const ValueKey('space-power'),
              TextSpan(
                style: RetroTheme.dosFont.copyWith(color: RetroTheme.ega(15)),
                children: [
                  const TextSpan(text: '## '),
                  TextSpan(
                    text: '${_k}000',
                    style: TextStyle(color: RetroTheme.ega(10)),
                  ),
                  const TextSpan(text: ' 공간 이동력'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('space-power-down'),
                  onPressed: () => _step(-1),
                  icon: const Icon(Icons.remove, size: 16),
                ),
                IconButton(
                  key: const ValueKey('space-power-up'),
                  onPressed: () => _step(1),
                  icon: const Icon(Icons.add, size: 16),
                ),
                IconButton(
                  key: const ValueKey('space-power-ok'),
                  onPressed: () => Navigator.of(context).pop(_k),
                  icon: const Icon(Icons.check, size: 16),
                ),
                IconButton(
                  key: const ValueKey('dialog-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: RetroTheme.lightRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 천리안's `print(15,'천리안의 사용중 ...')` and `아무키나 누르시오 ...` shown
/// over the map while the view scrolls; every key (Esc = true in [press]'s
/// `escape`) or tap releases the wait of [LoreKeyWait.next].
class LoreKeyWait {
  Completer<bool>? _wait;
  bool _closed = false;

  /// Completes with true when the key was Esc.
  Future<bool> next() {
    if (_closed) return Future.value(true);
    final wait = Completer<bool>();
    _wait = wait;
    return wait.future;
  }

  /// Route removal must release the procedure even without a final key.
  void close() {
    _closed = true;
    press(escape: true);
  }

  void press({bool escape = false}) {
    final wait = _wait;
    _wait = null;
    if (wait != null && !wait.isCompleted) wait.complete(escape);
  }
}

/// Opens the overlay and exposes its own route for scoped cleanup.
Future<void> showLoreKeyWaitOverlay(
  BuildContext context, {
  required LoreKeyWait wait,
  required List<(int, String)> lines,
  void Function(DialogRoute<void> route)? onRoute,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: (ctx) => _KeyWaitOverlay(wait: wait, lines: lines),
  );
  onRoute?.call(route);
  return navigator.push(route).whenComplete(wait.close);
}

class _KeyWaitOverlay extends StatefulWidget {
  const _KeyWaitOverlay({required this.wait, required this.lines});

  final LoreKeyWait wait;
  final List<(int, String)> lines;

  @override
  State<_KeyWaitOverlay> createState() => _KeyWaitOverlayState();
}

class _KeyWaitOverlayState extends State<_KeyWaitOverlay> {
  final FocusNode _focus = FocusNode(debugLabel: 'KeyWaitOverlay');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.wait.close();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      widget.wait.press(escape: event.logicalKey == LogicalKeyboardKey.escape);
      return KeyEventResult.handled;
    },
    child: GestureDetector(
      key: const ValueKey('lore-key-wait'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.wait.press,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          color: RetroTheme.black.withValues(alpha: 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (color, text) in widget.lines)
                Text(
                  text,
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.ega(color),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
