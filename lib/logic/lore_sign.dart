// ignore_for_file: prefer_interpolation_to_compose_strings
/// Direct LOREENT.PAS:sign text, including dynamic integer expressions.
library;

class LoreSign {
  static List<(int, String)> lines(int mapId, int x, int y) {
    var s = '';
    var j = 0;
    bool at(int ax, int ay) => x == ax && y == ay;
    final io = _SignLines();
    io.print(7, '푯말에 쓰여있기로 ...');
    io.print(7, '');
    io.print(7, '');
    switch (mapId) {
      case 2:
        {
          if (at(31, 44)) {
            io.print(15, "          WIVERN 가는길");
          }
          if (at(29, 50) || at(35, 72)) {
            io.print(15, "  북쪽 :");
            io.print(15, "       VALIANT PEOPLES 가는길");
            io.print(15, "  남쪽 :");
            io.print(15, "       GAIA TERRA 가는길");
          }
          if (at(44, 77)) {
            io.print(15, "  북동쪽 :");
            io.print(15, "       QUAKE 가는길");
            io.print(15, "  남서쪽 :");
            io.print(15, "       GAIA TERRA 가는길");
          }
        }
      case 6:
        {
          if (at(51, 84)) {
            io.cprint(15, 11, "       여기는 `", "CASTLE LORE", "'성");
            io.print(15, "         여러분을 환영합니다");
            // Source text color.
            io.print(13, 'Lord Ahn');
          }
          if (at(24, 31)) {
            io.print(7, "");
            io.print(15, "             여기는 LORE 주점");
            io.print(15, "       여러분 모두를 환영합니다 !!");
          }
          if (at(51, 18) || at(52, 18)) {
            io.print(7, "");
            io.print(15, "          LORE 왕립  죄수 수용소");
          }
        }
      case 7:
        {
          if (at(39, 68)) {
            io.cprint(15, 11, "        여기는 `", "LASTDITCH", "'성");
            io.print(15, "         여러분을 환영합니다");
          }
          if (at(39, 8)) {
            io.print(12, "       여기는 PYRAMID 의 입구");
          }
          if (at(54, 9)) {
            io.print(10, "     여기는 GROUND GATE 의 입구");
          }
        }
      case 8:
        {
          if (at(39, 67)) {
            io.cprint(15, 11, "      여기는`", "VALIANT PEOPLES", "'성");
            io.print(15, "    우리의 미덕은 굽히지 않는 용기");
            io.print(15, "   우리는 어떤 악에도 굽히지 않는다");
          } else {
            io.print(12, "     여기는 EVIL SEAL 의 입구");
          }
        }
      case 9:
        {
          if (at(24, 26)) {
            io.print(15, "       여기는 국왕의 보물 창고");
          } else {
            io.cprint(15, 11, "         여기는 `", "GAIA TERRA", "'성");
            io.print(15, "          여러분을 환영합니다");
          }
        }
      case 12:
        {
          if (at(24, 68)) {
            io.print(15, "               X 는 7");
          }
          if (at(27, 68)) {
            io.print(15, "               Y 는 9");
          }
          if (at(25, 63)) {
            io.print(15, "       바른 문의 번호는 X + Y");
          }
          if (y == 56) {
            s = ((x - 6) ~/ 7 + 12).toString();
            io.cprint(15, 11, "           문의 번호는 '", s, "'");
          }
          if (at(26, 42)) {
            io.print(15, "            Z 는 2 * Y + X");
          }
          if (at(26, 33)) {
            io.print(15, "        패스코드 x 패스코드 는 Z 라면");
            io.print(7, "");
            io.print(15, "            패스코드는 무엇인가 ?");
          }
          if (y == 29) {
            j = (x - 3) ~/ 5 + 2;
            s = j.toString();
            io.cprint(15, 11, "           패스코드는 '", s, "'");
          }
        }
      case 15:
        {
          io.print(7, "");
          if (at(26, 63)) {
            io.print(15, "            길의 마지막");
          }
          if (at(22, 15)) {
            io.print(15, "     (12,15) 로 공간이동 하시오");
          }
          if (at(11, 14)) {
            io.print(15, "     (13,7) 로 공간이동 하시오");
          }
          if (at(27, 14)) {
            io.print(15, "   황금의 갑옷은 (45,19) 에 숨겨져있음");
          }
        }
      case 17:
        {
          io.print(7, "");
          if (at(68, 47)) {
            io.print(15, "    하! 하! 하!  너는 우리에게 속았다");
          }
          if (at(58, 53)) {
            io.print(10, "      이 게임을 만든 사람");
            io.print(15, "  : 동아 대학교 전기 공학과");
            io.print(15, "        92 학번  안 영기");
          }
          if (at(51, 30)) {
            io.print(15, "       오른쪽 : Hidra 의 보물창고");
            io.print(15, "       왼  쪽 : Hidra 가 있는 방");
          }
          if (at(66, 13)) {
            io.print(15, "     일찌감치 이 곳 탐험을 포기해라");
          }
          if (at(9, 28)) {
            io.print(15, "         위쪽이 진짜 보물창고임");
          }
        }
      case 19:
        {
          io.print(15, "       이 길을 통과하고자하는 사람은");
          io.print(15, "     양측의 늪속에 있는 레버를 당기시오");
        }
      case 23:
        {
          io.print(15, "      (25,27)에 있는 레버를 움직이면");
          io.print(15, "          성을 볼수 있을 것이오.");
          io.print(7, "");
          io.print(10, "             제작자 안 영기 씀");
          io.setTile(25, 27, 52);
        }
    }
    return io.lines;
  }
}

class _SignLines {
  final lines = <(int, String)>[];
  void print(int color, String text) => lines.add((color, text));
  void cprint(
    int color,
    int highlight,
    String before,
    String word,
    String after,
  ) => print(color, before + word + after);
  // The original map-23 write is owned by LoreEntProcedures.sign.
  void setTile(int x, int y, int tile) {}
}
