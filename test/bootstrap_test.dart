import 'support/legacy_json_fixture_engine.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_sub_text.dart';
import 'package:lore/data/lore_data.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_dialogue_manager.dart';
import 'package:lore/game/lore_world_manager.dart';
import 'package:lore/game/sprite_sheet.dart';
import 'package:lore/logic/lore_join.dart';
import 'package:lore/main.dart';
import 'package:lore/widgets/dpad_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `main()`과 동일한 순서로 모든 JSON/PNG 데이터를 로드한 "JSON 사용 상태"의 통합 검증.
///
/// 개별 계층 테스트(data_json_test, dialogue_json_test, world_rules_test 등)는 각
/// 소스를 따로 확인하고, `widget_test`는 JSON 없이(내장 폴백) 앱을 부팅한다.
/// 이 테스트는 **여러 소스가 실제로 함께 로드된 상태**에서 데이터 조회·스크립트 실행·
/// 스프라이트 렌더링·앱 부팅이 모두 정상인지 확인한다.
///
/// 주의: 데이터 로딩은 `setUp`(실제 비동기 영역)에서 수행한다. `testWidgets` 본문은
/// 가짜 비동기(fake async) 영역이라 `instantiateImageCodec` 같은 실제 비동기 작업을
/// 기다리면 테스트가 그대로 멈춘다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('부트스트랩 통합 (JSON 데이터 사용 상태)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // main()과 동일한 로드 순서
      await LoreData.instance.load();
      await LegacyJsonFixtureEngine.instance.load();
      await SpriteLibrary.instance.load();
      await LoreWorldManager.instance.loadData();
    });

    test('1. 모든 JSON 소스가 로드되고 조회된다', () {
      expect(LoreData.instance.usingJson, isTrue);
      expect(LegacyJsonFixtureEngine.instance.usingJson, isTrue);
      expect(SpriteLibrary.instance.usingImages, isTrue);

      expect(LoreData.instance.monster(1).name, 'Orc');
      expect(LoreData.instance.spell(1).id, 1);
      expect(LoreData.instance.map(6)!.fileName, 'TOWN1');
      expect(SpriteLibrary.instance.get('CHARA')!.count, 56);
      expect(LoreWorldManager.instance.findPortal(1, 20, 11)!.targetMapId, 6);
      expect(LegacyJsonFixtureEngine.instance.scripts.length, 599);
    });

    test('2. JSON 대화/스크립트가 함께 동작한다 (모험 흐름 시뮬레이션)', () {
      final dialogue = LoreDialogueManager.instance;
      final scripts = LegacyJsonFixtureEngine.instance;
      dialogue.loadFlags({});

      // 1) 마을에서 NPC 대사 (JSON scripts.json, talk 트리거: LORETALK 원문)
      final guard = scripts.startTalk(6, 9, 64, const ScriptContext())!;
      expect(guard.outcome.messages.join(), contains('Serpent'));

      // 2) 좌표 이벤트로 금화 획득 (JSON scripts.json, step 트리거)
      //    게임 화면과 같이 결과의 플래그를 대화 매니저에 반영한다.
      final gold = scripts.startStep(9, 10, 24, const ScriptContext())!;
      expect(gold.outcome.goldDelta, 5000);
      for (final f in gold.outcome.setFlags) {
        dialogue.setFlag(f);
      }

      // 3) 동료 영입 (스크립트 → LoreJoin)
      final rigel = scripts.startStep(12, 12, 48, const ScriptContext())!;
      final joined = rigel.choose(0).outcome.recruits.single;
      final member = LoreJoin.byKey(joined.key)!;
      expect(member.name, 'Rigel');
      expect(member.playerClass.koreanName, '사냥꾼');

      // 4) 스크립트가 설정한 플래그가 대화 매니저에 반영된다
      dialogue.setFlag('rigelJoined');
      expect(dialogue.rigelJoined, isTrue);
      final flags = dialogue.getFlagsCopy();
      expect(flags['rigelJoined'], isTrue);

      // 5) 1회성 스크립트는 재실행되지 않는다
      // (원작 `party.etc` 비트가 켜졌으므로 현재 플래그로 다시 판정한다.)
      final liveFlags = dialogue
          .getFlagsCopy()
          .entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toSet();
      expect(
        scripts
                .startStep(9, 10, 24, ScriptContext(flags: liveFlags))
                ?.outcome
                .goldDelta ??
            0,
        0,
      );
    });

    test('3. 로드된 PNG 스프라이트를 실제로 그릴 수 있다', () async {
      final sheet = SpriteLibrary.instance.get('TOWN')!;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      sheet.draw(
        canvas,
        42,
        const ui.Rect.fromLTWH(0, 0, 40, 40),
        opaqueBackground: true,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(40, 40);
      expect(image.width, 40);
      expect(image.height, 40);
      image.dispose();
      picture.dispose();
    });

    testWidgets('4. 위젯 트리에서 스프라이트를 렌더링해도 정상 동작한다', (WidgetTester tester) async {
      final sheet = SpriteLibrary.instance.get('CHARA')!;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            painter: _SpritePainter(sheet),
            size: const Size(60, 60),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('5. JSON 데이터가 로드된 상태에서 앱이 부팅되고 필드에 진입한다', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const LoreApp());
      await tester.pump(const Duration(milliseconds: 100));

      // 타이틀 화면
      expect(find.text('또다른 지식의 성전  제 1 부'), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-start')), findsOneWidget);

      // 빠른 모험 시작 → 마을(51, 31) 진입
      await tester.tap(find.byKey(const ValueKey('quick-start')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DPadWidget), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('panel-tab-party')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text(LoreSubText.statusHeader), findsOneWidget);

      // 부팅 후에도 JSON 데이터가 계속 사용되고 있다
      expect(LoreData.instance.usingJson, isTrue);
      expect(SpriteLibrary.instance.usingImages, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}

class _SpritePainter extends CustomPainter {
  final SpriteSheet sheet;
  _SpritePainter(this.sheet);

  @override
  void paint(Canvas canvas, Size size) {
    sheet.draw(canvas, 0, Offset.zero & size, opaqueBackground: true);
  }

  @override
  bool shouldRepaint(covariant _SpritePainter oldDelegate) => false;
}
