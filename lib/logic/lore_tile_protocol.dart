/// `LOREMAIN.PAS:208-282`의 `position`별 `case map[x,y] of` 행동 분류.
///
/// 좌표와 퀘스트 상태는 여기서 판정하지 않는다. 같은 타일 값도 지도 종류에
/// 따라 다른 행동이다. 입장·표지판·대화는 원본에서 목표 칸으로 이동하지 않고
/// 실행하며, 특수 사건과 위험 지형은 목표 칸을 기준으로 실행한다.
enum LoreTileAction {
  special,
  wall,
  enter,
  sign,
  water,
  swamp,
  lava,
  walk,
  talk;

  bool get entersTargetBeforeAction => switch (this) {
    LoreTileAction.special ||
    LoreTileAction.water ||
    LoreTileAction.swamp ||
    LoreTileAction.lava ||
    LoreTileAction.walk => true,
    _ => false,
  };
}

class LoreTileProtocol {
  LoreTileProtocol._();

  /// `LORESUB.PAS:802-832` `ReturnDefaultFont(party.map)`: `Load` copies this
  /// font slot into slot 0 (`move(font^[j],font^[0],246)`), so a special cell
  /// (tile 0) is drawn like it. The font files store slot 0 as solid black.
  static int defaultFontSlot(int mapId) => switch (mapId) {
    1 => 2,
    2 || 3 || 5 || 12 => 0,
    4 => 41,
    6 || 9 || 11 || 14 || 20 || 26 || 27 => 44,
    7 => 45,
    8 || 24 => 47,
    10 => 27,
    13 => 42,
    15 => 39,
    16 || 17 || 25 => 41,
    18 => 43,
    19 => 49,
    21 || 22 => 40,
    23 => 46,
    _ => 0,
  };

  static LoreTileAction classify(String position, int tile) {
    if (tile == 0) return LoreTileAction.special;
    switch (position) {
      case 'town':
        if (tile >= 1 && tile <= 21) return LoreTileAction.wall;
        if (tile == 22) return LoreTileAction.enter;
        if (tile == 23) return LoreTileAction.sign;
        if (tile == 24) return LoreTileAction.water;
        if (tile == 25) return LoreTileAction.swamp;
        if (tile == 26) return LoreTileAction.lava;
        if (tile >= 27 && tile <= 47) return LoreTileAction.walk;
        return LoreTileAction.talk;
      case 'ground':
        if (tile >= 1 && tile <= 21) return LoreTileAction.wall;
        if (tile == 22) return LoreTileAction.sign;
        if (tile == 48) return LoreTileAction.water;
        if (tile == 23 || tile == 49) return LoreTileAction.swamp;
        if (tile == 50) return LoreTileAction.lava;
        if (tile >= 24 && tile <= 47) return LoreTileAction.walk;
        return LoreTileAction.enter;
      case 'den':
      case 'keep':
        if (tile == 52) return LoreTileAction.special;
        final wallEnd = position == 'keep' ? 39 : 40;
        if ((tile >= 1 && tile <= wallEnd) || tile == 51) {
          return LoreTileAction.wall;
        }
        if (tile == 53) return LoreTileAction.sign;
        if (tile == 48) return LoreTileAction.water;
        if (tile == 49) return LoreTileAction.swamp;
        if (tile == 50) return LoreTileAction.lava;
        if (tile == 54) return LoreTileAction.enter;
        if (tile >= wallEnd + 1 && tile <= 47) {
          return LoreTileAction.walk;
        }
        return LoreTileAction.talk;
      default:
        throw ArgumentError.value(
          position,
          'position',
          'Unknown LORE map kind',
        );
    }
  }
}
