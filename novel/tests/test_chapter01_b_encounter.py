"""Actual chapter-one routes and equipment-dependent prose, not literary approval."""
import copy
import itertools
import json
import re
import unittest

from materials import ROOT, read
from interactive import compile_chapter
from prose_variants import apply_variant, VariantSession
from prose_presentation import section_paragraphs
from story_continuity import CANON, context_for_routes, matches


class ChapterOneBEncounterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base, memory, overlay = compile_chapter()
        cls.story = apply_variant(cls.base)
        cls.session = VariantSession.__new__(VariantSession)
        cls.session.story, cls.session.memory, cls.session.overlay = cls.story, memory, overlay
        cls.session.packet_for = context_for_routes(cls.story, memory, read(CANON))
        cls.nodes = {n['id']: n for n in cls.story['nodes']}
        cls.blocks = {b['id']: b for n in cls.story['nodes'] for b in n['blocks']}
        cls.initial = {key: row['initial'] for key, row in cls.story['state_definitions'].items()}
        cls.gear = overlay['initial_equipment']
        cls.review = read(ROOT/'writing/variants/B/copyedit-review.json')['passes'][-1]

    def visible(self, state):
        return {b['id'] for b in self.nodes['lore_menace/return_road']['blocks'] if matches(b['when'], state)}

    def walk(self, town, shield, skeleton):
        route, packet = self.session.advance([])
        preferences = ['prologue/visit_lord', 'i/explore', 'i/visit_'+town,
                       'lore_menace/accept_skeleton' if skeleton else 'lore_menace/decline_skeleton',
                       'lore_menace/enter_menace',
                       'lore_menace/return_to_lore' if shield is None else 'i/cave_treasure',
                       'i/shield_'+(shield or 'cancel')]
        for _ in range(60):
            if not packet['available_choices']:
                return route, packet
            key = next((c for c in preferences if c in packet['available_choices']), packet['available_choices'][0])
            route, packet = self.session.choose(route, key)
        self.fail('chapter route did not terminate')

    def test_real_routes_preserve_main_story_and_show_only_owned_defence(self):
        # Includes no search, search but leave shield, and every possible holder.
        for town, owner, recruit in itertools.product(('armory', 'tavern'), (None, 'cancel', 'protagonist', *self.gear), (False, True)):
            with self.subTest(town=town, owner=owner, skeleton=recruit):
                route, packet = self.walk(town, owner, recruit)
                self.assertTrue(packet['main_story']['complete'])
                self.assertEqual(len(packet['main_story']['seen_scenes']), 17)
                self.assertEqual(packet['state']['event.visited.armory'], town=='armory')
                self.assertEqual(packet['state']['event.visited.tavern'], town=='tavern')
                expected = '' if owner in (None, 'cancel') else owner
                self.assertEqual(packet['state']['event.shield_owner'], expected)
                entry = next(h for h in packet['history'] if h['node_id']=='lore_menace/return_road')
                visible = set(entry['visible_block_ids'])
                guards = {b for b in visible if b.startswith('i/return_boar_shield_') and b!='i/return_boar_shield_after'}
                self.assertEqual(guards, {'i/return_boar_shield_'+expected} if expected else set())
                self.assertEqual('i/return_boar_no_shield' in visible, not expected)
                self.assertEqual('i/return_boar_gold' in visible, packet['state']['event.gold']>0)
                self.assertEqual('i/return_boar_gold_after' in visible, packet['state']['event.gold']>0)
                self.assertIn('i/return_boar_escape', visible)
                self.assertIn('i/return_boar_arrive', visible)
                if expected=='party_woodcutter':self.assertNotIn('i/return_boar_axe', visible)
                if expected=='party_magician':self.assertNotIn('i/return_boar_wand', visible)
                if expected=='party_hunter':self.assertNotIn('i/return_boar_hunter', visible)
                if expected=='party_cook':self.assertNotIn('i/return_boar_cook', visible)
                # The encounter itself changes no inventory or quest/party state.
                before = self.session.packet_for(route[:route.index('lore_menace/report_success')])
                after = self.session.packet_for(route[:route.index('lore_menace/report_success')+1])
                self.assertEqual(before['state'], after['state'])

    def test_guards_require_current_companion_current_weapon_and_free_hands(self):
        actions = {'party_woodcutter':'axe', 'party_hunter':'hunter', 'party_cook':'cook', 'party_magician':'wand'}
        for actor, item in self.gear.items():
            for present, equipped, holds_shield in itertools.product((False,True), repeat=3):
                state = copy.deepcopy(self.initial)
                if not present:state['companions.starting'].remove(actor)
                state['event.weapon.'+actor] = item if equipped else 'weapon_0'
                state['event.shield_owner'] = actor if holds_shield else ''
                self.assertEqual('i/return_boar_'+actions[actor] in self.visible(state), present and equipped and not holds_shield)

    def test_maintenance_payoff_requires_a_real_armory_visit(self):
        for actor, action in [('party_woodcutter','axe'), ('party_magician','wand')]:
            for visited, used, blocked in itertools.product((False,True), repeat=3):
                state = copy.deepcopy(self.initial)
                state['event.visited.armory'], state['event.armory_used'] = visited, used
                state['event.shield_owner'] = actor if blocked else ''
                visible = self.visible(state)
                self.assertEqual('i/return_boar_'+action+'_prepared' in visible, visited and not blocked)
                self.assertEqual('i/return_boar_'+action+'_unprepared' in visible, not visited and not blocked)

    def test_A_has_no_encounter_or_empty_visible_paragraphs(self):
        base = {b['id']: b for n in self.base['nodes'] for b in n['blocks']}
        added = [key for key in self.blocks if key.startswith('i/return_boar_')]
        self.assertEqual(len(added), 20)
        page = (ROOT/'writing/previews/chapter01-interactive.html').read_text()
        payload = json.loads(re.search(r'id="chapter-data">(.*?)</script>', page, re.S)[1])
        state = copy.deepcopy(self.initial)
        for key in added:
            self.assertEqual(base[key]['text'], [{'text':''}])
            node = {'blocks':[base[key]]}
            self.assertEqual(section_paragraphs(node,[key],state,payload), [])
            self.assertTrue(self.blocks[key]['text'])

    def test_sequence_and_narrative_revisions_are_marked_without_new_rewards(self):
        self.assertEqual(self.review['scope'], ['chapter01', 'chapter02', 'chapter03'])
        self.assertEqual(self.review['reviewed_existing_blocks']['chapter01'], 294)
        self.assertFalse(self.review['policy']['choices_or_effects_changed'])
        self.assertFalse(self.review['policy']['A_authored_prose_changed'])
        ids = [b['id'] for b in self.nodes['lore_menace/return_road']['blocks']]
        self.assertLess(ids.index('lore_menace/return_outside'), ids.index('lore_menace/return_arrive'))
        self.assertLess(ids.index('i/return_boar_escape'), ids.index('i/return_boar_arrive'))
        for key in ids:
            if key.startswith('i/return_boar_'):
                self.assertEqual(self.blocks[key]['provenance']['origin'], 'authored')
                self.assertNotIn('effects', self.blocks[key])
        plain = lambda key:''.join(s.get('text','') for s in self.blocks[key]['text'])
        self.assertIn('“안녕하세요.”', plain('i/tavern_story_entry_after'))
        self.assertNotIn('대답이 조금 작았다', plain('i/tavern_story_entry_after'))
        self.assertIn('성문', plain('i/return_boar_arrive'))
        self.assertIn('멧돼지', plain('lore_menace/report_words'))


if __name__=='__main__':unittest.main()
