import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/monster.dart';
import '../models/party_member.dart';
import '../presentation/battle_presentation.dart';
import '../presentation/battle_backdrop.dart';
import '../theme/mobile_theme.dart';
import 'battle_art.dart';
import 'atlas_art.dart';

const battleGold = MobileTheme.goldLine;

/// Illustrative families; source monster IDs/names and abilities are untouched.
int enemySpriteCell(String name) {
  final n = name.toLowerCase();
  if (RegExp('dragon|dracon|wivern|hydra|hidra|griffin').hasMatch(n)) return 9;
  if (RegExp('serpent|python|viper|worm|basilisk|medusa|euryale|stheno')
      .hasMatch(n)) {
    return 2;
  }
  if (RegExp('bat|insect|bug|spider|gagoyle').hasMatch(n)) return 3;
  if (RegExp('skeleton|skull|mummy|corpse|headless').hasMatch(n)) return 4;
  if (RegExp('slime|mud|molten').hasMatch(n)) return 5;
  if (RegExp('knight|hunter|guardian').hasMatch(n)) return 6;
  if (RegExp('wolf|cat|rat|kelpie').hasMatch(n)) return 7;
  if (RegExp('lich|mage|necro|vampire|ahn|monk').hasMatch(n)) return 8;
  if (RegExp('ghost|soul|phantom|wisp|wraith|death|reaper|sprite|gazer')
      .hasMatch(n)) {
    return 10;
  }
  if (RegExp('robo|crab|ancient|swd').hasMatch(n)) return 11;
  if (RegExp('troll|giant|ogre|rock|cyclops|minotaur|sphinx').hasMatch(n)) {
    return 1;
  }
  return 0;
}

int partySpriteCellFor(String name, int classId) {
  const named = {
    'Hero': 0,
    'Hercules': 1,
    'Merlin': 2,
    'Genius Kie': 3,
    'Regulus': 4,
    'Skeleton': 5,
    'Titan': 6,
    'Betelgeuse': 7,
    'Bellatrix': 8,
    'Polaris': 9,
    'Rigel': 11,
  };
  return named[name] ??
      switch (classId) {
        2 => 2,
        3 => 10,
        4 => 3,
        5 => 4,
        6 || 7 || 8 => 11,
        9 => 5,
        10 => 10,
        _ => 0,
      };
}

int partySpriteCell(PartyMember p) =>
    partySpriteCellFor(p.name, p.playerClass.id);

final _atlasImages = <String, Future<ui.Image>>{};
final _decodedAtlases = <String, ui.Image>{};

Future<ui.Image> _loadAtlas(String path) =>
    _atlasImages.putIfAbsent(path, () async {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      _decodedAtlases[path] = frame.image;
      return frame.image;
    });

/// Warm both shared atlases once, including before a captured preview.
Future<void> loadBattleArt() async {
  await Future.wait([
    loadAtlasArt('assets/images/ui/battle/characters.png'),
    _loadAtlas('assets/images/ui/battle/enemies.png'),
    loadBattleScenery(),
  ]);
}

class BattleSprite extends StatelessWidget {
  const BattleSprite({super.key, required this.cell, this.enemy = false});
  final int cell;
  final bool enemy;

  @override
  Widget build(BuildContext context) {
    if (!enemy) {
      return AtlasArt(
        path: 'assets/images/ui/battle/characters.png',
        cell: cell,
        columns: 4,
        rows: 3,
      );
    }
    final path = 'assets/images/ui/battle/${enemy ? 'enemies' : 'party'}.png';
    final cached = _decodedAtlases[path];
    if (cached != null) {
      return ExcludeSemantics(
        child: CustomPaint(
          painter: _SpritePainter(cached, cell, enemy ? 4 : 3, enemy ? 3 : 2),
        ),
      );
    }
    final future = _loadAtlas(path);
    return ExcludeSemantics(
      child: FutureBuilder<ui.Image>(
        future: future,
        builder: (_, snapshot) => snapshot.hasData
            ? CustomPaint(
                painter: _SpritePainter(
                  snapshot.data!,
                  cell,
                  enemy ? 4 : 3,
                  enemy ? 3 : 2,
                ),
              )
            : const Center(child: Icon(Icons.auto_awesome, color: battleGold)),
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.image, this.cell, this.columns, this.rows);
  final ui.Image image;
  final int cell, columns, rows;
  @override
  void paint(Canvas canvas, Size size) {
    // Visual crop bounds account for the spacing in the generated sheets.
    final xs = columns == 4
        ? [0.0, .265625, .50390625, .74609375, 1.0]
        : [0.0, .3125, .640625, 1.0];
    final ys = rows == 3 ? [0.0, .34375, .61328125, 1.0] : [0.0, .5, 1.0];
    final col = cell % columns;
    final row = cell ~/ columns;
    final source = Rect.fromLTRB(
      xs[col] * image.width,
      ys[row] * image.height,
      xs[col + 1] * image.width,
      ys[row + 1] * image.height,
    );
    final fitted = applyBoxFit(BoxFit.contain, source.size, size);
    final dest = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      source,
      dest,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.image != image || old.cell != cell;
}

/// Left party / right enemies. Animation is a visual clock, never a game clock.
class JrpgBattleStage extends StatelessWidget {
  const JrpgBattleStage({
    super.key,
    required this.party,
    required this.enemies,
    this.activeParty = 0,
    this.selectedEnemy = 0,
    this.event,
    this.duration = const Duration(milliseconds: 800),
    this.onEnemyTap,
    this.onPartyTap,
    this.backdrop = BattleBackdrop.meadow,
    this.showSelection = true,
    this.preparedParty = const {},
    this.excludeDeadTargets = false,
  });
  final List<PartyMember> party;
  final List<Monster> enemies;
  final int activeParty, selectedEnemy;
  final BattleActionEvent? event;
  final Duration duration;
  final ValueChanged<int>? onEnemyTap, onPartyTap;
  final BattleBackdrop backdrop;
  final bool showSelection;
  final Set<int> preparedParty;
  final bool excludeDeadTargets;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: LayoutBuilder(
      builder: (context, constraints) => TweenAnimationBuilder<double>(
        key: ValueKey('battle-animation-${event?.serial ?? 0}'),
        tween: Tween(begin: 0, end: event == null ? 0 : 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : duration,
        builder: (context, progress, _) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final rows = math.max(3, (enemies.length / 2).ceil());
          final rowHeight = (height - 12) / rows;
          final actorWidth = math.min(86.0, width * .225);
          final spriteHeight = math.min(84.0, math.max(12.0, rowHeight - 35));
          final reducedMotion = MediaQuery.disableAnimationsOf(context);
          Offset position(BattleSide side, int i) {
            final row = i % rows;
            final col = i ~/ rows;
            final count = side == BattleSide.party
                ? math.min(6, party.length)
                : enemies.length;
            final usedRows = math.min(rows, count);
            final x = side == BattleSide.party
                ? width * (.03 + col * .20)
                : width * (.77 - col * .20);
            return Offset(
              x,
              (height - usedRows * rowHeight) / 2 + row * rowHeight,
            );
          }

          Widget actor(BattleSide side, int i) {
            final foe = side == BattleSide.enemy;
            final name = foe ? enemies[i].name : party[i].name;
            final dead = foe ? enemies[i].isDead : party[i].dead != 0;
            final unconscious = foe
                ? enemies[i].isUnconscious
                : party[i].unconscious != 0;
            final poisoned = foe ? enemies[i].isPoisoned : party[i].poison != 0;
            final hp = foe ? enemies[i].hp : party[i].hp;
            final maxHp = foe ? enemies[i].maxHp : party[i].maxHp;
            final selected =
                showSelection && (foe ? selectedEnemy == i : activeParty == i);
            final selectionColor = foe ? MobileTheme.danger : MobileTheme.mint;
            final acting = event?.side == side && event?.actor == i;
            final hit =
                event?.feedback.any(
                  (f) =>
                      f.side == side &&
                      f.index == i &&
                      f.kind == BattleFeedbackKind.damage,
                ) ??
                false;
            final receiving =
                event?.feedback.any(
                  (f) =>
                      f.side == side &&
                      f.index == i &&
                      f.kind != BattleFeedbackKind.resource &&
                      f.kind != BattleFeedbackKind.experience,
                ) ??
                false;
            final highlighted = selected || acting || receiving;
            final highlightColor = receiving
                ? (event?.effect == BattleEffect.heal
                      ? MobileTheme.mint
                      : MobileTheme.danger)
                : selectionColor;
            final canTap = foe
                ? onEnemyTap != null && !(excludeDeadTargets && dead)
                : onPartyTap != null;
            final pos = position(side, i);
            final lunge =
                !reducedMotion &&
                    acting &&
                    (event?.effect == BattleEffect.weapon ||
                        event?.effect == BattleEffect.enemy)
                ? math.sin(progress * math.pi) * width * .11 * (foe ? -1 : 1)
                : 0.0;
            final shake = hit && !reducedMotion
                ? math.sin(progress * math.pi * 12) *
                      3 *
                      math.sin(progress * math.pi)
                : 0.0;
            final badges =
                event?.feedback
                    .where((f) => f.side == side && f.index == i)
                    .toList() ??
                [];
            return Positioned(
              left: pos.dx + lunge + shake,
              top: pos.dy,
              width: actorWidth,
              height: math.max(48, rowHeight),
              child: Semantics(
                container: true,
                excludeSemantics: true,
                button: canTap,
                onTap: !canTap
                    ? null
                    : foe
                    ? (onEnemyTap == null ? null : () => onEnemyTap!(i))
                    : (onPartyTap == null ? null : () => onPartyTap!(i)),
                selected: selected,
                label:
                    '$name, ${foe ? '적' : '일행'} ${i + 1}, HP $hp/$maxHp${selected
                        ? foe
                              ? ', 공격 대상'
                              : ', 현재 행동할 일행'
                        : ''}${dead
                        ? ', 격파'
                        : unconscious
                        ? ', 전투 불능'
                        : ''}${acting
                        ? ', 행동 중'
                        : receiving
                        ? ', 효과 대상'
                        : ''}${!foe && preparedParty.contains(i) ? ', 명령 준비 완료' : ''}',
                child: GestureDetector(
                  key: ValueKey(foe ? 'enemy-$i' : 'battle-party-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: !canTap
                      ? null
                      : () => foe ? onEnemyTap?.call(i) : onPartyTap?.call(i),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                SizedBox(
                                  width: actorWidth * .72,
                                  height: 14,
                                  child: highlighted
                                      ? IgnorePointer(
                                          child: TweenAnimationBuilder<double>(
                                            key: ValueKey(
                                              selected
                                                  ? (foe
                                                        ? 'enemy-selection-$i'
                                                        : 'party-selection-$i')
                                                  : 'battle-effect-mark-${side.name}-$i',
                                            ),
                                            tween: Tween(begin: 0, end: 1),
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            builder: (_, emphasis, _) =>
                                                CustomPaint(
                                                  painter:
                                                      BattleSelectionRingPainter(
                                                        color: highlightColor,
                                                        emphasis: emphasis,
                                                      ),
                                                ),
                                          ),
                                        )
                                      : DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: MobileTheme.ink.withValues(
                                              alpha: .12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              50,
                                            ),
                                          ),
                                        ),
                                ),
                                SizedBox(
                                  height: spriteHeight,
                                  width: actorWidth,
                                  child: Opacity(
                                    opacity: dead
                                        ? .18
                                        : unconscious
                                        ? .45
                                        : 1,
                                    child: BattleSprite(
                                      enemy: foe,
                                      cell: foe
                                          ? enemySpriteCell(name)
                                          : partySpriteCell(party[i]),
                                    ),
                                  ),
                                ),
                                if (poisoned)
                                  const Positioned(
                                    right: 2,
                                    top: 0,
                                    child: Icon(
                                      Icons.science,
                                      size: 14,
                                      color: Colors.purpleAccent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            key: ValueKey(
                              foe ? 'enemy-name-$i' : 'party-name-$i',
                            ),
                            duration: const Duration(milliseconds: 180),
                            constraints: BoxConstraints(maxWidth: actorWidth),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!foe &&
                                    preparedParty.contains(i) &&
                                    showSelection) ...[
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 12,
                                    color: MobileTheme.mint,
                                  ),
                                  const SizedBox(width: 2),
                                ],
                                if (selected) ...[
                                  Container(
                                    key: ValueKey(
                                      foe
                                          ? 'enemy-name-mark-$i'
                                          : 'party-name-mark-$i',
                                    ),
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: selectionColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: highlighted
                                          ? highlightColor
                                          : Colors.white,
                                      fontSize: selected ? 11 : 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .25,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0xCC14232D),
                                          blurRadius: 3,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            key: ValueKey(foe ? 'enemy-hp-$i' : 'party-hp-$i'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.diamond,
                                size: 7,
                                color: foe
                                    ? MobileTheme.danger
                                    : MobileTheme.mint,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$hp/$maxHp',
                                maxLines: 1,
                                style: TextStyle(
                                  color: foe
                                      ? const Color(0xFFFFC7B8)
                                      : const Color(0xFFD8FFF1),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .35,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xCC14232D),
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (badges.isNotEmpty && progress > .2)
                        Positioned(
                          top:
                              math.max(0, rowHeight - 35 - spriteHeight) -
                              (reducedMotion
                                  ? 0
                                  : math.sin(progress * math.pi) * 8),
                          left: -8,
                          right: -8,
                          child: IgnorePointer(
                            child: Column(
                              children: [
                                for (final f in badges)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      f.label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: f.positive
                                            ? MobileTheme.mint
                                            : f.kind ==
                                                  BattleFeedbackKind.damage
                                            ? MobileTheme.danger
                                            : MobileTheme.ink,
                                        fontSize:
                                            f.kind ==
                                                    BattleFeedbackKind.damage ||
                                                f.kind ==
                                                    BattleFeedbackKind.healing
                                            ? 22
                                            : 12,
                                        fontWeight: FontWeight.w900,
                                        shadows: const [
                                          Shadow(
                                            color: Color(0xEE14232D),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }

          final origin = event == null
              ? Offset.zero
              : position(event!.side, event!.actor) +
                    Offset(actorWidth / 2, rowHeight - 35 - spriteHeight / 2);
          final healing = event?.effect == BattleEffect.heal;
          final targetSide = healing
              ? event!.side
              : event?.side == BattleSide.party
              ? BattleSide.enemy
              : BattleSide.party;
          final changedTargets =
              event?.feedback
                  .where(
                    (f) =>
                        f.side == targetSide &&
                        f.kind != BattleFeedbackKind.resource &&
                        f.kind != BattleFeedbackKind.experience,
                  )
                  .map((f) => f.index)
                  .toSet() ??
              <int>{};
          final indices = event == null
              ? <int>[]
              : event?.allTargets == true
              ? List.generate(
                  targetSide == BattleSide.enemy
                      ? enemies.length
                      : math.min(6, party.length),
                  (i) => i,
                )
              : changedTargets.isNotEmpty
              ? changedTargets.toList()
              : [event?.target ?? (healing ? event!.actor : selectedEnemy)];
          final destinations = [
            for (final i in indices)
              position(targetSide, i) +
                  Offset(actorWidth / 2, rowHeight - 35 - spriteHeight / 2),
          ];
          return Stack(
            children: [
              Positioned.fill(child: BattleScenery(backdrop: backdrop)),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x66fffcf5),
                        Color(0x00fffcf5),
                        Color(0x33fffcf5),
                      ],
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < party.length && i < 6; i++)
                if (party[i].name.isNotEmpty) actor(BattleSide.party, i),
              for (var i = 0; i < enemies.length; i++)
                actor(BattleSide.enemy, i),
              if (event != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _BattleEffectPainter(
                        event!,
                        progress,
                        origin,
                        destinations,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

/// A restrained ground-plane marker, not a frame around the character artwork.
class BattleSelectionRingPainter extends CustomPainter {
  const BattleSelectionRingPainter({required this.color, this.emphasis = 1});
  final Color color;
  final double emphasis;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: (size.width - 5) * (.9 + .1 * emphasis),
      height: size.height - 5,
    );
    canvas.drawOval(
      ring,
      Paint()..color = color.withValues(alpha: .14 * emphasis),
    );
    canvas.drawOval(
      ring,
      Paint()
        ..color = MobileTheme.surface.withValues(alpha: .9 * emphasis)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawOval(
      ring,
      Paint()
        ..color = color.withValues(alpha: emphasis)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(BattleSelectionRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.emphasis != emphasis;
}

class _BattleEffectPainter extends CustomPainter {
  _BattleEffectPainter(this.event, this.progress, this.origin, this.targets);
  final BattleActionEvent event;
  final double progress;
  final Offset origin;
  final List<Offset> targets;

  @override
  void paint(Canvas canvas, Size size) {
    final power = math.sin(progress * math.pi);
    if (power <= .05 || event.effect == BattleEffect.escape) return;
    final color = switch (event.effect) {
      BattleEffect.heal => MobileTheme.mint,
      BattleEffect.magic =>
        event.title.contains('냉')
            ? const Color(0xff258bcb)
            : event.title.contains('화')
            ? const Color(0xffd86825)
            : const Color(0xff4779da),
      BattleEffect.status || BattleEffect.esp => const Color(0xff9954c4),
      _ => const Color(0xffc28418),
    };
    final paint = Paint()
      ..color = color.withValues(alpha: power)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final target in targets) {
      if (event.effect == BattleEffect.weapon ||
          event.effect == BattleEffect.enemy) {
        canvas.drawLine(
          target + Offset(-16 * power, 18 * power),
          target + Offset(18 * power, -20 * power),
          paint..strokeWidth = 4,
        );
        canvas.drawLine(
          target + Offset(-4, 18 * power),
          target + Offset(18 * power, -6),
          paint..strokeWidth = 2,
        );
      } else {
        final center = event.effect == BattleEffect.heal
            ? target
            : Offset.lerp(origin, target, progress.clamp(0, .65) / .65)!;
        canvas.drawCircle(center, 8 + power * 16, paint);
        // A luminous core and a short trail read against bright scenery.
        if (event.effect != BattleEffect.heal) {
          final trail = Offset.lerp(origin, center, .7)!;
          canvas.drawLine(
            trail,
            center,
            Paint()
              ..color = color.withValues(alpha: power * .35)
              ..strokeWidth = 10
              ..strokeCap = StrokeCap.round,
          );
        }
        canvas.drawCircle(
          center,
          4 + power * 5,
          Paint()..color = MobileTheme.surface.withValues(alpha: power),
        );
        canvas.drawCircle(target, 8 + progress * 26, paint..strokeWidth = 2);
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4 + progress * 2;
          final point =
              target +
              Offset(math.cos(angle), math.sin(angle)) * (12 + progress * 30);
          canvas.drawCircle(
            point,
            2 + power * 2,
            Paint()..color = color.withValues(alpha: power),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BattleEffectPainter old) =>
      old.progress != progress || old.event != event;
}
