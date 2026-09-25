import 'package:flutter/material.dart';
import '../theme/retro_theme.dart';
import '../models/party_member.dart';

enum TownFacilityType {
  weaponShop,
  hospital,
  trainCenter,
  grocery,
}

/// 1993년 원작 LORESUB.PAS 기반 마을 시설 다이얼로그
class TownFacilitiesDialog extends StatefulWidget {
  final TownFacilityType facilityType;
  final List<PartyMember> party;
  final int gold;
  final int food;
  final void Function(int newGold) onGoldChanged;
  final void Function(int newFood)? onFoodChanged;
  final void Function(String message) onLog;

  const TownFacilitiesDialog({
    super.key,
    required this.facilityType,
    required this.party,
    required this.gold,
    this.food = 100,
    required this.onGoldChanged,
    this.onFoodChanged,
    required this.onLog,
  });

  @override
  State<TownFacilitiesDialog> createState() => _TownFacilitiesDialogState();
}

class _TownFacilitiesDialogState extends State<TownFacilitiesDialog> {
  late int _currentGold;
  late int _currentFood;
  int _weaponShopCategory = 0; // 0: 메인(무기/방패/갑옷), 1: 무기류, 2: 방패류, 3: 갑옷류

  @override
  void initState() {
    super.initState();
    _currentGold = widget.gold;
    _currentFood = widget.food;
  }

  void _spendGold(int amount, String successMessage) {
    setState(() {
      _currentGold -= amount;
    });
    widget.onGoldChanged(_currentGold);
    widget.onLog(successMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: RetroTheme.black,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: RetroTheme.cyan, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 10),
            _buildBody(),
            const SizedBox(height: 12),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = '';
    switch (widget.facilityType) {
      case TownFacilityType.weaponShop:
        title = '⚔ 로어 왕국 무기 & 방어구 상점 ⚔';
        break;
      case TownFacilityType.hospital:
        title = '✚ 로어 왕립 구호 병원 ✚';
        break;
      case TownFacilityType.trainCenter:
        title = '★ 왕립 군사 훈련소 ★';
        break;
      case TownFacilityType.grocery:
        title = '🍞 식료품점 🍞';
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: RetroTheme.headerFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 13,
          ),
        ),
        Text(
          '금화: $_currentGold 개',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (widget.facilityType) {
      case TownFacilityType.weaponShop:
        return _buildWeaponShop();
      case TownFacilityType.hospital:
        return _buildHospital();
      case TownFacilityType.trainCenter:
        return _buildTrainCenter();
      case TownFacilityType.grocery:
        return _buildGrocery();
    }
  }

  Widget _buildFooter() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: RetroTheme.darkGray,
          foregroundColor: RetroTheme.white,
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: Text('나가기 (ESC)', style: RetroTheme.dosFont.copyWith(fontSize: 12)),
      ),
    );
  }

  // =========================================================================
  // 1. 무기 & 방어구 상점 (Weapon_Shop)
  // =========================================================================
  static const List<Map<String, dynamic>> weaponsList = [
    {'id': 1, 'name': '단도', 'price': 500, 'power': 5},
    {'id': 2, 'name': '곤봉', 'price': 1500, 'power': 7},
    {'id': 3, 'name': '미늘창', 'price': 3000, 'power': 9},
    {'id': 4, 'name': '장검', 'price': 5000, 'power': 10},
    {'id': 5, 'name': '철퇴', 'price': 10000, 'power': 15},
    {'id': 6, 'name': '기병창', 'price': 30000, 'power': 20},
    {'id': 7, 'name': '도끼창', 'price': 60000, 'power': 30},
    {'id': 8, 'name': '삼지창', 'price': 80000, 'power': 40},
    {'id': 9, 'name': '화염검', 'price': 100000, 'power': 50},
  ];

  static const List<Map<String, dynamic>> shieldsList = [
    {'id': 1, 'name': '가죽 방패', 'price': 1000, 'power': 1},
    {'id': 2, 'name': '청동 방패', 'price': 5000, 'power': 2},
    {'id': 3, 'name': '강철 방패', 'price': 25000, 'power': 3},
    {'id': 4, 'name': '기사 방패', 'price': 80000, 'power': 4},
    {'id': 5, 'name': '마법 방패', 'price': 100000, 'power': 5},
  ];

  static const List<Map<String, dynamic>> armorsList = [
    {'id': 1, 'name': '가죽 갑옷', 'price': 5000, 'power': 2},
    {'id': 2, 'name': '사슬 갑옷', 'price': 25000, 'power': 3},
    {'id': 3, 'name': '판금 갑옷', 'price': 80000, 'power': 4},
    {'id': 4, 'name': '기사 갑옷', 'price': 100000, 'power': 5},
    {'id': 5, 'name': '용비늘 갑옷', 'price': 200000, 'power': 6},
  ];

  Widget _buildWeaponShop() {
    if (_weaponShopCategory == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '상점 주인: "어서 오십시오! 우리들은 최상의 무기, 방패, 갑옷을 다룹니다."',
            style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _buildCategoryBtn('1. 무기류 (Weapons)', 1),
          _buildCategoryBtn('2. 방패류 (Shields)', 2),
          _buildCategoryBtn('3. 갑옷류 (Armors)', 3),
        ],
      );
    }

    final items = _weaponShopCategory == 1
        ? weaponsList
        : _weaponShopCategory == 2
            ? shieldsList
            : armorsList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _weaponShopCategory == 1
                  ? '무기 목록 (위력 / 가격)'
                  : _weaponShopCategory == 2
                      ? '방패 목록 (방어 / 가격)'
                      : '갑옷 목록 (방어 / 가격)',
              style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow, fontSize: 11),
            ),
            GestureDetector(
              onTap: () => setState(() => _weaponShopCategory = 0),
              child: Text(
                '◀ 이전 메뉴',
                style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightMagenta, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 190,
          decoration: BoxDecoration(
            border: Border.all(color: RetroTheme.darkGray),
            color: RetroTheme.background,
          ),
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final it = items[idx];
              final canAfford = _currentGold >= it['price'];
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  '${it['name']} (+${it['power']})',
                  style: RetroTheme.dosFont.copyWith(
                    color: canAfford ? RetroTheme.white : RetroTheme.darkGray,
                    fontSize: 12,
                  ),
                ),
                trailing: Text(
                  '금 ${it['price']} 개',
                  style: RetroTheme.dosFont.copyWith(
                    color: canAfford ? RetroTheme.yellow : RetroTheme.lightRed,
                    fontSize: 11,
                  ),
                ),
                onTap: canAfford
                    ? () => _chooseMemberForEquipment(it, _weaponShopCategory)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBtn(String title, int catIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: RetroTheme.blue,
          foregroundColor: RetroTheme.white,
          minimumSize: const Size.fromHeight(34),
        ),
        onPressed: () => setState(() => _weaponShopCategory = catIndex),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: RetroTheme.dosFont.copyWith(fontSize: 12)),
        ),
      ),
    );
  }

  void _chooseMemberForEquipment(Map<String, dynamic> item, int category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.black,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          '누가 [${item['name']}]을(를) 착용하시겠습니까?',
          style: RetroTheme.dosFont.copyWith(color: RetroTheme.yellow, fontSize: 12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.party.map((p) {
            final isMonkWeapon = category == 1 && p.playerClass == PlayerClass.monk;
            return ListTile(
              dense: true,
              title: Text(
                '${p.name} (${p.playerClass.koreanName})',
                style: RetroTheme.dosFont.copyWith(
                  color: isMonkWeapon ? RetroTheme.darkGray : RetroTheme.white,
                  fontSize: 12,
                ),
              ),
              subtitle: isMonkWeapon
                  ? Text('전투승은 무기를 사용할 수 없습니다',
                      style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightRed, fontSize: 10))
                  : Text(
                      '현재: ${category == 1 ? p.weaponName : category == 2 ? p.shieldName : p.armorName}',
                      style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan, fontSize: 10),
                    ),
              onTap: isMonkWeapon
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      if (category == 1) {
                        p.equipWeaponRaw(item['id'], item['power']);
                      } else if (category == 2) {
                        p.equipShieldRaw(item['id'], item['power']);
                      } else {
                        p.equipArmorRaw(item['id'], item['power']);
                      }
                      _spendGold(item['price'], '${p.name}이(가) [${item['name']}]을(를) 구매하여 착용했습니다!');
                    },
            );
          }).toList(),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. 병원 (Hospital)
  // =========================================================================
  Widget _buildHospital() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '치료사: "어떤 치료를 원하십니까? 신의 은총으로 모든 고통을 치유합니다."',
          style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          height: 190,
          decoration: BoxDecoration(
            border: Border.all(color: RetroTheme.darkGray),
            color: RetroTheme.background,
          ),
          child: ListView.builder(
            itemCount: widget.party.length,
            itemBuilder: (context, idx) {
              final p = widget.party[idx];
              return Card(
                color: RetroTheme.black,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: RetroTheme.dosFont.copyWith(
                                color: RetroTheme.white,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'HP: ${p.hp}/${p.maxHp} | 상태: ${p.isDead ? '사망' : p.isUnconscious ? '의식불명' : p.isPoisoned ? '중독' : '양호'}',
                              style: RetroTheme.dosFont.copyWith(
                                color: p.isDead ? RetroTheme.lightRed : RetroTheme.lightGreen,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          if (p.hp < p.maxHp && !p.isDead && !p.isUnconscious)
                            _buildHealBtn(p, 'HP치료', (p.maxHp - p.hp) * 2, () {
                              p.hp = p.maxHp;
                              _spendGold((p.maxHp - p.hp) * 2, '${p.name}의 모든 상처가 완치되었습니다!');
                            }),
                          if (p.isPoisoned)
                            _buildHealBtn(p, '해독', p.battleLevel * 10, () {
                              p.poison = 0;
                              _spendGold(p.battleLevel * 10, '${p.name}의 독이 깨끗이 정화되었습니다!');
                            }),
                          if (p.isUnconscious)
                            _buildHealBtn(p, '의식회복', 30, () {
                              p.unconscious = 0;
                              p.hp = 1;
                              _spendGold(30, '${p.name}이(가) 기적적으로 의식을 되찾았습니다!');
                            }),
                          if (p.isDead)
                            _buildHealBtn(p, '부활', 500, () {
                              p.dead = 0;
                              p.unconscious = 0;
                              p.hp = p.maxHp ~/ 2;
                              _spendGold(500, '${p.name}이(가) 신전의 성스러운 빛으로 부활했습니다!');
                            }),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHealBtn(PartyMember p, String label, int cost, VoidCallback onHeal) {
    final canAfford = _currentGold >= cost;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: canAfford ? RetroTheme.green : RetroTheme.darkGray,
        foregroundColor: RetroTheme.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        minimumSize: const Size(54, 26),
      ),
      onPressed: canAfford ? onHeal : null,
      child: Text('$label (${cost}G)', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
    );
  }

  // =========================================================================
  // 3. 군사 훈련소 (Train_Center)
  // =========================================================================
  static const List<int> expReqTable = [
    0, 0, 1500, 6000, 20000, 50000, 150000, 250000, 500000, 800000
  ];

  Widget _buildTrainCenter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '교관: "실전을 겪은 자만이 더 높은 경지에 오를 수 있다. 훈련할 자는 앞으로 나오라!"',
          style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          height: 190,
          decoration: BoxDecoration(
            border: Border.all(color: RetroTheme.darkGray),
            color: RetroTheme.background,
          ),
          child: ListView.builder(
            itemCount: widget.party.length,
            itemBuilder: (context, idx) {
              final p = widget.party[idx];
              final nextLevel = p.battleLevel + 1;
              final reqExp = nextLevel < expReqTable.length ? expReqTable[nextLevel] : 999999;
              final canLevelUp = p.experience >= reqExp;

              return ListTile(
                dense: true,
                title: Text(
                  '${p.name} (Lv.${p.battleLevel}) - Exp: ${p.experience} / $reqExp',
                  style: RetroTheme.dosFont.copyWith(
                    color: canLevelUp ? RetroTheme.yellow : RetroTheme.white,
                    fontSize: 12,
                  ),
                ),
                subtitle: Text(
                  '근력: ${p.strength} | 인내: ${p.endurance} | 민첩: ${p.agility}',
                  style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan, fontSize: 10),
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canLevelUp ? RetroTheme.yellow : RetroTheme.darkGray,
                    foregroundColor: RetroTheme.black,
                  ),
                  onPressed: canLevelUp
                      ? () {
                          setState(() {
                            p.levelUp();
                          });
                          widget.onLog('★ ${p.name}이(가) 혹독한 훈련 끝에 레벨 ${p.battleLevel}로 상승했습니다! ★');
                        }
                      : null,
                  child: Text('승급 훈련', style: RetroTheme.dosFont.copyWith(fontSize: 10)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 4. 식료품점 (Grocery)
  // =========================================================================
  Widget _buildGrocery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '상인: "모험자 여러분, 야외 탐험에서 식량이 떨어지면 체력을 보충할 수 없습니다!"',
          style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightCyan, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          '현재 보유 식량: $_currentFood 인분',
          style: RetroTheme.dosFont.copyWith(color: RetroTheme.lightGreen, fontSize: 11),
        ),
        const SizedBox(height: 8),
        for (int i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RetroTheme.blue,
                foregroundColor: RetroTheme.white,
                minimumSize: const Size.fromHeight(30),
              ),
              onPressed: _currentGold >= i * 100
                  ? () {
                      final addFood = i * 10;
                      final cost = i * 100;
                      setState(() {
                        _currentFood = (_currentFood + addFood).clamp(0, 255);
                      });
                      widget.onFoodChanged?.call(_currentFood);
                      _spendGold(cost, '식량 $addFood 인분을 구입했습니다. (총 $_currentFood 인분)');
                    }
                  : null,
              child: Text(
                '식량 ${i * 10} 인분 : 금 ${i * 100} 개',
                style: RetroTheme.dosFont.copyWith(fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }
}
