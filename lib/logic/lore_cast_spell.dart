/// `LOREMENU.PAS` `CastSpell` (622-641) with `AttackSpell`, `CureSpell`
/// (156-230) and `PhenominaSpell` (232-497), ported directly.
///
/// `Select`, `Print`/`Talk`/`Message`, the space-move power input and the
/// map/position globals go through [LoreCastSpellIo]. `party.etc[1..4]`
/// (torch, water, swamp, levitation) and `party.food` are the source bytes.
library;

import '../models/party_member.dart';
import 'field_magic_logic.dart';
import 'lore_menu_text.dart';
import 'lore_source_memory.dart';
import 'lore_sub_text.dart';

abstract interface class LoreCastSpellIo {
  /// `Select` with the texts printed above it; 0 = Esc.
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    List<(int, String)> lines,
  });

  /// `Print` lines followed by `PressAnyKey` (`Talk` is one line).
  Future<void> talk(List<(int, String)> lines);

  /// `Message(color, s)`: the window is cleared and [text] printed; no key.
  void message(int color, String text);

  /// `Print(color, s)`: [text] added to the window; no key.
  void print(int color, String text);

  /// The `## k000 공간 이동력` input: arrows move k in 1..9 from 5, Enter
  /// confirms, Esc returns null.
  Future<int?> spacePower();

  int get x;
  int get y;
  int get xmax;
  int get ymax;
  int get mapId;

  /// `position`: 'town', 'ground', 'den' or 'keep'.
  String get position;
  int tileAt(int x, int y);
  void setTile(int x, int y, int tile);

  /// `x := ..; y := ..; Scroll(TRUE)`.
  void moveTo(int x, int y);
  int get food;
  set food(int value);

  /// `SimpleDisCond` / `displaySP`.
  void displayCondition();
}

class LoreCastSpell {
  const LoreCastSpell._();

  static const String toWhom = '누구에게';
  static const String everyone = '모든 사람들에게';

  /// PhenominaSpell's own `SPnotEnough` (`Message`, no '그러나,').
  static const String phenominaSpNotEnough = '마법 지수가 충분하지 않습니다.';
  static const String phenominaBlocked = ' 이 동굴의 악의 힘이 이 마법을 방해합니다.';

  static PartyMember _slot(List<PartyMember> party, int i) =>
      i <= party.length ? party[i - 1] : PartyMember.blank();

  /// `ChooseWhom(FALSE)`: the named slots, `한명을 고르시오 ---` above them;
  /// returns the slot number or 0.
  static Future<int> chooseWhom(
    LoreCastSpellIo io,
    List<PartyMember> party,
  ) async {
    final slots = [
      for (var i = 1; i <= 6; i++)
        if (_slot(party, i).name.isNotEmpty) i,
    ];
    final k = await io.select(
      '',
      [for (final i in slots) _slot(party, i).name],
      lines: const [(10, LoreSubText.chooseOne)],
    );
    return k == 0 ? 0 : slots[k - 1];
  }

  static Future<void> run(
    LoreCastSpellIo io,
    List<PartyMember> party,
    LorePartyEtc etc,
  ) async {
    final person = await chooseWhom(io, party);
    if (person == 0) return;
    final caster = _slot(party, person);
    if (!caster.isBattleActive) {
      final sex = caster.sex == Gender.female ? '그녀' : '그';
      io.message(7, '$sex${LoreMenuText.castSpellNotReady}');
      return;
    }
    final k = await io.select(LoreMenuText.castSpellKind, const [
      LoreMenuText.castSpellAttack,
      LoreMenuText.castSpellCure,
      LoreMenuText.castSpellPhenomina,
    ]);
    switch (k) {
      case 1:
        await io.talk(const [(7, FieldMagicLogic.attackSpellMessage)]);
      case 2:
        await cureSpell(io, party, caster);
      case 3:
        await phenominaSpell(io, party, caster, etc);
    }
  }

  /// `CureSpell` outside battle (`party.etc[6] = 0`, so refusals print).
  static Future<void> cureSpell(
    LoreCastSpellIo io,
    List<PartyMember> party,
    PartyMember caster,
  ) async {
    // m[1..6] := player[1..6].name; j := 6 (7 with a sixth member).
    final names = [for (var i = 1; i <= 6; i++) _slot(party, i).name];
    final j = names[5].isNotEmpty ? 7 : 6;
    final whom = await io.select(toWhom, [...names.take(j - 1), everyone]);
    if (whom == 0) return;
    final printed = <(int, String)>[];
    Future<void> each(MagicCastResult result) async {
      for (final text in result.messages) {
        if (text == FieldMagicLogic.spNotEnoughMessage) {
          // SPnotEnough = Talk: what is printed so far, then a key.
          printed.add((7, text));
          await io.talk(List.of(printed));
          printed.clear();
        } else {
          printed.add((result.success ? 15 : 7, text));
        }
      }
    }

    final results = <MagicCastResult>[];
    if (whom != j) {
      var i = caster.magicLevel ~/ 2 + 1;
      if (i > 7) i = 7;
      final k = await io.select(
        LoreMenuText.phenominaSelect,
        FieldMagicLogic.cureSpellNames,
        maxsum: i,
      );
      if (k == 0) return;
      FieldMagicLogic.castPersonalCure(
        caster,
        _slot(party, whom),
        k,
        each: results.add,
      );
    } else {
      final i = caster.magicLevel ~/ 2 - 3;
      if (i < 0) {
        await io.talk([(7, FieldMagicLogic.strongCureNotReady(caster.name))]);
        return;
      }
      final k = await io.select(
        LoreMenuText.phenominaSelect,
        FieldMagicLogic.cureAllSpellNames,
        maxsum: i,
      );
      // No `if j = 0 then exit` here: Esc still ends with the key wait.
      FieldMagicLogic.castGroupCure(caster, party, k, each: results.add);
    }
    for (final result in results) {
      await each(result);
    }
    io.displayCondition();
    await io.talk([...printed, (7, ''), (7, '')]);
  }

  static Future<(int, int)?> _direction(
    LoreCastSpellIo io,
    String suffix,
  ) async {
    final k = await io.select(
      '',
      [
        for (final d in const ['북쪽', '남쪽', '동쪽', '서쪽']) '$d$suffix',
      ],
      lines: const [(15, LoreMenuText.espDirection)],
    );
    return switch (k) {
      1 => (0, -1),
      2 => (0, 1),
      3 => (1, 0),
      4 => (-1, 0),
      _ => null,
    };
  }

  /// `map[x,y] in [0, lo..47]`.
  static bool _zeroOr(int tile, int lo) =>
      tile == 0 || (tile >= lo && tile <= 47);

  /// `PhenominaSpell`.
  static Future<void> phenominaSpell(
    LoreCastSpellIo io,
    List<PartyMember> party,
    PartyMember caster,
    LorePartyEtc etc,
  ) async {
    final level = caster.magicLevel;
    var j = level > 1 ? level ~/ 2 + 1 : 1;
    if (j > 8) j = 8;
    final k = await io.select(
      LoreMenuText.phenominaSelect,
      FieldMagicLogic.phenominaSpellNames,
      maxsum: j,
    );
    if (k == 0) return;
    bool spNotEnough(int cost) {
      if (caster.sp >= cost) return false;
      io.message(7, phenominaSpNotEnough);
      return true;
    }

    final denOrKeep = io.position == 'den' || io.position == 'keep';
    switch (k) {
      case 1:
        if (spNotEnough(1)) return;
        if (etc.read(1) < 255) etc[1] = etc.read(1) + 1;
        io.message(15, LoreMenuText.phenominaTorch);
        caster.sp = caster.sp - 1;
      case 2:
        if (spNotEnough(5)) return;
        io.message(15, LoreMenuText.phenominaLevitate);
        etc[4] = 255;
        caster.sp = caster.sp - 5;
      case 3:
        if (spNotEnough(10)) return;
        io.message(15, LoreMenuText.phenominaWater);
        etc[2] = 255;
        caster.sp = caster.sp - 10;
      case 4:
        if (spNotEnough(20)) return;
        io.message(15, LoreMenuText.phenominaSwamp);
        etc[3] = 255;
        caster.sp = caster.sp - 20;
      case 5:
        if (spNotEnough(25)) return;
        final dir = await _direction(io, LoreMenuText.phenominaVaporize);
        if (dir == null) return;
        final (x1, y1) = dir;
        final x = io.x + 2 * x1, y = io.y + 2 * y1;
        if (x < 5 || x >= io.xmax - 3 || y < 5 || y >= io.ymax - 3) return;
        final ok = switch (io.position) {
          'town' => _zeroOr(io.tileAt(x, y), 27),
          'ground' => _zeroOr(io.tileAt(x, y), 24),
          'den' => _zeroOr(io.tileAt(x, y), 41),
          _ => _zeroOr(io.tileAt(x, y), 40),
        };
        if (!ok) {
          io.message(7, LoreMenuText.phenominaVaporizeFail);
          return;
        }
        caster.sp = caster.sp - 25;
        if (io.tileAt(x - x1, y - y1) == 0 ||
            (denOrKeep && io.tileAt(x + x1, y + y1) == 52)) {
          io.message(13, LoreMenuText.phenominaRejected);
        } else {
          io.message(15, LoreMenuText.phenominaVaporizeDone);
          io.moveTo(x, y);
        }
      case 6:
        if (const {20, 25, 26}.contains(io.mapId)) {
          io.message(13, phenominaBlocked);
          return;
        }
        if (spNotEnough(30)) return;
        final dir = await _direction(io, LoreMenuText.phenominaTerrain);
        if (dir == null) return;
        final (x1, y1) = dir;
        final tile = switch (io.position) {
          'town' => 47,
          'ground' => 41,
          _ => 43,
        };
        caster.sp = caster.sp - 30;
        final target = io.tileAt(io.x + x1, io.y + y1);
        if (target == 0 || (denOrKeep && target == 52)) {
          io.message(13, LoreMenuText.phenominaRejected);
        } else {
          io.setTile(io.x + x1, io.y + y1, tile);
          io.message(15, LoreMenuText.phenominaTerrainDone);
        }
      case 7:
        if (const {20, 25, 26}.contains(io.mapId)) {
          io.message(13, phenominaBlocked);
          return;
        }
        if (spNotEnough(50)) return;
        final dir = await _direction(io, LoreMenuText.phenominaSpaceMove);
        if (dir == null) return;
        final (x1, y1) = dir;
        final power = await io.spacePower();
        if (power == null) return;
        final x = io.x + power * x1, y = io.y + power * y1;
        if (x < 5 || x >= io.xmax - 3 || y < 5 || y >= io.ymax - 3) {
          io.message(7, FieldMagicLogic.spaceMoveNotAllowedMessage);
          return;
        }
        final tile = io.tileAt(x, y);
        final ok = switch (io.position) {
          'town' => tile >= 27 && tile <= 47,
          'ground' => tile >= 24 && tile <= 47,
          'den' => tile >= 41 && tile <= 47,
          _ => tile >= 27 && tile <= 47,
        };
        if (!ok) {
          io.message(7, FieldMagicLogic.spaceMoveBadSpotMessage);
          return;
        }
        caster.sp = caster.sp - 50;
        if (tile == 0 || (denOrKeep && io.tileAt(x + x1, y + y1) == 52)) {
          io.message(13, FieldMagicLogic.spaceMoveRejectedMessage);
        } else {
          io.message(15, FieldMagicLogic.spaceMoveDoneMessage);
          io.moveTo(x, y);
        }
      case 8:
        if (spNotEnough(30)) return;
        final members = party.take(6).where((p) => p.name.isNotEmpty).length;
        io.food = io.food + members > 255 ? 255 : io.food + members;
        caster.sp = caster.sp - 30;
        io.print(15, ' 식량 제조 마법은 성공적으로 수행되었습니다');
        io.print(15, '            $members 개의 식량이 증가됨');
        io.print(11, '      일행의 현재 식량은 ${io.food} 개 입니다');
    }
    io.displayCondition();
  }
}
