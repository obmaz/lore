import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import '../theme/mobile_theme.dart';
import 'mobile_dialog_action.dart';
import 'mobile_content_dialog.dart';

/// 원작 `LOREHELP.PAS`의 타이틀 편지(`Title_Str`)와 그 아래 문구.
class LoreGuideDialog extends StatelessWidget {
  const LoreGuideDialog({super.key});

  /// `Title_Str[1]`의 앞 공백을 뺀 첫 줄.
  static const String titleLine = '오래전 부터 만날 운명이었던 당신에게 드리는 글';

  /// `Title_Str[3..15]` + 서명 (원문 줄바꿈 그대로).
  static const List<String> authorPreface = [
    '         오래전 부터 만날 운명이었던 당신에게 드리는 글',
    '',
    '어서 오십시오. LORE의 세계에 당신을 초대합니다.',
    '이곳은 당신이 지금 있는 지구와는 같은 시간대를 지니고 있지만 공',
    '간적으로는 다르게 진화해 온 또다른 지구라고 할 수 있습니다.  이',
    '곳은 아직도 검과 마법이 존재하며 과학 기술은 지구의 중세 정도라',
    '고 해두면 이 곳이 이해가 되겠습니까 ?',
    '지금 이 곳은 다른 공간에서 차원의 문을 이용해 들어온  어떤 자에',
    '의해 고통을 겪고 있습니다. 이 일은 그전부터 이 세계에 지워진 운',
    '명으로 예언 되었었고  그 불가변한 운명에서 벗어나기 위해 당신을',
    '이 세계로 소환하게 되었습니다. 이제부터 당신은 이 세계의 사람입',
    '니다.  지금부터 당신의 일행과 함께 당신의 운명 또한 새롭게 개척',
    '해 보십시오.  당신의 현명한 판단에 의해 당신 앞에 펼쳐질 세계에',
    '도전 하십시오.',
    '언제나 운명의 파문은 당신 앞에 엄습해오고 있으니 ...',
    '',
    '                                          제작자  안 영기  드림',
  ];

  /// `Title_Menu`가 편지 아래에 `cHPrint`로 그리는 문구 (제목 포함).
  static const List<String> titleCaption = [
    '또다른 지식의 성전  제 1 부',
    '거친 황야의 대륙과 높은 산으로 둘러 싸인 대륙과 물속에 잠기고',
    '늪으로 덮히고 용암이 흐르는 대륙도  당신이 어쩔수 없이 거쳐야',
    '될 운명의 길입니다. 운명을 피하려 하지 마십시오.  당신 앞에는',
    '언제나 당신을 지켜보며 도와주는 내가 있고 당신의 신이 있고 당',
    '신의 동료들이 있습니다. 당신이 이 세계에 들어 오는 그 날이 바',
    '로 그 모든 운명을 지게 되는 시작임을 잊지 말기를 빕니다.',
  ];

  @override
  Widget build(BuildContext context) {
    return MobileContentDialog(
      title: '모험 안내',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in [...authorPreface, '', ...titleCaption])
            Text(line.isEmpty ? ' ' : line,
              style: RetroTheme.dosFont.copyWith(
                fontSize: 15, height: 1.6, color: MobileTheme.ink,
              )),
        ],
      ),
      footer: MobileDialogAction(
        key: const ValueKey('guide-close'), label: '닫기', secondary: true,
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}
