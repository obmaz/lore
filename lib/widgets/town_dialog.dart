import 'package:flutter/material.dart';
import '../theme/retro_theme.dart';
import '../models/party_member.dart';
import '../models/item.dart';

/// 마을 (CASTLE LORE) 상점 및 NPC 상호작용 모달 다이얼로그
class TownDialog extends StatefulWidget {
  final List<PartyMember> party;
  final int gold;
  final void Function(int newGold) onGoldChanged;
  final void Function(String message) onLog;

  const TownDialog({
    super.key,
    required this.party,
    required this.gold,
    required this.onGoldChanged,
    required this.onLog,
  });

  @override
  State<TownDialog> createState() => _TownDialogState();
}

class _TownDialogState extends State<TownDialog> {
  int _currentTab = 0; // 0: 마을 메인, 1: 무기 상점, 2: 신전/병원, 3: NPC 대화
  late int _gold;

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
    widget.onLog('${member.name}이(가) ${weapon.name}을(를) 구매하여 장착했습니다. (위력: ${member.weaPower})');
  }

  void _healAllParty() {
    const cost = 50;
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: RetroTheme.panelBg,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.borderColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 480,
        height: 320,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 상단 타이틀
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '◆ 성전 마을 : CASTLE LORE ◆',
                  style: RetroTheme.headerFont.copyWith(fontSize: 14),
                ),
                Text(
                  '금화: $_gold G',
                  style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow, fontSize: 13),
                ),
              ],
            ),
            const Divider(color: RetroTheme.borderColor, thickness: 1.5),

            // 내용 영역
            Expanded(child: _buildContent()),

            // 하단 닫기/뒤로가기 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_currentTab != 0)
                  TextButton(
                    onPressed: () => setState(() => _currentTab = 0),
                    child: Text('◀ 메인으로', style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan)),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RetroTheme.blue,
                    foregroundColor: RetroTheme.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('성 밖으로 나가기', style: RetroTheme.dosFont),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentTab) {
      case 1: // 무기 상점
        return ListView(
          children: [
            Text('구매할 무기와 장착할 파티원을 선택하십시오:', style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightGray)),
            const SizedBox(height: 6),
            ...Item.weapons.skip(1).take(5).map((w) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: RetroTheme.background,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text('${w.name} (위력:${w.power})', style: RetroTheme.dosFont),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('${w.price} G', style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow)),
                    ),
                    Expanded(
                      flex: 3,
                      child: DropdownButton<PartyMember>(
                        isExpanded: true,
                        hint: Text('장착자', style: RetroTheme.dosFont.copyWith(fontSize: 11)),
                        dropdownColor: RetroTheme.panelBg,
                        items: widget.party.map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text(m.name, style: RetroTheme.dosFont.copyWith(fontSize: 11)),
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
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.church_outlined, size: 48, color: RetroTheme.lightCyan),
              const SizedBox(height: 10),
              Text(
                '치유의 신전 (HOSPITAL)',
                style: RetroTheme.headerFont.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                '일행 전원의 부상과 중독을 치유합니다. (비용: 50 G)',
                style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightGray, fontSize: 12),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: RetroTheme.green),
                onPressed: _healAllParty,
                child: Text('전체 파티원 치료받기', style: RetroTheme.dosFont),
              ),
            ],
          ),
        );

      case 3: // NPC 대화
        return ListView(
          children: [
            _buildNpcTalk('수호 기사', 'Orc는 가장 하급 괴물이오. 하지만 Serpent와 Insects는 맹독을 품고 있으니 조심하시오.'),
            _buildNpcTalk('학자 Draconian', '시그너스 X1과 같은 블랙홀의 물리학적 파라독스에 의해 Necromancer가 생겨난 것이오.'),
            _buildNpcTalk('성전의 기록관', '이 세계의 창시자는 안영기 님이시며, 그는 위대한 1993년의 프로그래머입니다.'),
          ],
        );

      default: // 마을 메인 메뉴
        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMenuCard(Icons.shield_outlined, '무기 상점', '새로운 장비 구입', () {
                setState(() => _currentTab = 1);
              }),
              _buildMenuCard(Icons.health_and_safety_outlined, '성소/치료소', '파티원 전체 회복', () {
                setState(() => _currentTab = 2);
              }),
              _buildMenuCard(Icons.record_voice_over_outlined, '주민 대화', '소문과 정보 수집', () {
                setState(() => _currentTab = 3);
              }),
            ],
          ),
        );
    }
  }

  Widget _buildMenuCard(IconData icon, String title, String desc, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 130,
        height: 150,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: RetroTheme.background,
          border: Border.all(color: RetroTheme.borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: RetroTheme.lightBlue),
            const SizedBox(height: 10),
            Text(title, style: RetroTheme.headerFont.copyWith(fontSize: 13)),
            const SizedBox(height: 4),
            Text(desc, textAlign: TextAlign.center, style: RetroTheme.dosFont.copyWith(fontSize: 10, color: RetroTheme.lightGray)),
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
        border: Border.all(color: RetroTheme.darkGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('[NPC $name]', style: RetroTheme.headerFont.copyWith(fontSize: 12, color: RetroTheme.lightCyan)),
          const SizedBox(height: 4),
          Text(dialogue, style: RetroTheme.dosFont.copyWith(fontSize: 12, color: RetroTheme.white)),
        ],
      ),
    );
  }
}
