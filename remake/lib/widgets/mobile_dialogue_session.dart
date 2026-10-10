import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/lore_main_input.dart';
import 'lore_select_view.dart';

/// Keeps a conversation's route alive across source Print/PressAnyKey pages.
/// Acknowledging releases only the current wait; the procedure supplies the
/// next page or finishes. No future rules or mutations are evaluated early.
class MobileDialogueSession {
  MobileDialogueSession(this.context);

  final BuildContext context;
  final _page = ValueNotifier<({int serial, List<(int, String)> lines})?>(null);
  DialogRoute<void>? _route;
  void Function(LogicalKeyboardKey)? _acknowledge;
  int _serial = 0;
  bool _closed = false;

  Future<void> showPage(List<(int, String)> lines) async {
    if (_closed || !context.mounted) return;
    final wait = Completer<void>();
    final input = LoreMainInput.current;
    void acknowledge(LogicalKeyboardKey key) {
      if (wait.isCompleted) return;
      input?.read(
        escape: key == LogicalKeyboardKey.escape,
        space: key == LogicalKeyboardKey.space,
        backspace: key == LogicalKeyboardKey.backspace,
        tab: key == LogicalKeyboardKey.tab,
      );
      wait.complete();
    }

    _acknowledge = acknowledge;
    _page.value = (serial: ++_serial, lines: List.unmodifiable(lines));
    if (_route == null) {
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _acknowledge?.call(LogicalKeyboardKey.escape);
          },
          child: ValueListenableBuilder(
            valueListenable: _page,
            builder: (_, page, _) => LoreMessageDialog(
              key: ValueKey('dialogue-page-${page!.serial}'),
              lines: page.lines,
              correctSpacing: true,
              closeOnAcknowledgement: false,
              onKeyAcknowledged: (key) => _acknowledge?.call(key),
            ),
          ),
        ),
      );
      _route = route;
      unawaited(
        Navigator.of(context).push(route).then((_) {
          if (identical(_route, route)) {
            _route = null;
            _acknowledge?.call(LogicalKeyboardKey.escape);
          }
        }),
      );
    }
    await wait.future;
    if (identical(_acknowledge, acknowledge)) _acknowledge = null;
  }

  /// Yield the screen to a choice, a scene or a camera animation. Later speech
  /// can open a fresh route within the same source procedure.
  void hide() {
    final route = _route;
    _route = null;
    if (route != null && route.isActive) route.navigator!.removeRoute(route);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _acknowledge?.call(LogicalKeyboardKey.escape);
    hide();
    _page.dispose();
  }
}
