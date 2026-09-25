import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import '../services/audio_manager.dart';

/// 1993년 원작 LOREEND.PAS 기반 엔딩 및 스태프 크레딧 시퀀스 위젯
class EndingView extends StatefulWidget {
  final String heroName;
  final VoidCallback onFinish;

  static const List<String> epilogueTexts = [
    '밖은 비바람이 치기 시작한다. 이번 계절에 들어 처음 오는 비였다.',
    '마치 Necromancer의 기구한 운명을 애도하는 듯이 ...',
    '하지만 그는 또다른 운명의 아이러니 때문에 새로운 길을 떠났다.',
    '그가 이런 역사를 몇 번이나 반복했는지 그 자신도 모른다.',
    '그가 최후로 정착할 곳마저 알 수가 없었다.',
    '아니, 그가 정착할 곳이 있는지조차도 알 수가 없었다.',
    '',
    '당신도 이제 할 일을 모두 끝냈다.',
    '이제 편안하게 쉴 기회를 가지게 된 것이다.',
    '이제는 다시 이런 일이 일어나지 않을 것이다.',
    '후세의 사람들은 말하겠지, 수천억 년에 한 번 날까 말까 한 일이라고.',
    '아마 이 일도 별로 오래 기억되지 않을 것 같다.',
    '몇 천 년만 지나면 전설로서, 아니 잊혀진 얘기로만 남을 테니까 ...',
  ];

  const EndingView({
    super.key,
    required this.heroName,
    required this.onFinish,
  });

  @override
  State<EndingView> createState() => _EndingViewState();
}

class _EndingViewState extends State<EndingView> {
  int _currentStep = 0; // 0: 에필로그 스토리 (EndMessage), 1: 보스/영웅 크레딧 (StaffMessage), 2: 최종 크레딧 (The End)
  bool _lightningFlash = false;
  Timer? _lightningTimer;

  @override
  void initState() {
    super.initState();
    AudioManager.instance.playBgm(BgmTrack.title);
    _startThunderEffect();
  }

  @override
  void dispose() {
    _lightningTimer?.cancel();
    super.dispose();
  }

  void _startThunderEffect() {
    _lightningTimer = Timer.periodic(const Duration(milliseconds: 2500), (t) {
      if (!mounted) return;
      setState(() => _lightningFlash = true);
      Future.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        setState(() => _lightningFlash = false);
      });
      Future.delayed(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        setState(() => _lightningFlash = true);
      });
      Future.delayed(const Duration(milliseconds: 240), () {
        if (!mounted) return;
        setState(() => _lightningFlash = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _lightningFlash ? RetroTheme.white.withValues(alpha: 0.3) : RetroTheme.black,
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          width: 620,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: RetroTheme.panelBg.withValues(alpha: 0.9),
            border: Border.all(color: RetroTheme.borderColor, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _buildStepContent(),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildEpilogueStep();
      case 1:
        return _buildStaffStep();
      case 2:
      default:
        return _buildFinalCreditStep();
    }
  }

  // ------------------------------------------
  // 1. 에필로그 스토리 (EndMessage - LOREEND.PAS:86)
  // ------------------------------------------
  Widget _buildEpilogueStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '◆ 에필로그 (EPILOGUE) ◆',
          style: RetroTheme.headerFont.copyWith(fontSize: 14, color: RetroTheme.yellow),
        ),
        const Divider(color: RetroTheme.borderColor, height: 16),
        ...EndingView.epilogueTexts.map((line) {
          if (line.isEmpty) return const SizedBox(height: 8);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Text(
              line,
              style: RetroTheme.dosFont.copyWith(fontSize: 11, color: RetroTheme.white, height: 1.4),
            ),
          );
        }),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RetroTheme.blue,
              foregroundColor: RetroTheme.white,
            ),
            onPressed: () => setState(() => _currentStep = 1),
            child: Text('다음으로 [SPACE]', style: RetroTheme.dosFont),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------
  // 2. 보스/영웅 크레딧 (StaffMessage - LOREEND.PAS:127)
  // ------------------------------------------
  Widget _buildStaffStep() {
    final staffItems = [
      {'title': '영웅', 'name': widget.heroName, 'desc': '바로 당신이다. 이 세계의 구원자.'},
      {'title': 'NOTICE 보스', 'name': 'Hydra', 'desc': 'NOTICE 동굴을 지배하던 삼두룡.'},
      {'title': 'LOCKUP 보스', 'name': 'Huge Dragon', 'desc': 'LOCKUP 동굴의 거대한 화염룡.'},
      {'title': '미로의 괴수', 'name': 'Minotaur', 'desc': '던전 속에서 두 번 등장한 미노타우로스.'},
      {'title': '기계 생물', 'name': 'Panzer Viper', 'desc': 'DUNGEON OF EVIL을 지키던 사이버 바이퍼.'},
      {'title': '제 2 인자', 'name': 'Black Knight', 'desc': 'Necromancer 군단의 제 2 인자 암흑 기사.'},
      {'title': '왼팔', 'name': 'ArchiMonk', 'desc': 'Necromancer의 왼팔 역할을 맡았던 실력자.'},
      {'title': '오른팔', 'name': 'ArchiMage', 'desc': 'Necromancer의 오른팔 대마법사.'},
      {'title': '최종 보스', 'name': 'Neo-Necromancer', 'desc': '바로 당신의 궁극적인 목표였던 사악한 지배자.'},
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '◆ 이 게임의 끝마무리에 공헌한 인물들 (STAFF) ◆',
          style: RetroTheme.headerFont.copyWith(fontSize: 13, color: RetroTheme.lightCyan),
        ),
        const Divider(color: RetroTheme.borderColor, height: 14),
        SizedBox(
          height: 250,
          child: ListView.builder(
            itemCount: staffItems.length,
            itemBuilder: (ctx, idx) {
              final it = staffItems[idx];
              final isHero = idx == 0;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: isHero ? RetroTheme.blue.withValues(alpha: 0.5) : RetroTheme.background,
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        it['title']!,
                        style: RetroTheme.dosFont.copyWith(
                          color: isHero ? RetroTheme.yellow : RetroTheme.lightGray,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        it['name']!,
                        style: RetroTheme.dosFont.copyWith(
                          color: isHero ? RetroTheme.yellow : RetroTheme.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        it['desc']!,
                        style: RetroTheme.dosFont.copyWith(
                          color: RetroTheme.lightCyan,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RetroTheme.blue,
              foregroundColor: RetroTheme.white,
            ),
            onPressed: () => setState(() => _currentStep = 2),
            child: Text('최종 크레딧 보기 [SPACE]', style: RetroTheme.dosFont),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------
  // 3. 최종 크레딧 (The End - LOREEND.PAS:236)
  // ------------------------------------------
  Widget _buildFinalCreditStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Text(
          '<< The End >>',
          style: RetroTheme.headerFont.copyWith(
            fontSize: 22,
            color: RetroTheme.yellow,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '" The Codex of Another Lore vol. #1 "',
          style: RetroTheme.dosFont.copyWith(
            fontSize: 14,
            color: RetroTheme.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Original Created in 1993 by Moon Dong-Wook (문동욱)',
          style: RetroTheme.dosFont.copyWith(
            fontSize: 12,
            color: RetroTheme.lightCyan,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Engineered for Flutter/Flame in 2026',
          style: RetroTheme.dosFont.copyWith(
            fontSize: 11,
            color: RetroTheme.lightGray,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: RetroTheme.background,
            border: Border.all(color: RetroTheme.yellow),
          ),
          child: Text(
            '★ You must be a genius !!! ★',
            style: RetroTheme.headerFont.copyWith(
              fontSize: 14,
              color: RetroTheme.yellow,
            ),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: RetroTheme.green,
            foregroundColor: RetroTheme.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          onPressed: widget.onFinish,
          child: Text(
            '타이틀 화면으로 돌아가기 [ESC]',
            style: RetroTheme.dosFont.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
