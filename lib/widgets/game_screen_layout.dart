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
  final Widget? controls;

  const GameScreenLayout({
    super.key,
    required this.viewport,
    required this.party,
    required this.messages,
    this.controls,
  });

  Widget _tabButton(TabController controller, int index, String label) {
    final selected = controller.index == index;
    return Semantics(
      selected: selected,
      child: TextButton(
        key: ValueKey(index == 0 ? 'panel-tab-party' : 'panel-tab-dialogue'),
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
        length: 2,
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
                        _tabButton(controller, 0, '캐릭터'),
                        const SizedBox(height: gap),
                        _tabButton(controller, 1, '대화'),
                      ],
                    ),
                  ),
                ),
                Expanded(child: TabBarView(children: [party, messages])),
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
            Expanded(child: messages),
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
