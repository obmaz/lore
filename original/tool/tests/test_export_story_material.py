import json
from pathlib import Path
import re
import tempfile
import unittest

from export_story_material import Parser, SOURCE, build, descendants, display_event, extract_file, lex


class StorySyntaxTest(unittest.TestCase):
    def test_comments_escaped_quotes_and_empty_strings(self):
        source = "{ 'not dialogue' } (* 'also not' *) // 'no'\nPrint(7,'하늘''색'); talk('');"
        strings = [token.value for token in lex(source) if token.kind == "string"]
        self.assertEqual(strings, ["'하늘''색'", "''"])

    def test_dangling_else_belongs_to_inner_condition(self):
        parser = Parser("begin if a then if b then talk('yes') else talk('no'); talk('after'); end.", "TEST.PAS")
        body = parser.parse()[0]["body"]
        outer, after = body["children"]
        self.assertIsNone(outer["else"])
        self.assertEqual(outer["then"]["else"]["code"], "talk('no')")
        self.assertEqual(after["code"], "talk('after')")

    def test_case_ranges_loops_labels_and_early_exit(self):
        source = """begin
case party.etc[10] of
  0..2: begin talk('first'); inc(party.etc[10]); end;
  3,4: if k=0 then exit else talk('branch');
  else talk('fallback');
end;
retry: repeat for i:=1 to 3 do talk('repeat'); until done;
end."""
        body = Parser(source, "TEST.PAS").parse()[0]["body"]
        case, label = body["children"]
        self.assertEqual([arm["label"] for arm in case["arms"]], ["0..2", "3,4", "else"])
        self.assertEqual(case["arms"][1]["body"]["then"]["code"], "exit")
        self.assertEqual(label["label"], "retry")
        self.assertEqual(label["body"]["kind"], "repeat")
        self.assertEqual(label["body"]["children"][0]["kind"], "for")

    def test_assembly_end_does_not_end_pascal_routine(self):
        source = """unit Test; interface procedure p; implementation
procedure rgb; assembler; asm mov ax,1 end;
procedure p; begin asm mov ax,2 end; if a then talk('after assembly'); end;
begin end."""
        routines = Parser(source, "TEST.PAS").parse()
        self.assertEqual([r["name"] for r in routines], ["rgb", "p", "__main__"])
        self.assertEqual(routines[0]["body"]["kind"], "assembly")
        self.assertEqual(routines[1]["body"]["children"][1]["kind"], "if")

    def test_variable_and_choice_fragments_are_not_fabricated_dialogue(self):
        source = """unit Test; interface implementation
procedure p; begin s := '앞'; m[1] := '수락'; talk(s+player[1].name+'뒤'); talk(''); end;
begin end."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "TEST.PAS"
            path.write_bytes(source.encode("johab"))
            unit = extract_file(path)
        self.assertEqual([literal["text"] for literal in unit["literals"]], ["앞", "수락", "뒤", ""])
        self.assertEqual(unit["literals"][0]["role"], "text_variable_fragment")
        self.assertEqual(unit["literals"][1]["role"], "choice_label_or_prompt")
        self.assertIn("player[1].name", unit["scenes"][0]["original_source"])

    def test_highlighted_text_is_joined_without_losing_spaces(self):
        body = Parser("begin cPrint(7,11,' 나는 ','Lord Ahn',' 이오.'); end.", "TEST.PAS").parse()[0]["body"]
        event = display_event(body["children"][0], ())
        self.assertEqual(event["text_template"], " 나는 Lord Ahn 이오.")
        self.assertTrue(event["fully_literal"])
        self.assertIsNone(event["speaker"])

    def test_dynamic_text_keeps_exact_source_expression(self):
        body = Parser("begin talk('안녕, '+player[1].name+'.'); end.", "TEST.PAS").parse()[0]["body"]
        event = display_event(body["children"][0], ())
        self.assertEqual(event["text_template"], "안녕, {{player[1].name}}.")
        self.assertFalse(event["fully_literal"])


class StoryCorpusTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.outputs = build()
        cls.units = cls.outputs["scripts.json"]["source_units"]

    def test_independent_regex_finds_exactly_the_same_literal_spans(self):
        # Independent recognizer matches comments OR literals, never quotes
        # inside a comment. Compare offsets as well as text, including repeats.
        pattern = re.compile(r"\{[^}]*\}|\(\*.*?\*\)|//[^\n]*|'(?:''|[^'])*'", re.S)
        for unit in self.units:
            expected = [(m.start(), m.group()) for m in pattern.finditer(unit["original_source"]) if m.group().startswith("'")]
            actual = [(literal["source"]["offset_start"], literal["pascal_literal"]) for literal in unit["literals"]]
            self.assertEqual(actual, expected, unit["file"])
            self.assertEqual(unit["original_source"], (SOURCE / unit["file"]).read_bytes().decode("johab"))

    def test_every_literal_and_scene_is_in_a_quest_or_the_appendix(self):
        self.assertEqual(self.outputs["coverage.json"]["missing_literal_ids"], [])
        self.assertEqual(self.outputs["coverage.json"]["unassigned_scene_ids"], [])
        original = {literal["id"] for unit in self.units for literal in unit["literals"]}
        exported = {literal["id"] for filename, data in self.outputs.items()
                    if filename.startswith("quests/") for scene in data["scripts"] for literal in scene["text_occurrences"]}
        self.assertEqual(original, exported)
        maps = {map_id for quest in self.outputs["quests.json"]["quests"] for map_id in quest["maps"]}
        self.assertEqual(maps, set(range(1, 28)))

    def test_main_dialogue_stages_preserve_exact_increment_sequence(self):
        tracks = self.outputs["progression.json"]["quest_state_tracks"]
        expected = {10: [(0,1),(1,2),(2,3),(4,5),(5,6)],
                    13: [(0,1),(2,3)], 14: [(0,1),(2,3),(3,4),(5,6)],
                    15: [(0,1),(2,3),(4,5)]}
        for track in tracks:
            actual = [(change["case_input_state"], change["case_output_state"])
                      for change in track["transitions"] if change["source"]["file"] == "LORETALK.PAS"]
            self.assertEqual(actual, expected[track["slot"]])

    def test_direct_stage_assignment_and_parallel_gate_are_retained(self):
        tracks = self.outputs["progression.json"]["quest_state_tracks"]
        gaia = next(track for track in tracks if track["slot"] == 14)
        water = next(track for track in tracks if track["slot"] == 15)
        self.assertTrue(any(c.get("assigned_state") == 2 and c["source"]["file"] == "LORESPEC.PAS" for c in gaia["transitions"]))
        self.assertEqual({c["assigned_state"] for c in water["transitions"] if "assigned_state" in c}, {2,4})
        edges = self.outputs["quests.json"]["route_edges"]
        gate = next(edge for edge in edges if edge["kind"] == "required_all_state_gate")
        self.assertEqual(set(gate["from"]), {"evil_god_seal", "muddy_seal"})
        self.assertIn("odd(party.etc[40]) and odd(party.etc[41])", gate["condition"])

    def test_final_ending_call_and_all_ending_lines_survive(self):
        finale = self.outputs["quests/necromancer_finale.json"]
        self.assertTrue(any("end_demo" in scene["called_routine_candidates"] for scene in finale["scripts"]))
        text = [literal["text"] for scene in finale["scripts"] for literal in scene["text_occurrences"]]
        self.assertIn('                        You must be a genius !!!', text)
        self.assertTrue(any("잋혀진 애기" in line for line in text))

    def test_all_control_sites_and_node_references_are_present(self):
        for unit in self.units:
            for counts in unit["control_site_counts"].values():
                self.assertEqual(counts["source"], counts["extracted"])
            node_ids = {node["id"] for routine in unit["routines"] for node, _ in descendants(routine["body"])}
            literal_ids = {literal["id"] for literal in unit["literals"]}
            for scene in unit["scenes"]:
                if scene["structure_node_id"]:
                    self.assertIn(scene["structure_node_id"], node_ids)
                self.assertTrue(set(scene["text_occurrence_ids"]) <= literal_ids)

    def test_json_round_trip_and_stable_regeneration(self):
        for data in self.outputs.values():
            self.assertEqual(json.loads(json.dumps(data, ensure_ascii=False)), data)


if __name__ == "__main__":
    unittest.main()
