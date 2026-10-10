import unittest

from source_branch_inventory import case_alternatives, inventory, lex, program_files


class SourceBranchInventoryTest(unittest.TestCase):
    def test_lexer_ignores_comments_and_quoted_keywords(self):
        tokens = lex(b"{ if case } (* while *) 'repeat ''for''' if x := 1 then exit;")
        self.assertEqual([word for word, _ in tokens],
                         ["if", "x", ":=", "1", "then", "exit", ";"])

    def test_case_labels_exclude_assignment_and_nested_case(self):
        tokens = lex(b"case x of 1: y := 2; 2,3: begin case y of "
                     b"4: z := 5; end; end; end")
        outer = next(i for i, token in enumerate(tokens) if token[0] == "case")
        inner = next(i for i, token in enumerate(tokens) if token[0] == "case" and i != outer)
        self.assertEqual(case_alternatives(tokens, outer), 2)
        self.assertEqual(case_alternatives(tokens, inner), 1)

    def test_source_scope_excludes_cheat_programs(self):
        files = program_files()
        self.assertIn("LORESPEC", files)
        self.assertIn("LOREBATT", files)
        self.assertIn("ADLIB", files)
        self.assertNotIn("LORECHT", files)
        self.assertNotIn("LORECHT2", files)

    def test_all_case_sites_have_separate_label_and_unmatched_paths(self):
        cases = [site for site in inventory()["sites"] if site["kind"] == "case"]
        self.assertTrue(cases)
        self.assertTrue(all(site["outcomes"] == site["case_labels"] + 1
                            for site in cases))
        map_case = next(site for site in cases
                        if site["file"] == "LORESUB.PAS" and site["line"] == 1677)
        self.assertEqual(map_case["case_labels"], 27)


if __name__ == "__main__":
    unittest.main()
