import '../data/lore_script.dart';
import 'lore_source_memory.dart';

/// 화면과 저장소에 의존하지 않는 스크립트 자원 상태.
class ScriptResources {
  final int gold;
  final int food;

  const ScriptResources({required this.gold, required this.food});
}

/// 이름 있는 진행 플래그와 원본 `party.etc` 단계의 세션 스냅샷.
class ScriptProgressState {
  final Map<String, bool> flags;
  final Map<String, int> quests;
  final Map<int, int> sourceEtc;

  const ScriptProgressState({
    required this.flags,
    required this.quests,
    this.sourceEtc = const {},
  });
}

/// 현재 지도에서 스크립트가 읽거나 바꿀 수 있는 최소 상태.
class ScriptMapState {
  final int mapId;
  final int x;
  final int y;
  final int direction;
  final List<List<int>> grid;

  const ScriptMapState({
    required this.mapId,
    required this.x,
    required this.y,
    required this.direction,
    required this.grid,
  });
}

/// 현재 지도의 변경 결과와 다음 위치. 다른 맵으로 이동할 때 [grid]는 출발 맵이다.
class ScriptMapResult {
  final int mapId;
  final int x;
  final int y;
  final List<List<int>> grid;

  const ScriptMapResult({
    required this.mapId,
    required this.x,
    required this.y,
    required this.grid,
  });
}

/// `ScriptOutcome`의 자원·진행·지도 효과를 입력 상태에 적용하는 순수 함수들.
class ScriptWorldReducer {
  ScriptWorldReducer._();

  static ScriptResources applyResources(
    ScriptResources state,
    ScriptOutcome outcome,
  ) => ScriptResources(
    gold: state.gold + outcome.goldDelta,
    food: (state.food + outcome.foodDelta).clamp(0, 255),
  );

  static ScriptProgressState applyProgress(
    ScriptProgressState state,
    ScriptOutcome outcome, {
    Set<String> deferredFlags = const {},
  }) {
    final flags = Map<String, bool>.from(state.flags);
    final quests = Map<String, int>.from(state.quests);
    final sourceEtc = LorePartyEtc(state.sourceEtc);
    for (final flag in outcome.setFlags) {
      if (!deferredFlags.contains(flag)) flags[flag] = true;
    }
    for (final change in outcome.questChanges) {
      quests[change.name] =
          change.set ?? ((quests[change.name] ?? 0) + (change.inc ?? 0));
    }
    for (final write in outcome.sourceEtcWrites) {
      sourceEtc[write.index] = write.value;
    }
    return ScriptProgressState(
      flags: flags,
      quests: quests,
      sourceEtc: sourceEtc.snapshot(),
    );
  }

  static ScriptMapResult applyMap(
    ScriptMapState state,
    ScriptOutcome outcome, {
    int? talkTargetX,
    int? talkTargetY,
  }) {
    final grid = [for (final row in state.grid) List<int>.from(row)];
    final height = grid.length;
    final width = height == 0 ? 0 : grid.first.length;
    var x = state.x;
    var y = state.y;

    bool inBounds(int tx, int ty) =>
        tx >= 1 && tx <= width && ty >= 1 && ty <= height;

    void put(int tx, int ty, int tile, {int? ifZero, int? onlyIf}) {
      if (!inBounds(tx, ty)) return;
      final current = grid[ty - 1][tx - 1];
      if (onlyIf != null && current != onlyIf) return;
      grid[ty - 1][tx - 1] = ifZero != null && current == 0 ? ifZero : tile;
    }

    if (outcome.tileAtTarget case final tile?) {
      if (talkTargetX != null && talkTargetY != null) {
        put(talkTargetX, talkTargetY, tile);
      }
    }

    void putArea({
      required int xMin,
      required int xMax,
      required int yMin,
      required int yMax,
      required int tile,
      int? ifZero,
      int? onlyIf,
    }) {
      for (var ty = yMin; ty <= yMax; ty++) {
        for (var tx = xMin; tx <= xMax; tx++) {
          put(tx, ty, tile, ifZero: ifZero, onlyIf: onlyIf);
        }
      }
    }

    if (outcome.tileOperations.isNotEmpty) {
      for (final operation in outcome.tileOperations) {
        if (operation.teleportMap != null &&
            operation.teleportMap != state.mapId) {
          continue;
        }
        if (operation.kind == 'setTile') {
          put(
            operation.tileX!,
            operation.tileY!,
            operation.tileValue!,
            ifZero: operation.tileIfZero,
          );
        } else if (operation.kind == 'setTileArea') {
          putArea(
            xMin: operation.tileAtPlayerX ? x : operation.tileX!,
            xMax: operation.tileAtPlayerX
                ? x
                : (operation.tileXMax ?? operation.tileX!),
            yMin: operation.tileAtPlayerY ? y : operation.tileY!,
            yMax: operation.tileAtPlayerY
                ? y
                : (operation.tileYMax ?? operation.tileY!),
            tile: operation.tileValue!,
            ifZero: operation.tileIfZero,
            onlyIf: operation.tileOnlyIf,
          );
        }
      }
    } else {
      // 직접 생성한 레거시 ScriptOutcome은 기존 두 목록을 사용한다.
      for (final change in outcome.tileChanges) {
        if (change.map != null && change.map != state.mapId) continue;
        put(change.x, change.y, change.tile, ifZero: change.ifZero);
      }
      for (final area in outcome.tileAreas) {
        if (area.map != null && area.map != state.mapId) continue;
        putArea(
          xMin: area.atPlayerX ? x : area.xMin,
          xMax: area.atPlayerX ? x : area.xMax,
          yMin: area.atPlayerY ? y : area.yMin,
          yMax: area.atPlayerY ? y : area.yMax,
          tile: area.tile,
          ifZero: area.ifZero,
          onlyIf: area.onlyIf,
        );
      }
    }

    for (final playerTile in outcome.playerTiles) {
      put(x, y, playerTile.tile, ifZero: playerTile.ifZero);
    }

    for (final nudge in outcome.nudges) {
      x += nudge.dx;
      y += nudge.dy;
    }

    if (outcome.stepBack) {
      final (dx, dy) = switch (state.direction) {
        0 => (0, -1),
        1 => (0, 1),
        2 => (-1, 0),
        _ => (1, 0),
      };
      if (inBounds(x + dx, y + dy)) {
        x += dx;
        y += dy;
      }
    }

    var mapId = state.mapId;
    if (outcome.teleportX != null && outcome.teleportY != null) {
      mapId = outcome.teleportMap ?? state.mapId;
      if (!outcome.teleportKeepX) x = outcome.teleportX!;
      if (!outcome.teleportKeepY) y = outcome.teleportY!;
    }

    return ScriptMapResult(mapId: mapId, x: x, y: y, grid: grid);
  }
}
