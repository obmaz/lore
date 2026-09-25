import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import '../models/party_member.dart';
import '../models/item.dart';
import '../game/lore_dialogue_manager.dart';

/// 1993년 원작 LORECITY 및 LORETALK 기반 4대 성/마을 상점 및 NPC 상호작용 모달 다이얼로그
class TownDialog extends StatefulWidget {
  final List<PartyMember> party;
  final int gold;
  final int
  mapId; // 6: CASTLE LORE, 7: LASTDITCH, 9: GAIA TERRA, 10: WATER FIELD
  final void Function(int newGold) onGoldChanged;
  final void Function(String message) onLog;

  const TownDialog({
    super.key,
    required this.party,
    required this.gold,
    this.mapId = 6,
    required this.onGoldChanged,
    required this.onLog,
  });

  @override
  State<TownDialog> createState() => _TownDialogState();
}

class _TownDialogState extends State<TownDialog> {
  int _currentTab = 0; // 0: 마을 메인, 1: 무기 상점, 2: 신전/병원, 3: NPC 대화
  late int _gold;

  String get townName {
    switch (widget.mapId) {
      case 6:
        return '성전의 도읍 : CASTLE LORE';
      case 7:
        return '결사항전의 요새 : LASTDITCH';
      case 9:
        return '영광의 성채 : GAIA TERRA (VALIANT PEOPLES)';
      case 10:
        return '수몰 대륙의 마지막 왕국 : WATER FIELD';
      default:
        return '미지의 성채';
    }
  }

  @override
  void initState() {
    super.initState();
    _gold = widget.gold;
  }

  void _buyWeapon(Item weapon, PartyMember member) {
    if (_gold < weapon.price) {
      widget.onLog('골드가 부족합니다! (필요: ${weapon.price}G, 보유: ${_gold}G)');
      return;
    }
    if (member.playerClass == PlayerClass.monk) {
      widget.onLog('전투승(Monk)은 무기를 착용할 수 없습니다!');
      return;
    }

    setState(() {
      _gold -= weapon.price;
      widget.onGoldChanged(_gold);
      member.equipWeapon(weapon);
    });
    widget.onLog(
      '${member.name}이(가) ${weapon.name}을(를) 구매하여 장착했습니다. (위력: ${member.weaPower})',
    );
  }

  void _healAllParty() {
    final cost = widget.mapId == 10 ? 100 : (widget.mapId == 9 ? 80 : 50);
    if (_gold < cost) {
      widget.onLog('치료비($cost G)가 부족합니다.');
      return;
    }

    setState(() {
      _gold -= cost;
      widget.onGoldChanged(_gold);
      for (final member in widget.party) {
        member.hp = member.maxHp;
        member.sp = member.maxSp;
        member.poison = 0;
        member.unconscious = 0;
      }
    });
    widget.onLog('성소의 축복으로 모든 파티원의 체력, 마력 및 상태이상이 완전히 회복되었습니다!');
  }

  List<Item> _getTownWeapons() {
    // 마을 티어에 맞는 무기 목록
    if (widget.mapId == 7) {
      return Item.weapons.skip(3).take(5).toList();
    } else if (widget.mapId == 9) {
      return Item.weapons.skip(5).take(5).toList();
    } else if (widget.mapId == 10) {
      return Item.weapons.skip(7).take(5).toList();
    }
    return Item.weapons.skip(1).take(5).toList();
  }

  List<Map<String, String>> _getTownNpcTalks() {
    final dialogue = LoreDialogueManager.instance;
    switch (widget.mapId) {
      case 7:
        return [
          {
            'name': 'LASTDITCH 성주',
            'talk': dialogue.lastditchQuestStep >= 2
                ? 'Major Mummy를 처치하셨군요! 북동쪽 GROUND GATE를 통해 다음 대륙으로 나아가시오!'
                : '북쪽 동굴 PYRAMID의 보스 Major Mummy를 처단해 주시오!',
          },
          {'name': '전사 Polaris', 'talk': '나의 이름은 Polaris요. 당신들과 같이 전장에 서고 싶소!'},
          {
            'name': '노병',
            'talk': 'Major Mummy와 두 마리의 Sphinx의 공격은 가히 치명적이오. 단단히 대비하시오.',
          },
          {
            'name': '탐험가',
            'talk': 'GROUND GATE는 여기로부터 서쪽에 나타나며, 다른 대륙으로 인도해 줍니다.',
          },
        ];
      case 9:
        return [
          {
            'name': 'GAIA TERRA 성주',
            'talk': dialogue.gaiaQuestStep >= 3
                ? 'ArchiGagoyle을 물리치셨군요! Water Key로 WIVERN 동굴을 열어 다음 대륙으로 가시오!'
                : (dialogue.gaiaQuestStep >= 1
                      ? '지하의 EVIL SEAL로 가서 황금의 봉인을 찾으시오!'
                      : 'VALIANT PEOPLES 성을 파괴한 적들의 음모를 저지해 주시오!'),
          },
          {
            'name': '사냥꾼',
            'talk': '최대의 사냥꾼 Rigel은 성을 파괴시킨 적들을 물리치기 위해 EVIL SEAL로 들어갔습니다.',
          },
          {
            'name': '경비병',
            'talk': 'SWAMP 대륙으로 통하는 문에는 불멸에 가까운 고르곤 세자매가 살고 있습니다.',
          },
          {'name': '학자', 'talk': '황금의 갑옷이 QUAKE 동굴 안에 숨겨져 있다는 소문이 있습니다.'},
        ];
      case 10:
        return [
          {
            'name': 'WATER FIELD 성주',
            'talk': dialogue.waterFieldQuestStep >= 3
                ? 'Huge Dragon을 처단하고 Swamp Key를 얻으셨군요! 늪의 대륙으로 진격하시오!'
                : 'NOTICE 동굴의 Hidra와 LOCKUP 동굴의 거룡 Huge Dragon을 처단해 주시오!',
          },
          {
            'name': '특공대장 Lore Hunter',
            'talk': '나는 LORE 특공대장 Lore Hunter요! 새로운 영웅들과 함께 Necromancer의 목을 베러 가겠소!',
          },
          {
            'name': '탐험가',
            'talk': 'NOTICE 동굴은 혼란스러운 미로이며 삼두룡 Hidra가 도사리고 있습니다.',
          },
          {
            'name': '노인',
            'talk': 'LOCKUP의 Huge Dragon은 거대한 불꽃과 꼬리로 침입자를 짓밟습니다.',
          },
        ];
      default: // 6: CASTLE LORE
        return [
          {
            'name': '성주 Lord Ahn',
            'talk': dialogue.castleGateOpen
                ? '남쪽 성문을 개방했으니 광활한 LORE 대륙으로 나아가 Necromancer를 응징해주게!'
                : '용사들이여, 그대들의 결의를 보았다. 대륙의 평화를 위해 싸워주게!',
          },
          {
            'name': 'Jr. Antares의 영혼',
            'talk': '나의 아버지는 최강의 마법사 Red Antares였소! 동굴로 은신한 아버지를 찾아 동료로 삼으시오!',
          },
          {
            'name': '현자',
            'talk':
                'Necromancer에 대항하고자 한다면 바로 위의 피라밋에 가보시오. 또 다른 지식의 성전이기 때문이오.',
          },
          {
            'name': '경비병',
            'talk': '모험 중 마주칠 Serpent와 Insects와 Python은 치명적인 맹독을 품고 있으니 주의하시오.',
          },
          {
            'name': '성전 기록관',
            'talk': '이 세계의 창시자는 문동욱 님이시며, 그는 위대한 1993년의 프로그래머입니다.',
          },
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: RetroTheme.panelBg,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.borderColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 500,
        height: 330,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 상단 타이틀
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '◆ $townName ◆',
                  style: RetroTheme.headerFont.copyWith(fontSize: 13),
                ),
                Text(
                  '금화: $_gold G',
                  style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow),
                ),
              ],
            ),
            const Divider(color: RetroTheme.borderColor, height: 16),

            // 메인 컨텐츠 영역
            Expanded(child: _buildCurrentTabContent()),

            // 하단 탭 버튼
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabButton(0, '마을 광장'),
                _buildTabButton(1, '무기 상점'),
                _buildTabButton(2, '성소/치료소'),
                _buildTabButton(3, '주민 대화'),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '나가기 [ESC]',
                    style: RetroTheme.dosFont.copyWith(
                      color: RetroTheme.lightRed,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_currentTab) {
      case 1: // 무기 상점
        final weapons = _getTownWeapons();
        return ListView(
          children: [
            Text(
              '무기를 선택하고 장착할 파티원을 지정하십시오.',
              style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightGray),
            ),
            const SizedBox(height: 6),
            ...weapons.map((w) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: RetroTheme.background,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        '${w.name} (위력:${w.power})',
                        style: RetroTheme.dosFont,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${w.price} G',
                        style: RetroTheme.dosFont.copyWith(
                          color: RetroTheme.yellow,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: DropdownButton<PartyMember>(
                        isExpanded: true,
                        hint: Text(
                          '장착자',
                          style: RetroTheme.dosFont.copyWith(fontSize: 11),
                        ),
                        dropdownColor: RetroTheme.panelBg,
                        items: widget.party.map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text(
                              m.name,
                              style: RetroTheme.dosFont.copyWith(fontSize: 11),
                            ),
                          );
                        }).toList(),
                        onChanged: (member) {
                          if (member != null) _buyWeapon(w, member);
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );

      case 2: // 신전/병원
        final cost = widget.mapId == 10 ? 100 : (widget.mapId == 9 ? 80 : 50);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.church_outlined,
                size: 48,
                color: RetroTheme.lightCyan,
              ),
              const SizedBox(height: 10),
              Text(
                '치유의 신전 (HOSPITAL)',
                style: RetroTheme.headerFont.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                '일행 전원의 부상과 중독을 치유합니다. (비용: $cost G)',
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.lightGray,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RetroTheme.green,
                ),
                onPressed: _healAllParty,
                child: Text('전체 파티원 치료받기', style: RetroTheme.dosFont),
              ),
            ],
          ),
        );

      case 3: // NPC 대화
        final npcTalks = _getTownNpcTalks();
        return ListView(
          children: npcTalks.map((n) {
            return _buildNpcTalk(n['name']!, n['talk']!);
          }).toList(),
        );

      default: // 0: 마을 메인 허브
        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMenuCard(Icons.shield_outlined, '무기 상점', '새로운 장비 구입', () {
                setState(() => _currentTab = 1);
              }),
              _buildMenuCard(
                Icons.health_and_safety_outlined,
                '성소/치료소',
                '파티원 전체 회복',
                () {
                  setState(() => _currentTab = 2);
                },
              ),
              _buildMenuCard(
                Icons.record_voice_over_outlined,
                '주민 대화',
                '소문과 정보 수집',
                () {
                  setState(() => _currentTab = 3);
                },
              ),
            ],
          ),
        );
    }
  }

  Widget _buildMenuCard(
    IconData icon,
    String title,
    String desc,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 130,
        height: 140,
        decoration: BoxDecoration(
          color: RetroTheme.background,
          border: Border.all(color: RetroTheme.borderColor, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: RetroTheme.yellow),
            const SizedBox(height: 10),
            Text(title, style: RetroTheme.headerFont.copyWith(fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: RetroTheme.dosFont.copyWith(
                fontSize: 10,
                color: RetroTheme.lightGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNpcTalk(String name, String dialogue) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: RetroTheme.background,
        border: Border.all(color: RetroTheme.darkGray, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[$name]',
            style: RetroTheme.headerFont.copyWith(
              fontSize: 12,
              color: RetroTheme.lightCyan,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dialogue,
            style: RetroTheme.dosFont.copyWith(
              fontSize: 11,
              color: RetroTheme.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _currentTab == index;
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: isSelected ? RetroTheme.yellow : RetroTheme.lightGray,
      ),
      onPressed: () => setState(() => _currentTab = index),
      child: Text(
        label,
        style: RetroTheme.dosFont.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
