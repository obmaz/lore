import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/mobile_theme.dart';
import 'mobile_dialog_action.dart';
import 'mobile_content_dialog.dart';
import 'mobile_party_view.dart';

/// Mobile exploration: square map, party, log, actions LEFT / keypad RIGHT.
/// Battle/encounter get a full-height viewport rather than a map-sized square.
class GameScreenLayout extends StatelessWidget {
  static const double minimumPartyHeight = 108;
  static const double minimumMessagesHeight = 52;
  static const double gap = 8;
  static const double messageTabsHeight = 48;
  static const String partyLabel = '일행';
  static const String messagesLabel = '메시지';
  static const String historyLabel = '이전 대화';

  const GameScreenLayout({
    super.key,
    required this.viewport,
    required this.party,
    required this.messages,
    required this.history,
    this.controls,
    this.commands,
    this.header,
    this.partyDetails,
    this.onPartyDetailsTap,
    this.battleContentOnly = false,
  });
  final Widget viewport, party, messages, history;
  final Widget? controls, commands, header, partyDetails;
  final bool battleContentOnly;
  final VoidCallback? onPartyDetailsTap;

  void _openPanel(BuildContext context, Widget panel, String title) {
    showDialog<void>(
      context: context,
      builder: (context) => panel is MobilePartyView
          ? MobileContentDialog(
              title: title,
              contentPadding: EdgeInsets.zero,
              content: panel,
              footer: MobileDialogAction(
                label: '닫기',
                onPressed: () => Navigator.pop(context),
              ),
            )
          : Dialog(
              backgroundColor: MobileTheme.surface,
              insetPadding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SizedBox(
                width: 640,
                height: MediaQuery.sizeOf(context).height * .9,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: MobileTheme.ink,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: panel,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: MobileDialogAction(
                        label: '닫기',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      if (width <= 0 || height <= 0) return const SizedBox.shrink();
      final headerHeight = math.min(56.0, height * .12);
      if (controls == null) {
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              if (header != null) SizedBox(height: headerHeight, child: header),
              Expanded(child: viewport),
              if (!battleContentOnly) const SizedBox(height: gap),
              if (!battleContentOnly) SizedBox(height: 64, child: messages),
              if (!battleContentOnly)
                TextButton(
                  key: const ValueKey('panel-tab-history'),
                  onPressed: () => _openPanel(context, history, historyLabel),
                  child: const Text('기록'),
                ),
            ],
          ),
        );
      }
      // Short 3:4 devices shrink the MAP, never the touch targets or text.
      final compact = height / width < 1.65 && width < 600;
      final partyHeight = compact ? 0.0 : minimumPartyHeight;
      const dockHeight = 156.0;
      final logHeight = compact ? 48.0 : minimumMessagesHeight;
      final available = math.max(
        0.0,
        height -
            headerHeight -
            partyHeight -
            dockHeight -
            logHeight -
            (compact ? 36 : 52),
      );
      final side = math.max(0.0, math.min(width - 20, available));
      return Stack(
        children: [
          Offstage(
            child: SizedBox(width: width, height: 400, child: history),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              children: [
                SizedBox(height: headerHeight, child: header),
                SizedBox.square(dimension: side, child: viewport),
                const SizedBox(height: gap),
                if (!compact)
                  SizedBox(
                    height: partyHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(child: party),
                        Positioned(
                          top: 0,
                          right: 4,
                          child: TextButton(
                            key: const ValueKey('panel-tab-party'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed:
                                onPartyDetailsTap ??
                                () => _openPanel(
                                  context,
                                  partyDetails ?? party,
                                  partyLabel,
                                ),
                            child: const Text(
                              '상세',
                              style: TextStyle(
                                color: MobileTheme.mint,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: gap),
                Expanded(
                  child: Container(
                    decoration: MobileTheme.card(),
                    child: Row(
                      children: [
                        if (compact)
                          TextButton(
                            key: const ValueKey('panel-tab-party'),
                            onPressed:
                                onPartyDetailsTap ??
                                () => _openPanel(
                                  context,
                                  partyDetails ?? party,
                                  partyLabel,
                                ),
                            child: const Text(
                              '일행',
                              style: TextStyle(
                                color: MobileTheme.mint,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Expanded(child: messages),
                        TextButton(
                          key: const ValueKey('panel-tab-history'),
                          onPressed: () =>
                              _openPanel(context, history, historyLabel),
                          child: const Text(
                            '기록 ›',
                            style: TextStyle(color: MobileTheme.mint),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: gap),
                Container(
                  height: dockHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: MobileTheme.card(),
                  child: Row(
                    children: [
                      if (commands != null) Expanded(child: commands!),
                      const SizedBox(width: 8),
                      SizedBox(width: 148, height: 148, child: controls),
                    ],
                  ),
                ),
                const SizedBox(height: gap),
              ],
            ),
          ),
        ],
      );
    },
  );
}
