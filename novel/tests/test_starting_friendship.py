"""User-authored friendship disclosure and B1 arc coverage, not literary approval."""
import itertools
import unittest

from materials import ROOT, read
from characters import load_characters
from disclosure import project_character
from interactive import compile_chapter
from prose_variants import apply_variant, VariantSession
from story_continuity import CANON, context_for_routes, matches


class StartingFriendshipTests(unittest.TestCase):
    actors = {'protagonist', 'party_woodcutter', 'party_hunter', 'party_cook', 'party_magician'}

    @classmethod
    def setUpClass(cls):
        cls.master = load_characters()

    def test_all_five_are_mutual_friends_with_explicit_authored_provenance(self):
        directed = set()
        for actor in self.actors:
            card = project_character(self.master, actor, ['castle_arrival'])
            setting = card['writing_overrides']['settings']
            self.assertEqual(setting['origin'], 'authored')
            self.assertEqual(setting['status'], 'proposed')
            self.assertTrue(setting['metadata']['addition'])
            self.assertIn('처음 만나 이름을 익히는 사이로 쓰지 않는다', setting['value'])
            friends = [r for r in card['relationships'] if r['id'].startswith('starting_friends_')]
            self.assertEqual({r['target'] for r in friends}, self.actors - {actor})
            for relation in friends:
                self.assertEqual(relation['relation_type'], 'close_friend')
                self.assertEqual(relation['truth_type'], 'authored')
                self.assertEqual(relation['origin'], 'authored')
                self.assertEqual(relation['status'], 'proposed')
                self.assertEqual(relation['metadata']['kind'], 'new_setting')
                self.assertTrue(relation['metadata']['addition'])
                self.assertEqual(relation['evidence'], [])
                self.assertIn('경로 상태', relation['branch_condition'])
                directed.add((actor, relation['target']))
        self.assertEqual(directed, set(itertools.permutations(self.actors, 2)))

    def test_friendship_is_gated_and_does_not_include_new_recruits_or_spoilers(self):
        for actor in self.actors:
            hidden = project_character(self.master, actor, [])
            self.assertNotIn('writing_overrides', hidden)
            self.assertFalse(any(r['id'].startswith('starting_friends_') for r in hidden['relationships']))
            visible = project_character(self.master, actor, ['castle_arrival'])
            self.assertFalse(any(r['target'] in ('ancient_evil', 'skeleton', 'mad_joe') for r in visible['relationships']))
        for actor in ('skeleton', 'mad_joe'):
            self.assertFalse(any(r['id'].startswith('starting_friends_') for r in self.master['characters'][actor]['relationships']))

    def test_arc_pivots_are_mandatory_not_hidden_in_optional_side_visits(self):
        base, memory, overlay = compile_chapter()
        story = apply_variant(base)
        blocks = {b['id']: b for n in story['nodes'] for b in n['blocks']}
        review = read(ROOT/'writing/variants/B/copyedit-review.json')['passes'][-1]
        self.assertEqual([p['phase'] for p in review['dramatic_arc']], ['기', '승', '전', '결'])
        for phase in review['dramatic_arc']:
            for key in phase['blocks']:
                self.assertEqual(blocks[key]['provenance']['origin'], 'authored')
        # Center paragraphs intentionally suppress duplicates on a detour rejoin;
        # visibility must be checked over the actual reading history, not final state.
        session = VariantSession.__new__(VariantSession)
        session.story, session.memory, session.overlay = story, memory, overlay
        session.packet_for = context_for_routes(story, memory, read(CANON))
        for detour in (False, True):
            route, packet = session.advance([])
            preferred = ['prologue/visit_lord', 'i/depart_now', 'lore_menace/decline_skeleton',
                         'lore_menace/enter_menace', 'i/cave_treasure' if detour else 'lore_menace/return_to_lore',
                         'i/shield_protagonist']
            for _ in range(60):
                if not packet['available_choices']:
                    break
                key = next((k for k in preferred if k in packet['available_choices']), packet['available_choices'][0])
                route, packet = session.choose(route, key)
            self.assertFalse(packet['available_choices'])
            self.assertTrue(packet['main_story']['complete'])
            seen = {key for h in packet['history'] for key in h['visible_block_ids']}
            for phase in review['dramatic_arc']:
                self.assertLessEqual(set(phase['blocks']), seen)
        # All physical variants share the same bad decision / changed decision / honest report.
        for owner, gold in itertools.product(('', *self.actors), (0, 1000)):
            state = {key: row['initial'] for key, row in story['state_definitions'].items()}
            state.update({'event.shield_owner': owner, 'event.gold': gold})
            for key in ('lore_menace/return_arrive', 'i/return_boar_regroup', 'i/return_boar_escape', 'lore_menace/report_words'):
                self.assertTrue(matches(blocks[key]['when'], state))
        self.assertFalse(review['policy']['choices_or_effects_changed'])
        self.assertFalse(review['policy']['A_authored_prose_changed'])
        self.assertFalse(review['policy']['B_chapter02_03_prose_changed'])


if __name__ == '__main__':
    unittest.main()
