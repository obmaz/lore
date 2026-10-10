import 'package:flutter/material.dart';

import '../services/browser_fullscreen.dart';
import '../theme/retro_theme.dart';

/// Browser presentation control, independent of the source game commands.
class BrowserFullscreenButton extends StatefulWidget {
  const BrowserFullscreenButton({super.key});

  @override
  State<BrowserFullscreenButton> createState() =>
      _BrowserFullscreenButtonState();
}

class _BrowserFullscreenButtonState extends State<BrowserFullscreenButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await toggleBrowserFullscreen();
    if (!mounted) return;
    setState(() {
      _busy = false;
    });
    final message = switch (result) {
      'unsupported' =>
        '이 브라우저는 전체화면을 지원하지 않습니다. 브라우저 메뉴에서 홈 화면에 추가한 뒤 실행해 주세요.',
      'denied' => '브라우저에서 전체화면 전환을 허용하지 않았습니다. 다시 눌러 주세요.',
      _ => null,
    };
    if (message != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: RetroTheme.panelBg,
          content: Text(message, style: RetroTheme.dosFont),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!browserFullscreenAvailable) return const SizedBox.shrink();
    return IconButton(
      key: const ValueKey('browser-fullscreen'),
      tooltip: '전체화면 전환',
      onPressed: _busy ? null : _toggle,
      icon: const Icon(Icons.fullscreen, size: 20, color: RetroTheme.lightCyan),
    );
  }
}
