import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/lore_game_over.dart';
import '../logic/lore_load_failure.dart';
import '../theme/retro_theme.dart';
import 'lore_window.dart';

/// `GameOver` 를 오른쪽 창(뷰포트)에 그리는 어댑터: [LoreWindowView] 에 원본
/// 문구와 `Select`, `PressAnyKey` 를 그린다.
class GameOverView extends StatefulWidget {
  const GameOverView({
    super.key,
    required this.etc6,
    required this.load,
    required this.onFinished,
  });

  /// 호출 시점의 `party.etc[6]`.
  final int etc6;

  /// `Load` (슬롯 1..4, 저장이 없으면 false).
  final Future<bool> Function(int slot) load;
  final ValueChanged<LoreGameOverResult> onFinished;

  @override
  State<GameOverView> createState() => _GameOverViewState();
}

class _GameOverViewState extends State<GameOverView> implements LoreGameOverIo {
  final LoreWindowController _window = LoreWindowController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await LoreGameOver.run(widget.etc6, this);
      if (mounted) widget.onFinished(result);
    });
  }

  @override
  void dispose() {
    _window.dispose();
    super.dispose();
  }

  @override
  void clear() => _window.clear();

  @override
  void print(int color, String text) => _window.print(color, text);

  @override
  Future<void> pressAnyKey() => _window.pressAnyKey();

  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  }) => _window.select(title, items, maxsum: maxsum, clean: clean);

  @override
  Future<bool> load(int slot) => widget.load(slot);

  @override
  Widget build(BuildContext context) => LoreWindowView(controller: _window);
}

/// `Halt` 뒤 텍스트 화면. 일반 종료는 `Feel your RPG imagination !!` 을 원본
/// `RGB(7,..)` 순서(검정→흰색 63단계 15ms, 500ms, 회색 42까지)로 밝힌 뒤,
/// `Load` 실패는 `ErrorMessage` 두 줄을 쓴 뒤 앱을 닫는다(`SystemNavigator.pop`,
/// 웹에서는 화면이 그대로 남는다).
class HaltView extends StatefulWidget {
  const HaltView({super.key, this.missingSlot, this.loadFailure, this.onHalt});

  final int? missingSlot;
  final LoreLoadFailure? loadFailure;

  /// 기본값은 `SystemNavigator.pop`.
  final VoidCallback? onHalt;

  @override
  State<HaltView> createState() => _HaltViewState();
}

class _HaltViewState extends State<HaltView> {
  int _level = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.missingSlot != null || widget.loadFailure != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _halt());
      return;
    }
    // for i := 1 to 63 (15ms) ; delay(500) ; for i := 62 downto 42 (15ms)
    final steps = <(int, int)>[
      for (var i = 1; i <= 63; i++) (i, 15),
      (63, 500),
      for (var i = 62; i >= 42; i--) (i, 15),
    ];
    var index = 0;
    void next() {
      if (!mounted) return;
      if (index >= steps.length) {
        _halt();
        return;
      }
      final (level, ms) = steps[index++];
      setState(() => _level = level);
      _timer = Timer(Duration(milliseconds: ms), next);
    }

    next();
  }

  void _halt() {
    if (!mounted) return;
    (widget.onHalt ?? () => SystemNavigator.pop())();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.missingSlot;
    final errorLines =
        widget.loadFailure?.lines ??
        (slot != null ? LoreGameOver.missingSaveLines(slot) : null);
    final shade = (_level * 255 / 63).round();
    return Container(
      color: RetroTheme.black,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: errorLines != null
            ? [
                for (var i = 0; i < errorLines.length; i++)
                  Text(
                    errorLines[i],
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.ega(i == 0 ? 12 : 7),
                    ),
                  ),
              ]
            : [
                const SizedBox(height: 16), // Writeln(#13)
                Text(
                  LoreGameOver.haltMessage,
                  style: RetroTheme.dosFont.copyWith(
                    color: Color.fromARGB(255, shade, shade, shade),
                  ),
                ),
              ],
      ),
    );
  }
}
