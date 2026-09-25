import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import '../models/party_member.dart';
import '../models/item.dart';
import '../game/lore_dialogue_manager.dart';
import '../logic/town_logic.dart';
import 'town_facility_rows.dart';

/// 1993년 원작 LORECITY 및 LORETALK 기반 4대 성/마을 상점 및 NPC 상호작용 모달 다이얼로그
class TownDialog extends StatefulWidget {
  final List<PartyMember> party;
  final int gold;
  final int food;
  final int
  mapId; // 6: CASTLE LORE, 7: LASTDITCH, 9: GAIA TERRA, 10: WATER FIELD
  final void Function(int newGold) onGoldChanged;
  final void Function(int newFood)? onFoodChanged;
  final void Function(String message) onLog;

  const TownDialog({
    super.key,
    required this.party,
    required this.gold,
    this.food = 100,
    this.mapId = 6,
    required this.onGoldChanged,
    this.onFoodChanged,
    required this.onLog,
  });

  @override
  State<TownDialog> createState() => _TownDialogState();
}

class _TownDialogState extends State<TownDialog> {
  int _currentTab =
      0; // 0: 마을 메인, 1: 무기 상점, 2: 신전/병원, 3: 군사 훈련소, 4: 식료품점, 5: 주민 대화
  /// 무기 상점 카테고리 (0: 무기류, 1: 방패류, 2: 갑옷류) - 원작 Weapon_Shop
  int _shopCategory = 0;
  late int _gold;
  late int _food;

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
    _food = widget.food;
  }

  /// 식료품점 구입 (원작 LORESUB.PAS:1155 Grocery)
  void _buyFood(int amount) {
    final cost = TownLogic.foodPackagePrice(amount);
    if (_gold < cost) {
      widget.onLog(TownLogic.notEnoughMoney);
      widget.onLog('골드가 부족합니다! (필요: ${cost}G, 보유: ${_gold}G)');
      return;
    }

    setState(() {
      final result = TownLogic.buyFood(_gold, _food, amount);
      _gold = result.$1;
      _food = result.$2;
      widget.onGoldChanged(_gold);
      widget.onFoodChanged?.call(_food);
    });
    if (_food >= TownLogic.maxFood) {
      widget.onLog('식량이 ${TownLogic.maxFood}인분 가득 찼습니다. (현재 식량: $_food인분)');
    } else {
      widget.onLog('식량 $amount인분을 구입했습니다! (현재 식량: $_food인분)');
    }
  }

  /// 무기/방패/갑옷 구입 및 장착 (원작 Weapon_Shop)
  void _buyEquipment(Item item, PartyMember member) {
    if (_gold < item.price) {
      widget.onLog(TownLogic.notEnoughMoney);
      return;
    }
    if (item.type == ItemType.weapon &&
        member.playerClass == PlayerClass.monk) {
      widget.onLog(TownLogic.shopMonkRefuse);
      return;
    }

    setState(() {
      _gold -= item.price;
      widget.onGoldChanged(_gold);
      TownLogic.equipPurchased(member, item);
    });
    widget.onLog(
      '${member.name}이(가) ${item.name}을(를) 구매하여 장착했습니다. '
      '(위력: ${item.type == ItemType.weapon ? member.weaPower : (item.type == ItemType.shield ? member.shiPower : member.armPower)}'
      ' / 방어도: ${member.ac})',
    );
  }

  /// 병원 치료 (원작 LORESUB.PAS:1517 Hospital)
  void _treat(PartyMember member, Treatment treatment) {
    if (!TownLogic.canTreat(member, treatment)) {
      widget.onLog(TownLogic.unavailableReason(member, treatment));
      return;
    }
    final cost = TownLogic.treatmentCost(member, treatment);
    if (_gold < cost) {
      widget.onLog(TownLogic.notEnoughMoney);
      widget.onLog('치료비 ${cost}G가 부족합니다. (보유: ${_gold}G)');
      return;
    }

    setState(() {
      _gold -= cost;
      widget.onGoldChanged(_gold);
      TownLogic.applyTreatment(member, treatment);
    });
    widget.onLog(
      '${TownLogic.appliedMessage(member, treatment)} (치료비: ${cost}G)',
    );
  }

  /// 원작 무기 상점 3분류 아이템 목록
  List<Item> get _currentShopItems {
    switch (_shopCategory) {
      case 1:
        return TownLogic.shopShields;
      case 2:
        return TownLogic.shopArmors;
      default:
        return TownLogic.shopWeapons;
    }
  }

  String get _shopCategoryName {
    switch (_shopCategory) {
      case 1:
        return '방패류';
      case 2:
        return '갑옷류';
      default:
        return '무기류';
    }
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
        width: 620,
        height: 450,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 상단 타이틀
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '◆ $townName ◆',
                    overflow: TextOverflow.ellipsis,
                    style: RetroTheme.headerFont.copyWith(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '식량: $_food 인분',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.lightGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '금화: $_gold G',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.yellow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: RetroTheme.borderColor, height: 16),

            // 메인 컨텐츠 영역
            Expanded(child: _buildCurrentTabContent()),

            // 하단 탭 버튼
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTabButton(0, '마을 광장'),
                  _buildTabButton(1, '무기 상점'),
                  _buildTabButton(2, '성소/치료소'),
                  _buildTabButton(3, '군사 훈련소'),
                  _buildTabButton(4, '식료품점'),
                  _buildTabButton(5, '주민 대화'),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_currentTab) {
      case 1: // 무기 상점 (원작 LORESUB.PAS:1183 Weapon_Shop)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${TownLogic.shopIntro} ${TownLogic.shopSubIntro}\n${TownLogic.shopCategoryPrompt}',
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.lightGray,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildShopCategoryButton(0, '무기류'),
                const SizedBox(width: 6),
                _buildShopCategoryButton(1, '방패류'),
                const SizedBox(width: 6),
                _buildShopCategoryButton(2, '갑옷류'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '어떤 $_shopCategoryName 원하십니까 ? (장착할 파티원을 지정하십시오)',
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.yellow,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                children: _currentShopItems
                    .map(
                      (item) => TownShopRow(
                        item: item,
                        party: widget.party,
                        onBuy: _buyEquipment,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );

      case 2: // 신전/병원 (원작 LORESUB.PAS:1517 Hospital)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${TownLogic.hospitalIntro} ${TownLogic.hospitalWhatPrompt}',
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.lightGray,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                itemCount: widget.party.length,
                itemBuilder: (context, idx) => TownHospitalRow(
                  member: widget.party[idx],
                  gold: _gold,
                  onTreat: _treat,
                ),
              ),
            ),
          ],
        );

      case 3: // 군사 훈련소 (Train_Center - 원작 LORESUB.PAS:1331)
        return _buildTrainCenter();

      case 4: // 식료품점 (Grocery - 원작 LORESUB.PAS:1154)
        return _buildGrocery();

      case 5: // NPC 대화
        final npcTalks = _getTownNpcTalks();
        return ListView(
          children: npcTalks.map((n) {
            return _buildNpcTalk(n['name']!, n['talk']!);
          }).toList(),
        );

      default: // 0: 마을 메인 허브
        return Center(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
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
                Icons.military_tech_outlined,
                '군사 훈련소',
                '경험치로 레벨업 승급',
                () {
                  setState(() => _currentTab = 3);
                },
              ),
              _buildMenuCard(
                Icons.restaurant_outlined,
                '식료품점',
                '탐험용 식량 보급',
                () {
                  setState(() => _currentTab = 4);
                },
              ),
              _buildMenuCard(
                Icons.record_voice_over_outlined,
                '주민 대화',
                '소문과 정보 수집',
                () {
                  setState(() => _currentTab = 5);
                },
              ),
            ],
          ),
        );
    }
  }

  Widget _buildTrainCenter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${TownLogic.trainIntro} ${TownLogic.trainSubIntro}',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightCyan,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: RetroTheme.borderColor),
              color: RetroTheme.background,
            ),
            child: ListView.builder(
              itemCount: widget.party.length,
              itemBuilder: (context, idx) => TownTrainRow(
                member: widget.party[idx],
                gold: _gold,
                onTrain: _trainMember,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 원작 Train_Center 승급 처리 (도달 레벨로 즉시 점프, Lv.20은 무상)
  void _trainMember(PartyMember member, TrainOffer offer) {
    setState(() {
      if (offer.cost > 0) {
        _gold -= offer.cost;
        widget.onGoldChanged(_gold);
        widget.onLog('★ ${member.name}의 승급 훈련비로 금화 ${offer.cost}개를 지불했습니다.');
      } else {
        widget.onLog('★ ${member.name}이(가) 최고 레벨에 도달하여 무상으로 승급했습니다!');
      }
      for (final m in TownLogic.applyTraining(member, offer)) {
        widget.onLog(m);
      }
    });
  }

  Widget _buildGrocery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${TownLogic.groceryIntro} ${TownLogic.groceryPrompt}',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightCyan,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '현재 보유 식량: $_food 인분 (최대 ${TownLogic.maxFood}인분 소지 가능)',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightGreen,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: TownLogic.foodPackageAmounts
                .map((amount) => _buildFoodBuyRow(amount))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodBuyRow(int amount) {
    final cost = TownLogic.foodPackagePrice(amount);
    final canAfford = _gold >= cost;
    final isFull = _food >= TownLogic.maxFood;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: RetroTheme.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '식량 $amount 인분 : 금 $cost 개',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.white,
              fontSize: 11,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canAfford
                  ? RetroTheme.blue
                  : RetroTheme.darkGray,
              foregroundColor: RetroTheme.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(80, 26),
            ),
            onPressed: canAfford ? () => _buyFood(amount) : null,
            child: Text(
              isFull ? '식량 가득참' : '금 $cost G 구매',
              style: RetroTheme.dosFont.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  /// 무기/방패/갑옷 3분류 전환 버튼 (원작 Weapon_Shop의 select 메뉴)
  Widget _buildShopCategoryButton(int category, String label) {
    final isSelected = _shopCategory == category;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? RetroTheme.yellow : RetroTheme.darkGray,
        foregroundColor: isSelected ? RetroTheme.black : RetroTheme.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: const Size(70, 26),
      ),
      onPressed: () => setState(() => _shopCategory = category),
      child: Text(label, style: RetroTheme.dosFont.copyWith(fontSize: 11)),
    );
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
