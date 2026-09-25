import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_dialogue_manager.dart';

class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw Exception('asset not found');
}

/// 좌표 기반 NPC 대사를 JSON(`assets/data/dialogues.json`)으로 관리하는지 검증.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manager = LoreDialogueManager.instance;

  /// 검증 대상 좌표(JSON 파일에서 읽는다).
  Future<List<(int, int, int)>> jsonCoords() async {
    final raw = await rootBundle.loadString('assets/data/dialogues.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return (decoded['dialogues'] as List<dynamic>).map((e) {
      final m = e as Map<String, dynamic>;
      return (m['map'] as int, m['x'] as int, m['y'] as int);
    }).toList();
  }

  setUp(() {
    manager.loadFlags({});
    manager.resetDataForTest();
  });
  tearDown(() => manager.resetDataForTest());

  group('JSON 대화 테이블 (assets/data/dialogues.json)', () {
    test('1. JSON 문구가 코드 내장 문구와 완전히 일치한다', () async {
      final coords = await jsonCoords();
      expect(coords.length, 30);

      // 1) JSON 미로드 상태 = 코드 내장 문구
      final builtIn = <String, String?>{};
      for (final (map, x, y) in coords) {
        builtIn['$map,$x,$y'] = manager.getDialogue(map, x, y, 'Hero');
      }
      for (final key in builtIn.keys) {
        expect(builtIn[key], isNotNull, reason: '내장 대사 없음: $key');
      }

      // 2) JSON 로드 후에도 동일한 문구가 나와야 한다
      await manager.loadData();
      expect(
        manager.usingJsonDialogues,
        isTrue,
        reason: 'JSON 로드 실패: ${manager.dialoguesLoadError}',
      );

      for (final (map, x, y) in coords) {
        expect(
          manager.getDialogue(map, x, y, 'Hero'),
          builtIn['$map,$x,$y'],
          reason: '대사 불일치: 맵 $map ($x,$y)',
        );
      }
    });

    test('2. 주인공 이름 보간({hero})이 동작한다', () async {
      await manager.loadData();

      // 소꿉친구 대사는 주인공 이름을 포함한다 (원작 $heroName 보간)
      final text = manager.getDialogue(6, 24, 50, '카이저');
      expect(text, isNotNull);
      expect(text, contains('카이저'));
      expect(text, contains('Necromancer'));

      // 다른 이름으로도 치환된다
      expect(manager.getDialogue(6, 24, 50, 'Hercules'), contains('Hercules'));
    });

    test('3. JSON이 없으면 코드 내장 대화로 폴백한다', () async {
      await manager.loadData(bundle: _MissingBundle());

      expect(manager.usingJsonDialogues, isFalse);
      expect(manager.dialoguesLoadError, isNotNull);
      expect(manager.getDialogue(6, 9, 64, 'Hero'), contains('경비병'));
      expect(manager.getDialogue(7, 8, 44, 'Hero'), contains('다섯 개의 대륙'));
    });

    test('4. 퀘스트 분기 대화는 기존 로직이 그대로 담당한다', () async {
      await manager.loadData();
      manager.loadFlags({});

      // 성주 퀘스트는 플래그/단계에 따라 문구가 바뀐다(JSON에 없음)
      final first = manager.getDialogue(7, 38, 17, 'Hero');
      expect(first, contains('Major Mummy'));
      expect(manager.lastditchQuestStep, 1);

      manager.bossMajorMummyDefeated = true;
      final done = manager.getDialogue(7, 38, 17, 'Hero');
      expect(done, contains('EXP +10,000'));
      expect(manager.lastditchQuestStep, 2);
    });
  });
}
