import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';

/// A square map and panels sized to the available, safe screen area.
class GameScreenLayout extends StatelessWidget {
  final Widget viewport;
  final Widget party;
  final Widget messages;

  const GameScreenLayout({
    super.key,
    required this.viewport,
    required this.party,
    required this.messages,
  });

  Widget _panels({required bool tabbed}) {
    if (tabbed) {
      return DefaultTabController(
        length: 2,
        initialIndex: 1,
        child: Column(
          children: [
            const TabBar(
              labelColor: RetroTheme.yellow,
              unselectedLabelColor: RetroTheme.lightGray,
              indicatorColor: RetroTheme.lightCyan,
              tabs: [
                Tab(text: '캐릭터'),
                Tab(text: '대화'),
              ],
            ),
            Expanded(child: TabBarView(children: [party, messages])),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(flex: 4, child: party),
        const SizedBox(height: 4),
        Expanded(flex: 6, child: messages),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) return const SizedBox.shrink();
        // Landscape cannot fit a full-width square above usable controls.
        // Keep the map square beside the same tabbed panels when rotated.
        if (width > height || height - width < 104) {
          final side = math.min(height, width - math.min(240.0, width * .4));
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox.square(dimension: side, child: viewport),
              ),
              const SizedBox(width: 4),
              Expanded(child: _panels(tabbed: true)),
            ],
          );
        }
        final remaining = height - width;
        final tabbed = height / width <= 1.5 || remaining < 360;
        return Column(
          children: [
            SizedBox.square(dimension: width, child: viewport),
            const SizedBox(height: 4),
            Expanded(child: _panels(tabbed: tabbed)),
          ],
        );
      },
    );
  }
}
