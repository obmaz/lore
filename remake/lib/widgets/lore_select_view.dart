import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/lore_main_input.dart';
import '../theme/retro_theme.dart';
import 'lore_source_text.dart';
import 'mobile_content_dialog.dart';
import 'mobile_dialog_action.dart';
import 'mobile_choice_tile.dart';
import 'mobile_art.dart';
import '../theme/mobile_theme.dart';

/// DOS ReadKey receives typematic input, but lone modifiers/lock toggles
/// do not enqueue a byte. Extended keys arrive as one Flutter event.
bool isLoreReadKeyEvent(KeyEvent event) =>
    (event is KeyDownEvent || event is KeyRepeatEvent) &&
    !const [
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
      LogicalKeyboardKey.capsLock,
      LogicalKeyboardKey.numLock,
      LogicalKeyboardKey.scrollLock,
    ].contains(event.logicalKey);

/// [LoreSelectView] in a dialog: the `Select` result, 0 for Esc. The close
/// button is the touch equivalent of Esc.
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
  var selectedKey = LogicalKeyboardKey.enter;
  final k = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => MobileContentDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: loreDialogueText(lines),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: LoreSelectView(
              title: title,
              items: items,
              maxsum: maxsum,
              mobile: true,
              onKeySelected: (key) => selectedKey = key,
              onSelected: (k) => Navigator.of(ctx).pop(k),
            ),
          ),
        ],
      ),
      footer: MobileDialogAction(
        key: const ValueKey('dialog-cancel'),
        label: '돌아가기',
        secondary: true,
        onPressed: () => Navigator.of(ctx).pop(0),
      ),
    ),
  );
  final result = k ?? 0;
  LoreMainInput.record(
    escape: result == 0,
    space: result != 0 && selectedKey == LogicalKeyboardKey.space,
  );
  return result;
}

/// Texts printed in the window followed by `PressAnyKey`
/// (`아무키나 누르십시오 ...`); any key or a tap closes it.
Future<void> showLoreMessageDialog(
  BuildContext context, {
  required List<(int, String)> lines,
  bool transparentBarrier = false,
}) async {
  final input = LoreMainInput.current;
  var acknowledged = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: transparentBarrier ? Colors.transparent : null,
    builder: (ctx) => LoreMessageDialog(
      lines: lines,
      onKeyAcknowledged: (key) {
        acknowledged = true;
        input?.read(
          escape: key == LogicalKeyboardKey.escape,
          space: key == LogicalKeyboardKey.space,
          backspace: key == LogicalKeyboardKey.backspace,
          tab: key == LogicalKeyboardKey.tab,
        );
      },
    ),
  );
  // System back/route removal is the touch equivalent of Esc too.
  if (!acknowledged) input?.read(escape: true);
}

class LoreMessageDialog extends StatefulWidget {
  const LoreMessageDialog({
    super.key,
    required this.lines,
    this.leading = const [],
    this.acknowledgementKey,
    this.onAcknowledged,
    this.onKeyAcknowledged,
    this.closeOnAcknowledgement = true,
  });

  final List<(int, String)> lines;
  final List<Widget> leading;
  final Key? acknowledgementKey;
  final void Function(bool escape)? onAcknowledged;
  final void Function(LogicalKeyboardKey key)? onKeyAcknowledged;
  final bool closeOnAcknowledgement;

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

  void _close({LogicalKeyboardKey key = LogicalKeyboardKey.enter}) {
    if (_closed) return;
    _closed = true;
    if (!widget.closeOnAcknowledgement) setState(() {});
    widget.onAcknowledged?.call(key == LogicalKeyboardKey.escape);
    widget.onKeyAcknowledged?.call(key);
    if (widget.closeOnAcknowledgement) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    autofocus: true,
    onKeyEvent: (_, event) {
      if (!isLoreReadKeyEvent(event)) return KeyEventResult.ignored;
      _close(key: event.logicalKey);
      return KeyEventResult.handled;
    },
    child: MobileContentDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...widget.leading,
          if (widget.lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: loreDialogueText(widget.lines),
            ),
        ],
      ),
      footer: SizedBox(
        key: widget.acknowledgementKey,
        child: MobileDialogAction(
          key: const ValueKey('lore-press-any-key'),
          label: '계속',
          onPressed: _closed ? null : _close,
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
    this.onKeySelected,
    this.mobile = false,
    int? maxsum,
  }) : maxsum = maxsum ?? items.length;

  final String title;
  final List<String> items;
  final int maxsum;
  final ValueChanged<int> onSelected;
  final ValueChanged<LogicalKeyboardKey>? onKeySelected;
  final bool mobile;

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

  void _choose(int k, {LogicalKeyboardKey key = LogicalKeyboardKey.enter}) {
    if (_done) return;
    _done = true;
    widget.onKeySelected?.call(key);
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
      _choose(_k, key: key);
    } else if (key == LogicalKeyboardKey.escape) {
      _choose(0, key: key);
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
              child: SourceInk(
                child: Text(
                  widget.title,
                  style: RetroTheme.dosFont.copyWith(color: RetroTheme.ega(12)),
                ),
              ),
            ),
          for (var i = 1; i <= widget.items.length; i++)
            if (widget.mobile)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MobileChoiceTile(
                  key: ValueKey('lore-select-$i'),
                  label: widget.items[i - 1],
                  selected: i == _k,
                  onPressed: i == 1 || i <= widget.maxsum
                      ? () => _choose(i)
                      : null,
                  labelWidget: SourceInk(
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
              )
            else
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
Future<int?> showLoreSpacePowerDialog(BuildContext context) async {
  final result = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _SpacePowerDialog(),
  );
  LoreMainInput.record(escape: result == null);
  return result;
}

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
    child: MobileContentDialog(
      title: '당신의 공간 이동력을 지정',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '이동력을 조절한 뒤 확인하세요.',
            style: TextStyle(color: MobileTheme.muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('space-power-down'),
                tooltip: '이동력 줄이기',
                onPressed: _k > 1 ? () => _step(-1) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Center(
                  child: SourceInk(
                    child: Text.rich(
                      key: const ValueKey('space-power'),
                      TextSpan(
                        style: RetroTheme.dosFont.copyWith(
                          color: RetroTheme.ega(15),
                        ),
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
                  ),
                ),
              ),
              IconButton.filledTonal(
                key: const ValueKey('space-power-up'),
                tooltip: '이동력 늘리기',
                onPressed: _k < 9 ? () => _step(1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Slider(
            min: 1,
            max: 9,
            divisions: 8,
            value: _k.toDouble(),
            label: '${_k}000',
            semanticFormatterCallback: (value) => '${value.round()}000 이동력',
            onChanged: (value) => setState(() => _k = value.round()),
          ),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: MobileDialogAction(
              key: const ValueKey('dialog-cancel'),
              label: '돌아가기',
              secondary: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MobileDialogAction(
              key: const ValueKey('space-power-ok'),
              label: '확인',
              onPressed: () => Navigator.of(context).pop(_k),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 천리안's `print(15,'천리안의 사용중 ...')` and `아무키나 누르시오 ...` shown
/// over the map while the view scrolls; every key (Esc = true in [press]'s
/// `escape`) or tap releases the wait of [LoreKeyWait.next].
class LoreKeyWait {
  Completer<({bool escape, bool space, bool backspace, bool tab})>? _wait;
  bool _closed = false;

  /// Completes with true when the key was Esc.
  Future<bool> next() async {
    if (_closed) return Future.value(true);
    final wait =
        Completer<({bool escape, bool space, bool backspace, bool tab})>();
    _wait = wait;
    final key = await wait.future;
    LoreMainInput.record(
      escape: key.escape,
      space: key.space,
      backspace: key.backspace,
      tab: key.tab,
    );
    return key.escape;
  }

  /// Route removal must release the procedure even without a final key.
  void close() {
    _closed = true;
    press(escape: true);
  }

  void press({
    bool escape = false,
    bool space = false,
    bool backspace = false,
    bool tab = false,
  }) {
    final wait = _wait;
    _wait = null;
    if (wait != null && !wait.isCompleted) {
      wait.complete((
        escape: escape,
        space: space,
        backspace: backspace,
        tab: tab,
      ));
    }
  }
}

/// Opens the overlay and exposes its own route for scoped cleanup.
Future<void> showLoreKeyWaitOverlay(
  BuildContext context, {
  required LoreKeyWait wait,
  required List<(int, String)> lines,
  bool mobile = false,
  void Function(DialogRoute<void> route)? onRoute,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: (ctx) => _KeyWaitOverlay(wait: wait, lines: lines, mobile: mobile),
  );
  onRoute?.call(route);
  return navigator.push(route).whenComplete(wait.close);
}

class _KeyWaitOverlay extends StatefulWidget {
  const _KeyWaitOverlay({
    required this.wait,
    required this.lines,
    required this.mobile,
  });

  final LoreKeyWait wait;
  final List<(int, String)> lines;
  final bool mobile;

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
      if (!isLoreReadKeyEvent(event)) return KeyEventResult.ignored;
      widget.wait.press(
        escape: event.logicalKey == LogicalKeyboardKey.escape,
        space: event.logicalKey == LogicalKeyboardKey.space,
        backspace: event.logicalKey == LogicalKeyboardKey.backspace,
        tab: event.logicalKey == LogicalKeyboardKey.tab,
      );
      return KeyEventResult.handled;
    },
    child: widget.mobile
        ? MobileContentDialog(
            contentPadding: const EdgeInsets.all(12),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '천리안 · 지도 살펴보기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  '다음 보기를 누르면 선택한 방향으로 더 멀리 봅니다.',
                  style: TextStyle(fontSize: 12, color: MobileTheme.muted),
                ),
              ],
            ),
            footer: Row(
              children: [
                Expanded(
                  child: MobileDialogAction(
                    label: '보기 종료',
                    secondary: true,
                    onPressed: () => widget.wait.press(escape: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MobileDialogAction(
                    label: '다음 보기',
                    onPressed: widget.wait.press,
                  ),
                ),
              ],
            ),
          )
        : GestureDetector(
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
