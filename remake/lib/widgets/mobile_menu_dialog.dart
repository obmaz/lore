import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/lore_main_input.dart';
import 'mobile_content_dialog.dart';
import 'mobile_dialog_action.dart';
import 'mobile_choice_tile.dart';

class MobileMenuItem {
  const MobileMenuItem(this.label, {this.detail, this.enabled = true});
  final String label;
  final String? detail;
  final bool enabled;
}

/// Parents remain on the navigator while a child is open. A completed action
/// returns true through its ancestors; back returns false to just its parent.
Future<bool> showMobileMenuDialog(
  BuildContext context, {
  required String title,
  required List<MobileMenuItem> items,
  required Future<bool> Function(int selection) onSelected,
  bool isRoot = false,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MobileMenuDialog(
        title: title,
        items: items,
        onSelected: onSelected,
        isRoot: isRoot,
      ),
    ) ??
    false;

class _MobileMenuDialog extends StatefulWidget {
  const _MobileMenuDialog({
    required this.title,
    required this.items,
    required this.onSelected,
    required this.isRoot,
  });
  final String title;
  final List<MobileMenuItem> items;
  final Future<bool> Function(int) onSelected;
  final bool isRoot;
  @override
  State<_MobileMenuDialog> createState() => _MobileMenuDialogState();
}

class _MobileMenuDialogState extends State<_MobileMenuDialog> {
  final _focus = FocusNode();
  bool _busy = false;
  int _highlighted = 0;
  bool _keyboardSelection = false;
  late final _itemKeys = List.generate(widget.items.length, (_) => GlobalKey());

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _choose(int index) async {
    if (_busy ||
        index < 0 ||
        index >= widget.items.length ||
        !widget.items[index].enabled) {
      return;
    }
    LoreMainInput.record(escape: false);
    setState(() {
      _busy = true;
      _highlighted = index;
    });
    try {
      final completed = await widget.onSelected(index + 1);
      if (!mounted || ModalRoute.of(context)?.isActive != true) return;
      setState(() => _busy = false);
      if (completed) {
        Navigator.pop(context, true);
      } else {
        _focus.requestFocus();
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  void _back() {
    if (_busy) return;
    LoreMainInput.record(escape: true);
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: !_busy,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop && result != true) LoreMainInput.record(escape: true);
    },
    child: Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (_busy) return KeyEventResult.handled;
        final key = event.logicalKey;
        final number = int.tryParse(key.keyLabel);
        if (number != null && number > 0 && number <= widget.items.length) {
          _choose(number - 1);
        } else if (key == LogicalKeyboardKey.escape) {
          _back();
        } else if (key == LogicalKeyboardKey.enter) {
          _choose(_highlighted);
        } else if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown) {
          if (widget.items.isEmpty) return KeyEventResult.ignored;
          final step = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
          var next = _highlighted;
          for (var i = 0; i < widget.items.length; i++) {
            next = (next + step) % widget.items.length;
            if (widget.items[next].enabled) break;
          }
          setState(() {
            _highlighted = next;
            _keyboardSelection = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final itemContext = _itemKeys[_highlighted].currentContext;
            if (itemContext != null) {
              Scrollable.ensureVisible(
                itemContext,
                duration: const Duration(milliseconds: 150),
                alignment: .5,
              );
            }
          });
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: MobileContentDialog(
        title: widget.title,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.items.isEmpty) const Text('선택할 항목이 없습니다.'),
            for (var i = 0; i < widget.items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MobileChoiceTile(
                  key: _itemKeys[i],
                  label: widget.items[i].label,
                  detail: widget.items[i].detail,
                  selected: (_busy || _keyboardSelection) && _highlighted == i,
                  busy: _busy && _highlighted == i,
                  onPressed: _busy || !widget.items[i].enabled
                      ? null
                      : () => _choose(i),
                ),
              ),
          ],
        ),
        footer: MobileDialogAction(
          key: const ValueKey('dialog-cancel'),
          label: widget.isRoot ? '닫기' : '돌아가기',
          secondary: true,
          onPressed: _busy ? null : _back,
        ),
      ),
    ),
  );
}
