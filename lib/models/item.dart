enum ItemType {
  weapon,
  shield,
  armor,
}

class Item {
  final int id;
  final String name;
  final ItemType type;
  final int power;
  final int price;

  const Item({
    required this.id,
    required this.name,
    required this.type,
    required this.power,
    required this.price,
  });

  // 원작 LORESUB.PAS 기준 10종 무기 프리셋
  static const List<Item> weapons = [
    Item(id: 0, name: '맨손', type: ItemType.weapon, power: 2, price: 0),
    Item(id: 1, name: '단도', type: ItemType.weapon, power: 5, price: 500),
    Item(id: 2, name: '곤봉', type: ItemType.weapon, power: 7, price: 1500),
    Item(id: 3, name: '미늘창', type: ItemType.weapon, power: 9, price: 3000),
    Item(id: 4, name: '장검', type: ItemType.weapon, power: 10, price: 5000),
    Item(id: 5, name: '철퇴', type: ItemType.weapon, power: 15, price: 10000),
    Item(id: 6, name: '기병창', type: ItemType.weapon, power: 20, price: 30000),
    Item(id: 7, name: '도끼창', type: ItemType.weapon, power: 30, price: 60000),
    Item(id: 8, name: '삼지창', type: ItemType.weapon, power: 40, price: 80000),
    Item(id: 9, name: '화염검', type: ItemType.weapon, power: 50, price: 100000),
  ];

  // 원작 LORESUB.PAS 기준 6종 방패 프리셋
  static const List<Item> shields = [
    Item(id: 0, name: '없음', type: ItemType.shield, power: 0, price: 0),
    Item(id: 1, name: '가죽 방패', type: ItemType.shield, power: 1, price: 1000),
    Item(id: 2, name: '청동 방패', type: ItemType.shield, power: 2, price: 5000),
    Item(id: 3, name: '강철 방패', type: ItemType.shield, power: 3, price: 25000),
    Item(id: 4, name: '은제 방패', type: ItemType.shield, power: 4, price: 80000),
    Item(id: 5, name: '금제 방패', type: ItemType.shield, power: 5, price: 100000),
  ];

  // 원작 LORESUB.PAS 기준 6종 갑옷 프리셋 (power = k + 1)
  static const List<Item> armors = [
    Item(id: 0, name: '없음', type: ItemType.armor, power: 0, price: 0),
    Item(id: 1, name: '가죽 갑옷', type: ItemType.armor, power: 2, price: 5000),
    Item(id: 2, name: '청동 갑옷', type: ItemType.armor, power: 3, price: 25000),
    Item(id: 3, name: '강철 갑옷', type: ItemType.armor, power: 4, price: 80000),
    Item(id: 4, name: '은제 갑옷', type: ItemType.armor, power: 5, price: 100000),
    Item(id: 5, name: '금제 갑옷', type: ItemType.armor, power: 6, price: 200000),
  ];

  static Item getWeapon(int id) {
    if (id >= 0 && id < weapons.length) return weapons[id];
    return weapons[0];
  }

  static Item getShield(int id) {
    if (id >= 0 && id < shields.length) return shields[id];
    return shields[0];
  }

  static Item getArmor(int id) {
    if (id >= 0 && id < armors.length) return armors[id];
    return armors[0];
  }
}
