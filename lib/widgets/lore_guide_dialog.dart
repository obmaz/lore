import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';

/// 1993년 원작 LOREHELP.PAS 기반 원작자 서문 및 게임 안내 다이얼로그
class LoreGuideDialog extends StatefulWidget {
  const LoreGuideDialog({super.key});

  // 원작 LOREHELP.PAS Title_Str 배열 (Johab CP1361 원문 디코딩)
  static const List<String> authorPreface = [
    '오래전 부터 만날 운명이었던 당신에게 드리는 글',
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

  // 원작 LOREHELP.PAS Title_Menu 하단 자막 텍스트
  static const List<String> titleCaption = [
    '거친 황야의 대륙과 높은 산으로 둘러 싸인 대륙과 물속에 잠기고',
    '늪으로 덮히고 용암이 흐르는 대륙도  당신이 어쩔수 없이 거쳐야',
    '될 운명의 길입니다. 운명을 피하려 하지 마십시오.  당신 앞에는',
    '언제나 당신을 지켜보며 도와주는 내가 있고 당신의 신이 있고 당',
    '신의 동료들이 있습니다. 당신이 이 세계에 들어 오는 그 날이 바',
    '로 그 모든 운명을 지게 되는 시작임을 잊지 말기를 빕니다.',
  ];

  // 게임 시스템 가이드
  static const List<Map<String, String>> systemGuide = [
    {
      'title': '필드 이동',
      'desc':
          '방향키 또는 D-Pad 터치로 이동합니다.\n'
          '맵 경계의 성문/동굴 입구를 통해 다른 맵으로 진입합니다.',
    },
    {
      'title': '필드 메뉴 (Space / P / V / C / R)',
      'desc':
          '[P] 일행 상황 보기  [V] 개인 상세 보기\n'
          '[Q] 간이 상태 보기  [C] 마법 시전  [E] 초감각(ESP)\n'
          '[R] 야외 캠프 휴식  [G] 게임 저장/불러오기\n'
          '[B] 몬스터 도감 열람',
    },
    {
      'title': '전투 시스템 (턴제)',
      'desc':
          '[1] 무기 공격 (단일 대상)\n'
          '[2] 단일 공격 마법  [3] 전체 공격 마법\n'
          '[4] 특수 디버프 마법  [5] 치유 / 해독 / 부활 마법\n'
          '[6] ESP 초능력 (독심술 / 염력)\n'
          '[7] 자동 전투 / 도망',
    },
    {
      'title': '마을 시설',
      'desc':
          '무기 상점: 무기, 방패, 갑옷 구입 및 장착.\n'
          '군사 훈련소: 경험치와 금화로 레벨업 (최대 Lv.20).\n'
          '신전/병원: 부상, 중독, 의식불명, 사망 치료.\n'
          '식료품점: 야외 휴식에 필요한 식량 보급.',
    },
    {
      'title': '직업 체계 (10종)',
      'desc':
          '기사(Knight): 무기 위력 1.5배, 방어도+1.\n'
          '마법사(Mage): 마법Lv=전투Lv, 초능력Lv=전투Lv/2.\n'
          '에스퍼(Esper): 초능력Lv=전투Lv, 마법Lv=전투Lv/2.\n'
          '전사(Warrior): 마법Lv=min(전투Lv,15).\n'
          '전투승(Monk): 무기 착용 불가, 맨손 위력=Lv*2+10.\n'
          '닌자(Ninja): 저항력 특화, 마법/초능력 Lv=전투Lv/2.\n'
          '사냥꾼/떠돌이: 체질, 완력, 민첩 성장.\n'
          '반신(Demigod): 올스탯 성장, 마법/초능력Lv=전투Lv.',
    },
    {
      'title': '마법 분류',
      'desc':
          '단일 공격 (#1~6): Fire Ball ~ Inferno.\n'
          '전체 공격 (#7~12): Storm ~ Lightning.\n'
          '디버프 (#13~18): Weaken ~ Petrify.\n'
          '단일 치유 (#19~25): Heal ~ Revitalize.\n'
          '전체 치유 (#26~32): Heal All ~ Revitalize All.\n'
          '현상계 (#33~40): Torch ~ Teleport.\n'
          'ESP (#41~45): Mindread ~ Psychokinesis.',
    },
    {
      'title': '위험 지형',
      'desc':
          '독 늪지대: 파티원 중독 위험 (SwampWalk 마법으로 방호).\n'
          '용암 지대: 고대미지 화염 피해 (Levitate 마법으로 회피).\n'
          '깊은 물: 진입 시 익사 대미지 (WaterWalk 마법으로 보행).',
    },
  ];

  @override
  State<LoreGuideDialog> createState() => _LoreGuideDialogState();
}

class _LoreGuideDialogState extends State<LoreGuideDialog> {
  int _page = 0; // 0: 원작자 서문, 1: 조작법/시스템 가이드

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: RetroTheme.black,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.lightCyan, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 560,
        height: 420,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _page == 0
                      ? '◆ 또 다른 지식의 성전 - 제작자 서문 ◆'
                      : '◆ 게임 시스템 가이드 (F1) ◆',
                  style: RetroTheme.headerFont.copyWith(
                    color: RetroTheme.lightCyan,
                    fontSize: 13,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: RetroTheme.lightRed,
                    size: 18,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: RetroTheme.borderColor, height: 12),

            // 본문
            Expanded(child: _page == 0 ? _buildPreface() : _buildGuide()),

            // 하단 페이지 전환
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pageBtn(0, '제작자 서문'),
                const SizedBox(width: 12),
                _pageBtn(1, '시스템 가이드'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageBtn(int page, String label) {
    final isActive = _page == page;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? RetroTheme.lightCyan : RetroTheme.darkGray,
        foregroundColor: isActive ? RetroTheme.black : RetroTheme.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      onPressed: () => setState(() => _page = page),
      child: Text(label, style: RetroTheme.dosFont.copyWith(fontSize: 11)),
    );
  }

  Widget _buildPreface() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀
          Center(
            child: Text(
              '또다른 지식의 성전  제 1 부',
              style: RetroTheme.headerFont.copyWith(
                fontSize: 16,
                color: RetroTheme.lightMagenta,
              ),
            ),
          ),
          Center(
            child: Text(
              'The Codex of Another Lore Volume #1',
              style: RetroTheme.dosFont.copyWith(
                fontSize: 11,
                color: RetroTheme.lightMagenta,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 서문 본문 (원작 Title_Str 배열)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: RetroTheme.blue),
              color: RetroTheme.panelBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: LoreGuideDialog.authorPreface.map((line) {
                if (line.isEmpty) return const SizedBox(height: 8);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Text(
                    line,
                    style: RetroTheme.dosFont.copyWith(
                      fontSize: 11,
                      color: RetroTheme.lightCyan,
                      height: 1.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // 하단 자막
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: RetroTheme.yellow),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: LoreGuideDialog.titleCaption.map((line) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    line,
                    style: RetroTheme.dosFont.copyWith(
                      fontSize: 10,
                      color: RetroTheme.yellow,
                      height: 1.4,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'made by Ahn Young-Kie (안영기) / Moon Dong-Wook (문동욱)  ·  1993',
              style: RetroTheme.dosFont.copyWith(
                fontSize: 10,
                color: RetroTheme.darkGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuide() {
    return ListView.builder(
      itemCount: LoreGuideDialog.systemGuide.length,
      itemBuilder: (ctx, idx) {
        final g = LoreGuideDialog.systemGuide[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: RetroTheme.borderColor),
            color: RetroTheme.panelBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '▸ ${g['title']}',
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 12,
                  color: RetroTheme.yellow,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                g['desc']!,
                style: RetroTheme.dosFont.copyWith(
                  fontSize: 10,
                  color: RetroTheme.lightGray,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
