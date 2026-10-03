/// `LOREMENU.PAS` `Extrasense` (700-868) and `ReturnPredict` (643-698),
/// ported directly.
///
/// `Select`, `Print`/`Talk`/`Message`, the see-through map redraw and the
/// clairvoyance scrolling go through [LoreExtrasenseIo]. `party.etc[5]`
/// (mind reading), `etc[38]` and the quest bytes `etc[10, 13, 14, 15, 40, 41]`
/// are the source bytes.
library;

import '../models/party_member.dart';
import 'lore_menu_text.dart';
import 'lore_source_memory.dart';
import 'lore_sub_text.dart';

abstract interface class LoreExtrasenseIo {
  /// `Select` with the texts printed above it; 0 = Esc.
  Future<int> select(
    String title,
    List<String> items, {
    List<(int, String)> lines,
  });

  /// `Print` lines followed by `PressAnyKey`.
  Future<void> talk(List<(int, String)> lines);

  /// `Message(color, s)`: the window is cleared and [text] printed; no key.
  void message(int color, String text);

  /// 투시: the special cells (tile 0, and tile 52 in a den or keep) are
  /// drawn blank while [text] is shown with `PressAnyKey`, then restored.
  Future<void> seeThrough(String text);

  /// 천리안 `print(15,'천리안의 사용중 ...')` and the key prompt; the view
  /// follows [clairvoyanceStep] until [clairvoyanceEnd].
  void clairvoyanceBegin();

  /// `Scroll(FALSE)` at (x, y), then `readkey`: false when it was Esc.
  Future<bool> clairvoyanceStep(int x, int y);

  /// `Clear; x := party.xaxis; y := party.yaxis; Scroll(TRUE)`.
  void clairvoyanceEnd();

  int get x;
  int get y;
  int get xmax;
  int get ymax;
  int get mapId;

  /// `DisplayESP`.
  void displayEsp();
}

class LoreExtrasense {
  const LoreExtrasense._();

  /// `Predict_Data[1..25]`.
  static const List<String> predictData = [
    'Lord Ahn 을 만날',
    'MENACE를 탐험할',
    'Lord Ahn에게 다시 돌아갈',
    'LASTDITCH로 갈',
    'LASTDITCH의 성주를 만날',
    'PYRAMID 속의 Major Mummy를 물리칠',
    'LASTDITCH의 성주에게로 돌아갈',
    'LASTDITCH의 GROUND GATE로 갈',
    'GAIA TERRA의 성주를 만날',
    'EVIL SEAL에서 황금의 봉인을 발견할',
    'GAIA TERRA의 성주에게 돌아갈',
    'QUAKE에서 ArchiGagoyle를 물리칠',
    '북동쪽의 WIVERN 동굴에 갈',
    'WATER FIELD로 갈',
    'WATER FIELD의 군주를 만날',
    'NOTICE 속의 Hidra를 물리칠',
    'LOCKUP 속의 Dragon을 물리칠',
    'GAIA TERRA 의 SWAMP GATE로 갈',
    '위쪽의 게이트를 통해 SWAMP KEEP으로 갈',
    'SWAMP 대륙에 존재하는 두개의 봉인을 풀',
    'SWAMP KEEP의 라바 게이트를 작동 시킬',
    '적의 집결지인 EVIL CONCENTRATION으로 갈',
    '숨겨진 적의 마지막 요새로 들어갈',
    '위쪽의 동굴에서 Necromancer를 만날',
    'Necromancer와 마지막 결전을 벌일',
  ];

  static const String prophecyHeader = ' 당신은 당신의 미래를 예언한다 ...';
  static const String prophecyBlocked = '당신은 어떤 힘에 의해 예언을 방해 받고 있다';

  /// `ReturnPredict`: the `Predict_Data` index (1..25, 0 = none).
  static int returnPredict(LorePartyEtc etc, int map) {
    int e(int i) => etc.read(i);
    bool odd(int i) => e(i).isOdd;
    var r = 0;
    switch (e(10)) {
      case 0 || 1 || 2:
        r = 1;
      case 3:
        r = 2;
      case 4 || 5:
        r = 3;
      case 6:
        r = 4;
    }
    if (r == 4 && map == 7) r = 5;
    switch (e(13)) {
      case 1:
        r = 6;
      case 2:
        r = 7;
      case 3:
        r = 8;
    }
    if (e(13) == 3) {
      switch (e(14)) {
        case 0:
          r = 9;
        case 1:
          r = 10;
        case 2:
          r = 11;
        case 3:
          r = 9;
        case 4:
          r = 12;
        case 5:
          r = 11;
        case 6:
          r = 13;
      }
    }
    if (e(14) == 6 && map == 16) r = 14;
    if (e(14) == 6 && map == 2) {
      r = 13;
    } else if (r == 13) {
      switch (e(15)) {
        case 0:
          r = 15;
        case 1:
          r = 16;
        case 2:
          r = 15;
        case 3:
          r = 17;
        case 4:
          r = 15;
        case 5:
          r = 18;
      }
    }
    if (map == 13 && !odd(40)) r = 19;
    if (e(15) == 5) {
      if (map == 4 || (map >= 19 && map <= 21)) r = 20;
      if (odd(40) && odd(41)) r = 21;
    }
    if (map == 5) r = 22;
    if (e(15) == 5 && map > 21) {
      switch (map) {
        case 22 || 24:
          r = 22;
        case 23:
          r = 23;
        case 25:
          r = 24;
        case 26:
          r = 25;
      }
    }
    return r;
  }

  static const String espNotEnough = LoreMenuText.espNotEnough;

  static Future<void> run(
    LoreExtrasenseIo io,
    List<PartyMember> party,
    LorePartyEtc etc,
  ) async {
    // person := ChooseWhom(FALSE)
    final slots = [
      for (var i = 0; i < party.length && i < 6; i++)
        if (party[i].name.isNotEmpty) i,
    ];
    final whom = await io.select(
      '',
      [for (final i in slots) party[i].name],
      lines: const [(10, LoreSubText.chooseOne)],
    );
    if (whom == 0) return;
    final caster = party[slots[whom - 1]];
    if (!caster.isBattleActive) {
      final sex = caster.sex == Gender.female ? '그녀' : '그';
      io.message(7, '$sex${LoreMenuText.espNotReady}');
      return;
    }
    if (!(const {2, 3, 6}.contains(caster.playerClass.id) ||
        etc.hasBit(38, 1))) {
      await io.talk(const [(7, LoreMenuText.espNoAbility)]);
      return;
    }
    final k = await io.select(LoreMenuText.espKind, LoreMenuText.espNames);
    if (k == 5) {
      io.message(7, '${LoreMenuText.espNames[4]}${LoreMenuText.espBattleOnly}');
      return;
    }
    switch (k) {
      case 1:
        if (io.mapId > 24) {
          io.message(13, LoreMenuText.espEvilPower);
          return;
        }
        if (caster.esp < 10) {
          io.message(7, espNotEnough);
          return;
        }
        await io.seeThrough(LoreMenuText.espSeeThrough);
        caster.esp = caster.esp - 10;
      case 2:
        if (caster.esp < 5) {
          io.message(7, espNotEnough);
          return;
        }
        final i = returnPredict(etc, io.mapId);
        final s = i >= 1 && i <= 25
            ? '당신은 ${predictData[i - 1]} 것이다'
            : prophecyBlocked;
        caster.esp = caster.esp - 5;
        // `cPrint(10,15,' # ',s,'')`: ' # ' is color 10, the text color 15.
        await io.talk([(7, prophecyHeader), (7, ''), (15, ' # $s')]);
      case 3:
        if (caster.esp < 20) {
          io.message(7, espNotEnough);
          return;
        }
        io.message(15, LoreMenuText.espMindRead);
        etc[5] = 3;
      case 4:
        if (io.mapId > 24) {
          io.message(13, LoreMenuText.espEvilPower);
          return;
        }
        final cost = caster.espLevel * 5;
        if (caster.esp < cost) {
          io.message(7, espNotEnough);
          return;
        }
        final dir = await io.select(
          '',
          [
            for (final d in const ['북쪽', '남쪽', '동쪽', '서쪽'])
              '$d${LoreMenuText.espClairvoyanceUse}',
          ],
          lines: const [(15, LoreMenuText.espDirection)],
        );
        if (dir == 0) return;
        caster.esp = caster.esp - cost;
        final (x1, y1) = switch (dir) {
          1 => (0, -1),
          2 => (0, 1),
          3 => (1, 0),
          _ => (-1, 0),
        };
        io.clairvoyanceBegin();
        var x = io.x, y = io.y;
        final steps = caster.espLevel;
        for (var i = 1; i <= steps; i++) {
          x += x1;
          y += y1;
          if (x < 5 || x >= io.xmax - 3 || y < 5 || y >= io.ymax - 3) {
            x -= x1;
            y -= y1;
          } else if (!await io.clairvoyanceStep(x, y)) {
            break; // goto Exit_For
          }
        }
        io.clairvoyanceEnd();
    }
    io.displayEsp();
  }
}
