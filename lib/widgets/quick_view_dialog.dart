import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import '../models/party_member.dart';

/// 1993년 원작 LOREMENU.PAS: QuickView 기반 콤팩트 상태창 다이얼로그
class QuickViewDialog extends StatelessWidget {
  final List<PartyMember> party;

  const QuickViewDialog({super.key, required this.party});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: RetroTheme.black,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.lightMagenta, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(12),
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
                    '◆ 간이 일행 상황 (QUICK VIEW) ◆',
                    overflow: TextOverflow.ellipsis,
                    style: RetroTheme.headerFont.copyWith(
                      color: RetroTheme.lightMagenta,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '[ESC / Q / 닫기]',
                  style: RetroTheme.dosFont.copyWith(
                    color: RetroTheme.lightGray,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 테이블 헤더 (이름, HP/SP/ESP, 중독, 의식불명, 죽음)
            Container(
              color: RetroTheme.darkBlue,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '이름 (직업)',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'HP',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.lightGreen,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'SP',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.lightCyan,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'ESP',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.yellow,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '중독',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.lightRed,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '의식불명',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.lightRed,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '사망',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.lightRed,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // 파티원 목록
            ...party.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final p = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: RetroTheme.background,
                  border: Border.all(color: RetroTheme.darkGray, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        '$idx. ${p.name}',
                        style: RetroTheme.dosFont.copyWith(
                          color: p.isDead
                              ? RetroTheme.darkGray
                              : (p.isUnconscious
                                    ? RetroTheme.lightRed
                                    : RetroTheme.yellow),
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${p.hp}/${p.maxHp}',
                        style: RetroTheme.dosFont.copyWith(
                          color: p.hp <= p.maxHp ~/ 4
                              ? RetroTheme.lightRed
                              : RetroTheme.lightGreen,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${p.sp}/${p.maxSp}',
                        style: RetroTheme.dosFont.copyWith(
                          color: RetroTheme.lightCyan,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${p.esp}/${p.maxEsp}',
                        style: RetroTheme.dosFont.copyWith(
                          color: RetroTheme.yellow,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.poison > 0 ? '${p.poison} (중독)' : '-',
                        style: RetroTheme.dosFont.copyWith(
                          color: p.poison > 0
                              ? RetroTheme.lightRed
                              : RetroTheme.lightGray,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.unconscious > 0 ? '${p.unconscious} (기절)' : '-',
                        style: RetroTheme.dosFont.copyWith(
                          color: p.unconscious > 0
                              ? RetroTheme.lightRed
                              : RetroTheme.lightGray,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.dead > 0 ? '${p.dead} (사망)' : '-',
                        style: RetroTheme.dosFont.copyWith(
                          color: p.dead > 0
                              ? RetroTheme.lightRed
                              : RetroTheme.lightGray,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RetroTheme.darkGray,
                  foregroundColor: RetroTheme.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '확인 (ESC)',
                  style: RetroTheme.dosFont.copyWith(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
