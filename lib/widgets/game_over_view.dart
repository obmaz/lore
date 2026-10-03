import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/lore_game_over.dart';
import '../logic/lore_sub_text.dart';
import '../theme/retro_theme.dart';
import 'lore_select_view.dart';

/// `GameOver` 를 오른쪽 창(뷰포트)에 그리는 어댑터.
///
/// 문구는 `HPrintXY` 색 그대로 위에서부터 쌓고, `Select` 는 [LoreSelectView],
/// `PressAnyKey` 는 원본 안내 문구와 키(또는 터치) 대기이다.
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
  final List<(int, String)> _lines = [];
  ({String title, List<String> items, Completer<int> done})? _select;
  Completer<void>? _keyWait;
  int _selectSerial = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await LoreGameOver.run(widget.etc6, this);
      if (mounted) widget.onFinished(result);
    });
  }

  @override
  void clear() {
    if (mounted) setState(_lines.clear);
  }

  @override
  void print(int color, String text) {
    if (mounted) setState(() => _lines.add((color, text)));
  }

  @override
  Future<void> pressAnyKey() async {
    final wait = Completer<void>();
    setState(() => _keyWait = wait);
    await wait.future;
    if (!mounted) return;
    setState(() => _keyWait = null);
    clear();
  }

  @override
  Future<int> select(
    String title,
    List<String> items, {
    required bool clean,
  }) async {
    if (clean) clear();
    final done = Completer<int>();
    setState(() {
      _selectSerial++;
      _select = (title: title, items: items, done: done);
    });
    final k = await done.future;
    if (mounted) setState(() => _select = null);
    clear(); // lastclean = TRUE
    return k;
  }

  @override
  Future<bool> load(int slot) => widget.load(slot);

  void _releaseKey() {
    final wait = _keyWait;
    if (wait != null && !wait.isCompleted) wait.complete();
  }

  @override
  Widget build(BuildContext context) {
    final select = _select;
    return Container(
      color: RetroTheme.black,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (color, text) in _lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  text,
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.ega(color),
                  ),
                ),
              ),
            if (select != null)
              LoreSelectView(
                key: ValueKey('game-over-select-$_selectSerial'),
                title: select.title,
                items: select.items,
                onSelected: (k) {
                  if (!select.done.isCompleted) select.done.complete(k);
                },
              ),
            if (_keyWait != null)
              Focus(
                autofocus: true,
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent) {
                    _releaseKey();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: GestureDetector(
                  key: const ValueKey('game-over-press-any-key'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _releaseKey,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      LoreSubText.pressAnyKey,
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.ega(14),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `Halt` 뒤 텍스트 화면. 일반 종료는 `Feel your RPG imagination !!` 을 원본
/// `RGB(7,..)` 순서(검정→흰색 63단계 15ms, 500ms, 회색 42까지)로 밝힌 뒤,
/// `Load` 실패는 `ErrorMessage` 두 줄을 쓴 뒤 앱을 닫는다(`SystemNavigator.pop`,
/// 웹에서는 화면이 그대로 남는다).
class HaltView extends StatefulWidget {
  const HaltView({super.key, this.missingSlot, this.onHalt});

  final int? missingSlot;

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
    if (widget.missingSlot != null) {
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
    final shade = (_level * 255 / 63).round();
    return Container(
      color: RetroTheme.black,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: slot != null
            ? [
                Text(
                  LoreGameOver.missingSaveLines(slot)[0],
                  style: RetroTheme.dosFont.copyWith(color: RetroTheme.ega(12)),
                ),
                Text(
                  LoreGameOver.missingSaveLines(slot)[1],
                  style: RetroTheme.dosFont.copyWith(color: RetroTheme.ega(7)),
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
