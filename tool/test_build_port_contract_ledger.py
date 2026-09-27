"""Guard the baseline's scope without treating registration as parity proof."""

import unittest

import build_port_contract_ledger as ledger


class ContractLedgerTest(unittest.TestCase):
    def test_all_original_and_port_resources_are_registered(self):
        data = ledger.build()
        self.assertEqual(len(data["source_files"]), 14)
        self.assertEqual(len(data["source_catalog"]), 25)
        self.assertEqual(len(data["map_registry"]), 27)
        self.assertEqual(len(data["runtime_assets"]), 50)
        self.assertEqual(
            len({site["inventory_id"] for site in data["control_sites"]}),
            len(data["control_sites"]),
        )
        self.assertTrue(all(site["routine"] != "<program-or-unit-init>"
                            for site in data["control_sites"]))

    def test_dynamic_entries_and_prior_evidence_remain_visible(self):
        data = ledger.build()
        writes = data["map_writes"]
        self.assertTrue(any(w["file"] == "LORESPEC.PAS" and
                            w["index"] == "i,12" and w["value"] == "54"
                            for w in writes))
        self.assertTrue(any(w["file"] == "LORESPEC.PAS" and
                            w["index"] == "25,27" and w["value"] == "54"
                            for w in writes))
        evidence = data["existing_evidence"]
        self.assertTrue(any(e["path"] == "test/portal_reconciliation_test.dart"
                            for e in evidence))
        self.assertTrue(any(e["path"] == "test/fixtures/source_entrance_replay.json"
                            and e["test_users"] for e in evidence))
        self.assertTrue(all(not site["behavioral_evidence"]
                            for site in data["control_sites"]))


if __name__ == "__main__":
    unittest.main()
