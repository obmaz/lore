import 'package:flutter/material.dart';

import '../logic/lore_sub_text.dart';
import 'atlas_art.dart';

enum EquipmentKind { weapon, shield, armor }

int equipmentArtCell(EquipmentKind kind, int id) => switch (kind) {
  EquipmentKind.weapon => id >= 0 && id <= 9 ? id : 23,
  EquipmentKind.shield =>
    id == 0
        ? 10
        : id >= 1 && id <= 6
        ? 10 + id
        : 23,
  EquipmentKind.armor =>
    id == 0
        ? 10
        : id >= 1 && id <= 6
        ? 16 + id
        : 23,
};

String equipmentLabel(EquipmentKind kind, int id) => switch (kind) {
  EquipmentKind.weapon => LoreSubText.weaponLabel(id),
  _ => LoreSubText.defenseLabel(id),
};

class EquipmentArt extends StatelessWidget {
  const EquipmentArt({super.key, required this.kind, required this.id});
  final EquipmentKind kind;
  final int id;

  @override
  Widget build(BuildContext context) => AtlasArt(
    path: 'assets/images/ui/battle/equipment.png',
    cell: equipmentArtCell(kind, id),
    columns: 6,
    rows: 4,
  );
}
