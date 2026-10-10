/// `LOREMENU.PAS` `GameOption` (914-1022) 직접 이식.
///
/// `Select` 와 화면 출력, `Load`/`Save`/`GameOver`, 상태 창 갱신은
/// [LoreGameOptionIo] 어댑터가 맡는다. `encounter^`/`maxenemy^` 는 원본처럼
/// `party.etc[7]`/`party.etc[8]` 이다.
library;

import '../models/party_member.dart';
import 'lore_menu_text.dart';
import 'lore_source_memory.dart';
import 'lore_transient_slots.dart';
import 'lore_sub_text.dart';

abstract interface class LoreGameOptionIo {
  /// `Select` — [lines] are the texts printed above it (color, text); 0 = Esc.
  Future<int> select(
    String title,
    List<String> items, {
    List<(int, String)> lines,
  });

  /// [lines] printed, then `PressAnyKey`.
  Future<void> message(List<(int, String)> lines);

  /// `LoadNo := chr(k+47); Load` for slot 1..4 (`저장했던 게임을 다시 불러옵니다`).
  Future<void> load(int slot);

  /// `LoadNo := chr(k+47); Save` for slot 1..4.
  Future<void> save(int slot);

  /// `GameOver` with the current `party.etc[6]`.
  Future<void> gameOver();

  /// `Display_Condition`.
  void displayCondition();
}

class LoreGameOption {
  const LoreGameOption._();

  /// `m[i-1] := player[i].name`, or `'Reserved'` for an empty slot.
  static List<String> slotNames(List<PartyMember> party, int from, int to) => [
    for (var i = from; i <= to; i++)
      i <= party.length && party[i - 1].name.isNotEmpty
          ? party[i - 1].name
          : LoreMenuText.optionReserved,
  ];

  /// `move(player[j],player[7],55); move(player[k],player[j],55);
  /// move(player[7],player[k],55)` — the whole 55-byte `lore` record.
  static void swap(
    List<PartyMember> party,
    int j,
    int k, {
    LoreTransientSlots? slots,
  }) {
    while (party.length < (j > k ? j : k)) {
      party.add(PartyMember.blank());
    }
    final t = party[j - 1];
    slots?.rememberSwapPlayer(t);
    party[j - 1] = party[k - 1];
    party[k - 1] = t;
  }

  static Future<void> run(
    LoreGameOptionIo io,
    List<PartyMember> party,
    LorePartyEtc etc, {
    LoreTransientSlots? slots,
  }) async {
    final k = await io.select(LoreMenuText.optionTitle, const [
      LoreMenuText.optionDifficulty,
      LoreMenuText.optionOrder,
      LoreMenuText.optionRemove,
      LoreMenuText.optionResume,
      LoreMenuText.optionSave,
      LoreMenuText.optionQuit,
    ]);
    switch (k) {
      case 1:
        var maxEnemy =
            await io.select(
              '',
              [
                for (var i = 1; i <= 5; i++)
                  '${i + 2}${LoreMenuText.optionEnemySuffix}',
              ],
              lines: const [
                (12, LoreMenuText.optionMaxEnemy1),
                (12, LoreMenuText.optionMaxEnemy2),
              ],
            ) +
            2;
        if (maxEnemy == 2) maxEnemy = 5;
        etc[8] = maxEnemy;
        var encounter = await io.select(
          LoreMenuText.optionEncounterPrompt,
          const [
            LoreMenuText.optionEncounter1,
            LoreMenuText.optionEncounter2,
            LoreMenuText.optionEncounter3,
            LoreMenuText.optionEncounter4,
            LoreMenuText.optionEncounter5,
          ],
        );
        if (encounter == 0) encounter = 3;
        etc[7] = 6 - encounter;
      case 2:
        const heading = [
          (12, LoreMenuText.optionOrderPrompt),
          (11, LoreMenuText.optionOrderWho),
        ];
        final names = slotNames(party, 2, 5);
        final j = await io.select('', names, lines: heading) + 1;
        if (j == 1) return;
        final k = await io.select('', names, lines: heading) + 1;
        if (k == 1) return;
        swap(party, j, k, slots: slots);
        io.displayCondition();
      case 3:
        final k =
            await io.select(
              '',
              slotNames(party, 2, 6),
              lines: const [(12, LoreMenuText.optionRemovePrompt)],
            ) +
            1;
        if (k == 1) return;
        if (k <= party.length) party[k - 1].name = '';
        io.displayCondition();
      case 4:
        final k = await io.select(
          LoreSubText.selectLoadGame,
          LoreSubText.loadSlots,
        );
        if (k < 2) return;
        await io.load(k - 1);
      case 5:
        final k = await io.select(
          LoreMenuText.optionLoadPrompt,
          LoreSubText.loadSlots,
        );
        if (k < 2) return;
        await io.save(k - 1);
        await io.message(const [
          (12, LoreMenuText.optionSaving),
          (7, LoreMenuText.optionSaveDone),
        ]);
      case 6:
        await io.gameOver();
    }
  }
}
