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

  void _spendGold(int amount) {
    setState(() {
      _currentGold -= amount;
    });
    widget.onGoldChanged(_currentGold);
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
    // The first Print line of each LORESUB.PAS procedure.
    final title = switch (widget.facilityType) {
      TownFacilityType.weaponShop => TownLogic.shopIntro,
      TownFacilityType.hospital => TownLogic.hospitalIntro,
      TownFacilityType.trainCenter => TownLogic.trainIntro,
      TownFacilityType.grocery => TownLogic.groceryIntro,
    };
    return Text(
      title,
      style: RetroTheme.dosFont.copyWith(
        color: RetroTheme.white,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
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
      child: IconButton(
        key: const ValueKey('facility-close'),
        style: IconButton.styleFrom(
          backgroundColor: RetroTheme.darkGray,
          foregroundColor: RetroTheme.white,
        ),
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close, size: 16),
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
            '${TownLogic.shopSubIntro} ${TownLogic.shopCategoryPrompt}',
            style: RetroTheme.dosFont.copyWith(
              color: RetroTheme.lightCyan,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          _buildCategoryBtn('무기류', 1),
          _buildCategoryBtn('방패류', 2),
          _buildCategoryBtn('갑옷류', 3),
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
                  ? TownLogic.shopWeaponPrompt
                  : _weaponShopCategory == 2
                  ? TownLogic.shopShieldPrompt
                  : TownLogic.shopArmorPrompt,
              style: RetroTheme.dosFont.copyWith(
                color: RetroTheme.yellow,
                fontSize: 11,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _weaponShopCategory = 0),
              child: const Icon(
                Icons.arrow_back,
                size: 16,
                color: RetroTheme.lightMagenta,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 190,
          decoration: BoxDecoration(
            border: Border.all(color: RetroTheme.darkGray),
          ),
          child: Material(
            color: RetroTheme.background,
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, idx) {
                final it = items[idx];
                final canAfford = _currentGold >= it.price;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    '${it.name} : 금 ${it.price} 개',
                    style: RetroTheme.dosFont.copyWith(
                      color: canAfford ? RetroTheme.white : RetroTheme.darkGray,
                      fontSize: 12,
                    ),
                  ),
                  onTap: canAfford ? () => _chooseMemberForEquipment(it) : null,
                );
              },
            ),
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
        backgroundColor: RetroTheme.black,
        shape: Border.all(color: RetroTheme.lightCyan, width: 2),
        title: Text(
          '누가 이 ${item.name}를 사용하시겠습니까 ?',
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
                p.name,
                style: RetroTheme.dosFont.copyWith(
                  color: blocked ? RetroTheme.darkGray : RetroTheme.white,
                  fontSize: 12,
                ),
              ),
              onTap: blocked
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      TownLogic.equipPurchased(p, item);
                      _spendGold(item.price);
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
          ),
          child: Material(
            color: RetroTheme.background,
            child: ListView.builder(
              itemCount: widget.party.length,
              itemBuilder: (context, idx) => TownHospitalRow(
                member: widget.party[idx],
                gold: _currentGold,
                onTreat: _treat,
              ),
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
    widget.onLog(TownLogic.appliedMessage(member, treatment));
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
          ),
          child: Material(
            color: RetroTheme.background,
            child: ListView.builder(
              itemCount: widget.party.length,
              itemBuilder: (context, idx) => TownTrainRow(
                member: widget.party[idx],
                onTrain: _trainMember,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 원작 Train_Center: 인물을 고르면 판정하고 그 결과를 출력한다.
  void _trainMember(PartyMember member) {
    final offer = TownLogic.evaluateTraining(member);
    if (!offer.canTrain) {
      widget.onLog(TownLogic.trainNotEnoughExp);
      if (member.battleLevel >= 1 && member.battleLevel <= 19) {
        widget.onLog(
          ' 당신이 다음 레벨이 되려면 경험치가 '
          '${TownLogic.expRequiredForLevel(member.battleLevel + 1)}'
          ' 이상 이어야 합니다.',
        );
      }
      return;
    }
    if (offer.cost > _currentGold) {
      widget.onLog('당신은 금 ${_currentGold - offer.cost}개가 더 필요합니다.');
      return;
    }
    setState(() => _currentGold -= offer.cost);
    widget.onGoldChanged(_currentGold);
    for (final m in TownLogic.applyTraining(member, offer)) {
      widget.onLog(m);
    }
    setState(() {});
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
                '$amount 인분 : 금 ${TownLogic.foodPackagePrice(amount)} 개',
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
    widget.onLog(TownLogic.thankYou);
  }
}
