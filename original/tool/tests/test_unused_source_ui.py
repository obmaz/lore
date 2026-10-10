"""LORESUB.PAS helpers with no call/reference in the closed original program.

This is reachability evidence, not executed pixel parity. Do not create runtime
implementations merely to close declaration-body inventory entries.
"""
import re
import unittest
from pathlib import Path
from build_port_contract_ledger import ROOT, SOURCE, strip_pascal_comments

class UnusedSourceUiTest(unittest.TestCase):
    def test_auxscroll_and_eprint_have_only_declarations(self):
        for name, expected in {'auxscroll': [123,255], 'eprint':[126,328]}.items():
            occurrences=[]
            for path in sorted(SOURCE.glob('*.PAS')):
                clean=strip_pascal_comments(path.read_bytes())
                for match in re.finditer(r'\b'+name+r'\b',clean,re.I):
                    line=clean[:match.start()].count('\n')+1
                    # Includes identifiers in assembler and @procedure references.
                    prefix=clean[:match.start()].rstrip()
                    self.assertRegex(prefix,r'(?i)\bprocedure$')
                    occurrences.append((path.name,line))
            self.assertEqual(occurrences,[('LORESUB.PAS',n) for n in expected])

    def test_inline_assembler_has_no_hidden_game_procedure_calls(self):
        for path in sorted(SOURCE.glob('*.PAS')):
            clean=strip_pascal_comments(path.read_bytes())
            for match in re.finditer(r'\basm\b(.*?)\bend\b',clean,re.I|re.S):
                self.assertIsNone(re.search(r'\b(call|jmp)\b',match[1],re.I),path.name)

    def test_no_unused_runtime_helpers_added(self):
        for path in (ROOT/'lib').rglob('*.dart'):
            self.assertIsNone(re.search(r'\b(?:auxScroll|ePrint)\s*\(',path.read_text()),str(path))

if __name__=='__main__':unittest.main()
