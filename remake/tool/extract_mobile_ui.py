"""Reproducible crops from approved AI concepts; never crop runtime text/numbers.

Run: python3 tool/extract_mobile_ui.py
All coordinates refer to the committed 853 × 1844 originals. Images are
presentation assets only: no map, game rule, or save data is extracted.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/design/mobile-ui"
DEST = ROOT / "assets/images/ui"
CROPS = {
    "title-landscape": ("01-start", (0, 426, 853, 1110)),
    "crystal": ("01-start", (375, 130, 491, 226)),
    "map-scroll": ("01-start", (162, 1338, 293, 1465)),
    "save-book": ("01-start", (159, 1510, 291, 1647)),
    "backpack": ("03-exploration", (408, 1512, 497, 1605)),
    "status-scroll": ("03-exploration", (565, 1517, 637, 1604)),
    "extrasense": ("03-exploration", (710, 1511, 796, 1608)),
    "hero": ("03-exploration", (39, 1078, 162, 1201)),
    "priest": ("03-exploration", (169, 1078, 290, 1201)),
    "wizard": ("03-exploration", (304, 1078, 425, 1201)),
    "villager": ("03-exploration", (432, 1078, 555, 1201)),
    "merchant": ("03-exploration", (564, 1078, 689, 1201)),
    "warrior": ("02-creation", (81, 449, 355, 684)),
    "mage": ("02-creation", (484, 461, 748, 684)),
    "monk": ("02-creation", (94, 862, 358, 1107)),
    "knight": ("02-creation", (480, 858, 765, 1108)),
    "hero-full": ("06-party", (35, 424, 343, 883)),
    "elder": ("04-dialogue", (53, 1070, 276, 1314)),
    "sword": ("06-party", (124, 1082, 348, 1345)),
    "armor": ("06-party", (505, 1114, 738, 1340)),
    "attack": ("05-battle", (103, 1304, 166, 1379)),
    "magic-one": ("05-battle", (496, 1300, 553, 1381)),
    "magic-all": ("05-battle", (106, 1416, 165, 1493)),
    "magic-special": ("05-battle", (489, 1417, 562, 1495)),
    "heal": ("05-battle", (102, 1536, 171, 1613)),
    "esp": ("05-battle", (491, 1530, 570, 1620)),
    "cave": ("05-battle", (24, 146, 828, 279)),
    "slime": ("05-battle", (108, 406, 244, 515)),
    "skeleton": ("05-battle", (343, 338, 509, 517)),
    "bat": ("05-battle", (565, 354, 798, 475)),
}

DEST.mkdir(parents=True, exist_ok=True)
for name, (source, box) in CROPS.items():
    with Image.open(SOURCE / f"{source}.png") as original:
        original.crop(box).save(DEST / f"{name}.png", optimize=True)
print(f"Extracted {len(CROPS)} art-only PNG assets into {DEST}")
