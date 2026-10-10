import unittest

from build_port_contract_ledger import declarations, owner


class PortContractOwnerTest(unittest.TestCase):
    def test_nested_sgn_ends_before_map_branches(self):
        _, routines = declarations("LORESPEC.PAS")
        self.assertEqual(owner(routines, 17), "LORESPEC.PAS:sgn:1")
        for line in (23, 37, 190, 996):
            self.assertEqual(
                owner(routines, line), "LORESPEC.PAS:specialevent_part1:1"
            )

    def test_other_nested_routines_return_to_parent(self):
        for filename, nested, inside, after, parent in (
            ("LORECRET.PAS", "which", 193, 197, "first"),
            ("LOREMENU.PAS", "viewpartysub", 502, 505, "viewparty"),
            ("ADLIB.PAS", "block_read", 417, 427, "loadsong"),
            ("LORESUB.PAS", "errormessage", 1639, 1645, "load"),
        ):
            with self.subTest(filename=filename, nested=nested):
                _, routines = declarations(filename)
                self.assertEqual(owner(routines, inside).split(":")[1], nested)
                self.assertEqual(owner(routines, after).split(":")[1], parent)


if __name__ == "__main__":
    unittest.main()
