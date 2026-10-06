/// 원작 `LOREMAIN.PAS` `Main` 루프의 필드 핫키 매핑.
///
/// 원작 코드:
/// ```pascal
/// if upcase(c) in ['P','V','Q','C','E','R','G'] then
///    case upcase(c) of
///       'P' : ViewParty;  'V' : ViewCharacter; 'Q' : QuickView;
///       'C' : CastSpell;  'E' : Extrasense;    'R' : Rest;
///       'G' : GameOption;
///    end;
/// if c = #32 then SelectMode;   { Space: 전체 커맨드 메뉴 }
/// ```
library;

import 'package:flutter/services.dart';

/// 필드에서 누른 키가 뜻하는 동작.
enum FieldAction {
  /// Space - 원작 `SelectMode` (전체 커맨드 메뉴)
  openMenu,

  /// P - 일행의 상황
  viewParty,

  /// V - 개인의 상황
  viewCharacter,

  /// Q - 간이 일행 상황
  quickView,

  /// C - 비전투 마법 시전
  castSpell,

  /// E - 초감각(ESP)
  extrasense,

  /// R - 야외 캠프 휴식
  rest,

  /// G - 게임 저장/불러오기
  gameOption,

  /// Backspace - original `soundon := not soundon`.
  toggleSound,

  /// 그 밖의 키(방향키 등은 이동 처리로 넘긴다)
  none,
}

class FieldHotkeys {
  FieldHotkeys._();

  /// 원작 키 배열대로 동작을 판정한다.
  static FieldAction resolve(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) return FieldAction.openMenu;
    if (key == LogicalKeyboardKey.keyP) return FieldAction.viewParty;
    if (key == LogicalKeyboardKey.keyV) return FieldAction.viewCharacter;
    if (key == LogicalKeyboardKey.keyQ) return FieldAction.quickView;
    if (key == LogicalKeyboardKey.keyC) return FieldAction.castSpell;
    if (key == LogicalKeyboardKey.keyE) return FieldAction.extrasense;
    if (key == LogicalKeyboardKey.keyR) return FieldAction.rest;
    if (key == LogicalKeyboardKey.keyG) return FieldAction.gameOption;
    if (key == LogicalKeyboardKey.backspace) return FieldAction.toggleSound;
    return FieldAction.none;
  }

  /// 원작 표기(도움말/로그용) 문자열.
  static String keyLabel(FieldAction action) {
    switch (action) {
      case FieldAction.openMenu:
        return 'Space';
      case FieldAction.viewParty:
        return 'P';
      case FieldAction.viewCharacter:
        return 'V';
      case FieldAction.quickView:
        return 'Q';
      case FieldAction.castSpell:
        return 'C';
      case FieldAction.extrasense:
        return 'E';
      case FieldAction.rest:
        return 'R';
      case FieldAction.gameOption:
        return 'G';
      case FieldAction.toggleSound:
        return 'Backspace';
      case FieldAction.none:
        return '';
    }
  }
}
