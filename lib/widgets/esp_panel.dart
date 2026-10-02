import 'package:flutter/material.dart';

import '../game/lore_dialogue_manager.dart';
import '../logic/lore_menu_text.dart';
import '../models/party_member.dart';
import '../theme/retro_theme.dart';

/// LOREMENU.PAS `Extrasense`: 인물 선택(ChooseWhom, LORESUB.PAS) → 초감각 종류.
///
/// 화면 문구는 모두 원작 문자열이다. 비용(투시 10, 예언 5, 독심 20, 천리안 10)은
/// 기존 포트 동작을 유지한다.
class EspPanel extends StatefulWidget {
  final List<PartyMember> party;
  final void Function(String message) onLog;
  final void Function(int count)? onMindReadActivated;

  const EspPanel({
    super.key,
    required this.party,
    required this.onLog,
    this.onMindReadActivated,
  });

  /// LORESUB.PAS `ChooseWhom`.
  static const String chooseWhom = '한명을 고르시오 ---';

  /// LOREMENU.PAS `Extrasense` 예언(2) 첫 줄.
  static const String prophecyHeader = ' 당신은 당신의 미래를 예언한다 ...';

  @override
  State<EspPanel> createState() => _EspPanelState();
}

class _EspPanelState extends State<EspPanel> {
  int _memberIdx = 0;
  String? _resultText;

  bool _canUse(PartyMember member) =>
      member.playerClass == PlayerClass.mage ||
      member.playerClass == PlayerClass.monk ||
      member.playerClass == PlayerClass.esper ||
      member.playerClass == PlayerClass.vagrant ||
      member.esp > 0;

  /// 원작처럼 선택은 항상 가능하고, 부족하면 `ESPnotEnough` 메시지를 보인다.
  void _use(PartyMember member, int cost, String Function() effect) {
    if (member.esp < cost) {
      setState(() => _resultText = LoreMenuText.espNotEnough);
      return;
    }
    final message = effect();
    setState(() {
      member.esp -= cost;
      _resultText = message;
    });
    widget.onLog(message);
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.party[_memberIdx];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          EspPanel.chooseWhom,
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightGreen,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: widget.party.asMap().entries.map((entry) {
            final isSel = entry.key == _memberIdx;
            return ChoiceChip(
              label: Text(
                entry.value.name,
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 10,
                  color: isSel ? RetroTheme.black : RetroTheme.white,
                ),
              ),
              selected: isSel,
              selectedColor: RetroTheme.yellow,
              backgroundColor: RetroTheme.darkBlue,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _memberIdx = entry.key;
                    _resultText = null;
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        if (!_canUse(member))
          Text(
            LoreMenuText.espNoAbility,
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.lightRed,
              fontSize: 11,
            ),
          )
        else ...[
          Text(
            LoreMenuText.espKind,
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.lightCyan,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          _button(
            1,
            LoreMenuText.espNames[0],
            () => _use(member, 10, () => LoreMenuText.espSeeThrough),
          ),
          _button(2, LoreMenuText.espNames[1], () {
            final prophecy = LoreDialogueManager.instance.getProphecy();
            _use(member, 5, () => '${EspPanel.prophecyHeader}\n\n$prophecy');
          }),
          _button(3, LoreMenuText.espNames[2], () {
            _use(member, 20, () {
              widget.onMindReadActivated?.call(3);
              return LoreMenuText.espMindRead;
            });
          }),
          _button(
            4,
            LoreMenuText.espNames[3],
            () => _use(member, 10, () => LoreMenuText.espClairvoyanceBusy),
          ),
          _button(5, LoreMenuText.espNames[4], () {
            setState(() {
              _resultText =
                  '${LoreMenuText.espNames[4]}${LoreMenuText.espBattleOnly}';
            });
          }),
        ],
        if (_resultText != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: RetroTheme.darkBlue,
              border: Border.all(color: RetroTheme.lightCyan),
            ),
            child: Text(
              _resultText!,
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.yellow,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _button(int number, String title, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ElevatedButton(
        key: ValueKey('esp-$number'),
        style: ElevatedButton.styleFrom(
          backgroundColor: RetroTheme.blue,
          foregroundColor: RetroTheme.white,
          minimumSize: const Size.fromHeight(30),
        ),
        onPressed: onPressed,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: RetroTheme.dosFont.copyWith(fontSize: 11)),
        ),
      ),
    );
  }
}
