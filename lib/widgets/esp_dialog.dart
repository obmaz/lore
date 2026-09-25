import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import '../models/party_member.dart';
import '../game/lore_dialogue_manager.dart';

/// 1993년 원작 LOREMENU.PAS: Extrasense (ESP 초감각 / 정신 기술) 다이얼로그
class EspDialog extends StatefulWidget {
  final List<PartyMember> party;
  final void Function(String message) onLog;
  final void Function(int count)? onMindReadActivated;

  const EspDialog({
    super.key,
    required this.party,
    required this.onLog,
    this.onMindReadActivated,
  });

  @override
  State<EspDialog> createState() => _EspDialogState();
}

class _EspDialogState extends State<EspDialog> {
  int _selectedMemberIdx = 0;
  String? _resultText;

  @override
  Widget build(BuildContext context) {
    final member = widget.party[_selectedMemberIdx];
    final hasEspAbility =
        member.playerClass == PlayerClass.mage ||
        member.playerClass == PlayerClass.monk ||
        member.playerClass == PlayerClass.esper ||
        member.playerClass == PlayerClass.vagrant ||
        member.esp > 0;

    return Dialog(
      backgroundColor: RetroTheme.black,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.lightMagenta, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '◆ 초감각 기술 (EXTRASENSE / ESP) ◆',
                    overflow: TextOverflow.ellipsis,
                    style: RetroTheme.headerFont.copyWith(
                      color: RetroTheme.lightMagenta,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '[ESC / 닫기]',
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.lightGray,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 파티원 선택 탭
            Text(
              '초감각을 사용할 인물을 선택하십시오:',
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.yellow,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.party.asMap().entries.map((entry) {
                final isSel = entry.key == _selectedMemberIdx;
                final p = entry.value;

                return ChoiceChip(
                  label: Text(
                    '${p.name} (ESP:${p.esp})',
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
                        _selectedMemberIdx = entry.key;
                        _resultText = null;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            if (!hasEspAbility) ...[
              Container(
                padding: const EdgeInsets.all(12),
                color: RetroTheme.background,
                child: Text(
                  '${member.name}에게는 아직 초감각 능력이 없습니다.\n(마법사, 승려, 에스퍼, 방랑자 등이 초감각을 사용할 수 있습니다.)',
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.lightRed,
                    fontSize: 11,
                  ),
                ),
              ),
            ] else ...[
              Text(
                '사용할 초감각의 종류 ===>',
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.lightCyan,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),

              _espButton(
                '[1] 투시 (Clairvoyance) - 소모 ESP 10',
                '던전 벽과 숨겨진 비밀 통로를 투시하여 주변 지형을 파악합니다.',
                member.esp >= 10,
                () {
                  setState(() {
                    member.esp -= 10;
                    _resultText = '✨ 일행은 마법의 혜안으로 주변 지형과 숨겨진 통로를 꿰뚫어 보고 있습니다.';
                  });
                  widget.onLog(
                    '👁 [투시] ${member.name}이(가) 초감각으로 주변 지형을 투시했습니다.',
                  );
                },
              ),
              _espButton(
                '[2] 미래 예언 (Prophecy) - 소모 ESP 5',
                '운명의 흐름을 읽어 일행이 다음에 완수해야 할 목표를 예언합니다.',
                member.esp >= 5,
                () {
                  final prophecy = LoreDialogueManager.instance.getProphecy();
                  setState(() {
                    member.esp -= 5;
                    _resultText = '🔮 당신은 당신의 미래를 예언한다 ...\n\n"$prophecy"';
                  });
                  widget.onLog('🔮 [예언] $prophecy');
                },
              ),
              _espButton(
                '[3] 독심술 (Telepathy) - 소모 ESP 20',
                '타인의 깊은 속마음을 읽어내는 텔레파시를 활성화합니다 (3회 지속).',
                member.esp >= 20,
                () {
                  setState(() {
                    member.esp -= 20;
                    _resultText =
                        '🧠 당신은 잠시동안 다른 사람의 숨겨진 마음을 읽을 수 있습니다. (3회 가능)';
                  });
                  widget.onMindReadActivated?.call(3);
                  widget.onLog(
                    '🧠 [독심술] ${member.name}이(가) 타인의 마음을 읽는 능력을 활성화했습니다.',
                  );
                },
              ),
              _espButton(
                '[4] 천리안 (Scrying) - 소모 ESP 10',
                '원하는 방향으로 영혼의 시야를 투사하여 전방을 정찰합니다.',
                member.esp >= 10,
                () {
                  setState(() {
                    member.esp -= 10;
                    _resultText =
                        '🔭 천리안의 눈으로 전방 원거리 지형을 정찰했습니다. 주변에 특이 동향이 감지되었습니다.';
                  });
                  widget.onLog(
                    '🔭 [천리안] ${member.name}이(가) 전방 원거리 지형을 정찰했습니다.',
                  );
                },
              ),
            ],

            if (_resultText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
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

            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RetroTheme.darkGray,
                  foregroundColor: RetroTheme.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '닫기 (ESC)',
                  style: RetroTheme.dosFont.copyWith(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _espButton(
    String title,
    String desc,
    bool enabled,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? RetroTheme.blue : RetroTheme.darkGray,
          foregroundColor: RetroTheme.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        onPressed: enabled ? onPressed : null,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 11,
                  color: RetroTheme.yellow,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 9,
                  color: RetroTheme.lightGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
