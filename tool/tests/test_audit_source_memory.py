import unittest

from audit_source_memory import classify, render
from build_port_contract_ledger import strip_pascal_comments


class SourceMemoryAuditTest(unittest.TestCase):
    def test_comments_and_strings_do_not_invent_risks(self):
        clean = strip_pascal_comments(b"Print(7,'map[x,y] := 0; shr'); { etc[i] := 5; }\nmap[x,y] := 45;")
        self.assertEqual(classify(clean.splitlines()[0]), [])
        self.assertEqual(classify(clean.splitlines()[1]), ["map write"])

    def test_computed_index_is_distinct_from_constant_byte_slot(self):
        self.assertIn("computed etc index", classify("party.etc[31+i] := 2;"))
        self.assertNotIn("computed etc index", classify("party.etc[45] := 2;"))
        self.assertNotIn("computed etc index", classify("party.etc[ 45 ] := 2;"))
        self.assertIn("etc pointer alias", classify("encounter := @party.etc[7];"))

    def test_report_contains_original_map_levers_and_pointer_aliases(self):
        report = render()
        for location in ("LORESPEC.PAS:2082", "LORESPEC.PAS:2093", "LORESUB.PAS:1794", "LORESUB.PAS:1795"):
            self.assertIn(location, report)
        self.assertNotIn("LORECHT.PAS", report)


if __name__ == "__main__":
    unittest.main()
