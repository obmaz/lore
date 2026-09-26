import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/game/lore_world_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('활성 대화 스크립트 좌표는 실제 맵의 NPC 타일이다', () async {
    final engine = LoreScriptEngine.instance;
    engine.resetForTest();
    await engine.load();
    final maps = <int, LoreMapData>{};

    for (final script in engine.scripts) {
      if (script.disabled ||
          script.trigger != 'talk' ||
          script.x == null ||
          script.y == null) {
        continue;
      }
      final info = LoreWorldManager.mapRegistry[script.map]!;
      final map = maps[script.map] ??= await LoreMapData.loadFromAsset(
        info.fileName,
        category: info.category.name,
      );
      final tile = map.getTile(script.x!, script.y!);
      expect(
        map.getCategory(tile),
        TileCategory.npc,
        reason:
            '${script.id}: 맵 ${script.map} (${script.x},${script.y}) '
            '타일 $tile은 대화로 발동하지 않는다',
      );
    }
    engine.resetForTest();
  });

  test('원작 특수 타일의 핵심 만남은 걸음 이벤트로 등록된다', () async {
    final engine = LoreScriptEngine.instance;
    engine.resetForTest();
    await engine.load();
    for (final id in [
      'rigel-join',
      'redantares-teach',
      'redantares-join',
      'ancient-evil-first',
      'ancient-evil-later',
      'spica-first-meeting',
      'spica-join',
    ]) {
      final script = engine.scripts.singleWhere((s) => s.id == id);
      expect(script.trigger, 'step', reason: id);
    }
    engine.resetForTest();
  });

  test('EVIL SEAL의 일곱 봉인 방은 실제 특수 타일에서 발동한다', () async {
    final engine = LoreScriptEngine.instance;
    engine.resetForTest();
    await engine.load();
    final info = LoreWorldManager.mapRegistry[19]!;
    final map = await LoreMapData.loadFromAsset(
      info.fileName,
      category: info.category.name,
    );

    for (var room = 1; room <= 7; room++) {
      final x = 10 + room * 4;
      expect(map.getCategory(map.getTile(x, 6)), TileCategory.special);
      final script = engine.startStep(
        19,
        x,
        6,
        ScriptContext(flags: {'evilSealRoom$room'}),
      );
      expect(script?.script.id, 'evil-seal-room-$room');
    }
    engine.resetForTest();
  });

  test('좌표 없는 자동 변환 이벤트는 원본의 전체 맵 분기에만 남긴다', () async {
    final engine = LoreScriptEngine.instance;
    engine.resetForTest();
    await engine.load();
    final unboundedMaps = {
      for (final script in engine.scripts)
        if (!script.disabled &&
            script.trigger == 'step' &&
            script.id.startsWith('spec-') &&
            script.x == null &&
            script.xMin == null &&
            script.xMax == null &&
            script.y == null &&
            script.yMin == null &&
            script.yMax == null)
          script.map,
    };
    expect(unboundedMaps, {1, 26, 27});
    engine.resetForTest();
  });

  test('활성 포털 전투 스크립트는 실제 포털에서 참조한다', () async {
    final engine = LoreScriptEngine.instance;
    engine.resetForTest();
    await engine.load();
    final data = jsonDecode(
      await rootBundle.loadString('assets/data/portals.json'),
    ) as Map<String, dynamic>;
    final references = (data['portals'] as List<dynamic>)
        .map((item) => (item as Map<String, dynamic>)['script'] as String?)
        .whereType<String>()
        .toSet();
    final active = engine.scripts
        .where((s) => s.trigger == 'portal' && !s.disabled)
        .map((s) => s.id)
        .toSet();
    expect(active, references);
    engine.resetForTest();
  });
}
