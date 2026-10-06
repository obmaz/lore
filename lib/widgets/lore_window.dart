import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/lore_sub_text.dart';
import '../logic/lore_window_io.dart';
import '../theme/retro_theme.dart';
import 'lore_select_view.dart';
import 'lore_source_text.dart';

/// State of the original's right-hand text window: the printed lines, the
/// active `Select` and the `PressAnyKey` wait. [LoreWindowView] draws it.
class LoreWindowController extends ChangeNotifier implements LoreWindowIo {
  final List<(int, String)> _lines = [];
  ({String title, List<String> items, int maxsum, Completer<int> done})?
  _select;
  Completer<void>? _keyWait;
  int _selectSerial = 0;

  List<(int, String)> get lines => List.unmodifiable(_lines);
  int get selectSerial => _selectSerial;
  bool get waitingForKey => _keyWait != null;
  ({String title, List<String> items, int maxsum, Completer<int> done})?
  get activeSelect => _select;

  @override
  void clear() {
    _lines.clear();
    notifyListeners();
  }

  @override
  void print(int color, String text) {
    _lines.add((color, text));
    notifyListeners();
  }

  @override
  Future<void> pressAnyKey() async {
    final wait = Completer<void>();
    _keyWait = wait;
    notifyListeners();
    await wait.future;
    _keyWait = null;
    clear();
  }

  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  }) async {
    if (clean) _lines.clear();
    final done = Completer<int>();
    _selectSerial++;
    _select = (
      title: title,
      items: items,
      maxsum: maxsum ?? items.length,
      done: done,
    );
    notifyListeners();
    final k = await done.future;
    _select = null;
    clear(); // lastclean = TRUE
    return k;
  }

  /// A key (or tap) at `PressAnyKey`.
  void releaseKey() {
    final wait = _keyWait;
    if (wait != null && !wait.isCompleted) wait.complete();
  }

  /// Esc (the close icon, the system back button): 0 for an active `Select`,
  /// any key for a `PressAnyKey`.
  void escape() {
    final select = _select;
    if (select != null && !select.done.isCompleted) {
      select.done.complete(0);
    } else {
      releaseKey();
    }
  }
}

class LoreWindowView extends StatefulWidget {
  const LoreWindowView({super.key, required this.controller});

  final LoreWindowController controller;

  @override
  State<LoreWindowView> createState() => _LoreWindowViewState();
}

class _LoreWindowViewState extends State<LoreWindowView> {
  final FocusNode _keyFocus = FocusNode(debugLabel: 'PressAnyKey');
  bool _hadKeyWait = false;

  @override
  void dispose() {
    _keyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final select = c.activeSelect;
      if (c.waitingForKey && !_hadKeyWait) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _keyFocus.requestFocus();
        });
      }
      _hadKeyWait = c.waitingForKey;
      return Container(
        color: RetroTheme.panelBg,
        padding: const EdgeInsets.all(16),
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (select != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const ValueKey('dialog-cancel'),
                    onPressed: c.escape,
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: RetroTheme.lightRed,
                    ),
                  ),
                ),
              for (final (color, text) in c.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: loreSourceText(
                    text,
                    RetroTheme.dosFont.copyWith(color: RetroTheme.ega(color)),
                  ),
                ),
              if (select != null)
                LoreSelectView(
                  key: ValueKey('lore-window-select-${c.selectSerial}'),
                  title: select.title,
                  items: select.items,
                  maxsum: select.maxsum,
                  onSelected: (k) {
                    if (!select.done.isCompleted) select.done.complete(k);
                  },
                ),
              if (c.waitingForKey)
                Focus(
                  focusNode: _keyFocus,
                  autofocus: true,
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent) {
                      c.releaseKey();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: GestureDetector(
                    key: const ValueKey('lore-window-press-any-key'),
                    behavior: HitTestBehavior.opaque,
                    onTap: c.releaseKey,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        LoreSubText.pressAnyKey,
                        style: RetroTheme.dosFont.copyWith(
                          color: RetroTheme.ega(14),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Opens the window in a dialog, runs [run] with its controller and closes
/// it. The text still printed when [run] ends (a `Message` before `exit`)
/// is handed to [onClose]: the original leaves it in the window until the next
/// `Clear`, the message log is its closest persistent place.
Future<void> showLoreWindow(
  BuildContext context, {
  required Future<void> Function(LoreWindowController window) run,
  required void Function(List<(int, String)> remaining) onClose,
}) async {
  final controller = LoreWindowController();
  final navigator = Navigator.of(context);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    // The system back button must not pop the route under `run`: it is Esc.
    builder: (_) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.escape();
      },
      child: Dialog(
        backgroundColor: RetroTheme.panelBg,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        child: SizedBox(
          width: 520,
          height: 360,
          child: LoreWindowView(controller: controller),
        ),
      ),
    ),
  );
  unawaited(navigator.push(route));
  try {
    await run(controller);
  } finally {
    final remaining = controller.lines;
    if (route.isActive) navigator.removeRoute(route);
    onClose(remaining);
    controller.dispose();
  }
}
