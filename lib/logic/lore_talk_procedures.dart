import '../data/lore_script.dart';

/// Verified closed recruitment arms of `LORETALK.PAS:talkmode`.
/// Mad Joe, Polaris and Lore Hunter are closed Dart-owned branches; the
/// remaining talkmode branches execute in LoreTalkMode.
///
/// Dispatches dialogue/interaction sequences in Pascal source order.
/// Facilities are checked first (Weapon shop, Hospital, Train center, Grocery),
/// then map-specific procedures evaluate coordinates, conditions, dialogue,
/// selections, and flag/tile modifications.
class LoreTalkProcedures {
  LoreTalkProcedures._();

  /// Complete Mad Joe choice arm, LORETALK.PAS:191-217. Escape and reply 2
  /// call asyouwish; reply 1 always overwrites source player[6].
  static const madJoeRecruit = LoreScript(
    id: 'madjoe-join',
    trigger: 'talk',
    map: 6,
    x: 40,
    y: 15,
    once: false,
    require: ScriptRequire(),
    steps: [
      ScriptStep(kind: 'say', text: ' 히히히... 위대한 용사님. 낄낄낄.. 내가 당'),
      ScriptStep(kind: 'say', text: '신들의 일행에 끼이면 안될까요 ? 우히히히..'),
      ScriptStep(
        kind: 'choice',
        prompt: '',
        cancelOptionIndex: 1,
        options: [
          ScriptOption('그렇다면 당신을 받아들이지요', [
            ScriptStep(kind: 'join', key: 'mad_joe', slot: 4),
            ScriptStep(
              kind: 'setTile',
              teleportMap: 6,
              tileX: 40,
              tileY: 15,
              tileValue: 47,
            ),
            ScriptStep(kind: 'flag', key: 'madJoeJoined'),
            ScriptStep(kind: 'flag', key: 'etc50_bit2'),
          ]),
          ScriptOption('당신은 이곳에 그냥 있는게 낫겠소', [
            ScriptStep(kind: 'message', text: '당신이 바란다면 ...'),
          ]),
        ],
      ),
    ],
  );

  /// LORETALK.PAS:406-435. The caller checks raw etc[13] < 2; accepting
  /// still waits for ReturnJoinMember before mutating the party or map.
  static const polarisRecruit = LoreScript(
    id: 'polaris-join',
    trigger: 'talk',
    map: 7,
    x: 37,
    y: 41,
    once: false,
    require: ScriptRequire(),
    steps: [
      ScriptStep(kind: 'say', text: '나의 이름은 Polaris 요.'),
      ScriptStep(kind: 'say', text: '당신들과 같이 Major Mummy 를 물리치고 싶소.'),
      ScriptStep(kind: 'say', text: '내가 당신의 일행에 끼여도 되겠소 ?'),
      ScriptStep(
        kind: 'choice',
        prompt: '',
        cancelOptionIndex: 1,
        options: [
          ScriptOption('나는 당신의 제안을 받아 들이겠소', [
            ScriptStep(kind: 'join', key: 'polaris'),
            ScriptStep(kind: 'flag', key: 'polarisJoined'),
            ScriptStep(
              kind: 'setTile',
              teleportMap: 7,
              tileX: 37,
              tileY: 41,
              tileValue: 44,
            ),
          ]),
          ScriptOption('나는 당신의 도움은 필요 없소', [
            ScriptStep(kind: 'message', text: '당신이 바란다면 ...'),
          ]),
        ],
      ),
    ],
  );

  /// LORETALK.PAS:607-639. Only reply 2 prints asyouwish; Escape exits
  /// silently. A fresh NPC tile can offer recruitment even after etc[38] bit4.
  static const loreHunterRecruit = LoreScript(
    id: 'lorehunter-join',
    trigger: 'talk',
    map: 10,
    x: 40,
    y: 56,
    once: false,
    require: ScriptRequire(),
    steps: [
      ScriptStep(kind: 'say', text: ' 나는 LORE 특공대의 대장인 Lore Hunter 라고'),
      ScriptStep(kind: 'say', text: '하오. 여기서의 적들과는, 이제 대항하기가 혼'),
      ScriptStep(kind: 'say', text: '자서는 무리라고 판단했소. 그래서, 나는 여태'),
      ScriptStep(kind: 'say', text: '껏 여기서 새로운 영웅들을 기다리고 있었소.'),
      ScriptStep(kind: 'say', text: ' 내가 당신의 일행에 끼게 되는걸 어떻게 생각'),
      ScriptStep(kind: 'say', text: '하오 ?'),
      ScriptStep(
        kind: 'choice',
        prompt: '',
        options: [
          ScriptOption('우리도 그러기를 바라오', [
            ScriptStep(kind: 'join', key: 'lore_hunter'),
            ScriptStep(
              kind: 'setTile',
              teleportMap: 10,
              tileX: 40,
              tileY: 56,
              tileValue: 44,
            ),
            ScriptStep(kind: 'flag', key: 'etc38_bit4'),
            ScriptStep(kind: 'flag', key: 'loreHunterJoined'),
          ]),
          ScriptOption('몸이 완전히 회복될때까지 기다리시오', [
            ScriptStep(kind: 'message', text: '당신이 바란다면 ...'),
          ]),
        ],
      ),
    ],
  );
  static ScriptRun? map6(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) => x == 40 && y == 15
      ? scripts.startProcedure(madJoeRecruit, context)
      : null;
  static ScriptRun? map7(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) =>
      x == 37 &&
          y == 41 &&
          (context.sourceEtc[13] ?? context.questSteps['lastditch'] ?? 0) < 2
      ? scripts.startProcedure(polarisRecruit, context)
      : null;
  static ScriptRun? map10(
    int x,
    int y,
    ScriptContext context,
    LoreScriptEngine scripts,
  ) => x == 40 && y == 56
      ? scripts.startProcedure(loreHunterRecruit, context)
      : null;
}
