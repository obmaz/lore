import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/field_hotkeys.dart';
import 'package:lore/main.dart';

/// 키보드 입력 검증.
///
/// 1) 원작 `LOREMAIN.PAS Main` 루프의 핫키(P/V/Q/C/E/R/G/Space) 매핑 단위 테스트
/// 2) `LoreGame.handleKeyEvent`의 방향키/WASD 이동 경로 검증
/// 3) 실제 위젯 트리에 키 이벤트를 보내 UI가 열리는지 확인하는 통합 테스트
void main() {
  KeyDownEvent keyDown(LogicalKeyboardKey key) => KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.arrowRight,
    logicalKey: key,
    timeStamp: Duration.zero,
  );

  LoreMapData openMap() => LoreMapData(
    name: 'TEST',
    xmax: 20,
    ymax: 20,
    grid: List.generate(
      20,
      (y) => List.generate(20, (x) {
        if (x == 0 || y == 0 || x == 19 || y == 19) return 1; // 외곽 성벽
        return 42; // 바닥
      }),
    ),
  );

  group('1. 필드 핫키 매핑 (원작 LOREMAIN.PAS)', () {
    test('원작 키 배열 P/V/Q/C/E/R/G/Space 가 정확히 매핑된다', () {
      expect(
        FieldHotkeys.resolve(LogicalKeyboardKey.space),
        FieldAction.openMenu,
      );
      expect(
        FieldHotkeys.resolve(LogicalKeyboardKey.keyP),
        FieldAction.viewParty,
      );
      expect(
        FieldHotkeys.resolve(LogicalKeyboardKey.keyV),
        FieldAction.viewCharacter,
      );
      expect(
        FieldHotkeys.resolve(LogicalKeyboardKey.keyQ),
        FieldAction.quickView,
      );
      expect(
        FieldHotkeys.resolve(LogicalKeyboardKey.keyC),
        FieldAction.castSpell,
      );
      expect(
        FieldHotkeys.resolve(LogicalKeyboardKey.keyE),
        FieldAction.extrasense,
      );
      expect(FieldHotkeys.resolve(LogicalKeyboardKey.keyR), FieldAction.rest);
      expect(
        FieldHotkeys.resolve(LogicalKeyboardKey.keyG),
        FieldAction.gameOption,
      );
      expect(
        FieldHotkeys.resolve(LogicalKeyboardKey.backspace),
        FieldAction.toggleSound,
      );
    });

    test('이식편 추가 키(F1/H)와 이동 키는 구분된다', () {
      expect(FieldHotkeys.resolve(LogicalKeyboardKey.f1), FieldAction.guide);
      expect(FieldHotkeys.resolve(LogicalKeyboardKey.keyH), FieldAction.guide);

      // 방향키와 WASD는 핫키가 아니라 이동으로 처리된다.
      for (final key in [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyS,
        LogicalKeyboardKey.keyD,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.escape,
      ]) {
        expect(FieldHotkeys.resolve(key), FieldAction.none);
      }
    });

    test('핫키 라벨(도움말 표기) 검증', () {
      expect(FieldHotkeys.keyLabel(FieldAction.openMenu), 'Space');
      expect(FieldHotkeys.keyLabel(FieldAction.rest), 'R');
      expect(FieldHotkeys.keyLabel(FieldAction.gameOption), 'G');
      expect(FieldHotkeys.keyLabel(FieldAction.guide), 'F1');
      expect(FieldHotkeys.keyLabel(FieldAction.none), '');
    });
  });

  group('2. LoreGame.handleKeyEvent 이동 처리', () {
    test('방향키/WASD 로 이동하고 벽에서는 제자리다', () {
      final game = LoreGame();
      game.currentMap = openMap();
      game.playerX = 6;
      game.playerY = 6;

      // → (동)
      game.handleKeyEvent(keyDown(LogicalKeyboardKey.arrowRight));
      expect(game.playerX, 7);
      expect(game.playerDirection, 2);

      // A (서)
      game.handleKeyEvent(keyDown(LogicalKeyboardKey.keyA));
      expect(game.playerX, 6);
      expect(game.playerDirection, 3);

      // ↑ (북)
      game.handleKeyEvent(keyDown(LogicalKeyboardKey.arrowUp));
      expect(game.playerY, 5);
      expect(game.playerDirection, 1);

      // S (남)
      game.handleKeyEvent(keyDown(LogicalKeyboardKey.keyS));
      expect(game.playerY, 6);
      expect(game.playerDirection, 0);

      // 원본 지도 경계(4열)는 내부 타일 값과 관계없이 진입할 수 없다.
      game.playerX = 5;
      game.handleKeyEvent(keyDown(LogicalKeyboardKey.arrowLeft));
      expect(game.playerX, 5);
    });

    test('KeyUp 이벤트와 무관한 키는 이동시키지 않는다', () {
      final game = LoreGame();
      game.currentMap = openMap();
      game.playerX = 3;
      game.playerY = 3;

      game.handleKeyEvent(
        KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.arrowRight,
          logicalKey: LogicalKeyboardKey.arrowRight,
          timeStamp: Duration.zero,
        ),
      );
      expect(game.playerX, 3);

      game.handleKeyEvent(keyDown(LogicalKeyboardKey.keyZ));
      expect(game.playerX, 3);
      expect(game.playerY, 3);
    });
  });

  group('3. 위젯 통합: 실제 키 입력으로 해당 UI가 열린다', () {
    Future<void> startGame(WidgetTester tester) async {
      await tester.pumpWidget(const LoreApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('빠른 모험 시작 (기본 파티)'));
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Flame GameWidget이 계속 프레임을 요청하므로 pumpAndSettle 대신 수동 pump를 쓴다.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> closeDialog(WidgetTester tester) async {
      await tester.tap(find.text('닫기'));
      await settle(tester);
    }

    testWidgets('Space/P/V/C/R/G 키가 각각 해당 탭을 연다', (WidgetTester tester) async {
      await startGame(tester);

      // Space -> 전체 커맨드 메뉴
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(find.text('당신의 명령을 고르시오 ===>'), findsWidgets);
      await closeDialog(tester);

      // P -> 일행의 상황
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await settle(tester);
      expect(find.text('일행의 상황을 본다'), findsOneWidget);
      await closeDialog(tester);

      // V -> 개인의 상황
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await settle(tester);
      expect(find.text('능력을 보고싶은 인물을 선택하시오'), findsOneWidget);
      await closeDialog(tester);

      // C -> 비전투 마법 시전
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await settle(tester);
      expect(find.text('사용할 마법의 종류 ===>'), findsWidgets);
      await closeDialog(tester);

      // R -> 야외 캠프 휴식
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await settle(tester);
      expect(find.text('여기서 쉰다'), findsWidgets);
      expect(find.text('여기서 쉰다'), findsWidgets);
      await closeDialog(tester);

      // G -> 게임 저장/불러오기
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await settle(tester);
      expect(find.text('게임 선택 상황'), findsOneWidget);
      await closeDialog(tester);
    });

    testWidgets('Q/E/F1 키가 각각 전용 화면을 연다', (WidgetTester tester) async {
      await startGame(tester);

      // Q -> 간이 일행 상황
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await settle(tester);
      expect(find.text('중독'), findsOneWidget);
      expect(find.text('죽음'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await settle(tester);

      // E -> 초감각(ESP)
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await settle(tester);
      expect(find.textContaining('초감각'), findsWidgets);
      await tester.tap(find.text('닫기'));
      await settle(tester);

      // F1 -> 제작자 서문 & 가이드
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await settle(tester);
      expect(find.text('◆ 또 다른 지식의 성전 - 제작자 서문 ◆'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
    });
  });
}
