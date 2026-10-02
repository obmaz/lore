import '../data/lore_script.dart';
import 'lore_source_memory.dart';

/// Gameplay branches from `LORESPEC.specialevent_part1`.
///
/// Each branch returns ordered effects for the shared script interpreter. The
/// visual `scroll`/`Clear` calls remain with the field presentation adapter.
class LoreSpecProcedures {
  LoreSpecProcedures._();

  /// `LORESPEC.PAS:190-305`, map 6 (Castle LORE).
  ///
  /// The ordered guards evaluate:
  /// 1. `(62, 82)`: treasure chest (gold 1000, tile 44).
  /// 2. `(51, 12)` or `(52, 12)`: prison guard battle.
  ///    - Guarded by `etc50_bit2` / `madJoeJoined`.
  ///    - Return encounter: `prison-battle-return` (7 soldiers).
  ///    - First encounter: `prison-battle-first` (2 soldiers).
  /// 3. `(41, 79)`: weapon room.
  ///    - Guarded by not `etc50_bit4` / `weaponRoomVisited`.
  ///    - Nudges player west 3 times, sets tile 44, gives basic weapons.
  /// 4. Exit branch:
  ///    - Evaluated at castle exit portal (`castle-exit-skeleton`) via
  ///      [LorePortalSession].
  static ScriptRun? map6(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson || context.tileAtPlayer != 0) return null;

    // 1. on(62,82) - 상자
    if (x == 62 && y == 82) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'spec-6-L190',
      );
      return scripts.startProcedure(content, context);
    }

    // 2. on(51,12) or on(52,12) - 감옥 전투
    if ((x == 51 || x == 52) && y == 12) {
      final hasMadJoe =
          context.flags.contains('madJoeJoined') ||
          context.flags.contains('etc50_bit2');
      if (!hasMadJoe || context.flags.contains('prisonBattleDone')) {
        return null;
      }
      final isReturn =
          context.flags.contains('prisonBattleStarted') ||
          context.flags.contains('etc50_bit3');
      final scriptId = isReturn
          ? 'prison-battle-return'
          : 'prison-battle-first';
      final content = scripts.scripts.singleWhere(
        (script) => script.id == scriptId,
      );
      return scripts.startProcedure(content, context);
    }

    // 3. on(41,79) - 무기실
    if (x == 41 && y == 79) {
      final visited =
          context.flags.contains('weaponRoomVisited') ||
          context.flags.contains('etc50_bit4');
      if (visited) return null;
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'lore-weapon-room',
      );
      return scripts.startProcedure(content, context);
    }

    return null;
  }

  /// `LORESPEC.PAS:306-331`, map 7 (LASTDITCH).
  ///
  /// The ordered guards evaluate:
  /// 1. `x == 50`: GROUND GATE portal to map 8 (handled via portal session).
  /// 2. `x == 30` or `x == 32`: secret passage wall at `(31, y)` opens (tile 45).
  /// 3. `y == 71`: exit to map 1 (handled via portal session).
  static ScriptRun? map7(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (context.tileAtPlayer != 0) return null;

    if (x == 30 || x == 32) {
      return scripts.startProcedure(
        LoreScript(
          id: x == 30 ? 'lastditch-passwall-left' : 'lastditch-passwall-right',
          trigger: 'step',
          map: 7,
          once: false,
          require: const ScriptRequire(),
          steps: const [
            ScriptStep(
              kind: 'setTileArea',
              tileX: 31,
              tileY: 1,
              tileAtPlayerY: true,
              tileValue: 45,
            ),
          ],
        ),
        context,
      );
    }

    return null;
  }

  /// `LORESPEC.PAS:332-353`, `case 8` (TOWN3).
  ///
  /// Both arms are prompts owned by `LoreWorldManager`: any special tile at
  /// x = 50 asks `wantenter('GROUND GATE')` (map 7 (50,10); refusal stays on
  /// the gate), and y = 71 asks `wantexit` (map 2 (19,27); refusal y - 1).
  static ScriptRun? map8(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) => null;

  /// Raw `party.etc[index]`, falling back to the named quest step for
  /// contexts built without a raw snapshot.
  static int _questByte(ScriptContext context, int index, String quest) =>
      context.sourceEtc.containsKey(index)
      ? context.etcValue(index)
      : LorePascal.byte(context.questSteps[quest] ?? 0);

  /// `LORESPEC.PAS:354-443`, `case 9` (TOWN4 / GAIA TERRA).
  ///
  /// Five `findgold(5000)` cells guarded by raw etc[35] bits 1..5, the y = 10
  /// barrier while etc[15] < 5 (`Message` has no key wait, then y + 1). The
  /// y = 5 `wantenter('SWAMP GATE')` and y = 46 `wantexit` are portal
  /// boundaries; [swampGateSpeech] runs after the gate is accepted.
  static ScriptRun? map9(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if ((context.tileAtPlayer ?? 0) != 0) return null;
    const gold = {
      (10, 24): 1,
      (12, 26): 2,
      (15, 25): 3,
      (16, 23): 4,
      (18, 27): 5,
    };
    final bit = gold[(x, y)];
    ScriptRun start(String id, List<ScriptStep> steps) =>
        scripts.startProcedure(
          LoreScript(
            id: id,
            trigger: 'step',
            map: 9,
            once: false,
            require: const ScriptRequire(),
            steps: steps,
          ),
          context,
        );
    if (bit != null) {
      if ((context.etcValue(35) & LorePascal.bit(bit)) != 0) return null;
      return start('spec-9-gold-$bit', [
        const ScriptStep(kind: 'say', text: '당신은 금화 5000개를 발견했다.'),
        const ScriptStep(kind: 'gold', amount: 5000),
        ScriptStep(kind: 'flag', key: 'etc35_bit$bit'),
      ]);
    }
    if (y == 10 && _questByte(context, 15, 'water') < 5) {
      return start('spec-9-barrier-y10', const [
        ScriptStep(kind: 'say', text: '알수없는 힘이 당신을 배척합니다.'),
        ScriptStep(kind: 'nudge', nudgeDy: 1),
      ]);
    }
    return null;
  }

  /// `LORESPEC.PAS:383-428`: after `wantenter('SWAMP GATE')`, Lord Ahn speaks
  /// once (etc[35] bit6), then map 13 (81,95) loads. The gate animation is
  /// presentation only.
  static LoreScript? swampGateSpeech(ScriptContext context) {
    if ((context.etcValue(35) & LorePascal.bit(6)) != 0) return null;
    return const LoreScript(
      id: 'portal-9-13-swamp-gate',
      trigger: 'portal',
      map: 9,
      once: false,
      require: ScriptRequire(),
      steps: [
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(
            title: 'SWAMP GATE',
            lines: [' SWAMP GATE 로 들어가고 있는 당신에게  허공', '에서 갑자가 누군가가 말을 꺼낸다'],
          ),
        ),
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(
            title: 'Lord Ahn',
            lines: [
              ' 나는 LORE 성의 성주 Lord Ahn 이오.',
              ' 역시 내가 예상한 대로 당신들은 훌륭한 용사',
              '로 성장해 나가고 있소. 여태까지는 모험이 순',
              '조롭게 진행 되었지만 이제부터는 완전한 적들',
              '의 소굴이오. 그래서 나도 직접적인 도움은 못',
              '주더라도 여러가지 조언을 해주겠소.',
            ],
          ),
        ),
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(
            title: 'Lord Ahn',
            lines: [
              ' 당신들은 식량을 많이 가지고 있소?  이 식량',
              '은 당신들을 회복시키기  위해  필요한 것이니',
              '절대 바닥나게 해서는 안되오. 왜냐하면 이 이',
              '후에 전개되는 모험에서는 식량을 파는곳이 거',
              '의 없다고 생각해도 될만큼 식량이 귀중하므로',
              '낭패를 보는일이 없도록 하시오.',
            ],
          ),
        ),
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(
            title: 'Lord Ahn',
            lines: [
              ' SWAMP의 대륙에서의 할일을 요약하면 이렇소.',
              ' 스왐프 게이트와 통하는 SWAMP KEEP에는 많은',
              '강한 괴물들이 버티고 있소. 하지만 이전에 그',
              '대륙에 있는 2 개의 동굴 요새를 점령한뒤에야',
              'SWAMP KEEP의 중앙에 있는 라바 게이트를 작동',
              '시킬수 있을 것이오. 그곳의 괴물들은 매우 힘',
              '든 상대일 것이오. 하지만  당신들의 능력이라',
              '면 충분히 가능할 것이오. 나는 당신들이 라바',
              '게이트를 통과하려 할때 다시 조언을 해주겠소.',
              ' 그때까지 건투를 비는 바이오.',
            ],
          ),
        ),
        ScriptStep(kind: 'flag', key: 'etc35_bit6'),
      ],
    );
  }

  /// `LORESPEC.PAS:444-464`, `case 10` (TOWN5).
  ///
  /// y = 46 moves to y = 50 and y = 49 to y = 45 (x unchanged); y = 71 is the
  /// `wantexit` boundary (map 3 (74,20); refusal y - 1) owned by
  /// `LoreWorldManager`. No other special tile has an effect.
  static ScriptRun? map10(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    // LOREMAIN calls specialevent in a town only for tile 0.
    if ((context.tileAtPlayer ?? 0) != 0) return null;
    final target = switch (y) {
      46 => 50,
      49 => 45,
      _ => null,
    };
    if (target == null) return null;
    return scripts.startProcedure(
      LoreScript(
        id: y == 46 ? 'spec-10-L444' : 'spec-10-L444x',
        trigger: 'step',
        map: 10,
        once: false,
        require: const ScriptRequire(),
        steps: [ScriptStep(kind: 'teleport', tileX: x, tileY: target)],
      ),
      context,
    );
  }

  /// `LORESPEC.PAS:465-559`, `case 11` (T_DEN1).
  ///
  /// Seven `findgold(5000)` cells on raw etc[33] bits 1..7. y = 44 offers the
  /// Oedipus spear while bit8 is clear; bit8 is set only after a member
  /// takes it (refusal and the monk rejection leave it for another visit).
  /// y = 46 is a `wantexit` boundary with no refusal branch. y = 24 fights
  /// the mummy room while raw etc[13] = 1; victory or a dead third enemy
  /// increments etc[13].
  static ScriptRun? map11(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    // LOREMAIN calls specialevent in a den for tiles 0 and 52.
    final tile = context.tileAtPlayer ?? 0;
    if (tile != 0 && tile != 52) return null;
    ScriptRun start(String id, List<ScriptStep> steps) =>
        scripts.startProcedure(
          LoreScript(
            id: id,
            trigger: 'step',
            map: 11,
            once: false,
            require: const ScriptRequire(),
            steps: steps,
          ),
          context,
        );
    const gold = {
      (20, 30): 1,
      (18, 36): 2,
      (35, 32): 3,
      (33, 36): 4,
      (35, 14): 5,
      (14, 16): 6,
      (37, 12): 7,
    };
    final etc33 = context.etcValue(
      33,
      bitAliases: const {8: 'oedipusSpearTaken'},
    );
    final bit = gold[(x, y)];
    if (bit != null) {
      if ((etc33 & LorePascal.bit(bit)) != 0) return null;
      return start('spec-11-gold-$bit', [
        const ScriptStep(kind: 'say', text: '당신은 금화 5000개를 발견했다.'),
        const ScriptStep(kind: 'gold', amount: 5000),
        ScriptStep(kind: 'flag', key: 'etc33_bit$bit'),
      ]);
    }
    if (y == 44) {
      if ((etc33 & LorePascal.bit(8)) != 0) return null;
      return start('oedipus-spear', const [
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(title: '오이디푸스의 창', lines: ['당신은 어떤 창을 발견했다.']),
        ),
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(
            title: '오이디푸스의 창',
            lines: [
              '그 창의 손잡이에 쓰인 문구를 따르면..',
              '',
              '        이것은 오이디푸스의 창',
              '   이것으로 전에 Sphinx 를 무찌르다',
            ],
          ),
        ),
        ScriptStep(kind: 'say', text: '누가 오이디푸스의 창을 다루겠습니까 ?'),
        ScriptStep(
          kind: 'equip',
          equipKind: 'weapon',
          equipIndex: 3,
          equipPower: 12,
          equipPrompt: true,
        ),
        ScriptStep(kind: 'flag', key: 'etc33_bit8'),
      ]);
    }
    if (y == 24 && _questByte(context, 13, 'lastditch') == 1) {
      return start('spec-11-mummy-room', const [
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(title: '미이라의 방', lines: ['당신은 미이라의 방을 발견했다.']),
        ),
        ScriptStep(
          kind: 'battle',
          battleTitle: 'Major Mummy',
          battleEnemyFirst: true,
          monsters: [35, 35, 26],
          battleOverrides: [
            {
              'index': 1,
              'name': 'Sphinx',
              'level': 4,
              'special': 0,
              'eNumber': 20,
            },
            {
              'index': 2,
              'name': 'Sphinx',
              'level': 4,
              'special': 0,
              'eNumber': 20,
            },
            {'index': 3, 'name': 'Major Mummy', 'ac': 1},
          ],
          battleVictoryIfEnemyDead: 3,
        ),
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(
            title: 'Major Mummy',
            lines: ['당신들은 Major Mummy 물리쳤다.', '그리고 당신은 이 임무에 성공했다.'],
          ),
        ),
        ScriptStep(kind: 'questStep', questName: 'lastditch', questInc: 1),
      ]);
    }
    return null;
  }

  /// `LORESPEC.PAS:560-668`, `case 12` (T_DEN2 / GAIA DEN).
  ///
  /// An `else if` chain: y = 71 is the `wantexit` boundary; y = 50 doors
  /// unless the step was southward (`y1 = 1`); y = 10 while raw etc[14] < 2
  /// (seal at x = 18, else the column 10..23 becomes 49); Rigel at (12,48)
  /// while etc[31] bit2 is clear (Escape: y - 1); otherwise, without
  /// levitation (raw etc[4] = 0) and off (12,48), the party steps back.
  /// Declining a join slot (`ReturnJoinMember` = 1) keeps the existing
  /// join dialog behaviour and does not apply the source y - 1.
  static ScriptRun? map12(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    final tile = context.tileAtPlayer ?? 0;
    if (tile != 0 && tile != 52) return null;
    if (y == 71) return null;
    ScriptRun start(String id, List<ScriptStep> steps) =>
        scripts.startProcedure(
          LoreScript(
            id: id,
            trigger: 'step',
            map: 12,
            once: false,
            require: const ScriptRequire(),
            steps: steps,
          ),
          context,
        );
    if (y == 50 && context.moveDy != 1) {
      if (x == 33) {
        return start('puzzle-door-right', const [
          ScriptStep(kind: 'say', text: '여기는 옳은 문이었다.'),
          ScriptStep(kind: 'setTile', tileX: 33, tileY: 49, tileValue: 0),
        ]);
      }
      return start('puzzle-door-wrong', const [
        ScriptStep(kind: 'say', text: '당신은 바보군요, 다시 생각하십시오.'),
        ScriptStep(kind: 'teleport', tileX: 25, tileY: 70),
      ]);
    }
    if (y == 10 && _questByte(context, 14, 'gaia') < 2) {
      if (x == 18) {
        return start('golden-seal-12-18-10', const [
          ScriptStep(kind: 'setTile', tileX: 18, tileY: 9, tileValue: 0),
          ScriptStep(kind: 'questStep', questName: 'gaia', questSet: 2),
          ScriptStep(
            kind: 'scene',
            scene: ScriptScene(
              title: '황금의 봉인',
              lines: [
                '당신은 황금의 봉인을 찾았다 !!',
                '그러므로 당신의 임무는 성공했다.',
                '이제는 GAIA TERRA로 돌아가라.',
              ],
            ),
          ),
        ]);
      }
      return start('t_den2-trap-y10', [
        ScriptStep(
          kind: 'setTileArea',
          tileX: x,
          tileY: 10,
          tileYMax: 23,
          tileValue: 49,
        ),
      ]);
    }
    final rigel = x == 12 && y == 48;
    if (rigel) {
      final met = context.etcValue(31, bitAliases: const {2: 'rigelMet'});
      if ((met & LorePascal.bit(2)) != 0) return null;
      return start('rigel-join', const [
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(
            title: 'Rigel',
            lines: [' 일행들은 심한 부상 때문에 거의 몸을 가누지', '못하는 한 남자와 마주쳤다.'],
          ),
        ),
        ScriptStep(kind: 'say', text: ' 나는 VALIANT PEOPLES 의 용사였던  Rigel 이'),
        ScriptStep(kind: 'say', text: '오. 내가 동굴속에서 적들을 막아내는 동안 지'),
        ScriptStep(kind: 'say', text: '각변동으로 인해  이런 절벽이 군데 군데 생겼'),
        ScriptStep(kind: 'say', text: '소.  나는 이제 너무 지치고 많은 상처를 입어'),
        ScriptStep(kind: 'say', text: '서 혼자 힘으로는 이곳을 빠져 나갈수가 없소.'),
        ScriptStep(kind: 'say', text: ' 나를 도와 주시오.'),
        ScriptStep(
          kind: 'choice',
          prompt: '',
          options: [
            ScriptOption('좋소, 같이 모험을 합시다', [
              ScriptStep(kind: 'join', key: 'rigel'),
              ScriptStep(kind: 'flag', key: 'rigelJoined'),
              ScriptStep(kind: 'flag', key: 'etc31_bit2'),
            ]),
            ScriptOption('식량과 치료는 해결해 주겠소', [
              ScriptStep(
                kind: 'scene',
                scene: ScriptScene(
                  title: 'Rigel',
                  lines: [
                    ' 일행은 그에게 치료 마법을 사용하여  상처를',
                    '모두 치료한후  그가 이곳을 빠져 나갈수 있을',
                    '정도의 식량을 나누어 주었다. 그러자 Rigel이',
                    '란 그 용사는 우리의 무기에 신의 축복을 내려',
                    '주고는 자신의 길을 떠났다.',
                  ],
                ),
              ),
              ScriptStep(kind: 'food', amount: -5),
              ScriptStep(kind: 'rigelBlessing', rigelBlessing: true),
              ScriptStep(kind: 'flag', key: 'etc31_bit2'),
            ]),
            ScriptOption('당신을 도와줄 시간이 없소', [
              ScriptStep(kind: 'flag', key: 'etc31_bit2'),
            ]),
          ],
          cancelSteps: [ScriptStep(kind: 'nudge', nudgeDy: -1)],
        ),
      ]);
    }
    final levitating = context.sourceEtc.containsKey(4)
        ? context.etcValue(4) != 0
        : context.flags.contains('etc4') ||
              context.flags.contains('levitateActive');
    if (levitating) return null;
    return start('gaia-den-cliff-no-levitation', const [
      ScriptStep(kind: 'say', text: '일행들은 절벽으로 떨어질뻔 했다.'),
      ScriptStep(kind: 'stepBack'),
    ]);
  }

  static const _den4PyramidScenes = <List<String>>[
    [],
    [' 여기에는 기묘한 피라밋이 있었다', ' 갑자기 피라밋이 아래로 가라앉기 시작했다'],
    [
      ' 그 물속에서 당신은 한 시대의 운명을 바라다',
      '보고있었다',
      ' 당신은 왜 하필이면 당신이 이 세계에 뛰어들',
      '어 단신으로 악과 싸워야하는 이유를 아는가 ?',
      ' 여기서 당신은 Lord Ahn, Ancient Evil, Nec-',
      'romancer 의 관계를 기술한 예언서를 발견하여',
      '읽기 시작했다.',
    ],
    [
      'CHAPTER 1',
      '',
      ' 이 세상에는 두개의 개념이 필요하다.',
      ' 그것은 바로 선과 악이다.',
      ' 전자의 상징은 Lord Ahn 이고, 후자의 상징은',
      'Ancient Evil 이다.',
    ],
    [
      'CHAPTER 2',
      '',
      ' 만약 당신이 황야에서 Ancient Evil을 만나더',
      '라도 두려워하지 말라. 그는 비록 악의 표상이',
      '지만 Necromancer 가 행하는 악과는 다른 표현',
      '임을 명심하라. 만약 세상이 "선"만이 있고 이',
      '런 "악"은 존재하지 않는다면  누구도 선의 중',
      '요성을 인식하지 못한채 보편적인 진리로만 인',
      '식되어가는 시대가 올것이며 선으로 둘러 쌓여',
      '진 생활에 대한 고마움을 망각하는 시대가  우',
      '리 앞에 도래하는 때가 결국 올것이다. 그런때',
      '가 오기전에 사람들이  이런 선의 소중함을 느',
      '끼고 스스로 지키려고 노력하게  만들  하나의',
      '개념이 필요하게 되었는데 이것이 바로 태초에',
      '생겨난 악의 개념이었다. 하지만 일부러 뭇 사',
      '람들에게 비난을 사면서 까지 악을 대표해줄만',
      '한 자는 나타나지 않았다. 이에 스스로를 악의',
      '집대성으로 불러주기를 요구하는 한 현자가 있',
      '었으니 본명은 알수 없지만 그가 바로 Ancient',
      'Evil이라고 칭하는 자였다.  선에 의해 보호되',
      '어 너무나도 평화로운 생활을 해왔던 사람들은',
      '이제 새로운 마음을 갖고 그에게 대항하는  자',
      '세를 취하게 되었다. 하지만 그는 실지로 사람',
      '들에게 해를 입히지 않았으며  그의 본심은 선',
      '에 있다는걸 알아두기 바란다.',
    ],
    [
      'CHAPTER 3',
      '',
      ' 위에서 기술한 Ancient Evil이 의미하는 악과',
      '는 달리 Neromancer 는 진정한 악의 의미를 알',
      '지 못한다. 그것으로 인해 Ancient Evil 은 그',
      '를 벌하려 하는 것이다. 하지만 육체가 없어진',
      'Ancient Evil의 능력으로는 그에게 대항하기가',
      '어렵다고 단정하고는 그의 강력한 마력으로 미',
      '래의 역사를 뒤틀어 운명적으로 Necromancer에',
      '대항하여야 하는 한 희생물을 창조해 냈으니..',
      '..그는 바로 당신인것이다.',
    ],
    [
      'CHAPTER 4',
      '',
      ' Necromancer 에게 대항 할 수 있는 단 두명의',
      '존재는 바로 Lord Ahn과 그의 대립자이며 깊은',
      '관계를 가진 Ancient Evil이다.',
      ' 그들은 모두 Semi-God라는 계급의 인물들이며',
      '보통의 사람들은  상대하기조차 어려운 인물들',
      '이며 능력또한 인간을 초월하는 것뿐이다.  그',
      '러므로 만약 당신이 Necromancer를 응징하려고',
      '한다면 먼저 당신 자신이 Semi-God가 되어야만',
      '될것이다.',
    ],
  ];

  /// `LORESPEC.PAS:669-813`, `case 13` (DEN4).
  ///
  /// y = 96 is the `wantexit` boundary. Any special tile in x 76..86,
  /// y 71..81 runs the pyramid: per cell 52 -> 44 and 40/51 -> 42, the party
  /// walks one cell at a time to x = 81 then y = 77 (faces 6/7, 4/5), every 42
  /// becomes 51, face 5, map[81,76] := 48 between the two lines, then the
  /// prophecy pages. No flag is set: the 52 cells are gone afterwards.
  /// y = 68 fights the Gorgons while etc[38] bit5 is clear; only victory
  /// sets bit5, and an escape moves y + 1 only while enemy 3 is alive.
  static ScriptRun? map13(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    final tile = context.tileAtPlayer ?? 0;
    if (tile != 0 && tile != 52) return null;
    if (y == 96) return null;
    ScriptRun start(String id, List<ScriptStep> steps) =>
        scripts.startProcedure(
          LoreScript(
            id: id,
            trigger: 'step',
            map: 13,
            once: false,
            require: const ScriptRequire(),
            steps: steps,
          ),
          context,
        );
    ScriptStep area(int value, int onlyIf) => ScriptStep(
      kind: 'setTileArea',
      tileX: 76,
      tileXMax: 86,
      tileY: 71,
      tileYMax: 81,
      tileValue: value,
      tileOnlyIf: onlyIf,
    );
    if (x >= 76 && x <= 86 && y >= 71 && y <= 81) {
      final dx = (81 - x).sign;
      final dy = (77 - y).sign;
      ScriptScene page(int i, String title) =>
          ScriptScene(title: title, lines: _den4PyramidScenes[i]);
      return start('den4-pyramid-chapters', [
        area(44, 52),
        area(42, 40),
        area(42, 51),
        for (var cx = x; cx != 81; cx += dx) ...[
          ScriptStep(kind: 'sourceFace', sourceFace: dx == 1 ? 6 : 7),
          ScriptStep(kind: 'nudge', nudgeDx: dx),
        ],
        for (var cy = y; cy != 77; cy += dy) ...[
          ScriptStep(kind: 'sourceFace', sourceFace: dy == 1 ? 4 : 5),
          ScriptStep(kind: 'nudge', nudgeDy: dy),
        ],
        area(51, 42),
        const ScriptStep(kind: 'sourceFace', sourceFace: 5),
        const ScriptStep(
          kind: 'scene',
          scene: ScriptScene(title: '피라밋', lines: ['알수없는 힘이 당신을 당기는걸 느꼈다']),
        ),
        const ScriptStep(kind: 'setTile', tileX: 81, tileY: 76, tileValue: 48),
        ScriptStep(kind: 'scene', scene: page(1, '피라밋')),
        ScriptStep(kind: 'scene', scene: page(2, '예언서')),
        for (var i = 3; i <= 6; i++)
          ScriptStep(kind: 'scene', scene: page(i, 'CHAPTER ${i - 2}')),
      ]);
    }
    if (y == 68) {
      if ((context.etcValue(38) & LorePascal.bit(5)) != 0) return null;
      return start('den4-gorgon', const [
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(
            title: 'Gorgon',
            actors: [50, 51, 52],
            lines: ['우리들의 영역을 침범하는 자는 가만두지 않겠다 !!!'],
          ),
        ),
        ScriptStep(
          kind: 'battle',
          battleTitle: 'Gorgon',
          battleEnemyFirst: true,
          monsters: [50, 51, 52],
          battleOverrides: [
            {'index': 1, 'eNumber': 1},
            {'index': 2, 'eNumber': 1},
            {'index': 3, 'eNumber': 1},
          ],
          battleRunAwayIfEnemyAlive: 3,
          battleRunAwaySteps: [ScriptStep(kind: 'nudge', nudgeDy: 1)],
        ),
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(title: 'Gorgon', lines: ['당신들은 Gorgon을 물리쳤다.']),
        ),
        ScriptStep(kind: 'flag', key: 'etc38_bit5'),
      ]);
    }
    return null;
  }

  /// `LORESPEC.PAS:814-878`, map 14 (DEN1 / SWAMP DEN / MENACE).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 46` handled via portal session.
  /// 2. MENACE center at `(25, 8)` or `(26, 8)` when `party.etc[10] == 3`:
  ///    - `spec-14-L814-1-1` / `spec-14-L814-2-1` increments `lordahn` quest step to 4.
  /// 3. Gold finds:
  ///    - `(6, 6)`: 1000 gold, `etc32_bit1`
  ///    - `(18, 10)`: 2500 gold, `etc32_bit2`
  ///    - `(6, 44)`: 400 gold, `etc32_bit3`
  ///    - `(31, 30)`: 600 gold, `etc32_bit4`
  ///    - `(31, 8)`: 1500 gold, `etc32_bit5`
  ///    - `(14, 28)`: 1000 gold, `etc32_bit6`
  /// 4. Golden Shield at `(16, 20)`:
  ///    - `party.etc[32] and bit7 == 0` (`etc32_bit7` / `goldenShieldMenaceTaken`).
  static ScriptRun? map14(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if ((x == 25 || x == 26) && y == 8) {
      final quest = context.questSteps['lordahn'] ?? 0;
      if (quest == 3) {
        final scriptId = x == 25 ? 'spec-14-L814-1-1' : 'spec-14-L814-2-1';
        final content = scripts.scripts.singleWhere(
          (script) => script.id == scriptId,
        );
        return scripts.startProcedure(content, context);
      }
    }

    final goldId = switch ((x, y)) {
      (6, 6) => !context.flags.contains('etc32_bit1') ? 'spec-14-L814' : null,
      (18, 10) =>
        !context.flags.contains('etc32_bit2') ? 'spec-14-L814x' : null,
      (6, 44) =>
        !context.flags.contains('etc32_bit3') ? 'spec-14-L814xx' : null,
      (31, 30) =>
        !context.flags.contains('etc32_bit4') ? 'spec-14-L814xxx' : null,
      (31, 8) =>
        !context.flags.contains('etc32_bit5') ? 'spec-14-L814xxxx' : null,
      (14, 28) =>
        !context.flags.contains('etc32_bit6') ? 'spec-14-L814xxxxx' : null,
      _ => null,
    };
    if (goldId != null) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == goldId,
      );
      return scripts.startProcedure(content, context);
    }

    if (x == 16 && y == 20) {
      final hasTaken =
          context.flags.contains('etc32_bit7') ||
          context.flags.contains('goldenShieldMenaceTaken');
      if (!hasTaken) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spec-14-L814xxxxxx',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:879-965`, map 15 (T_DEN3 / QUAKE DEN).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 71` handled via portal session.
  /// 2. Gold chests at `y == 48` and `x in [10, 11, 40, 41]`:
  ///    - First chest gives 6000 gold and sets `etc36_bit1`.
  ///    - Second chest gives 4000 gold and sets `etc36_bit2`.
  ///    - Sets tiles `(x, 48)` and `(x, 47)` to 44.
  /// 3. Golden Shield at `(14, 7)`:
  ///    - `party.etc[36] and bit3 == 0` (`etc36_bit3` / `goldenShieldQuakeTaken`).
  /// 4. Golden Armor at `(45, 19)`:
  ///    - `party.etc[36] and bit4 == 0` (`etc36_bit4` / `goldenArmorQuakeTaken`).
  /// 5. ArchiGagoyle boss battle at `y == 27`:
  ///    - `party.etc[14] == 4` (`gaia` quest step 4 -> 5).
  static ScriptRun? map15(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (y == 48 && (x == 10 || x == 11 || x == 40 || x == 41)) {
      if (!context.flags.contains('etc36_bit2')) {
        final isFirst = !context.flags.contains('etc36_bit1');
        final scriptId = isFirst ? 'spec-15-L879-1xx' : 'spec-15-L879-2xx';
        final content = scripts.scripts.singleWhere(
          (script) => script.id == scriptId,
        );
        final procedure = LoreScript(
          id: 'lorespec-map15-gold-$x-$y',
          trigger: 'step',
          map: 15,
          once: false,
          require: const ScriptRequire(),
          steps: [
            ...content.steps,
            ScriptStep(kind: 'setTile', tileX: x, tileY: 48, tileValue: 44),
            ScriptStep(kind: 'setTile', tileX: x, tileY: 47, tileValue: 44),
          ],
        );
        return scripts.startProcedure(procedure, context);
      }
    }

    if (x == 14 && y == 7) {
      final hasTaken =
          context.flags.contains('etc36_bit3') ||
          context.flags.contains('goldenShieldQuakeTaken');
      if (!hasTaken) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spec-15-L879',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (x == 45 && y == 19) {
      final hasTaken =
          context.flags.contains('etc36_bit4') ||
          context.flags.contains('goldenArmorQuakeTaken');
      if (!hasTaken) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spec-15-L879x',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (y == 27) {
      final quest = context.questSteps['gaia'] ?? 0;
      if (quest == 4) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spec-15-L879-1xxxx',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:966-1004`, map 16 (DEN2 / TYPHOON DEN).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 36` handled via portal session.
  /// 2. Wivern encounter at `y == 10`:
  ///    - If `party.etc[37] < 3`:
  ///      - 0 defeated: 3 Wiverns (`wivern-3-remaining`)
  ///      - 1 defeated: 2 Wiverns (`wivern-2-remaining`)
  ///      - 2 defeated: 1 Wivern (`wivern-1-remaining`)
  ///    - If `party.etc[37] >= 3`:
  ///      - Corpse message (`wivern-cleared`).
  static ScriptRun? map16(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (y == 10) {
      final wivernQuest = context.questSteps['wivern'] ?? 0;
      final scriptId = switch (wivernQuest) {
        0 => 'wivern-3-remaining',
        1 => 'wivern-2-remaining',
        2 => 'wivern-1-remaining',
        _ => 'wivern-cleared',
      };
      final content = scripts.scripts.singleWhere(
        (script) => script.id == scriptId,
      );
      return scripts.startProcedure(content, context);
    }

    return null;
  }

  /// `LORESPEC.PAS:1006-1173`, map 17 (DEN3 / DRAGON DEN).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 95` handled via portal session.
  /// 2. Vertical wrap at `y == 80`:
  ///    - `y := 6` (`spec-17-L1010`).
  /// 3. Passage toggle at `y == 44`:
  ///    - `map[67..69, 44] := 44`, `map[67..69, 38] := 52` (`map17-passage-44`).
  /// 4. Red Antares meeting at `(75, 52)`:
  ///    - `party.etc[38] and bit2 == 1` -> null (이미 합류/결정 완료).
  ///    - `party.etc[38] and bit1 == 1` and `mindRead`:
  ///      - `redantares-join` (합류 선택지).
  ///    - `party.etc[38] and bit1 == 1` and not `mindRead`:
  ///      - `redantares-wait-for-mindread`.
  ///    - `party.etc[38] and bit1 == 0`:
  ///      - `redantares-teach` (용암 변형 및 간접 마법 전수).
  /// 5. Secret shortcut at `x == 72`:
  ///    - `map[72, 19..21] := 44`, `y := y - 7` (`map17-shortcut-72`).
  /// 6. Passage return at `y == 38`:
  ///    - `map[67..69, 38] := 44`, `map[67..69, 44] := 52`, teleport `(56, 93)` (`map17-passage-38`).
  /// 7. Hidra boss battle at `x == 22`:
  ///    - `party.etc[15] < 2`:
  ///      - `map17-hidra` (보스 전투, 승리 시 `swamp` 퀘스트 2, 워프 `(56, 93)`).
  static ScriptRun? map17(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (y == 80) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'spec-17-L1010',
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 44) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'map17-passage-44',
      );
      return scripts.startProcedure(content, context);
    }

    if (x == 75 && y == 52) {
      final hasJoinedOrRefused = context.flags.contains('etc38_bit2');
      if (hasJoinedOrRefused) return null;

      final hasLearned =
          context.flags.contains('etc38_bit1') ||
          context.flags.contains('specialMagicLearned');
      if (hasLearned) {
        final hasMindRead = context.mindReadActive;
        final scriptId = hasMindRead
            ? 'redantares-join'
            : 'redantares-wait-for-mindread';
        final content = scripts.scripts.singleWhere(
          (script) => script.id == scriptId,
        );
        return scripts.startProcedure(content, context);
      } else {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'redantares-teach',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (x == 72) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'map17-shortcut-72',
      );
      return scripts.startProcedure(content, context);
    }

    if (y == 38) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'map17-passage-38',
      );
      return scripts.startProcedure(content, context);
    }

    if (x == 22) {
      final swampQuest = context.questSteps['swamp'] ?? 0;
      if (swampQuest < 2) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'map17-hidra',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:1174-1365`, map 18 (T_DEN4 / LOCKUP).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 95` handled via portal session.
  /// 2. Passage at `(22, 41)`:
  ///    - `map[22, 41] := 44; map[21, 41] := 52;` (`lockup-passage-22-41`).
  /// 3. Guardian battle at `(21, 41)`:
  ///    - `party.etc[39] and bit3 == 0`: Minotaur battle (`lockup-guardian-21-41`).
  /// 4. Spica at `(37, 31)`:
  ///    - `party.etc[39] and bit2 > 0`: null (이미 합류/결정 완료).
  ///    - `party.etc[39] and bit1 > 0`:
  ///      - if not `context.mindReadActive`: `spica-mind-read-inactive`.
  ///      - if `context.maxEspLevel < 5`: `spica-cannot-read`.
  ///      - if `context.maxEspLevel >= 5`: `spica-join` (합류 제의).
  ///    - `party.etc[39] and bit1 == 0`:
  ///      - `spica-first-meeting` (초자연력 설명, `etc39_bit1` 설정).
  /// 5. Huge Dragon boss battle at `x == 31`:
  ///    - `party.etc[15] < 4`: Huge Dragon battle (`map18-huge-dragon`).
  static ScriptRun? map18(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    if (x == 22 && y == 41) {
      final content = scripts.scripts.singleWhere(
        (script) => script.id == 'lockup-passage-22-41',
      );
      return scripts.startProcedure(content, context);
    }

    if (x == 21 && y == 41) {
      final hasDefeated =
          context.flags.contains('etc39_bit3') ||
          context.flags.contains('lockupGuardianDefeated');
      if (!hasDefeated) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'lockup-guardian-21-41',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (x == 37 && y == 31) {
      final hasDecided = context.flags.contains('etc39_bit2');
      if (hasDecided) return null;

      final hasMet = context.flags.contains('etc39_bit1');
      if (hasMet) {
        if (!context.mindReadActive) {
          final content = scripts.scripts.singleWhere(
            (script) => script.id == 'spica-mind-read-inactive',
          );
          return scripts.startProcedure(content, context);
        }
        if (context.maxEspLevel < 5) {
          final content = scripts.scripts.singleWhere(
            (script) => script.id == 'spica-cannot-read',
          );
          return scripts.startProcedure(content, context);
        }
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spica-join',
        );
        return scripts.startProcedure(content, context);
      } else {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'spica-first-meeting',
        );
        return scripts.startProcedure(content, context);
      }
    }

    if (x == 31) {
      final swampQuest = context.questSteps['swamp'] ?? 0;
      if (swampQuest < 4) {
        final content = scripts.scripts.singleWhere(
          (script) => script.id == 'map18-huge-dragon',
        );
        return scripts.startProcedure(content, context);
      }
    }

    return null;
  }

  /// `LORESPEC.PAS:1378-1473`, map 19 (DEN6 / EVIL DEN).
  /// Direct, closed internal branches; the southern exit remains in the portal
  /// session. Preserve etc[3], odd/shr/div, random calls and battle exits.
  static ScriptRun? map19(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    ScriptRun start(String id, List<ScriptStep> steps) =>
        scripts.startProcedure(
          LoreScript(
            id: id,
            trigger: 'step',
            map: 19,
            once: false,
            require: const ScriptRequire(),
            steps: steps,
          ),
          context,
        );
    ScriptStep tile(int tx, int ty, int value) =>
        ScriptStep(kind: 'setTile', tileX: tx, tileY: ty, tileValue: value);
    Map<String, Object?> guardOverride(int slot) => {
      'index': slot,
      'eNumber': 25,
      'hp': 210,
      'level': 7,
    };

    var sealByte = context.etcValue(40, bitAliases: {1: 'evilSealRoomCleared'});
    // Transition adapter for old JSON snapshots. Raw byte zero wins.
    if (!context.sourceEtc.containsKey(40)) {
      for (var room = 1; room <= 7; room++) {
        if (context.flags.contains('evilSealRoom$room')) {
          sealByte = (room << 1) | (sealByte & 1);
        }
      }
    }
    final sealCleared = (sealByte & 1) != 0;

    if ((x == 11 && y == 40) || (x == 41 && y == 39)) {
      final lever = x == 11 ? 'a' : 'b';
      final swampWalk =
          context.etcValue(3) > 0 ||
          (!context.sourceEtc.containsKey(3) &&
              context.flags.contains('swampWalkActive'));
      if (swampWalk) {
        return start('evil-seal-lever-$lever-blocked', const [
          ScriptStep(kind: 'say', text: ' 늪 아래를 보니 무언가 반짝이는 물체가 있었'),
          ScriptStep(kind: 'say', text: '다. 하지만 늪위를 걷는 마법 때문에 늪속으로'),
          ScriptStep(kind: 'say', text: '들어갈수가 없다.'),
        ]);
      }
      if (x == 11) {
        return start('evil-seal-lever-a', [
          const ScriptStep(kind: 'say', text: ' 일행은 독을 무릅쓰고  늪속에 빠져있는 레버'),
          const ScriptStep(kind: 'say', text: '를 당겼다. 순간 동굴 중심부에서 굉음이 들렸'),
          const ScriptStep(kind: 'say', text: '다.'),
          tile(11, 40, 49),
          tile(41, 39, 0),
        ]);
      }
      return start('evil-seal-lever-b', [
        const ScriptStep(kind: 'say', text: ' 일행은 독을 무릅쓰고  늪속에 빠져있는 레버'),
        const ScriptStep(kind: 'say', text: '를 당겼다. 순간 동굴 중심부에서 조금전 보다'),
        const ScriptStep(kind: 'say', text: '더 큰 굉음이 들렸다.'),
        tile(41, 39, 49),
        if (!sealCleared) ...[
          for (var j = 27; j <= 36; j++) ...[tile(24, j, 25), tile(28, j, 23)],
          tile(24, 37, 17),
          tile(28, 37, 19),
          for (var j = 27; j <= 37; j++)
            for (var i = 25; i <= 27; i++) tile(i, j, 44),
          ScriptStep(
            kind: 'sourceEtc',
            sourceEtcIndex: 40,
            sourceEtcValue: (scripts.roll(7) + 1) << 1,
          ),
        ],
      ]);
    }

    if (!sealCleared && y >= 8 && y <= 12) {
      final count = scripts.roll(3) + 3;
      final closeTile = tile(x, y, 49);
      return start('evil-seal-guardians', [
        ScriptStep(
          kind: 'battle',
          monsters: List.filled(count, 59),
          battleOverrides: [for (var i = 1; i <= count; i++) guardOverride(i)],
          // BattleMode(TRUE); map[x,y] := 49 on every battle result.
          battleRunAwaySteps: [closeTile],
          battleDefeatSteps: [closeTile],
        ),
        closeTile,
      ]);
    }

    if (!sealCleared && y == 6) {
      final room = LorePascal.div(x - 10, 4);
      if ((sealByte >> 1) != room) {
        return start('evil-seal-room-wrong-$room', [
          tile(x, y - 1, 49),
          const ScriptStep(kind: 'say', text: ' 여기에는 봉인이 발견되지 않았다'),
          tile(x, y, 49),
        ]);
      }
      return start('evil-seal-room-$room', [
        tile(x, y - 1, 49),
        const ScriptStep(kind: 'say', text: '나는 EVIL GOD의 봉인을 지키고 있는 CRAB GOD'),
        const ScriptStep(kind: 'say', text: '의 왕이다. CRAB GOD 족의 명예를 걸고 절대로'),
        const ScriptStep(kind: 'say', text: '너희 같은 자들에게 봉인을 넘겨주지 않겠다!!'),
        ScriptStep(
          kind: 'battle',
          monsters: List.filled(7, 59),
          battleEnemyFirst: true,
          battleOverrides: [for (var i = 4; i <= 7; i++) guardOverride(i)],
          battleRunAwaySteps: const [ScriptStep(kind: 'nudge', nudgeDy: 1)],
        ),
        const ScriptStep(kind: 'say', text: ' 당신은 이 동굴에 보관되어 있는 봉인을 발견'),
        const ScriptStep(kind: 'say', text: '했다.  그리고는 봉쇄 되었던 봉인을 풀어버렸'),
        const ScriptStep(kind: 'say', text: '다.'),
        ScriptStep(
          kind: 'sourceEtc',
          sourceEtcIndex: 40,
          sourceEtcValue: sealByte | LorePascal.bit(1),
        ),
      ]);
    }
    return null;
  }

  static const _den7Quiz91Heading = <String>[
    ' 다음 물음이 맞다면 왼쪽길로, 아니면 오른쪽',
    '길로 가시오.',
    '',
  ];
  static const _den7Quiz91Statements = <String>[
    '문> CONFIG.SYS가 없으면 부팅이 안된다',
    '문> Quick-BASIC은 인터프리터어 이다',
    '문> Super VGA는 호환이 잘된다',
    '문> 8-bit APPLE의 CPU는 Z - 80 이다',
    '문> COMMAND.COM 안에 도스 명령이 들어있다',
    '문> AdLib 카드는 9 채널이다',
    '문> Ultima의 제작자는 리차드 게리오트이다',
    '문> 당신의 컴퓨터는 IBM 계열이다',
  ];
  static const _den7Quiz75Heading = <String>[
    ' 다음 물음이 맞다면 왼쪽길로, 아니면 오른쪽',
    '길로 가시오.',
    '',
  ];
  static const _den7Quiz75Statements = <String>[
    '문> 태양계의 제 4 혹성은 지구이다',
    '문> 북극성이 가장 밝은 별이다',
    '문> 1월의 수호성좌는 1월에 볼수있다',
    '문> 빛보다 빠른 입자는 실험상 없었다',
    '문> 달이 지구보다 먼저 생겨났다',
    '문> 시그너스 X1은 블랙홀이다',
    '문> 과거로의 타임머신은 불가능하다',
    '문> 북극성은 주기적으로 달라진다',
  ];
  static const _den7Quiz54Heading = <String>['<< 다음의 옳고 그름을 가리시오 >>', ''];
  static const _den7Quiz54Statements = <String>[
    '문> 이 게임의 배경은 4개의 대륙이다',
    '문> Ancient Evil은 응징되어야 한다',
    '문> Lord Ahn만이 유일한 Semi-God이다',
    '문> 이 세계의 모든 악은 응징되어야 한다',
    '문> 이 게임의 제작자는 안 영기이다',
    '문> 게임속의 인물은 거의 별의 이름을 가졌다',
    '문> Necromancer는 신의 경지에 이르렀다',
    '문> Necromancer는 이 세계의 존재가 아니었다',
  ];

  /// `LORESPEC.PAS:1475-1759`, `case 20` (DEN7 / ASTRAL DEN).
  ///
  /// The arm is a run of independent `if`s on the current y. `y = 96` is the
  /// `wantexit` boundary. Doors at y = 88/71 pass on tile 0 (`y := 80/63`)
  /// and otherwise load map 4 (82,17). The y = 91/75 quizzes draw one
  /// `random(8)`, write the row and the two doors, then wait. The y = 54 quiz
  /// draws one `random(8)` and asks; Escape moves y + 1, a right answer opens
  /// rows 49..52 and a wrong one loads map 4. The torch decrement of the
  /// x 8..42, y 19..43 maze (every cell there is tile 0 or a wall) stays in
  /// the field step handler. y = 18 sets etc[1] := 1. The y = 48 Minotaur
  /// sets etc[41] bit4 after victory or escape; y = 13 chains the dragon,
  /// mud and Astral Mud fights on raw etc[41] bits 2, 3 and 1, each escape
  /// moving y + 1. Defeat runs no continuation (GameOver reload overlay).
  static ScriptRun? map20(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (y == 96) return null;
    ScriptRun start(String id, List<ScriptStep> steps) =>
        scripts.startProcedure(
          LoreScript(
            id: id,
            trigger: 'step',
            map: 20,
            once: false,
            require: const ScriptRequire(),
            steps: steps,
          ),
          context,
        );
    const leave = ScriptStep(
      kind: 'teleport',
      teleportMap: 4,
      tileX: 82,
      tileY: 17,
    );
    const back = ScriptStep(kind: 'nudge', nudgeDy: 1);
    if (y == 88 || y == 71) {
      if ((context.tileAtPlayer ?? 0) != 0) {
        return start('den7-exit-y$y', [leave]);
      }
      return start('den7-passage-y$y', [
        ScriptStep(kind: 'teleport', tileX: x, tileY: y == 88 ? 80 : 63),
      ]);
    }
    if (y == 91 || y == 75) {
      final i = scripts.roll(8);
      final door = y == 91 ? 88 : 71;
      return start('den7-quiz-y$y', [
        ScriptStep(
          kind: 'setTileArea',
          tileX: 23,
          tileXMax: 26,
          tileY: y,
          tileValue: 44,
        ),
        ScriptStep(
          kind: 'setTile',
          tileX: 8,
          tileY: door,
          tileValue: i < 4 ? 52 : 0,
        ),
        ScriptStep(
          kind: 'setTile',
          tileX: 43,
          tileY: door,
          tileValue: i < 4 ? 0 : 52,
        ),
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(
            title: '퀴즈',
            lines: [
              ...(y == 91 ? _den7Quiz91Heading : _den7Quiz75Heading),
              (y == 91 ? _den7Quiz91Statements : _den7Quiz75Statements)[i],
            ],
          ),
        ),
      ]);
    }
    if (y == 54) {
      final i = scripts.roll(8);
      final open = [
        const ScriptStep(
          kind: 'setTileArea',
          tileX: 23,
          tileXMax: 25,
          tileY: 54,
          tileValue: 44,
        ),
        // LORESPEC.PAS:1580-1584: j outer, then 22, 26 and 23..25 per row.
        for (var j = 49; j <= 52; j++) ...[
          ScriptStep(kind: 'setTile', tileX: 22, tileY: j, tileValue: 25),
          ScriptStep(kind: 'setTile', tileX: 26, tileY: j, tileValue: 23),
          ScriptStep(
            kind: 'setTileArea',
            tileX: 23,
            tileXMax: 25,
            tileY: j,
            tileValue: 44,
          ),
        ],
      ];
      final wrong = [
        const ScriptStep(
          kind: 'setTileArea',
          tileX: 23,
          tileXMax: 25,
          tileY: 54,
          tileValue: 44,
        ),
        leave,
      ];
      return start('den7-quiz-y54', [
        for (final line in [..._den7Quiz54Heading, _den7Quiz54Statements[i]])
          ScriptStep(kind: 'say', text: line),
        ScriptStep(
          kind: 'choice',
          prompt: '',
          options: [
            ScriptOption('위의 말은 옳다', i > 3 ? open : wrong),
            ScriptOption('위의 말은 잘못되었다', i < 4 ? open : wrong),
          ],
          cancelSteps: const [back],
        ),
      ]);
    }
    if (y == 18) {
      return start('den7-torch-y18', const [
        ScriptStep(kind: 'sourceEtc', sourceEtcIndex: 1, sourceEtcValue: 1),
        ScriptStep(kind: 'torch', torchLit: true),
      ]);
    }
    if (y != 48 && y != 13) return null;
    final etc41 = context.etcValue(
      41,
      bitAliases: const {
        1: 'den7MazeCleared',
        2: 'den7DragonsCleared',
        3: 'den7MudmenCleared',
        4: 'den7MinotaurCleared',
      },
    );
    bool clear(int bit) => (etc41 & LorePascal.bit(bit)) == 0;
    final torch = context.etcValue(1);
    final unlit =
        torch == 0 &&
        (context.sourceEtc.containsKey(1) ||
            !context.flags.contains('torchActive'));
    final light = [
      if (unlit) ...const [
        ScriptStep(kind: 'sourceEtc', sourceEtcIndex: 1, sourceEtcValue: 1),
        ScriptStep(kind: 'torch', torchLit: true),
      ],
    ];
    if (y == 48) {
      if (!clear(4)) return null;
      const seen = ScriptStep(kind: 'flag', key: 'etc41_bit4');
      return start('den7-minotaur-y48', [
        ...light,
        const ScriptStep(
          kind: 'scene',
          scene: ScriptScene(title: '미궁의 괴물', lines: ['미로속에서 소를 닮은 괴물이 나타났다']),
        ),
        const ScriptStep(
          kind: 'battle',
          battleTitle: '미궁의 괴물',
          battleEnemyFirst: true,
          monsters: [53],
          battleRunAwaySteps: [seen],
        ),
        seen,
      ]);
    }
    return start('den7-final-y13', [
      ...light,
      if (clear(2)) ...const [
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(title: '미궁의 수호룡', lines: []),
        ),
        ScriptStep(
          kind: 'battle',
          battleTitle: 'Dragon',
          battleEnemyFirst: true,
          monsters: [54, 54, 54],
          battleRunAwaySteps: [back],
        ),
        ScriptStep(kind: 'flag', key: 'etc41_bit2'),
      ],
      if (clear(3)) ...const [
        ScriptStep(
          kind: 'battle',
          battleTitle: 'Mud-Man',
          battleEnemyFirst: true,
          monsters: [31, 31, 31, 31, 31, 31, 31],
          battleRunAwaySteps: [back],
        ),
        ScriptStep(kind: 'flag', key: 'etc41_bit3'),
      ],
      if (clear(1)) ...const [
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(
            title: 'Astral Mud',
            lines: [
              ' 나는 Necromacer 와 함께 다른 차원에서 내려',
              '온 Astral Mud 이다. 여기는 그가 세운 최고의',
              '동굴이자 너가 마지막으로 거칠 동굴이다.  나',
              '를 만만하게 보지마라.  다른 차원의 능력들을',
              '너가 맛볼 기회를 가진다는 것에 대해  고맙게',
              '생각하기 바란다. 하하하 ...',
            ],
          ),
        ),
        // LORESPEC.PAS:1736-1756: only enemy 7's death decides the result.
        ScriptStep(
          kind: 'battle',
          battleTitle: 'Astral Mud',
          battleEnemyFirst: true,
          monsters: [31, 31, 31, 31, 31, 31, 57],
          battleVictoryIfEnemyDead: 7,
          battleRunAwaySteps: [back],
        ),
        ScriptStep(kind: 'flag', key: 'etc41_bit1'),
        leave,
        ScriptStep(
          kind: 'scene',
          scene: ScriptScene(
            title: '봉인',
            lines: [
              ' 당신은 이 동굴에 보관되어 있는 봉인을 발견',
              '했다.  그리고는 봉쇄 되었던 봉인을 풀어버렸',
              '다.',
            ],
          ),
        ),
      ] else
        leave,
    ]);
  }

  /// `LORESPEC.PAS:1760-1815`, `case 21` (KEEP1 / SWAMP KEEP).
  ///
  /// `y = 46` is the exit boundary ([keep1ExitGuard] after `wantexit`).
  /// `on(25,20)` refuses the lava gate unless both `odd(etc[40])` and
  /// `odd(etc[41])`, pushing the party to y + 1. Every other special tile
  /// draws `random(4) + 3` enemies 58 and, after victory or escape, writes 40
  /// over tile 0 and 46 over any other tile. Defeat runs no continuation.
  static ScriptRun? map21(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (y == 46) return null;
    LoreScript procedure(String id, List<ScriptStep> steps) => LoreScript(
      id: id,
      trigger: 'step',
      map: 21,
      once: false,
      require: const ScriptRequire(),
      steps: steps,
    );
    if (x == 25 && y == 20) {
      final seal1 = context.etcValue(
        40,
        bitAliases: const {1: 'evilSealRoomCleared'},
      );
      final seal2 = context.etcValue(
        41,
        bitAliases: const {1: 'den7MazeCleared'},
      );
      if (seal1.isOdd && seal2.isOdd) return null;
      return scripts.startProcedure(
        procedure('keep1-seal-gate-a', const [
          ScriptStep(
            kind: 'scene',
            scene: ScriptScene(
              title: '라바 게이트',
              lines: [
                ' 당신은 아직 라바 게이트를 열수가 없다',
                '',
                ' 아직 당신은 이 대륙의 동굴속에  존재하',
                ' 는 2개의 봉인을 풀지 못했기 때문이다.',
              ],
            ),
          ),
          ScriptStep(kind: 'nudge', nudgeDy: 1),
        ]),
        context,
      );
    }
    // LORESPEC.PAS:1806-1813: the tile is read after BattleMode, with no
    // result check, so victory and escape both rewrite it.
    final count = scripts.roll(4) + 3;
    final after = ScriptStep(
      kind: 'setTile',
      tileX: x,
      tileY: y,
      tileValue: (context.tileAtPlayer ?? 0) == 0 ? 40 : 46,
    );
    return scripts.startProcedure(
      procedure('keep1-special-ambush', [
        ScriptStep(
          kind: 'battle',
          battleEnemyFirst: true,
          monsters: List<int>.filled(count, 58),
          battleRunAwaySteps: [after],
        ),
        after,
      ]),
      context,
    );
  }

  /// `LORESPEC.PAS:1763-1789`: after `wantexit` while etc[42] bit1 is clear.
  /// Enemy 55 joins unless bit3, then 56 unless bit4, then five 35s. With
  /// neither boss the source sets bit1 and exits without loading, leaving the
  /// party on the exit cell. After the fight bit3/bit4 follow the deaths of
  /// enemy slots 1/2 (not of a particular boss), bit1 needs both, and the
  /// party leaves for map 4 after victory or escape.
  static LoreScript? keep1ExitGuard(ScriptContext context, int x, int y) {
    final etc42 = context.etcValue(42);
    if ((etc42 & LorePascal.bit(1)) != 0) return null;
    final bosses = [
      if ((etc42 & LorePascal.bit(3)) == 0) 55,
      if ((etc42 & LorePascal.bit(4)) == 0) 56,
    ];
    LoreScript guard(List<ScriptStep> steps) => LoreScript(
      id: 'keep1-exit-guard',
      trigger: 'portal',
      map: 21,
      once: false,
      require: const ScriptRequire(),
      steps: steps,
    );
    if (bosses.isEmpty) {
      return guard([
        const ScriptStep(kind: 'flag', key: 'etc42_bit1'),
        ScriptStep(kind: 'teleport', tileX: x, tileY: y),
        const ScriptStep(kind: 'block', block: true),
      ]);
    }
    return guard([
      ScriptStep(
        kind: 'battle',
        battleEnemyFirst: true,
        monsters: [...bosses, ...List<int>.filled(5, 35)],
        battleEnemyDefeatFlags: const {1: 'etc42_bit3', 2: 'etc42_bit4'},
        battleRunAwayFlagsWhenDead: const [
          (slots: [1, 2], flag: 'etc42_bit1'),
        ],
        battleVictoryFlags: const ['etc42_bit1'],
        battleContinueOnRunAway: true,
      ),
    ]);
  }

  /// `LORESPEC.PAS:1816-1879`, `case 22` (KEEP2).
  ///
  /// Raw `party.etc[43]` bits decide every fight; there are no clear flags.
  /// `y = 46` is the exit boundary ([keep2ExitGuard] runs after `wantexit`),
  /// `on(25,18)` is the Death Knight, `(y = 25, x in [24..26])` the guards and
  /// every other special tile the Wraith ambush that turns the tile into 40.
  /// Defeat runs no continuation: the source GameOver reloads a saved game and
  /// would then resume this arm on the loaded state; that reload overlay is an
  /// intentional difference.
  static ScriptRun? map22(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (y == 46) return null;
    final etc43 = context.etcValue(
      43,
      bitAliases: const {1: 'keep2GuardsCleared', 2: 'keep2AmbushCleared'},
    );
    bool clear(int bit) => (etc43 & LorePascal.bit(bit)) != 0;
    LoreScript procedure(String id, List<ScriptStep> steps) => LoreScript(
      id: id,
      trigger: 'step',
      map: 22,
      once: false,
      require: const ScriptRequire(),
      steps: steps,
    );
    if (x == 25 && y == 18) {
      if (clear(2)) return null;
      // LORESPEC.PAS:1842-1844: one random(5) picks the slot that becomes 63.
      final monsters = List<int>.filled(5, 60);
      monsters[scripts.roll(5)] = 63;
      return scripts.startProcedure(
        procedure('keep2-ambush-25-18', [
          const ScriptStep(
            kind: 'scene',
            scene: ScriptScene(
              title: 'Death Knight',
              lines: [
                ' 나는 이 요새의 Wraith를 조종하는 죽음의 기',
                '사 Death Knight이다. 나에게 도전하다니 가소',
                '로운 것들. 으하하....',
              ],
            ),
          ),
          ScriptStep(
            kind: 'battle',
            battleTitle: 'Death Knight',
            battleEnemyFirst: true,
            monsters: monsters,
          ),
          const ScriptStep(kind: 'flag', key: 'etc43_bit2'),
        ]),
        context,
      );
    }
    if (y == 25 && x >= 24 && x <= 26) {
      if (clear(1)) return null;
      return scripts.startProcedure(
        procedure('keep2-guards-y25', const [
          ScriptStep(
            kind: 'battle',
            battleTitle: '요새 수비대',
            monsters: [61, 58, 56, 55, 60],
          ),
          ScriptStep(kind: 'flag', key: 'etc43_bit1'),
        ]),
        context,
      );
    }
    if (clear(2)) return null;
    // LORESPEC.PAS:1867-1875: no result check; the tile becomes 40 after
    // victory or escape.
    final floor = ScriptStep(
      kind: 'setTile',
      tileX: x,
      tileY: y,
      tileValue: 40,
    );
    return scripts.startProcedure(
      procedure('keep2-ambush-zone-a', [
        ScriptStep(
          kind: 'battle',
          battleTitle: 'Wraith',
          battleEnemyFirst: true,
          monsters: const [60, 60, 60, 60, 60],
          battleRunAwaySteps: [floor],
        ),
        floor,
      ]),
      context,
    );
  }

  /// `LORESPEC.PAS:1818-1834`: after `wantexit` is accepted and while
  /// etc[43] bit3 is clear, one `random(5) + 42` (42 read as 35) picks six
  /// guards plus enemy 66. bit3 is set when enemy 7 is dead, whatever the
  /// result, and the party leaves for map 5 after victory or escape.
  static LoreScript? keep2ExitGuard(
    ScriptContext context,
    int Function(int upperBound) roll,
  ) {
    if ((context.etcValue(43) & LorePascal.bit(3)) != 0) return null;
    var j = roll(5) + 42;
    if (j == 42) j = 35;
    return LoreScript(
      id: 'keep2-exit-guard',
      trigger: 'portal',
      map: 22,
      once: false,
      require: const ScriptRequire(),
      steps: [
        const ScriptStep(
          kind: 'scene',
          scene: ScriptScene(
            title: 'KEEP2 출구',
            appendPartyNameSlot: 1,
            appendPartyNameLine: 0,
            partyNameBefore: true,
            lines: [', 나의 힘을 보여주겠다.'],
          ),
        ),
        ScriptStep(
          kind: 'battle',
          battleEnemyFirst: true,
          monsters: [...List<int>.filled(6, j), 66],
          battleEnemyDefeatFlags: const {7: 'etc43_bit3'},
          battleContinueOnRunAway: true,
        ),
      ],
    );
  }

  /// `LORESPEC.PAS:1880-1979`, `case 23` (KEEP3 / DUNGEON OF EVIL).
  ///
  /// Source order: `if map[x,y] = 0 then exit` (1881), `Clear`, the `y = 46` exit
  /// (the `wantexit` boundary is owned by `LoreWorldManager.findPortal`), the
  /// `y = 26` impostor battle, then the `on(25,27)` lever. There is no random
  /// call and no cleared flag: revisits stop because the source overwrites the
  /// special tiles (`map[24..27,25..27] := 46`, `map[25,27] := 46`).
  static ScriptRun? map23(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    // LOREMAIN calls specialevent for den/keep tiles 0 and 52; tile 0 exits.
    final tile = context.tileAtPlayer;
    if (tile == 0 || (tile != null && tile != 52)) return null;
    if (y == 46) return null;
    if (y == 26) {
      return scripts.startProcedure(_keep3Impostor(), context);
    }
    if (x == 25 && y == 27) {
      return scripts.startProcedure(_keep3Lever(), context);
    }
    return null;
  }

  /// `LORESPEC.PAS:1895-1966`. Both fights use `BattleMode(FALSE)` and the
  /// battle result in etc[6]: 255 exits, any other non-zero value is an escape.
  /// The mirror fight repeats on escape with the same enemy objects; the real
  /// Necromancer fight moves the party to y + 1 on escape. Presentation
  /// (DisplayEnemies, Clear, PressAnyKey) is adapted to native scenes.
  static LoreScript _keep3Impostor() => LoreScript(
    id: 'keep3-necromancer-y26',
    trigger: 'step',
    map: 23,
    once: false,
    require: const ScriptRequire(),
    steps: [
      const ScriptStep(
        kind: 'scene',
        scene: ScriptScene(
          title: 'Necromancer',
          appendPartyNameSlot: 1,
          appendPartyNameLine: 0,
          appendPartyNameSuffix: '.',
          lines: [
            ' 잘도 여기까지 찾아왔구나 ',
            ' 네가 찾던 그 Necromancer가 바로 나다. 드디',
            '어 너의 실력을 보게 되겠구나. 하지만 분명히',
            '나보다는 떨어지겠지만. 으하하하.',
          ],
        ),
      ),
      const ScriptStep(
        kind: 'scene',
        scene: ScriptScene(
          title: '환상',
          lines: [
            ' 너희들은 곧 환상에 빠져들게 될 것이다.',
            ' 나는 벌써 너희들의 약점을 파악 했지.  너희',
            '일행들은 항상 자신을  너무 신뢰하고 믿고 있',
            '더군. 그러나 그 착각은 곧 깨어질 것이다.',
            ' 어둠의 신이여, 당신의 힘으로 이들을 환상에',
            '빠져 들게 하소서. 인 쿠아스 젠 ~~',
          ],
        ),
      ),
      const ScriptStep(
        kind: 'battle',
        battleTitle: '환상의 도플갱어',
        battleEnemyFirst: true,
        monsters: [60, 60, 60, 60, 60, 60],
        battleMirrorParty: true,
        battleRetryOnRunAway: true,
        battleRunAwaySteps: [
          ScriptStep(
            kind: 'scene',
            scene: ScriptScene(title: '환상', lines: [' 하지만 당신은 환상에서 벗어나지 못했다.']),
          ),
        ],
      ),
      const ScriptStep(
        kind: 'scene',
        scene: ScriptScene(
          title: 'Necromancer',
          lines: [' 환상에서 벗어나다니 대단한 의지력이군.', ' 하지만 진짜 적은 바로 나다. 받아라 !!'],
        ),
      ),
      const ScriptStep(
        kind: 'battle',
        battleTitle: 'Necromancer',
        battleEnemyFirst: true,
        monsters: [70],
        battleOverrides: [
          {'index': 1, 'name': 'Necromancer', 'eNumber': 1},
        ],
        battleRunAwaySteps: [ScriptStep(kind: 'nudge', nudgeDy: 1)],
      ),
      const ScriptStep(
        kind: 'scene',
        scene: ScriptScene(
          title: 'Necromancer',
          lines: [
            ' 욱! 너의 힘은 대단하구나. 나는 너에게 졌다',
            '고 인정하겠다.  흐흐, 그러나 사실 나는 너희',
            '찾던 Necromancer님이 아니다.  만약 그분이라',
            '이렇게 쉽게 당하지는 않았을게니까.  내 생명',
            '이 얼마 안남았구나. Necromancer님 만세 !!',
          ],
        ),
      ),
      // The map writes precede the final PressAnyKey in the source.
      const ScriptStep(kind: 'setTile', tileX: 29, tileY: 43, tileValue: 53),
      const ScriptStep(
        kind: 'setTileArea',
        tileX: 24,
        tileXMax: 27,
        tileY: 25,
        tileYMax: 27,
        tileValue: 46,
      ),
      const ScriptStep(
        kind: 'scene',
        scene: ScriptScene(
          title: '기둥 소멸',
          lines: [' 그는 숨이 끊어졌고 주위의 기둥도 그와 함께', '사라져 버렸다.'],
        ),
      ),
    ],
  );

  /// `LORESPEC.PAS:1967-1978`: the lever writes the map first, then prints
  /// and waits. Only tile 0 cells of the 12..39 x 7..34 area become 39.
  static LoreScript _keep3Lever() => LoreScript(
    id: 'keep3-trap-25-27',
    trigger: 'step',
    map: 23,
    once: false,
    require: const ScriptRequire(),
    steps: [
      const ScriptStep(kind: 'setTile', tileX: 25, tileY: 27, tileValue: 46),
      const ScriptStep(kind: 'setTile', tileX: 29, tileY: 43, tileValue: 44),
      const ScriptStep(
        kind: 'setTileArea',
        tileX: 12,
        tileXMax: 39,
        tileY: 7,
        tileYMax: 34,
        tileValue: 39,
        tileOnlyIf: 0,
      ),
      const ScriptStep(kind: 'setTile', tileX: 25, tileY: 12, tileValue: 54),
      const ScriptStep(kind: 'setTile', tileX: 26, tileY: 12, tileValue: 54),
      const ScriptStep(
        kind: 'scene',
        scene: ScriptScene(
          title: '레버',
          lines: [
            ' 푯말에 쓰여 있는 대로 이 곳의 레버를 당겼 ',
            '더니 굉음과 함께 감추어져 있었던 성이 지하 ',
            '로부터 떠 올랐다.',
          ],
        ),
      ),
    ],
  );

  /// `LORESPEC.PAS:1980-1994`, map 24 (K_DEN1 / LAST SHELTER).
  ///
  /// The single exit at `y == 46` is handled via portal session.
  /// No other internal special tiles exist on map 24.
  static ScriptRun? map24(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    return null;
  }

  /// `LORESPEC.PAS:1995-2103`, map 25 (K_DEN2 / DUNGEON OF EVIL DEEP / CASTLE KEEP).
  ///
  /// The ordered guards evaluate:
  /// 1. Southern exit at `y == 46` handled via portal session.
  /// 2. Metal Guardian encounter at `y == 43`:
  ///    - Torch ignition (`party.etc[1] := 1`), battle with metal enemy + 4 soldiers,
  ///    - set corridor tile `(24..27, 43) := 41`, dialogue and class promotion (`class := 10`).
  /// 3. Hidden passage at `(15, 34)`:
  ///    - `keep25-corridor-15-34`.
  /// 4. Hidden passage at `(36, 34)`:
  ///    - `keep25-corridor-36-34`.
  /// 5. Lever A at `(5, 34)`:
  ///    - Sets `etc45_bit7`. If both bit7 & bit8 set -> opens portal doors `map[25..26, 27] := 54`.
  /// 6. Lever B at `(46, 34)`:
  ///    - Sets `etc45_bit8`. If both bit7 & bit8 set -> opens portal doors `map[25..26, 27] := 54`.
  static ScriptRun? map25(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (context.tileAtPlayer != null &&
        context.tileAtPlayer != 52 &&
        context.tileAtPlayer != 0) {
      return null;
    }

    // LORESPEC.PAS:2009-2065. No clear flag or random draw in this branch.
    // Revisits stop because tiles 24..27 become ordinary floor after victory.
    if (y == 43) {
      final torch = context.etcValue(1);
      final alreadyLit =
          torch != 0 ||
          (!context.sourceEtc.containsKey(1) &&
              context.flags.contains('torchActive'));
      return scripts.startProcedure(
        LoreScript(
          id: 'keep3-metal-guardian-y43',
          trigger: 'step',
          map: 25,
          once: false,
          require: const ScriptRequire(),
          steps: [
            if (!alreadyLit) ...const [
              ScriptStep(
                kind: 'sourceEtc',
                sourceEtcIndex: 1,
                sourceEtcValue: 1,
              ),
              ScriptStep(kind: 'torch', torchLit: true),
            ],
            const ScriptStep(
              kind: 'scene',
              scene: ScriptScene(
                title: '금속 수호자',
                actors: [71],
                lines: [
                  ' 금속으로된 어떤 적이 나타났다.',
                  ' 여기까지 잘도왔구나. 나의 임무는 너희 같은',
                  '쓰레기들 때문에 Necromancer 님이 수고하시지',
                  '않도록 미리 처단해 버리는 것이다.',
                ],
              ),
            ),
            const ScriptStep(
              kind: 'battle',
              battleTitle: '금속 수호자',
              battleEnemyFirst: true,
              monsters: [66, 66, 66, 66, 71],
              battleRunAwaySteps: [ScriptStep(kind: 'nudge', nudgeDy: 1)],
            ),
            for (var i = 24; i <= 27; i++)
              ScriptStep(kind: 'setTile', tileX: i, tileY: y, tileValue: 41),
            const ScriptStep(
              kind: 'scene',
              scene: ScriptScene(
                title: '금속 수호자 격파',
                lines: [' 당신이 적을 물리치자 조금후에 이상하리만큼', '편안한 기운이 일행을 감쌌다.'],
              ),
            ),
            const ScriptStep(
              kind: 'scene',
              scene: ScriptScene(
                title: '안내',
                actors: [68, 67],
                appendPartyNameSlot: 1,
                appendPartyNameLine: 0,
                lines: [
                  ' 매우 수고하시는군요. ',
                  ' 당신이 Necromancer에게 가기전에 한 가지 일',
                  '러 두고자 하오.',
                  ' 이곳에는 비밀스런 문이 두군데 있소. 지금은',
                  '보이지가 않지만 양쪽의 벽을 살피다 보면  숨',
                  '겨진 문 안에 레버가 각각 하나씩 있소.  그걸',
                  '모두 작동시키면 용암의 중앙에서 Necromancer',
                  '의 방으로 통하는 입구가 보일 것이오. 여기까',
                  '지만 내가 알려줄 수가 있는 부분이오. 마지막',
                  '으로 당신의 건투를 빌겠소.',
                ],
              ),
            ),
            const ScriptStep(kind: 'partyClass', partyClassId: 10),
          ],
        ),
        context,
      );
    }

    // LORESPEC.PAS:2067-2079. Preserve the loop order and its final overwrites.
    if ((x == 15 || x == 36) && y == 34) {
      final left = x == 15;
      final steps = <ScriptStep>[
        ScriptStep(kind: 'setTile', tileX: x, tileY: 34, tileValue: 41),
        for (var i = left ? 11 : 37; i <= (left ? 14 : 40); i++) ...[
          ScriptStep(kind: 'setTile', tileX: i, tileY: 33, tileValue: 24),
          ScriptStep(kind: 'setTile', tileX: i, tileY: 35, tileValue: 26),
          ScriptStep(kind: 'setTile', tileX: i, tileY: 34, tileValue: 42),
        ],
        ScriptStep(
          kind: 'setTile',
          tileX: left ? 14 : 37,
          tileY: 33,
          tileValue: left ? 17 : 19,
        ),
        ScriptStep(
          kind: 'setTile',
          tileX: left ? 14 : 37,
          tileY: 35,
          tileValue: left ? 18 : 22,
        ),
      ];
      return scripts.startProcedure(
        LoreScript(
          id: 'keep25-corridor-$x-34',
          trigger: 'step',
          map: 25,
          once: false,
          require: const ScriptRequire(),
          steps: steps,
        ),
        context,
      );
    }

    // LORESPEC.PAS:2081-2101: write our bit before testing BOTH lever bits.
    // Raw etc[45], including a stored zero, takes precedence over old aliases.
    if ((x == 5 || x == 46) && y == 34) {
      final bit = x == 5 ? 7 : 8;
      final after =
          context.etcValue(
            45,
            bitAliases: const {7: 'keep3KeyA', 8: 'keep3KeyB'},
          ) |
          LorePascal.bit(bit);
      final opened = (after & 0xc0) == 0xc0;
      return scripts.startProcedure(
        LoreScript(
          id: 'keep3-key-${x == 5 ? 'a' : 'b'}-${opened ? 'second' : 'first'}',
          trigger: 'step',
          map: 25,
          once: false,
          require: const ScriptRequire(),
          steps: [
            ScriptStep(kind: 'flag', key: 'etc45_bit$bit'),
            // Compatibility name for old UI/saves; not a second source state.
            ScriptStep(kind: 'flag', key: x == 5 ? 'keep3KeyA' : 'keep3KeyB'),
            const ScriptStep(kind: 'say', text: ' 당신이 레버를 당기자  철컥하는 소리가 동굴'),
            const ScriptStep(kind: 'say', text: '에 울려 퍼졌다.'),
            if (opened) ...const [
              ScriptStep(kind: 'setTile', tileX: 25, tileY: 27, tileValue: 54),
              ScriptStep(kind: 'setTile', tileX: 26, tileY: 27, tileValue: 54),
              ScriptStep(kind: 'say', text: ' 곧 이어 기계 작동하는 큰 소리가 들렸다.'),
            ],
          ],
        ),
        context,
      );
    }

    return null;
  }

  /// `LORESPEC.PAS:2104-2201`, map 26 (CHAMBER OF NECROMANCER / 결전의 방).
  ///
  /// Final showdown cutscene and battle sequence with Neo-Necromancer, ArchiMonk, and ArchiMage:
  ///    - Triggered on empty floor (tile == 0).
  ///    - `spec-26-L2104-seq`.
  static ScriptRun? map26(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (context.tileAtPlayer != 0) return null;
    // LORESPEC.PAS:2104-2201: no cleared flag and no random call.
    return scripts.startProcedure(
      LoreScript(
        id: 'spec-26-L2104-seq',
        trigger: 'step',
        map: 26,
        once: false,
        require: const ScriptRequire(),
        steps: [
          const ScriptStep(kind: 'sourceFace', sourceFace: 5),
          for (var i = 1; i <= 3; i++)
            const ScriptStep(kind: 'nudge', nudgeDy: -1),
          const ScriptStep(kind: 'sourceFace', sourceFace: 6),
          for (var sourceX = x; sourceX < 26; sourceX++)
            const ScriptStep(kind: 'nudge', nudgeDx: 1),
          const ScriptStep(kind: 'sourceFace', sourceFace: 5),
          const ScriptStep(
            kind: 'scene',
            scene: ScriptScene(
              title: "결전의 방",
              actors: [73, 74, 75],
              lines: [
                " 당신들이 나를 없에겠다고 온자들인가?",
                " 그럼 예의를 갖추고 소개를 하지.  당신의 오",
                "른쪽의 사람은  ArchiMonk라고 하며 맨손을 사",
                "용하는 무예의 일인자로 통하지.  그리고 당신",
                "의 정면의 사람은 ArchiMage 라고 하는 마법사",
                "중의 마법사이라네.  당신들은 우리 셋 보다도",
                "숫자가 많군. 그렇다면 나도 그것에 대비를 해",
                "야겠지.  내가 여기서 약간의 인원을 늘인다고",
                "너무 섭섭하게 생각말게.  그렇다면 이제 서로",
                "의 실력을 겨뤄볼 시간이 다 되었나보군. 당신",
                "의 행운을 빌겠네.",
              ],
            ),
          ),
          const ScriptStep(
            kind: 'battle',
            battleTitle: 'Neo-Necromancer',
            battleEnemyFirst: true,
            monsters: [69, 70, 71, 72, 73, 74, 75],
            battleRetryOnRunAway: true,
            battleVictoryIfEnemyDead: 7,
            battleRunAwaySteps: [
              ScriptStep(
                kind: 'scene',
                scene: ScriptScene(
                  title: "도주 불가",
                  actors: [75],
                  lines: [" 하지만 나에게 도전한 이상 도주는 허용할 수", "없다는 점이 안타깝군."],
                ),
              ),
            ],
          ),
          const ScriptStep(
            kind: 'scene',
            scene: ScriptScene(
              title: "최후의 대사",
              actors: [75],
              lines: [
                " 욱!!! 역시 너희들의 능력으로 여기까지 뚫고",
                "들어왔다는게 믿어지는구나. 대단한 힘이다.",
                " 내가 졌다는걸 인정하마. 하지만 나는 완전히",
                "너에게 진것은 아니야.  나에게는 탈출할 수단",
                "이 있기 때문이지. 안심해라. 그렇지만 다시는",
                "나와 만날 인연은 없으니까.  블랙홀이 생기기",
                "시작하는구나.  다음 공간에서 또다시 힘을 길",
                "러야 겠군. 내가 이 블랙홀로 들어간다면 다시",
                "이 공간으로 올 확률이 거의 제로이지. 흠, 멋",
                "진 나의 도전자여 안녕.  나는 이런 공간의 패",
                "러독스를 운명적으로 반복하는 생명체로  태어",
                "난 내가 참으로 비참하지. 무한히 많은 3 차원",
                "의 공간중에서 내가 여기로 온것도  이 공간의",
                "생명이 끝날때까지도 한번 있을까 말까한 희귀",
                "한 일이었다고 기억해다오.  이제 블랙홀이 완",
                "전히 생겼군. 자! 나의 멋진 도전자 친구여 영",
                "원히 안녕 ! !",
              ],
            ),
          ),
          const ScriptStep(kind: 'endDemo'),
        ],
      ),
      context,
    );
  }

  /// `LORESPEC.PAS:2202-2212`, map 27 (PYRAMID1 / ANOTHER LORE).
  ///
  /// The whole arm is `wantexit`: acceptance loads map 1 at (20,8) and refusal
  /// moves `y < 25 ? y + 1 : y - 1`. Both belong to the exit boundary in
  /// `LoreWorldManager.findPortal`/`sourceExitRejectY`; no special event runs.
  static ScriptRun? map27(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) => null;

  /// `LORESPEC.PAS:190-196`: the chest is a special tile until its tile is
  /// replaced with floor. Keep the reward and tile effect in JSON data.
  static ScriptRun? map6Chest(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (x != 62 || y != 82) return null;
    return map6(x, y, context, scripts);
  }

  /// `LORESPEC.PAS:37-189`, map 4. The ordered Pascal guards select one
  /// event; the existing JSON records provide its dialogue and effects.
  static ScriptRun? map4(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) {
    if (!scripts.usingJson) return null;
    final flags = context.flags;
    final id = switch ((x, y)) {
      (40, 18) => 'spec-4-L37',
      (26, 16) =>
        flags.contains('draconianMet')
            ? 'spec-4-L37-3'
            : flags.contains('etc5')
            ? 'spec-4-L37-2'
            : 'spec-4-L37-1',
      (20, 39) =>
        flags.contains('ancientEvilMet')
            ? 'ancient-evil-later'
            : 'ancient-evil-first',
      _ => null,
    };
    if (id == null) return null;
    final content = scripts.scripts.where((script) => script.id == id).single;
    return scripts.startProcedure(content, context);
  }

  /// `LORESPEC.PAS:23-34`, map 1: every special tile gives food once, then
  /// moves the party back from the trigger tile on both first and later visits.
  static ScriptRun? map1Food(ScriptContext context, LoreScriptEngine scripts) {
    if (context.tileAtPlayer != 0) return null;
    final visited = context.etcValue(32) & LorePascal.bit(8) != 0;
    final procedure = LoreScript(
      id: 'lorespec-map1-food',
      trigger: 'step',
      map: 1,
      once: false,
      require: const ScriptRequire(),
      steps: [
        ScriptStep(
          kind: 'say',
          text: visited ? '우리들은 아무것도 발견할수 없었다.' : '일행들은 100 인분의 식량을 발견했다.',
        ),
        if (!visited) ...const [
          ScriptStep(kind: 'food', amount: 100),
          ScriptStep(kind: 'flag', key: 'etc32_bit8'),
        ],
        const ScriptStep(kind: 'stepBack'),
      ],
    );
    return scripts.startProcedure(procedure, context);
  }
}
