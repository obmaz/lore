"""Real JSON choices, source/main gates, role conditions, replay and safe merging."""
import copy
import unittest

import jsonschema

from branch_system import BranchSession, PLAN, branch_document
from materials import read
from text_refs import indexes, literals, render


class BranchSystemTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.session = BranchSession()
        cls.plan = read(PLAN)

    def engine(self, plan):
        return BranchSession(plan, self.session.outline, self.session.profiles, self.session.references)

    def finish(self, prefix=(), seal='seal_order/evil_first', shelter='shelter_prepare/food'):
        route = list(prefix)
        while True:
            p = self.session.replay(route)
            if p['status'] == 'complete': return route, p
            available = [o['id'] for o in p['available_options']]
            preferred = seal if p['decision_id'] == 'seal_order' else shelter if p['decision_id'] == 'shelter_prepare' else available[0]
            route.append(preferred)

    def test_01_all_declared_paths_are_reachable_and_preserve_every_main_unit(self):
        r = self.session.validate_paths()
        self.assertEqual((r['main_units'], r['decisions'], r['options'], r['complete_paths'], r['required_beats']), (88, 6, 14, 96, 44))
        self.assertEqual(len(r['deferred_candidate_units']), 25)
        self.assertEqual(r['prose'], 'outline')
        self.assertEqual(r['dialogue_coverage'], 'partial')
        self.assertFalse(r['public_reader_updated'])

    def test_02_choices_apply_equipment_and_members_without_overwriting_job_weapons(self):
        p = self.session.replay(['prepare/armory', 'company/join'])
        self.assertEqual(p['state']['equipment.protagonist'], 'weapon_1')
        self.assertIn('weapon_1', p['state']['inventory'])
        self.assertEqual(p['state']['party.optional'], 'skeleton')
        self.assertEqual(len(p['state']['party.members']), 6)
        for actor, weapon in [('party_woodcutter', 'story_axe'), ('party_hunter', 'story_bow'), ('party_cook', 'story_knife'), ('party_magician', 'story_wand')]:
            self.assertEqual(p['state']['equipment.'+actor], weapon)
        q = self.session.replay(['prepare/self', 'company/leave'])
        self.assertNotIn('weapon_1', q['state']['inventory'])
        self.assertEqual(q['state']['equipment.protagonist'], '')
        self.assertNotIn('skeleton', q['state']['party.members'])

    def test_03_conversation_has_its_own_later_story_not_only_a_flag(self):
        direct = self.session.replay(['prepare/self', 'company/join'])
        talked = self.session.replay(['prepare/self', 'company/talk_join'])
        self.assertNotIn('skeleton_memory', [h.get('id') for h in direct['history']])
        self.assertIn('skeleton_memory', [h.get('id') for h in talked['history']])
        self.assertTrue(any(h['kind']=='choice' and h['text'] for h in talked['history']))

    def test_04_occupied_slot_prevents_second_recruit_and_single_option_is_automatic(self):
        p = self.session.replay(['prepare/self', 'company/join', 'aid/together'])
        self.assertEqual(p['decision_id'], 'seal_order')
        self.assertIn('spica_company/continue', p['automatic_options'])
        self.assertNotIn('spica', p['state']['party.members'])
        q = self.session.replay(['prepare/self', 'company/leave', 'aid/together'])
        self.assertEqual(q['decision_id'], 'spica_company')
        q = self.session.replay(['prepare/self', 'company/leave', 'aid/together', 'spica_company/join'])
        self.assertEqual(q['state']['party.optional'], 'spica')
        self.assertIn('spica_present', [h.get('id') for h in q['history']])

    def test_05_both_parallel_orders_change_real_main_reading_order_and_finish_both(self):
        prefix = ['prepare/self', 'company/leave', 'aid/together', 'spica_company/continue']
        for first, earlier, later in [('seal_order/evil_first', 'chapter09/p02', 'chapter09/p04'), ('seal_order/muddy_first', 'chapter09/p04', 'chapter09/p02')]:
            route, p = self.finish(prefix, seal=first)
            self.assertLess(p['visited_units'].index(earlier), p['visited_units'].index(later))
            self.assertTrue(p['state']['seals.evil_god'] and p['state']['seals.muddy'])
            self.assertEqual(len(p['visited_units']), len(set(p['visited_units'])))
            self.assertEqual((len(p['visited_units']), len(p['completed_beats'])), (88, 44))
            self.assertEqual(len([h for h in p['history'] if h['kind']=='outcome']), 88)
            self.assertEqual(next(h['title'] for h in p['history'] if h['kind']=='main' and h['unit_id']=='chapter09/p06'), '시험 끝의 봉인을 해제하다')

    def test_06_rewards_and_future_information_only_arrive_at_main_events(self):
        early = self.session.replay([])
        self.assertFalse(early['state']['keys.water'])
        self.assertFalse(early['state']['knowledge.prophecy'])
        self.assertFalse(early['state']['knowledge.impostor'])
        self.assertEqual(early['state']['party.rank'], '')
        _, late = self.finish()
        self.assertTrue(late['state']['quest.finished'])
        self.assertTrue(late['state']['keys.water'] and late['state']['keys.swamp'])
        self.assertEqual(late['state']['party.rank'], 'semi_god')
        p = copy.deepcopy(self.plan)
        p['decisions'][0]['options'][0]['effects'][0]['state'] = 'knowledge.impostor'
        with self.assertRaisesRegex(ValueError, 'protected'): self.engine(p)

    def test_07_state_types_unknown_ids_predicates_and_operations_are_checked(self):
        for mode in ('type', 'reference', 'predicate', 'set_operation', 'initial_truth', 'domain', 'empty_reference'):
            p = copy.deepcopy(self.plan)
            o = p['decisions'][0]['options'][0]
            if mode == 'type': o['effects'][0]['value'] = 1
            elif mode == 'reference': o['effects'][1]['value'] = 'fake_weapon'
            elif mode == 'predicate': o['when'] = {'state': 'not_declared', 'op': 'eq', 'value': True}
            elif mode == 'set_operation': o['effects'][0]['op'] = 'add'
            elif mode == 'initial_truth': p['state_definitions']['knowledge.impostor']['initial'] = True
            elif mode == 'domain': p['state_definitions']['party.optional']['reference_catalog'] = None
            else: o['effects'][1]['value'] = ''
            with self.assertRaisesRegex(ValueError, 'type|reference|predicate|set|future'): self.engine(p)

    def test_08_effects_are_atomic_and_cannot_equip_unowned_items_or_duplicate_slots(self):
        state = self.session.replay([])['state']
        before = copy.deepcopy(state)
        effects = [dict(self.plan['decisions'][0]['options'][0]['effects'][2])]
        with self.assertRaisesRegex(ValueError, 'owned'): self.session._commit(effects, state)
        self.assertEqual(state, before)
        effects = copy.deepcopy(self.plan['decisions'][1]['options'][0]['effects'])
        effects[1]['value'] = 'spica'
        with self.assertRaisesRegex(ValueError, 'disagree'): self.session._commit(effects, state)
        self.assertEqual(state, before)

    def test_09_role_choices_and_reactions_need_actual_member_and_equipment(self):
        state = self.session.replay([])['state']
        cook = self.plan['decisions'][2]['options'][0]['participants']
        self.assertTrue(self.session._participants_present(cook, state))
        state['equipment.party_cook'] = ''
        self.assertFalse(self.session._participants_present(cook, state))
        state['equipment.party_cook'] = 'story_knife'
        state['party.members'].remove('party_cook')
        self.assertFalse(self.session._participants_present(cook, state))
        _, food = self.finish(shelter='shelter_prepare/food')
        _, gear = self.finish(shelter='shelter_prepare/equipment')
        self.assertIn('food_preparation', [h.get('id') for h in food['history']])
        self.assertNotIn('equipment_preparation', [h.get('id') for h in food['history']])
        self.assertIn('equipment_preparation', [h.get('id') for h in gear['history']])

    def test_10_save_replays_ids_not_injected_state_and_new_input_invalidates_save(self):
        route = ['prepare/armory', 'company/talk_join']
        saved = self.session.save(route)
        self.assertEqual(self.session.restore(saved)['state'], self.session.replay(route)['state'])
        for mode in ('state', 'fingerprint', 'extra', 'future', 'long', 'type'):
            s = copy.deepcopy(saved)
            if mode == 'state': s['state'] = {'keys.water': True}
            elif mode == 'fingerprint': s['fingerprint'] = 'wrong'
            elif mode == 'extra': s['visited_units'] = list(self.session.units)
            elif mode == 'future': s['route'] = ['seal_order/muddy_first']
            elif mode == 'long': s['route'] = route*20
            else: s['route'] = [42]
            with self.assertRaises(ValueError): self.session.restore(s)
        p = copy.deepcopy(self.plan); p['revision'] += 1
        with self.assertRaisesRegex(ValueError, 'incompatible'): self.engine(p).restore(saved)

    def test_11_no_out_of_order_repeated_automatic_or_post_ending_choices(self):
        for route in (['aid/cook'], ['prepare/self', 'prepare/self'], ['prepare/self', 'company/join', 'aid/together', 'spica_company/continue']):
            with self.assertRaisesRegex(ValueError, 'unavailable'): self.session.replay(route)
        route, _ = self.finish()
        with self.assertRaisesRegex(ValueError, 'ending'): self.session.replay(route+['prepare/self'])
        with self.assertRaisesRegex(ValueError, 'unavailable'): self.session.choose([], 'seal_order/muddy_first')

    def test_12_main_rejoin_parallel_permutation_source_and_revision_are_validated(self):
        for mode in ('rejoin', 'order', 'source', 'revision', 'duplicate', 'unmarked', 'empty'):
            p = copy.deepcopy(self.plan)
            if mode == 'rejoin': p['decisions'][0]['rejoin_before'] = 'chapter02/p01'
            elif mode == 'order': p['parallel_orders'][0]['orders']['seal_order/muddy_first'] = [1]
            elif mode == 'source': p['decisions'][0]['source_section_refs'] = ['15-final']
            elif mode == 'revision': p['subsection_revision'] += 1
            elif mode == 'duplicate': p['decisions'][0]['options'][1]['id'] = p['decisions'][0]['options'][0]['id']
            elif mode == 'unmarked': p['decisions'][0]['options'][0]['metadata']['addition'] = False
            else: p['unit_rules']['chapter01/p05']['content_override'] = [{'text': ''}]
            with self.assertRaises((ValueError, jsonschema.ValidationError)): self.engine(p)

    def test_13_missing_gate_reward_dead_end_and_path_limit_are_not_claimed_verified(self):
        for mode in ('reward', 'deadend', 'limit', 'unreachable'):
            p = copy.deepcopy(self.plan)
            if mode == 'reward': p['unit_rules']['chapter09/p03']['effects'] = []
            elif mode == 'deadend':
                for o in p['decisions'][0]['options']: o['when'] = False
            elif mode == 'limit': p['limits']['max_paths'] = 1
            else: p['decisions'][0]['options'][0]['when'] = False
            with self.assertRaisesRegex(ValueError, 'entry|dead end|limit|unreachable'): self.engine(p).validate_paths()

    def test_14_output_is_author_only_outline_and_names_remain_reference_bound(self):
        text = self.plan['decisions'][0]['options'][0]['body']
        profiles = copy.deepcopy(self.session.profiles)
        profiles['characters']['protagonist']['writing_name']['value'] = '하나'
        value = render(text, indexes(profiles, self.session.references), literals(), profiles, author=True)
        self.assertIn('하나는', value)
        page = branch_document(self.session)
        self.assertIn('작가 전용', page)
        self.assertIn('전편 스포일러', page)
        self.assertIn('JSON 조건', page)
        self.assertNotIn('onclick="print()"', page)
        packet = self.session.replay([])
        self.assertEqual(packet['visibility'], 'author_only')
        self.assertNotIn('character_profiles', packet)
