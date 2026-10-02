"""Guard the baseline's scope without treating registration as parity proof."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

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
        linked = [site for site in data["control_sites"]
                  if site["behavioral_evidence"]]
        self.assertEqual(len(linked), 299)
        self.assertEqual(data["baseline_gaps"]["unmapped_behavior_sites"], 1549)
        self.assertEqual(data["baseline_gaps"]["unverified_behavior_sites"], 1848)
        self.assertTrue(all(site["verification_status"] == "partial"
                            for site in linked))
        linked_cases = {site["id"] for site in linked if site["kind"] == "case"}
        self.assertLessEqual(
            {f"LOREMAIN.PAS:main:1:case:{number}" for number in range(3, 7)},
            linked_cases,
        )
        reviewed = json.loads(ledger.EVIDENCE.read_text(encoding="utf-8"))
        self.assertEqual(
            linked_cases,
            {row["id"] for row in reviewed["contracts"] if row["kind"] == "case"},
        )
        self.assertTrue(all(
            site["port_handler"] and site["reviewed_scope"]
            for site in linked
        ))

    def test_evidence_link_rejects_source_line_drift(self):
        rows = json.loads(ledger.EVIDENCE.read_text(encoding="utf-8"))
        rows["contracts"][0]["line"] += 1
        _, sites, _ = ledger.source_contracts(ledger.inventory())
        with tempfile.TemporaryDirectory() as directory:
            candidate = Path(directory) / "evidence.json"
            candidate.write_text(json.dumps(rows), encoding="utf-8")
            with patch.object(ledger, "EVIDENCE", candidate):
                with self.assertRaisesRegex(ValueError, "source moved"):
                    ledger.link_contract_evidence(sites)


if __name__ == "__main__":
    unittest.main()
