import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';
import '../logic/town_logic.dart';
import '../models/item.dart';
import '../models/party_member.dart';
import 'town_facility_rows.dart';

enum TownFacilityType { weaponShop, hospital, trainCenter, grocery }

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
      backgroundColor: RetroTheme.panelBg,
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
        child: Text(
          '나가기 (ESC)',
          style: RetroTheme.dosFont.copyWith(fontSize: 12),
        ),
      ),
    );
  }

  // =========================================================================
  // 1. 무기 & 방어구 상점 (LORESUB.PAS:1183 Weapon_Shop)
  //    무기 1~9, 방패 1~5(위력=등급), 갑옷 1~5(위력=등급+1)
  // =========================================================================

  /// 현재 카테고리의 원작 아이템 목록
  List<Item> get _shopItems {
    switch (_weaponShopCategory) {
      case 1:
        return TownLogic.shopWeapons;
      case 2:
        return TownLogic.shopShields;
      case 3:
        return TownLogic.shopArmors;
      default:
        return const [];
    }
  }

  Widget _buildWeaponShop() {
    if (_weaponShopCategory == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '상점 주인: "어서 오십시오! 우리들은 최상의 무기, 방패, 갑옷을 다룹니다."',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.lightCyan,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          _buildCategoryBtn('1. 무기류 (Weapons)', 1),
          _buildCategoryBtn('2. 방패류 (Shields)', 2),
          _buildCategoryBtn('3. 갑옷류 (Armors)', 3),
        ],
      );
    }

    final items = _shopItems;

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
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.yellow,
                fontSize: 11,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _weaponShopCategory = 0),
              child: Text(
                '◀ 이전 메뉴',
                style: RetroTheme.dosFont.copyWith(
                  color: RetroTheme.lightMagenta,
                  fontSize: 11,
                ),
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
              final canAfford = _currentGold >= it.price;
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  '${it.name} (+${it.power})',
                  style: RetroTheme.dosFont.copyWith(
                    color: canAfford ? RetroTheme.white : RetroTheme.darkGray,
                    fontSize: 12,
                  ),
                ),
                trailing: Text(
                  '금 ${it.price} 개',
                  style: RetroTheme.dosFont.copyWith(
                    color: canAfford ? RetroTheme.yellow : RetroTheme.lightRed,
                    fontSize: 11,
                  ),
                ),
                onTap: canAfford ? () => _chooseMemberForEquipment(it) : null,
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
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => setState(() => _weaponShopCategory = catIndex),
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: RetroTheme.dosFont.copyWith(fontSize: 12),
        ),
      ),
    );
  }

  void _chooseMemberForEquipment(Item item) {
    if (_currentGold < item.price) {
      widget.onLog(TownLogic.notEnoughMoney);
      return;
    }
    final isWeapon = item.type == ItemType.weapon;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.panelBg,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          '누가 이 ${item.name}를 사용하시겠습니까?',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.yellow,
            fontSize: 12,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.party.map((p) {
            final blocked = isWeapon && p.playerClass == PlayerClass.monk;
            return ListTile(
              dense: true,
              title: Text(
                '${p.name} (${p.playerClass.koreanName})',
                style: RetroTheme.dosFont.copyWith(
                  color: blocked ? RetroTheme.darkGray : RetroTheme.white,
                  fontSize: 12,
                ),
              ),
              subtitle: blocked
                  ? Text(
                      TownLogic.shopMonkRefuse,
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.lightRed,
                        fontSize: 10,
                      ),
                    )
                  : Text(
                      '현재: ${item.type == ItemType.weapon
                          ? p.weaponName
                          : item.type == ItemType.shield
                          ? p.shieldName
                          : p.armorName}',
                      style: RetroTheme.dosFont.copyWith(
                        color: RetroTheme.lightCyan,
                        fontSize: 10,
                      ),
                    ),
              onTap: blocked
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      TownLogic.equipPurchased(p, item);
                      _spendGold(
                        item.price,
                        '${p.name}이(가) [${item.name}]을(를) 구매하여 착용했습니다! (방어도: ${p.ac})',
                      );
                    },
            );
          }).toList(),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. 병원 (LORESUB.PAS:1517 Hospital)
  //    상처 치료 / 독 제거 / 의식 회복 / 부활 4종을 개별 비용으로 처리한다.
  // =========================================================================
  Widget _buildHospital() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${TownLogic.hospitalIntro} ${TownLogic.hospitalWhatPrompt}',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightCyan,
            fontSize: 12,
          ),
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
            itemBuilder: (context, idx) => TownHospitalRow(
              member: widget.party[idx],
              gold: _currentGold,
              onTreat: _treat,
            ),
          ),
        ),
      ],
    );
  }

  /// 원작 Hospital의 개별 치료 처리
  void _treat(PartyMember member, Treatment treatment) {
    if (!TownLogic.canTreat(member, treatment)) {
      widget.onLog(TownLogic.unavailableReason(member, treatment));
      return;
    }
    final cost = TownLogic.treatmentCost(member, treatment);
    if (_currentGold < cost) {
      widget.onLog(TownLogic.notEnoughMoney);
      return;
    }
    setState(() {
      _currentGold -= cost;
      TownLogic.applyTreatment(member, treatment);
    });
    widget.onGoldChanged(_currentGold);
    widget.onLog(
      '${TownLogic.appliedMessage(member, treatment)} (치료비: ${cost}G)',
    );
  }

  // =========================================================================
  // 3. 군사 훈련소 (원작 LORESUB.PAS:1332 Train_Center)
  // =========================================================================
  Widget _buildTrainCenter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${TownLogic.trainIntro} ${TownLogic.trainSubIntro}',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightCyan,
            fontSize: 12,
          ),
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
            itemBuilder: (context, idx) => TownTrainRow(
              member: widget.party[idx],
              gold: _currentGold,
              onTrain: _trainMember,
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
        _currentGold -= offer.cost;
        widget.onLog('★ ${member.name}의 승급 훈련비로 금화 ${offer.cost}개를 지불했습니다.');
      } else {
        widget.onLog('★ ${member.name}이(가) 최고 레벨에 도달하여 무상으로 승급했습니다!');
      }
    });
    widget.onGoldChanged(_currentGold);
    for (final m in TownLogic.applyTraining(member, offer)) {
      widget.onLog(m);
    }
  }

  // =========================================================================
  // 4. 식료품점 (원작 LORESUB.PAS:1155 Grocery)
  // =========================================================================
  Widget _buildGrocery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${TownLogic.groceryIntro} ${TownLogic.groceryPrompt}',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightCyan,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '현재 보유 식량: $_currentFood 인분 (최대 ${TownLogic.maxFood}인분)',
          style: RetroTheme.dosFont.copyWith(
            color: RetroTheme.lightGreen,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        for (final amount in TownLogic.foodPackageAmounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _currentGold >= TownLogic.foodPackagePrice(amount)
                    ? RetroTheme.blue
                    : RetroTheme.darkGray,
                foregroundColor: RetroTheme.white,
                minimumSize: const Size.fromHeight(30),
              ),
              onPressed: _currentGold >= TownLogic.foodPackagePrice(amount)
                  ? () => _buyFood(amount)
                  : null,
              child: Text(
                '식량 $amount 인분 : 금 ${TownLogic.foodPackagePrice(amount)} 개',
                style: RetroTheme.dosFont.copyWith(fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  /// 원작 Grocery 구입 처리 (10인분당 금 100개, 최대 255인분)
  void _buyFood(int amount) {
    final cost = TownLogic.foodPackagePrice(amount);
    if (_currentGold < cost) {
      widget.onLog(TownLogic.notEnoughMoney);
      return;
    }
    setState(() {
      final result = TownLogic.buyFood(_currentGold, _currentFood, amount);
      _currentGold = result.$1;
      _currentFood = result.$2;
    });
    widget.onGoldChanged(_currentGold);
    widget.onFoodChanged?.call(_currentFood);
    if (_currentFood >= TownLogic.maxFood) {
      widget.onLog(
        '식량이 ${TownLogic.maxFood}인분 가득 찼습니다. (현재: $_currentFood 인분)',
      );
    } else {
      widget.onLog('식량 $amount 인분을 구입했습니다. (총 $_currentFood 인분)');
    }
  }
}
