import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';

/// Keeps the map above usable panels, including on short browser viewports.
class GameScreenLayout extends StatelessWidget {
  static const double minimumPartyHeight = 160;
  static const double minimumMessagesHeight = 200;
  static const double gap = 4;

  final Widget viewport;
  final Widget party;
  final Widget messages;

  /// `이전 대화`: the NPC speeches that were shown in the dialogue window.
  final Widget history;
  final Widget? controls;

  static const String partyLabel = '캐릭터';
  static const String messagesLabel = '대화';
  static const String historyLabel = '이전 대화';

  const GameScreenLayout({
    super.key,
    required this.viewport,
    required this.party,
    required this.messages,
    required this.history,
    this.controls,
  });

  Widget _tabButton(TabController controller, int index, String label) {
    final selected = controller.index == index;
    return Semantics(
      selected: selected,
      child: TextButton(
        key: ValueKey(switch (index) {
          0 => 'panel-tab-party',
          1 => 'panel-tab-dialogue',
          _ => 'panel-tab-history',
        }),
        onPressed: () => controller.animateTo(index),
        style: TextButton.styleFrom(
          foregroundColor: selected ? RetroTheme.yellow : RetroTheme.lightGray,
          backgroundColor: selected ? RetroTheme.panelBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          minimumSize: const Size(60, 48),
          shape: const RoundedRectangleBorder(),
          side: BorderSide(
            color: selected ? RetroTheme.lightCyan : RetroTheme.darkGray,
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _panels({required bool tabbed}) {
    if (tabbed) {
      return DefaultTabController(
        length: 3,
        initialIndex: 1,
        child: Builder(
          builder: (context) {
            final controller = DefaultTabController.of(context);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 64,
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _tabButton(controller, 0, partyLabel),
                        const SizedBox(height: gap),
                        _tabButton(controller, 1, messagesLabel),
                        const SizedBox(height: gap),
                        _tabButton(controller, 2, historyLabel),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(children: [party, messages, history]),
                ),
              ],
            );
          },
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final extra =
            constraints.maxHeight -
            minimumPartyHeight -
            minimumMessagesHeight -
            gap;
        return Column(
          children: [
            SizedBox(height: minimumPartyHeight + extra * .4, child: party),
            const SizedBox(height: gap),
            Expanded(
              child: _StackedMessages(messages: messages, history: history),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) return const SizedBox.shrink();
        // Reserve a readable panel before sizing the square map. Never switch
        // to side-by-side map/panels when browser chrome reduces the height.
        final side = math.min(
          width,
          math.max(0.0, height - minimumMessagesHeight - gap),
        );
        final remaining = height - side - gap;
        final tabbed =
            height / width <= 1.5 ||
            remaining < minimumPartyHeight + minimumMessagesHeight + gap;
        return Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                SizedBox(
                  width: width,
                  height: side,
                  child: Center(
                    child: SizedBox.square(dimension: side, child: viewport),
                  ),
                ),
                const SizedBox(height: gap),
                Expanded(child: _panels(tabbed: tabbed)),
              ],
            ),
            if (controls != null)
              Positioned(
                right: 8,
                bottom: 8,
                width: 146,
                height: 146,
                child: FittedBox(child: controls!),
              ),
          ],
        );
      },
    );
  }
}

/// The stacked layout's bottom panel: `대화` (messages) and `이전 대화`.
class _StackedMessages extends StatefulWidget {
  final Widget messages;
  final Widget history;

  const _StackedMessages({required this.messages, required this.history});

  @override
  State<_StackedMessages> createState() => _StackedMessagesState();
}

class _StackedMessagesState extends State<_StackedMessages> {
  int _index = 0;

  Widget _tab(int index, String label, String key) {
    final selected = _index == index;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton(
          key: ValueKey(key),
          onPressed: () => setState(() => _index = index),
          style: TextButton.styleFrom(
            foregroundColor: selected
                ? RetroTheme.yellow
                : RetroTheme.lightGray,
            backgroundColor: selected ? RetroTheme.panelBg : Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 4),
            minimumSize: const Size(60, 28),
            shape: const RoundedRectangleBorder(),
            side: BorderSide(
              color: selected ? RetroTheme.lightCyan : RetroTheme.darkGray,
            ),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          _tab(0, GameScreenLayout.messagesLabel, 'panel-tab-dialogue'),
          _tab(1, GameScreenLayout.historyLabel, 'panel-tab-history'),
        ],
      ),
      Expanded(
        child: IndexedStack(
          index: _index,
          children: [widget.messages, widget.history],
        ),
      ),
    ],
  );
}
