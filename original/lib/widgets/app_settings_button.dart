import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/sprite_sheet.dart';
import '../services/graphics_settings.dart';

/// Presentation controls; never invokes a source game menu or procedure.
class AppSettingsButton extends StatefulWidget {
  const AppSettingsButton({
    super.key,
    this.enabled = true,
    this.onOpenChanged,
    this.settings,
  });

  final bool enabled;
  final ValueChanged<bool>? onOpenChanged;
  final GraphicsSettings? settings;

  @override
  State<AppSettingsButton> createState() => _AppSettingsButtonState();
}

class _AppSettingsButtonState extends State<AppSettingsButton> {
  bool _open = false;

  Future<void> _showSettings() async {
    if (_open) return;
    _open = true;
    widget.onOpenChanged?.call(true);
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => AppSettingsDialog(
          settings: widget.settings ?? GraphicsSettings.instance,
        ),
      );
    } finally {
      _open = false;
      if (mounted) widget.onOpenChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('app-settings'),
    tooltip: '앱 설정',
    onPressed: widget.enabled ? _showSettings : null,
    icon: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF9BE2D6)),
  );
}

class AppSettingsDialog extends StatelessWidget {
  const AppSettingsDialog({super.key, required this.settings});
  final GraphicsSettings settings;

  static const ink = Color(0xFFE9F0FF);
  static const muted = Color(0xFF9BAAC5);
  static const accent = Color(0xFF8BE0CF);

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.of(context).pop(),
    },
    // Unhandled game hotkeys must not bubble to the field behind the dialog.
    child: Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
        return KeyEventResult.handled;
      },
      child: Dialog(
        backgroundColor: const Color(0xFF111B2D),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF33445F)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: accent, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '앱 설정',
                          style: TextStyle(
                            color: ink,
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('close-app-settings'),
                        tooltip: '설정 닫기',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '나만의 모험을 위한 화면 설정',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 18, color: accent),
                      SizedBox(width: 8),
                      Text(
                        '그래픽 스킨',
                        style: TextStyle(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '익숙한 원작의 풍경, 또는 새로운 판타지 세계.',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cards = [
                        for (final skin in GraphicsSkin.values)
                          _SkinCard(
                            skin: skin,
                            selected: settings.skin == skin,
                            enabled: !settings.busy,
                            onTap: () => settings.select(skin),
                          ),
                      ];
                      if (constraints.maxWidth < 460) {
                        return Column(
                          children: [
                            cards[0],
                            const SizedBox(height: 12),
                            cards[1],
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[1]),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  if (settings.busy)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          '새로운 풍경을 불러오는 중…',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    )
                  else
                    const Text(
                      '선택하면 바로 적용됩니다. 언제든 다시 바꿀 수 있어요.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  if (settings.error case final error?) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      key: const ValueKey('graphics-error'),
                      style: const TextStyle(
                        color: Color(0xFFFFCE96),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final GraphicsSkin skin;
  final bool selected, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: skin.label,
    child: Material(
      color: selected ? const Color(0xFF1D3243) : const Color(0xFF182439),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('skin-${skin.id}'),
        onTap: enabled ? onTap : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected
                  ? AppSettingsDialog.accent
                  : const Color(0xFF34425B),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1.8,
                    child: Image.asset(
                      skin.previewPath,
                      fit: BoxFit.cover,
                      filterQuality: skin == GraphicsSkin.original
                          ? FilterQuality.none
                          : FilterQuality.low,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              skin.label,
                              style: const TextStyle(
                                color: AppSettingsDialog.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: selected
                                ? AppSettingsDialog.accent
                                : AppSettingsDialog.muted,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        skin.description,
                        style: const TextStyle(
                          color: AppSettingsDialog.muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
