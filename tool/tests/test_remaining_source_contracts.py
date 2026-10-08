"""Check that the final source bundles retain explicit Pascal ownership."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class RemainingSourceContractTest(unittest.TestCase):
    def test_source_and_port_owners_exist_for_remaining_bundles(self):
        # These are the source files covered by the final partial contract
        # bundles: LORE.PAS, LORECRET.PAS, LOREHELP.PAS, LORESPEC.PAS,
        # LOREMAIN.PAS, LORETALK.PAS, and LORESUB.PAS.
        owners = {
            "LORE.PAS": "lib/logic/lore_main_procedures.dart",
            "LORECRET.PAS": "lib/data/lore_creation.dart",
            "LOREHELP.PAS": "lib/screens/main_game_screen.dart",
            "LORESPEC.PAS": "lib/logic/lore_spec_procedures.dart",
            "LOREMAIN.PAS": "lib/logic/lore_main_procedures.dart",
            "LORETALK.PAS": "lib/logic/lore_talk_procedures.dart",
            "LORESUB.PAS": "lib/models/party_member.dart",
        }
        for source, implementation in owners.items():
            source_path = ROOT / "repo_source/LORE_1993_src" / source
            self.assertTrue(source_path.is_file(), source)
            self.assertTrue(source_path.read_bytes().strip(), source)
            self.assertTrue((ROOT / implementation).is_file(), implementation)

