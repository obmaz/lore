import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/sprite_sheet.dart';
import '../logic/lore_end.dart';
import '../services/audio_manager.dart';

/// 원작 `LOREEND.PAS` `End_Demo` 화면.
///
/// 순서: `FadeIn` → 바탕 지움 → `EndMessage` → `FadeOut` → (`StaffMessage`를
/// 숨은 쪽에 그림) 천둥 번쩍임, Esc를 누를 때까지 → 스태프 화면과 걷는 스프라이트,
/// Esc를 누를 때까지 → 텍스트 모드의 `<< The End >>` 와 팔레트 페이드 → `Halt`.
/// 문구·좌표·팔레트 식·스프라이트 순환·난수 호출은 [LoreEnd] 가 원본과 같다.
///
/// 어댑터(원본은 하드웨어 속도·BGI): 페이드 한 단계의 길이,
/// 천둥 반복문의 초당 반복 횟수, 화면 크기 맞춤, 터치/클릭은 Esc(또는 마지막
/// 화면에서는 아무 키)로 취급한다. 원본은 `Halt`로 끝나므로 마지막 화면에서
/// 키를 누르면 [onFinish]로 게임을 처음으로 되돌린다.
class EndingView extends StatefulWidget {
  final String heroName;
  final VoidCallback onFinish;
  final Random? random;

  /// Shared source c after the final talk('')/PressAnyKey.
  final bool initialKeyWasEscape;

  /// 페이드 한 단계(`FadeSub`) 길이 — DOS에서는 하드웨어 속도에 달려 있었다.
  static const Duration fadeStep = Duration(milliseconds: 30);

  /// 천둥 반복문(`repeat ... until ok`)의 초당 반복 횟수 추정치.
  static const int thunderIterationsPerSecond = 20000;

  // 원작 LOREEND.PAS `EndMessage` 의 cHPrint 문구.
  static List<String> get epilogueTexts => [
    for (final line in LoreEnd.messageLines) line.$3,
  ];

  const EndingView({
    super.key,
    required this.heroName,
    required this.onFinish,
    this.random,
    this.initialKeyWasEscape = false,
  });

  @override
  State<EndingView> createState() => EndingViewState();
}

enum EndPhase {
  fadeIn,
  fadeOut,
  message,
  staff,
  outroFadeUp,
  outroHold,
  outroDim,
  halted,
}

@visibleForTesting
class EndingViewState extends State<EndingView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final Random _random = widget.random ?? Random();
  final FocusNode _focus = FocusNode();

  EndPhase phase = EndPhase.fadeIn;
  Duration _phaseStart = Duration.zero;
  Duration _last = Duration.zero;

  /// `FadeSub`에 넘기는 값(0..310); 한 칸에 10.
  int adder = 0;

  // ThunderEffect
  VgaColor shadowFlash = LoreEnd.thunderBase;
  int _openingIndex = 0;
  Duration _flashUntil = Duration.zero;
  bool _openingDone = false;
  double _iterationCarry = 0;
  late bool _lastThunderKeyWasEscape = widget.initialKeyWasEscape;
  bool _thunderWaitingForFlash = false;

  /// 키 버퍼: `ThunderEffect`는 첫 반복에서 `keypressed` 로 이미 눌린 키를 읽는다.
  /// 페이드·첫 번쩍임 동안 누른 Esc도 버퍼에 남아 천둥 반복문이 시작되자마자 끝난다.
  final List<bool> _keyBuffer = [];

  // 걷는 스프라이트
  final LoreEndWalker walker = LoreEndWalker();
  final Set<int> erasedRows = {};
  ({int eraseRow, int y, int sprite})? walkerFrame;
  Duration _walkerDue = Duration.zero;
  bool _staffExitPending = false;

  // 마지막 텍스트 화면: 색 7/15의 현재 밝기(6비트).
  int ramp15 = 0;
  int ramp7 = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _enter(EndPhase next, Duration now) {
    phase = next;
    _phaseStart = now;
  }

  void _onTick(Duration now) {
    final dt = now - _last;
    _last = now;
    final inPhase = now - _phaseStart;
    switch (phase) {
      case EndPhase.fadeIn:
        final steps = LoreEnd.fadeInAdders;
        final index = min(
          inPhase.inMicroseconds ~/ EndingView.fadeStep.inMicroseconds,
          steps.length - 1,
        );
        adder = steps[index];
        if (inPhase >= EndingView.fadeStep * steps.length) {
          _enter(EndPhase.fadeOut, now);
        }
      case EndPhase.fadeOut:
        final steps = LoreEnd.fadeOutAdders;
        final index = min(
          inPhase.inMicroseconds ~/ EndingView.fadeStep.inMicroseconds,
          steps.length - 1,
        );
        adder = steps[index];
        if (inPhase >= EndingView.fadeStep * steps.length) {
          adder = 0;
          _enter(EndPhase.message, now);
          _openingIndex = 0;
          _openingDone = false;
          shadowFlash = LoreEnd.openingFlashes.first.$1;
          _flashUntil =
              now + Duration(milliseconds: LoreEnd.openingFlashes.first.$2);
        }
      case EndPhase.message:
        _thunder(now, dt);
      case EndPhase.staff:
        if (walkerFrame == null || now >= _walkerDue) {
          // The source checks c, then still delays 200 ms before `until ok`.
          if (_staffExitPending) {
            _escape(force: true);
            break;
          }
          final frame = walker.frame();
          erasedRows
            ..add(frame.eraseRow)
            ..add(frame.eraseRow + 1);
          walkerFrame = frame;
          if (_keyBuffer.isNotEmpty) {
            _staffExitPending = _keyBuffer.removeAt(0);
          }
          _walkerDue =
              now + const Duration(milliseconds: LoreEndWalker.delayMs);
        }
      case EndPhase.outroFadeUp:
        final i = min(
          inPhase.inMilliseconds ~/ LoreEnd.outroFadeDelayMs + 1,
          LoreEnd.outroFadeTo,
        );
        ramp7 = ramp15 = i;
        // LOREEND.PAS delays after every palette write, including i = 63.
        if (inPhase.inMilliseconds >=
            LoreEnd.outroFadeTo * LoreEnd.outroFadeDelayMs) {
          _enter(EndPhase.outroHold, now);
        }
      case EndPhase.outroHold:
        if (inPhase.inMilliseconds >= LoreEnd.outroHoldMs) {
          _enter(EndPhase.outroDim, now);
        }
      case EndPhase.outroDim:
        final count = LoreEnd.outroDimFrom - LoreEnd.outroDimTo + 1;
        final i = min(
          inPhase.inMilliseconds ~/ LoreEnd.outroDimDelayMs,
          count - 1,
        );
        ramp7 = LoreEnd.outroDimFrom - i;
        // Keep the final delay(15) after RGB(7,42,42,42) before Halt.
        if (inPhase.inMilliseconds >= count * LoreEnd.outroDimDelayMs) {
          _enter(EndPhase.halted, now);
          _focus.requestFocus();
        }
      case EndPhase.halted:
        break;
    }
    if (mounted) setState(() {});
  }

  /// `StaffMessage` 뒤의 네 번 번쩍임, 이어서 `ThunderEffect`의 반복문.
  void _thunder(Duration now, Duration dt) {
    if (now < _flashUntil) return;
    if (!_openingDone) {
      _openingIndex++;
      if (_openingIndex < LoreEnd.openingFlashes.length) {
        final (color, delay) = LoreEnd.openingFlashes[_openingIndex];
        shadowFlash = color;
        _flashUntil = now + Duration(milliseconds: delay);
        return;
      }
      _openingDone = true;
      shadowFlash = LoreEnd.thunderBase;
      return;
    }
    shadowFlash = LoreEnd.thunderBase;
    // A flash delay finishes before the current iteration reads its key.
    if (_thunderWaitingForFlash) {
      _thunderWaitingForFlash = false;
      if (_finishThunderIteration()) return;
    }
    _iterationCarry +=
        dt.inMicroseconds *
        EndingView.thunderIterationsPerSecond /
        Duration.microsecondsPerSecond;
    var iterations = _iterationCarry.floor();
    _iterationCarry -= iterations;
    while (iterations-- > 0) {
      final flash = LoreEndThunder.iterate(_random);
      if (flash != null) {
        shadowFlash = LoreEnd.thunderFlash;
        _flashUntil = now + Duration(milliseconds: flash);
        _thunderWaitingForFlash = true;
        break;
      }
      if (_finishThunderIteration()) return;
    }
  }

  bool _finishThunderIteration() {
    // `if KeyPressed then c := ReadKey; if c = #27 then ok := TRUE`:
    // one queued key replaces c, after that iteration's random calls.
    if (_keyBuffer.isNotEmpty) {
      _lastThunderKeyWasEscape = _keyBuffer.removeAt(0);
    }
    if (!_lastThunderKeyWasEscape) return false;
    // End_Demo drains the keyboard buffer and sets c := #255 before staff.
    _keyBuffer.clear();
    _lastThunderKeyWasEscape = false;
    _escape(force: true);
    return true;
  }

  /// 원본 `c = #27`: 천둥 화면과 스태프 화면에서만 Esc가 다음으로 넘긴다.
  void _escape({bool force = false}) {
    final now = _last;
    switch (phase) {
      case EndPhase.message:
        if (!force) {
          // 열린 번쩍임은 끝까지 돌고, 키는 버퍼에 남는다.
          _keyBuffer.add(true);
          return;
        }
        shadowFlash = LoreEnd.thunderBase;
        _enter(EndPhase.staff, now);
        walkerFrame = null;
      case EndPhase.staff:
        if (!force) {
          _keyBuffer.add(true);
          return;
        }
        // `if AdLibOn then PlayOff; UnSound;`
        AudioManager.instance.stopBgm();
        ramp15 = ramp7 = 0;
        _enter(EndPhase.outroFadeUp, now);
      case EndPhase.halted:
        widget.onFinish();
      default:
        // 페이드 중의 키는 읽히지 않고 키보드 버퍼에 쌓인다.
        _keyBuffer.add(true);
        return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sprites = SpriteLibrary.instance;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (phase == EndPhase.halted ||
            event.logicalKey == LogicalKeyboardKey.escape) {
          _escape();
        } else if (phase == EndPhase.fadeIn ||
            phase == EndPhase.fadeOut ||
            phase == EndPhase.message ||
            phase == EndPhase.staff) {
          _keyBuffer.add(false);
        }
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _escape,
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 640,
                height: 350,
                child: CustomPaint(
                  key: const ValueKey('ending-canvas'),
                  painter: _EndPainter(
                    phase: phase,
                    adder: adder,
                    shadowFlash: shadowFlash,
                    heroName: widget.heroName,
                    chara: sprites.get('CHARA'),
                    town: sprites.get('TOWN'),
                    walker: walkerFrame,
                    erasedRows: Set.of(erasedRows),
                    ramp15: ramp15,
                    ramp7: ramp7,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EndPainter extends CustomPainter {
  final EndPhase phase;
  final int adder;
  final VgaColor shadowFlash;
  final String heroName;
  final SpriteSheet? chara;
  final SpriteSheet? town;
  final ({int eraseRow, int y, int sprite})? walker;
  final Set<int> erasedRows;
  final int ramp15;
  final int ramp7;

  _EndPainter({
    required this.phase,
    required this.adder,
    required this.shadowFlash,
    required this.heroName,
    required this.chara,
    required this.town,
    required this.walker,
    required this.erasedRows,
    required this.ramp15,
    required this.ramp7,
  });

  static Color _vga(VgaColor c) => Color.fromARGB(
    255,
    LoreEnd.channel(c.$1),
    LoreEnd.channel(c.$2),
    LoreEnd.channel(c.$3),
  );

  /// 현재 팔레트의 색 [index] (`FadeSub` 상태, 색 6은 천둥이 덮어쓴다).
  Color _palette(int index, {bool staff = false}) {
    if (index == 15) return _vga((63, 63, 63));
    if (staff && index == 6) return _vga(LoreEnd.thunderBase);
    if (index == 6 && phase == EndPhase.message) return _vga(shadowFlash);
    return _vga(LoreEnd.fadeColor(index, staff ? 0 : adder));
  }

  void _text(
    Canvas canvas,
    String s,
    double x,
    double y,
    Color color, {
    double size = 15,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: size,
          height: 1.0,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x, y));
  }

  /// `cHPrint`: 색이 8보다 크면 (색-8)로 (+2,+1) 그림자를 먼저 그린다.
  void _cPrint(
    Canvas canvas,
    int color,
    int x,
    int y,
    String s, {
    bool staff = false,
  }) {
    if (color > 8) {
      _text(canvas, s, x + 2.0, y + 1.0, _palette(color - 8, staff: staff));
    }
    _text(canvas, s, x.toDouble(), y.toDouble(), _palette(color, staff: staff));
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (phase) {
      case EndPhase.fadeIn:
        canvas.drawRect(Offset.zero & size, Paint()..color = _palette(0));
      case EndPhase.fadeOut:
      case EndPhase.message:
        canvas.drawRect(Offset.zero & size, Paint()..color = _palette(0));
        for (final (x, y, s) in LoreEnd.messageLines) {
          _cPrint(canvas, LoreEnd.messageColor, x, y, s);
        }
      case EndPhase.staff:
        _paintStaff(canvas, size);
      case EndPhase.outroFadeUp:
      case EndPhase.outroHold:
      case EndPhase.outroDim:
      case EndPhase.halted:
        _paintOutro(canvas, size);
    }
  }

  void _paintStaff(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    for (var j = 0; j <= 18; j++) {
      for (var i = 0; i <= 32; i++) {
        town?.draw(
          canvas,
          LoreEnd.backgroundTile,
          Rect.fromLTWH(i * 20.0, j * 20.0, 20, 20),
        );
      }
    }
    var color = 0;
    for (final op in LoreEnd.staffOps) {
      switch (op.kind) {
        case 'color':
          color = op.a;
        case 'bold':
          _text(
            canvas,
            op.text,
            op.a.toDouble(),
            op.b.toDouble(),
            _palette(color, staff: true),
          );
          _text(
            canvas,
            op.text,
            op.a + 1.0,
            op.b.toDouble(),
            _palette(color, staff: true),
          );
        case 'sprite':
          chara?.draw(
            canvas,
            op.c,
            Rect.fromLTWH(op.a.toDouble(), op.b.toDouble(), 20, 20),
          );
        case 'text':
          _cPrint(canvas, color, op.a, op.b, op.resolve(heroName), staff: true);
      }
    }
    for (final row in erasedRows) {
      town?.draw(
        canvas,
        LoreEnd.backgroundTile,
        Rect.fromLTWH(LoreEndWalker.x.toDouble(), row * 20.0, 20, 20),
      );
    }
    final w = walker;
    if (w != null) {
      chara?.draw(
        canvas,
        w.sprite,
        Rect.fromLTWH(LoreEndWalker.x.toDouble(), w.y.toDouble(), 20, 20),
      );
    }
  }

  void _paintOutro(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    for (var n = 0; n < LoreEnd.outroLines.length; n++) {
      final ramp = LoreEnd.outroColors[n] == 15 ? ramp15 : ramp7;
      final color = _vga((ramp, ramp, ramp));
      _text(
        canvas,
        LoreEnd.outroLines[n],
        0,
        (LoreEnd.outroBlankLines + n) * 14.0,
        color,
        size: 13,
      );
    }
  }

  @override
  bool shouldRepaint(_EndPainter old) => true;
}
