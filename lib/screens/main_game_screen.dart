import 'package:flutter/material.dart';
import '../theme/retro_theme.dart';
import '../widgets/viewport_view.dart';
import '../widgets/party_status_view.dart';
import '../widgets/message_log_view.dart';

/// 4:3 레트로 콘솔 레이아웃 메인 게임 화면
class MainGameScreen extends StatefulWidget {
  final Widget? customViewport;
  final List<PartyMemberStatus>? partyMembers;
  final List<String>? initialLogs;

  const MainGameScreen({
    super.key,
    this.customViewport,
    this.partyMembers,
    this.initialLogs,
  });

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  late List<PartyMemberStatus> _members;
  late List<String> _logs;

  @override
  void initState() {
    super.initState();
    _members = widget.partyMembers ??
        const [
          PartyMemberStatus(
            name: 'Hercules',
            hp: 17,
            maxHp: 17,
            sp: 5,
            maxSp: 5,
            level: 1,
            condition: 'good',
          ),
          PartyMemberStatus(
            name: 'Merlin',
            hp: 11,
            maxHp: 11,
            sp: 19,
            maxSp: 19,
            level: 1,
            condition: 'good',
          ),
          PartyMemberStatus(
            name: 'Genius Kie',
            hp: 14,
            maxHp: 14,
            sp: 11,
            maxSp: 11,
            level: 1,
            condition: 'good',
          ),
          PartyMemberStatus(
            name: 'Bellatrix',
            hp: 14,
            maxHp: 14,
            sp: 11,
            maxSp: 11,
            level: 1,
            condition: 'good',
          ),
          PartyMemberStatus(
            name: 'Regulus',
            hp: 19,
            maxHp: 19,
            sp: 5,
            maxSp: 5,
            level: 1,
            condition: 'good',
          ),
        ];

    _logs = widget.initialLogs ??
        [
          '또 다른 지식의 성전 제 1 부 (1993 - 2026 Flutter Port)',
          '시스템 초기화가 완료되었습니다. 비디오 모드: VGA 4:3',
          '용사 5명이 성전의 비밀을 밝히기 위해 모험을 떠납니다.',
          '모바일 및 데스크톱 크로스플랫폼 지원 준비 완료.',
        ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.black,
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 4 / 3, // 4:3 고정 종횡비 레트로 콘솔 스타일
            child: Container(
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: RetroTheme.background,
                border: Border.all(color: RetroTheme.darkGray, width: 3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  // 상단 영역 (메인 뷰포트 + 파티 상태창)
                  Expanded(
                    flex: 68,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 왼쪽 상단: 메인 뷰포트 (약 62% 가로폭)
                        Expanded(
                          flex: 62,
                          child: ViewportView(
                            content: widget.customViewport,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 오른쪽 상단: 파티원 상태창 (약 38% 가로폭)
                        Expanded(
                          flex: 38,
                          child: PartyStatusView(
                            members: _members,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 하단 영역: 3~4줄 분량 메시지 로그 스크롤 영역 (약 32% 세로폭)
                  Expanded(
                    flex: 32,
                    child: MessageLogView(
                      logs: _logs,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
