import 'package:flutter/material.dart';

import '../services/browser_fullscreen.dart';
import '../theme/retro_theme.dart';

/// Browser presentation control; leaves the source menu selection pending.
class BrowserFullscreenButton extends StatefulWidget {
  const BrowserFullscreenButton({super.key});

  @override
  State<BrowserFullscreenButton> createState() =>
      _BrowserFullscreenButtonState();
}

class _BrowserFullscreenButtonState extends State<BrowserFullscreenButton> {
  bool _busy = false;
  String? _message;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await toggleBrowserFullscreen();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (result) {
        'unsupported' =>
          '이 브라우저는 전체화면을 지원하지 않습니다. 브라우저 메뉴에서 홈 화면에 추가한 뒤 실행해 주세요.',
        'denied' => '브라우저에서 전체화면 전환을 허용하지 않았습니다. 다시 눌러 주세요.',
        _ => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!browserFullscreenAvailable) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          key: const ValueKey('browser-fullscreen'),
          onPressed: _busy ? null : _toggle,
          icon: const Icon(Icons.fullscreen),
          label: const Text('전체화면 전환'),
          style: TextButton.styleFrom(foregroundColor: RetroTheme.lightCyan),
        ),
        if (_message != null) Text(_message!, style: RetroTheme.dosFont),
      ],
    );
  }
}
