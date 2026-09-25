import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import '../models/monster.dart';

/// 1993년 원작 LOOKFOE.PAS 기반 75종 전체 몬스터 도감 모달
class MonsterBestiaryDialog extends StatefulWidget {
  const MonsterBestiaryDialog({super.key});

  @override
  State<MonsterBestiaryDialog> createState() => _MonsterBestiaryDialogState();
}

class _MonsterBestiaryDialogState extends State<MonsterBestiaryDialog> {
  int _selectedIndex = 0;
  String _searchQuery = '';

  List<Monster> get _allMonsters => Monster.monsterTemplates;

  List<Monster> get _filteredMonsters {
    if (_searchQuery.trim().isEmpty) return _allMonsters;
    return _allMonsters.where((m) {
      final q = _searchQuery.toLowerCase();
      return m.name.toLowerCase().contains(q) ||
          m.eNumber.toString().contains(q) ||
          'lv.${m.level}'.contains(q);
    }).toList();
  }

  Monster get _currentMonster {
    final list = _filteredMonsters;
    if (_selectedIndex >= list.length) {
      _selectedIndex = 0;
    }
    return list.isNotEmpty ? list[_selectedIndex] : _allMonsters.first;
  }

  String _getSpecialDesc(int special) {
    switch (special) {
      case 1:
        return '독 브레스 (Poison Breath)';
      case 2:
        return '치명타 기절 (Critical Stun)';
      case 3:
        return '죽음의 일격 (Instant Death)';
      default:
        return '없음 (None)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _currentMonster;

    return Dialog(
      backgroundColor: RetroTheme.panelBg,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.borderColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 580,
        height: 380,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 상단 타이틀 및 검색창
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '◆ 1993 LORE 원작 75종 몬스터 대도감 (FOE.LST) ◆',
                  style: RetroTheme.headerFont.copyWith(fontSize: 13),
                ),
                SizedBox(
                  width: 140,
                  height: 28,
                  child: TextField(
                    style: RetroTheme.dosFont.copyWith(fontSize: 10),
                    decoration: InputDecoration(
                      hintText: '검색(이름/번호)...',
                      hintStyle: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.darkGray,
                        fontSize: 9,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      fillColor: RetroTheme.background,
                      filled: true,
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: RetroTheme.borderColor),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _selectedIndex = 0;
                      });
                    },
                  ),
                ),
              ],
            ),
            const Divider(color: RetroTheme.borderColor, height: 14),

            // 메인 2분할 뷰 (왼쪽: 리스트, 오른쪽: 스탯 카드)
            Expanded(
              child: Row(
                children: [
                  // 1. 왼쪽: 몬스터 목록 리스트뷰
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: RetroTheme.viewportBg,
                      child: ListView.builder(
                        itemCount: _filteredMonsters.length,
                        itemBuilder: (ctx, idx) {
                          final m = _filteredMonsters[idx];
                          final isCur = idx == _selectedIndex;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedIndex = idx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              color: isCur
                                  ? RetroTheme.blue.withValues(alpha: 0.6)
                                  : Colors.transparent,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '#${m.eNumber.toString().padLeft(2, '0')} ${m.name}',
                                    style: RetroTheme.dosFont.copyWith(
                                      color: isCur ? RetroTheme.yellow : RetroTheme.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'Lv.${m.level}',
                                    style: RetroTheme.dosFont.copyWith(
                                      color: isCur ? RetroTheme.lightCyan : RetroTheme.lightGray,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. 오른쪽: 선택된 몬스터 상세 스탯 카드 (LOOKFOE.PAS 형식)
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: RetroTheme.black,
                        border: Border.all(color: RetroTheme.borderColor, width: 1),
                      ),
                      child: ListView(
                        children: [
                          // 몬스터 헤더
                          Row(
                            children: [
                              const Icon(Icons.pest_control_outlined, color: RetroTheme.yellow, size: 28),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '#${selected.eNumber} ${selected.name}',
                                    style: RetroTheme.headerFont.copyWith(fontSize: 14),
                                  ),
                                  Text(
                                    '등급: Level ${selected.level} | 최대 HP: ${selected.maxHp}',
                                    style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightGreen, fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(color: RetroTheme.lightGray, height: 14),

                          // 스탯 테이블 (LOOKFOE.PAS와 100% 동일 규격)
                          _buildStatRow('힘 (Strength)', '${selected.strength}', '정신력 (Mentality)', '${selected.mentality}'),
                          _buildStatRow('체질 (Endurance)', '${selected.endurance}', '마법 저항력 (Resistance)', '${selected.resistance}%'),
                          _buildStatRow('민첩성 (Agility)', '${selected.agility}', '방어 등급 (Armor Class)', '${selected.ac}'),
                          _buildStatRow('물리 명중 (Acc Arms)', '${selected.accArms}/20', '마법 명중 (Acc Magic)', '${selected.accMagic}/20'),
                          _buildStatRow('마법 레벨 (Cast Lv)', '${selected.castLevel}', '초자연 레벨 (Special Cast)', '${selected.specialCastLevel}'),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(6),
                            color: RetroTheme.background,
                            child: Row(
                              children: [
                                Text('특수 공격: ', style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan, fontSize: 10)),
                                Expanded(
                                  child: Text(
                                    _getSpecialDesc(selected.special),
                                    style: RetroTheme.dosFont.copyWith(
                                      color: selected.special > 0 ? RetroTheme.lightRed : RetroTheme.lightGray,
                                      fontSize: 10,
                                      fontWeight: selected.special > 0 ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 하단 닫기 버튼
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 ${_allMonsters.length}종 수록 (1993 문동욱 원작 발굴 복원)',
                  style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightGray, fontSize: 10),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RetroTheme.background,
                    foregroundColor: RetroTheme.yellow,
                    side: const BorderSide(color: RetroTheme.borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('닫기 [ESC]', style: RetroTheme.dosFont.copyWith(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label1, String val1, String label2, String val2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text('$label1: $val1', style: RetroTheme.dosFont.copyWith(fontSize: 10, color: RetroTheme.white)),
          ),
          Expanded(
            flex: 5,
            child: Text('$label2: $val2', style: RetroTheme.dosFont.copyWith(fontSize: 10, color: RetroTheme.lightCyan)),
          ),
        ],
      ),
    );
  }
}
