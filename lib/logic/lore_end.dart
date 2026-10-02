/// 원작 `LOREEND.PAS` `End_Demo`의 데이터와 상태 기계.
///
/// 문구·좌표·팔레트 식·스프라이트 순환·난수 호출 순서는 원본 그대로이고
/// (`test/fixtures/loreend_parity.json` 으로 대조), BGI 출력과 DOS 지연 시간은
/// 화면 어댑터(`EndingView`)가 대신한다.
library;

import 'dart:math';

/// 6비트 VGA 값 [r],[g],[b].
typedef VgaColor = (int, int, int);

class LoreEnd {
  const LoreEnd._();

  /// `FadeSub(adder)`: 색 0..14의 팔레트. `adder`는 `FadeIn/FadeOut`이 넘기는
  /// `adder * 10` (0..310)이고 모든 나눗셈은 Pascal `div`(정수 몫)이다.
  static VgaColor fadeColor(int color, int adder) {
    final a5 = adder ~/ 5;
    final a15 = adder ~/ 15;
    return switch (color) {
      0 => (a5, a5, a5),
      1 => (a5, a5, 42 + a15),
      2 => (a5, 42 + a15, a5),
      3 => (a5, 42 + a15, 42 + a15),
      4 => (42 + a15, a5, a5),
      5 => (42 + a15, a5, 42 + a15),
      6 => (42 + a15, 21 + adder * 2 ~/ 15, a5),
      7 => (a15 + 42, a15 + 42, a15 + 42),
      8 => (21 + adder * 2 ~/ 15, 21 + adder * 2 ~/ 15, 21 + adder * 2 ~/ 15),
      9 => (a5, a5, 62),
      10 => (a5, 62, a5),
      11 => (a5, 62, 62),
      12 => (62, a5, a5),
      13 => (62, a5, 62),
      14 => (62, 62, a5),
      _ => throw RangeError.range(color, 0, 14, 'color'),
    };
  }

  /// `FadeIn`: `for adder := 0 to 31 do FadeSub(adder*10)`.
  static final List<int> fadeInAdders = [for (var a = 0; a <= 31; a++) a * 10];

  /// `FadeOut`: `for adder := 31 downto 0 do FadeSub(adder*10)`.
  static final List<int> fadeOutAdders = [for (var a = 31; a >= 0; a--) a * 10];

  /// `EndMessage`: `SetColor(14)` 와 `cHPrint(x,y,s)` 열한 줄.
  static const int messageColor = 14;
  static const List<(int, int, String)> messageLines = [
    (50, 50, '밖은 비바람이 치기 시작한다. 이번 계절에 들어 처음 오는 비였다.'),
    (50, 70, '마치 Necromancer의 기구한 운명을 애도하는 듯이 ...'),
    (50, 90, '하지만 그는 또다른 운명의 아이러니 때문에 새로운 길을 떠났다.'),
    (50, 110, '그가 이런 역사를 몇번이나 반복했는지 그 자신도 모른다.'),
    (50, 130, '그가 최후로 정착할 곳 마저 알수가 없었다'),
    (50, 150, '아니, 그가 정착할 곳이 있는지 조차도 알수가 없었다.'),
    (50, 180, '당신도 이제 할일을 모두 끝냈다. 이제 편안하게 쉴 기회를 가지게 된것이다.'),
    (50, 200, '이제는 다시 이런 일이 일어나지 않을 것이다.'),
    (50, 220, '후세의 사람들은 말하겠지, 수천억년에 한번 날까 말까한 일이라고.'),
    (50, 240, '아마 이 일도 별로 오래 기억되지 않을 것같다.'),
    (50, 260, '몇 천년만 지나면 전설로서, 아니 잋혀진 애기로만 남을테니까 ...'),
  ];

  /// `StaffMessage`의 그리기 목록 (순서 그대로).
  static const List<EndStaffOp> staffOps = [
    EndStaffOp.color(11),
    EndStaffOp.bold(170, 10, '이 게임의 끝마무리에 공헌한 인물'),
    EndStaffOp.color(10),
    EndStaffOp.sprite(40, 40, 4),
    EndStaffOp.text(120, 42, '이름은 ', after: '. 바로 당신이다.', hero: true),
    EndStaffOp.sprite(20, 70, 8),
    EndStaffOp.sprite(40, 70, 8),
    EndStaffOp.sprite(60, 70, 12),
    EndStaffOp.text(120, 72, 'Hydra, NOTICE 동굴의 보스였다.'),
    EndStaffOp.sprite(20, 100, 10),
    EndStaffOp.sprite(40, 100, 14),
    EndStaffOp.sprite(60, 100, 18),
    EndStaffOp.sprite(20, 120, 11),
    EndStaffOp.sprite(40, 120, 15),
    EndStaffOp.sprite(60, 120, 19),
    EndStaffOp.text(120, 112, 'Huge Dragon, LOCKUP 동굴의 보스였다.'),
    EndStaffOp.sprite(40, 150, 9),
    EndStaffOp.text(120, 152, 'Minotaur, 여기서 두번 등장하는 생물이다.'),
    EndStaffOp.sprite(40, 180, 23),
    EndStaffOp.text(120, 182, 'Panzer Viper, DUNGEON OF EVIL 을 지키던 기계 생물.'),
    EndStaffOp.sprite(40, 210, 22),
    EndStaffOp.text(120, 212, 'Black Knight, Necromancer 쪽의 제 2 인자 이다.'),
    EndStaffOp.sprite(40, 240, 26),
    EndStaffOp.text(120, 242, 'ArchiMonk, Necromancer의 왼팔 역할의 실력자.'),
    EndStaffOp.sprite(40, 270, 25),
    EndStaffOp.text(120, 272, 'ArchiMage, Necromancer의 오른팔인 마법사.'),
    EndStaffOp.sprite(40, 300, 16),
    EndStaffOp.sprite(40, 320, 17),
    EndStaffOp.text(120, 312, 'Neo-Necromancer, 바로 당신의 목표였던 그자.'),
  ];

  /// `PutSprite`의 AND 마스크 오프셋 (`Chara^[number+28]`).
  static const int spriteMaskOffset = 28;

  /// `Font^[47]` 배경 타일.
  static const int backgroundTile = 47;

  /// `RGB(6, ...)` 천둥 번쩍임: 색 6의 평상시/번쩍 값.
  static const VgaColor thunderBase = (40, 20, 0);
  static const VgaColor thunderFlash = (10, 20, 63);

  /// `StaffMessage` 직후의 번쩍임 열: (색, 이어지는 `delay` ms).
  static const List<(VgaColor, int)> openingFlashes = [
    (thunderFlash, 40),
    (thunderBase, 100),
    (thunderFlash, 100),
    (thunderBase, 0),
  ];

  /// 마지막 텍스트 화면 (`Writeln`) — 앞에 빈 줄 둘.
  static const int outroBlankLines = 2;
  static const List<String> outroLines = [
    '                              << The End >>',
    '    " The Codex of Another Lore  vol. #1 " is made by Ahn Young-Kie.',
    '                        You must be a genius !!!',
  ];
  static const List<int> outroColors = [15, 15, 7];

  /// `for i := 1 to 63 do begin RGB(7,i,i,i); RGB(15,i,i,i); delay(10)`.
  static const int outroFadeTo = 63;
  static const int outroFadeDelayMs = 10;

  /// `delay(500)`, 이어서 `for i := 62 downto 42 do RGB(7,i,i,i); delay(15)`.
  static const int outroHoldMs = 500;
  static const int outroDimFrom = 62;
  static const int outroDimTo = 42;
  static const int outroDimDelayMs = 15;

  /// 6비트 VGA → 8비트 채널.
  static int channel(int v) => (v << 2) | (v >> 4);
}

/// `StaffMessage`의 한 그리기 동작.
class EndStaffOp {
  final String kind; // color | bold | sprite | text
  final int a; // color 번호 또는 x
  final int b; // y
  final int c; // sprite 번호
  final String text;
  final String after;
  final bool hero;

  const EndStaffOp.color(int color)
    : kind = 'color',
      a = color,
      b = 0,
      c = 0,
      text = '',
      after = '',
      hero = false;
  const EndStaffOp.bold(int x, int y, this.text)
    : kind = 'bold',
      a = x,
      b = y,
      c = 0,
      after = '',
      hero = false;
  const EndStaffOp.sprite(int x, int y, int number)
    : kind = 'sprite',
      a = x,
      b = y,
      c = number,
      text = '',
      after = '',
      hero = false;
  const EndStaffOp.text(
    int x,
    int y,
    this.text, {
    this.after = '',
    this.hero = false,
  }) : kind = 'text',
       a = x,
       b = y,
       c = 0;

  /// 주인공 이름을 끼운 문구 (`'이름은 '+player[1].name+'. 바로 당신이다.'`).
  String resolve(String heroName) => hero ? '$text$heroName$after' : text;
}

/// `End_Demo`의 걷는 스프라이트 루프 (x = 600, 200 ms/프레임).
class LoreEndWalker {
  static const int x = 600;
  static const int wrapAbove = 350;
  static const int step = 2;
  static const int delayMs = 200;
  static const int tile = LoreEnd.backgroundTile;

  int y = 0;
  int j = 24;
  int i = 1;

  /// 한 반복. 지우는 두 타일 줄(`y div 20`, `y div 20 + 1`), 그려질 y, 스프라이트.
  ({int eraseRow, int y, int sprite}) frame() {
    final eraseRow = y ~/ 20;
    if (y > wrapAbove) y = 0;
    y += step;
    final drawn = (eraseRow: eraseRow, y: y, sprite: j);
    if (i == 1) {
      switch (j) {
        case 20:
          j = 24;
        case 24:
          j = 21;
        case 21:
          j = 24;
          i = 0;
      }
    } else {
      switch (j) {
        case 20:
          j = 24;
          i = 1;
        case 24:
          j = 20;
        case 21:
          j = 24;
      }
    }
    return drawn;
  }
}

/// `ThunderEffect`의 한 반복: `random(1000)` 이 0이면 `random(100)` 을 뽑고,
/// 둘 다 0일 때 `random(100)+20` ms 번쩍인다.
class LoreEndThunder {
  const LoreEndThunder._();

  /// 번쩍임 길이(ms) 또는 이번 반복에서 번쩍이지 않으면 null.
  static int? iterate(Random random) {
    if (random.nextInt(1000) == 0) {
      if (random.nextInt(100) == 0) return random.nextInt(100) + 20;
    }
    return null;
  }
}
