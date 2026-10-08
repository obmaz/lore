"""Keep the remaining map-write bundles tied to source and port owners."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class MapWriteContractBundleTest(unittest.TestCase):
    def test_remaining_map_write_sources_and_owners_exist(self):
        # Bundle sources: LORESPEC.PAS, LOREMENU.PAS, LORETALK.PAS,
        # and LOREENT.PAS. Behavioral replay remains a separate concern.
        owners = {
            "LORESPEC.PAS": "lib/logic/lore_spec_procedures.dart",
            "LOREMENU.PAS": "lib/logic/lore_special_event_dispatcher.dart",
            "LORETALK.PAS": "lib/logic/lore_talk_procedures.dart",
            "LOREENT.PAS": "lib/logic/lore_ent_procedures.dart",
        }
        for source, implementation in owners.items():
            self.assertTrue(
                (ROOT / "repo_source/LORE_1993_src" / source).read_bytes().strip(),
                source,
            )
            self.assertTrue((ROOT / implementation).is_file(), implementation)

