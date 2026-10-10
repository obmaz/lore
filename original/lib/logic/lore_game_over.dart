/// `LORESUB.PAS` `GameOver` (447-543) 직접 이식.
///
/// `party.etc[6]` 값으로 갈래가 나뉜다.
///  - `255` (`DetectGameOver`: 전멸): 전멸 문구 → `PressAnyKey` → 불러올 게임 선택.
///    `없습니다`/취소면 종료 확인으로 내려간다.
///  - `1` (`BattleMode` 패배): 패배 문구 → 재개/끝냄 선택 → 불러올 게임 선택.
///    불러오면 `party.etc[6] := 255`, 아니면 프로그램 종료(`Halt`).
///  - 그 밖(`GameOption` 6번 등): `정말로 끝내겠습니까 ?` → `<< 아니오 >>`/취소면
///    그대로 돌아가고 `<< 예 >>`면 종료.
///
/// 화면(`Clear`, `HPrintXY`, `PressAnyKey`, `Select`)과 `Load` 는 [LoreGameOverIo]
/// 어댑터가 맡는다.
library;

import 'lore_sub_text.dart';
import 'lore_load_failure.dart';
import 'lore_window_io.dart';

abstract interface class LoreGameOverIo implements LoreWindowIo {
  /// `LoadNo := chr(k+47); Load` — [slot] 1..4. 저장이 없으면 false.
  Future<bool> load(int slot);
}

enum LoreGameOverEnd {
  /// `exit` 로 호출자에게 돌아간다(불러오지 않음).
  resumed,

  /// 저장한 게임을 불러온 뒤 돌아간다.
  reloaded,

  /// `Halt` (프로그램 종료).
  halted,
}

class LoreGameOverResult {
  const LoreGameOverResult(this.end, {this.etc6, this.missingSlot});

  final LoreGameOverEnd end;

  /// 불러온 뒤 덮어쓸 `party.etc[6]` (전투 패배 갈래의 255). null 이면 불러온 값 유지.
  final int? etc6;

  /// `Load` 의 `ErrorMessage('party'+LoadNo+'.dat', TRUE); Halt` 로 끝난 슬롯.
  final int? missingSlot;
}

class LoreGameOver {
  const LoreGameOver._();

  /// `Load` 실패 시 `ErrorMessage` 가 텍스트 화면에 쓰는 두 줄.
  static List<String> missingSaveLines(int slot) =>
      LoreLoadFailure('party$slot.dat', needCreate: true).lines;

  /// `Halt` 직전 텍스트 화면 문구.
  static const String haltMessage = 'Feel your RPG imagination !!';

  static Future<LoreGameOverResult> run(int etc6, LoreGameOverIo io) async {
    if (etc6 == 255) {
      io.clear();
      io.print(13, LoreSubText.allDead);
      await io.pressAnyKey();
      final k = await io.select(
        LoreSubText.selectLoadGame,
        LoreSubText.loadSlots,
        clean: true,
      );
      if (k > 1) {
        io.print(11, LoreSubText.loadingGame);
        if (!await io.load(k - 1)) {
          return LoreGameOverResult(LoreGameOverEnd.halted, missingSlot: k - 1);
        }
        io.clear();
        return const LoreGameOverResult(LoreGameOverEnd.reloaded);
      }
    }
    if (etc6 != 1) {
      io.print(10, LoreSubText.quitConfirm);
      final k = await io.select('', const [
        LoreSubText.quitNo,
        LoreSubText.quitYes,
      ], clean: false);
      if (k < 2) return const LoreGameOverResult(LoreGameOverEnd.resumed);
    } else {
      io.clear();
      io.print(13, LoreSubText.battleLost);
      io.print(10, LoreSubText.battleLostAsk);
      var k = await io.select('', const [
        LoreSubText.resumeGame,
        LoreSubText.endGame,
      ], clean: false);
      if (k == 1) {
        k = await io.select(
          LoreSubText.selectLoadGame,
          LoreSubText.loadSlots,
          clean: true,
        );
        if (k > 1) {
          io.print(11, LoreSubText.loadingGame);
          if (!await io.load(k - 1)) {
            return LoreGameOverResult(
              LoreGameOverEnd.halted,
              missingSlot: k - 1,
            );
          }
          io.clear();
          return const LoreGameOverResult(LoreGameOverEnd.reloaded, etc6: 255);
        }
      }
    }
    return const LoreGameOverResult(LoreGameOverEnd.halted);
  }
}
