import copy
import unittest

from materials import ROOT, read
from reading import compile_reading, load_reading
from story_continuity import CANON, context, context_for_routes, validate
from text_refs import archival, literals, source_ids
from validate_story_authoring import validate as validate_story


class FirstChapterTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.opening = read(ROOT/'writing/quests/prologue.json')
        cls.opening_memory = read(ROOT/'writing/quests/prologue.continuity.json')
        cls.chapter = read(ROOT/'writing/quests/lore_menace.json')
        cls.chapter_memory = read(ROOT/'writing/quests/lore_menace.continuity.json')
        cls.recipes = read(ROOT/'writing/reading.json')['routes']
        cls.story,cls.memory,cls.route = load_reading(cls.recipes['first-journey'])
        cls.packet_for = staticmethod(context_for_routes(cls.story,cls.memory,read(CANON)))
        cls.accepted = cls.packet_for(cls.route)
        cls.declined_route = [c.replace('accept_skeleton','decline_skeleton') for c in cls.route]
        cls.declined = cls.packet_for(cls.declined_route)
        cls.tavern_route = ['prologue/enter_courtyard','prologue/visit_tavern','prologue/remember_veteran',*cls.route[1:]]
        cls.tavern = cls.packet_for(cls.tavern_route)

    def test_four_review_routes_end_at_next_quest_boundary(self):
        self.assertEqual(len([k for k in self.recipes if k.startswith('first-journey')]),4)
        for route in [self.route,self.declined_route,self.tavern_route,[c.replace('accept_skeleton','decline_skeleton') for c in self.tavern_route]]:
            packet = self.packet_for(route)
            self.assertEqual(packet['handoff_packet']['quest_id'],'lastditch_pyramid')
            self.assertEqual(packet['state']['quest.lore_stage'],6)
            self.assertTrue(packet['state']['quest.menace_reward_claimed'])

    def test_optional_companion_and_knowledge_do_not_merge(self):
        self.assertEqual(self.accepted['state']['companions.optional_recruits'],['skeleton'])
        self.assertEqual(self.declined['state']['companions.optional_recruits'],[])
        self.assertEqual(self.accepted['knowledge']['protagonist'],self.declined['knowledge']['protagonist'])
        self.assertIn('skeleton_departure_account',self.declined['knowledge']['protagonist'])
        self.assertNotIn('menace_assignment_account',self.declined['knowledge']['skeleton'])
        self.assertIn('menace_assignment_account',self.accepted['knowledge']['skeleton'])
        self.assertNotIn('skeleton',self.declined['character_profiles'])
        self.assertIn('skeleton',self.accepted['character_profiles'])

    def test_optional_tavern_memory_survives_file_boundary(self):
        self.assertFalse(self.accepted['state']['knowledge.missing_squad'])
        self.assertTrue(self.tavern['state']['knowledge.missing_squad'])
        self.assertIn('veteran_story',self.tavern['knowledge']['protagonist'])
        self.assertNotIn('veteran_story',self.accepted['knowledge']['protagonist'])
        direct = self.packet_for(self.route[:5])
        tavern = self.packet_for(self.tavern_route[:7])
        ids = lambda p:{b['id'] for b in p['visible_blocks']}
        self.assertNotIn('lore_menace/request_veteran_memory',ids(direct))
        self.assertIn('lore_menace/request_veteran_memory',ids(tavern))

    def test_only_actual_prior_events_reveal_information(self):
        self.assertEqual(self.accepted['disclosed_events'],['castle_arrival','lord_assignment','lord_briefing'])
        self.assertNotIn('prisoner_account',self.accepted['disclosed_events'])
        self.assertNotIn('world_prophecy',self.accepted['disclosed_events'])
        self.assertNotIn('squad_whereabouts',self.accepted['knowledge']['protagonist'])

    def test_conditional_event_skips_absent_companion(self):
        accepted = {e['id'] for e in self.accepted['proposed_events']}
        declined = {e['id'] for e in self.declined['proposed_events']}
        self.assertIn('lore_menace/companion_next_direction_heard',accepted)
        self.assertNotIn('lore_menace/companion_next_direction_heard',declined)
        self.assertIn('lastditch_direction_account',self.accepted['knowledge']['skeleton'])
        self.assertNotIn('lastditch_direction_account',self.declined['knowledge']['skeleton'])

    def test_source_core_dialogues_are_preserved_without_retyping(self):
        raw = literals()
        used = {i for n in self.chapter['nodes'] for b in n['blocks'] for i in source_ids(b['text'])}
        ranges = {'LORETALK.PAS':[(340,355),(359,359),(363,364),(371,376),(380,380)],'LORESPEC.PAS':[(265,265),(275,285),(828,830)]}
        expected = {i for i,l in raw.items() if l['role']=='display_text_fragment' and any(a<=l['source']['line']<=b for a,b in ranges.get(l['source']['file'],[]))}
        self.assertEqual(used,expected)
        for n in self.chapter['nodes']:
            for b in n['blocks']:
                if b['kind']=='source_quote':
                    self.assertEqual(archival(b['text'],raw),''.join(raw[i]['text'] for i in b['literal_ids']))
        counter = next(b for n in self.chapter['nodes'] for b in n['blocks'] if b['id']=='reward_counter_quote')
        self.assertIsNone(counter['speaker'])
        self.assertEqual(archival(counter['text'],raw),'[EXP + 1000]')

    def test_actual_source_choice_labels_are_both_retained(self):
        choices = next(n for n in self.chapter['nodes'] if n['id']=='castle_exit')['choices']
        for c in choices:
            self.assertEqual(c['provenance']['origin'],'source_exact')
            self.assertEqual(c['label'][0]['text'],literals()[c['label_literal_id']]['text'])

    def test_unused_equipment_and_gold_are_not_awarded(self):
        self.assertFalse(any('inventory' in key or 'gold' in key for key in self.accepted['state']))
        deferred = {r['ref'] for r in self.chapter['coverage']['deferred_source_refs']}
        self.assertEqual(deferred,{'armory_pending','joe_pending','guard_pending','treasure_pending'})
        choices = {d['literal_id']:d['handling'] for d in self.chapter['coverage']['literal_dispositions']}
        for i,l in literals().items():
            if l['source']['file']=='LORETALK.PAS' and l['source']['line'] in (195,196):
                self.assertEqual(choices[i],'pending')

    def test_partial_coverage_and_added_prose_are_not_auto_approved(self):
        result = validate_story(self.chapter)
        self.assertEqual((result['nodes'],result['choices'],result['blocks']),(14,15,77))
        self.assertEqual(result['coverage'],'partial')
        self.assertEqual(result['unaccounted_scoped_literals'],0)
        self.assertEqual(self.accepted['committed_events'],[])
        self.assertTrue(self.accepted['knowledge_is_provisional'])
        authored = [b for n in self.chapter['nodes'] for b in n['blocks'] if b['kind']!='source_quote']
        self.assertTrue(all(b['provenance']['origin']=='authored' and '추가' in b['provenance']['note'] for b in authored))
        self.assertNotIn('홍길동',(ROOT/'writing/quests/lore_menace.json').read_text())

    def test_standalone_chapter_cannot_invent_prior_briefing(self):
        with self.assertRaisesRegex(ValueError,'lacks knowledge'):
            context(self.chapter,self.chapter_memory,read(CANON),[])

    def test_wrong_handoff_entry_and_missing_carry_flag_fail(self):
        for field in ['entry','carry']:
            opening = copy.deepcopy(self.opening)
            handoff = opening['nodes'][-1]['handoff']
            if field=='entry': handoff['entry_node']='wrong_entry'
            else: handoff['carry_states']=[]
            with self.assertRaisesRegex(ValueError,'handoff|shared states'):
                compile_reading([(opening,self.opening_memory),(self.chapter,self.chapter_memory)])

    def test_unfinished_previous_route_cannot_cross_file_boundary(self):
        recipe = copy.deepcopy(self.recipes['first-journey'])
        recipe['parts'][0]['route']=['enter_courtyard']
        with self.assertRaisesRegex(ValueError,'does not reach'):
            load_reading(recipe)

    def test_reading_paths_cannot_escape_quest_folder(self):
        recipe = copy.deepcopy(self.recipes['first-journey'])
        recipe['parts'][0]['file']='../../reference/names.json'
        with self.assertRaisesRegex(ValueError,'escapes'):
            load_reading(recipe)

    def test_unknown_conditional_event_state_fails_validation(self):
        memory = copy.deepcopy(self.chapter_memory)
        memory['event_templates'][0]['when']={'state':'not_declared','op':'eq','value':True}
        with self.assertRaisesRegex(ValueError,'unknown condition state'):
            validate(self.chapter,memory,read(CANON))

    def test_frozen_context_does_not_accept_mutated_source_inputs(self):
        story = copy.deepcopy(self.story)
        replay = context_for_routes(story,self.memory,read(CANON))
        story['state_definitions']['quest.lore_stage']['initial']=99
        self.assertEqual(replay([])['state']['quest.lore_stage'],2)

    def test_optional_direction_reminder_preserves_stage_and_companion_choice(self):
        route = [*self.route[:6],'lore_menace/ask_directions_again','lore_menace/finish_reminder',*self.route[7:]]
        packet = self.packet_for(route)
        self.assertEqual(packet['state'],self.accepted['state'])
        self.assertEqual(packet['knowledge'],self.accepted['knowledge'])


if __name__=='__main__': unittest.main()
