# Mobile party and equipment art

Generated on 2026-10-09 for the `new_ui` mobile presentation. These PNGs only
illustrate existing characters and equipment; they do not define game records.

`characters.png` is a transparent, uniform 4 × 3 atlas. Reading order:
Hero, Hercules, Merlin, Genius Kie; Regulus, Skeleton, Titan, Betelgeuse;
Bellatrix, Polaris, generic esper, Rigel/generic hunter.
The direction is right-facing. Status, detail and battle share the same cells.
The visual brief used adult proportions, painterly JRPG clothing, restrained
colors, distinctive silhouettes and full figures rather than face portraits.

`equipment.png` is a transparent, uniform 6 × 4 atlas. Reading order:
wrapped fist, dagger, club, halberd, longsword, mace;
cavalry lance, axe polearm, trident, flame sword, empty slot, leather shield;
bronze shield, steel shield, silver shield, gold shield, arcane shield, leather armor;
bronze armor, steel armor, silver armor, gold armor, arcane armor, unknown item.
Weapon IDs 0..9 map to cells 0..9, shield IDs 1..6 to 11..16,
armor IDs 1..6 to 17..22. Defense ID 0 uses the empty slot; unknown IDs use 23.
Source label functions remain authoritative for item names.

The atlases are sampled at runtime without rescaling or editing the originals.
