"""Independent first-chapter branch/state/archival regression checks."""
import copy
import itertools
import json
import os
import subprocess
import sys
import unittest

from interactive import Session, compile_chapter
from materials import ROOT, read
from text_refs import archival, indexes, literals, render
from characters import load_characters
from reference import load_references
from story_continuity import matches

INTRO = ['prologue/enter_courtyard','prologue/visit_lord','prologue/hear_lord_intro',
         'prologue/hear_lord_briefing','prologue/first_quest_boundary/continue','lore_menace/receive_assignment']


class InteractiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.session = Session()
        cls.nodes = {n['id']:n for n in cls.session.story['nodes']}
        cls.profiles = load_characters()
        cls.witnessed = set()

    def walk(self,choices,route=None):
        route = list(route or [])
        for choice in choices:
            packet = self.session.replay(route)
            self.witnessed.update(b['id'] for b in packet['visible_blocks'])
            route,packet = self.session.choose(route,choice)
        self.witnessed.update(b['id'] for b in packet['visible_blocks'])
        return route,packet

    def town(self,choices):
        return self.walk([*INTRO,'i/explore',*choices])

    def finish(self,route,skeleton=True,roles=(),treasure=()):
        packet = self.session.replay(route)
        if packet['node_id']=='i/hub': route,packet = self.walk(['i/depart_now'],route)
        if packet['node_id']=='lore_menace/preparation': route,packet = self.walk(['lore_menace/leave_castle'],route)
        if packet['node_id']=='i/threshold': route,packet = self.walk(['i/threshold_yes','i/threshold_outside'],route)
        if packet['node_id']=='lore_menace/castle_exit':
            route,packet = self.walk(['lore_menace/accept_skeleton' if skeleton else 'lore_menace/decline_skeleton'],route)
        route,packet = self.walk(['lore_menace/set_out'],route)
        if roles:
            route,packet = self.walk(['i/choose_role'],route)
            for actor in roles: route,packet = self.walk(['i/use_'+actor,'i/role_back_'+actor],route)
            route,packet = self.walk(['i/role_finish'],route)
        else: route,packet = self.walk(['lore_menace/enter_menace'],route)
        route,packet = self.walk(['lore_menace/walk_deeper','lore_menace/confirm_center'],route)
        if treasure: route,packet = self.walk(['i/cave_treasure',*treasure],route)
        route,packet = self.walk(['lore_menace/return_to_lore','lore_menace/report_success',
            'lore_menace/acknowledge_reward','lore_menace/hear_next_task','lore_menace/leave_audience'],route)
        self.assertEqual(packet['state']['quest.lore_stage'],6)
        self.assertTrue(packet['state']['quest.menace_reward_claimed'])
        return route,packet

    def test_01_four_separate_authored_cards_and_weapons(self):
        expected = [('party_woodcutter','나무꾼','story_axe'),('party_hunter','사냥꾼','story_bow'),
                    ('party_cook','요리사','story_knife'),('party_magician','마술사','story_wand')]
        refs = load_references()
        for key,name,weapon in expected:
            p = self.profiles['characters'][key]
            self.assertEqual(p['writing_name']['value'],name)
            self.assertEqual(p['biography']['occupation']['value'],name)
            self.assertIsNone(p['canonical_name']['value'])
            self.assertIsNone(p['biography']['age']['value'])
            self.assertTrue(p['biography']['occupation']['metadata']['addition'])
            self.assertEqual(p['resource_refs']['equipment'],[weapon])
            self.assertEqual(p['resource_refs']['abilities'],[])
            self.assertIsNone(refs['equipment']['items'][weapon]['original_name']['value'])
            self.assertEqual(refs['equipment']['items'][weapon]['writing_name']['origin'],'authored')
        self.assertEqual(self.profiles['characters']['initial_merlin']['canonical_name']['value'],'Merlin')

    def test_02_skip_every_optional_place(self):
        route,packet = self.walk(INTRO)
        route,packet = self.finish(route,skeleton=False)
        self.assertEqual(packet['state']['event.city_visits'],0)
        self.assertFalse(packet['state']['event.armory_used'])
        self.assertEqual(packet['state']['event.gold'],0)
        self.assertEqual(packet['state']['companions.optional_recruits'],[])
        self.assertEqual(packet['state']['event.slot6'],'')
        self.assertNotIn('skeleton',packet['character_profiles'])
        self.assertFalse(any(e['id']=='lore_menace/mission_shared' for e in packet['proposed_events']))

    def test_03_armory_first_keeps_profession_weapons(self):
        route,packet = self.walk([*INTRO,'i/armory_first','i/armory_finish','i/armory_back'])
        self.assertTrue(packet['state']['event.armory_used'])
        self.assertEqual(packet['state']['event.armory_order'],'first')
        for p,w in self.session.overlay['initial_equipment'].items(): self.assertEqual(packet['state']['event.weapon.'+p],w)
        self.finish(route)

    def test_04_every_pair_of_region_orders_and_three_visit_auto(self):
        simple = {'armory':['i/armory_finish','i/armory_back'],'streets':['i/streets_back'],
                  'grave':['i/grave_back'],'support':['i/support_back'],'mine_lore':['i/mine_lore_back']}
        for regions in itertools.permutations(simple,2):
            route,packet = self.town([c for r in regions for c in ['i/visit_'+r,*simple[r]]])
            self.assertEqual(packet['state']['event.city_visits'],2)
            self.assertEqual(packet['node_id'],'i/hub')
        route,packet = self.town(['i/visit_armory','i/armory_finish','i/armory_back','i/visit_streets','i/streets_back','i/visit_mine_lore','i/mine_lore_back'])
        self.assertEqual(packet['state']['event.city_visits'],3)
        self.assertEqual(packet['node_id'],'i/threshold')
        self.assertEqual(route[-1],'i/depart_now')
        self.finish(route)

    def test_05_same_region_cannot_repeat(self):
        route,packet = self.town(['i/visit_mine_lore','i/mine_lore_back'])
        self.assertNotIn('i/visit_mine_lore',packet['available_choices'])
        with self.assertRaises(ValueError):self.session.choose(route,'i/visit_mine_lore')

    def test_06_both_tavern_greetings_and_late_testimony(self):
        for greeting,follow in [('personal','i/hear_tavern_people'),('menu','i/hear_tavern_people_menu')]:
            route,packet = self.town(['i/visit_tavern','i/tavern_'+greeting,follow,'i/late_veteran','i/late_veteran_back'])
            self.assertTrue(packet['state']['knowledge.missing_squad'])
            self.assertIn('veteran_story',packet['knowledge']['protagonist'])
            self.finish(route)
        route,packet = self.walk(['prologue/enter_courtyard','prologue/visit_tavern','prologue/remember_veteran'])
        self.assertNotIn('prologue/visit_tavern',packet['available_choices'])

    def test_07_grave_chest_only_after_actual_visit(self):
        route,packet = self.town(['i/visit_grave','i/grave_chest','i/grave_chest_back'])
        self.assertEqual(packet['state']['event.gold'],1000)
        self.assertIn('antares_testimony',packet['disclosed_events'])
        self.assertNotIn('red_antares',packet['state']['companions.optional_recruits'])
        self.finish(route)

    def test_08_repeated_conditional_city_lines(self):
        route,_ = self.town(['i/visit_streets','i/streets_repeat_hint','i/street_second_back','i/visit_support','i/support_again','i/support_repeat_back'])
        self.finish(route)

    def test_09_prison_refusal_no_free_recruit(self):
        route,packet = self.town(['i/visit_prison','i/prison_request','i/decline_joe','i/joe_declined_back'])
        self.assertEqual(packet['state']['companions.optional_recruits'],[])
        self.assertFalse(packet['state']['event.joe_accepted'])
        self.assertIn('prisoner_account',packet['disclosed_events'])
        self.finish(route)

    def test_10_prison_front_and_joe_flee_on_battle_start(self):
        route,packet = self.town(['i/visit_prison','i/prison_request','i/accept_joe','i/joe_guard_exit'])
        self.assertTrue(packet['state']['event.joe_accepted'])
        self.assertTrue(packet['state']['event.joe_fled'])
        self.assertEqual(packet['state']['event.slot6'],'')
        self.assertEqual(packet['state']['companions.optional_recruits'],[])
        self.assertIn('i/joe_flee',{b['id'] for b in packet['visible_blocks']})
        route,_ = self.walk(['i/guard_win','i/guard_victory_back'],route)
        self.finish(route)

    def test_11_guard_repeat_after_escape_not_first_visit(self):
        route,packet = self.town(['i/visit_prison','i/prison_request','i/accept_joe','i/joe_guard_exit','i/guard_escape','i/guard_try_again'])
        self.assertTrue(packet['state']['event.guard_fight_seen'])
        self.assertIn('i/guard_repeat_words',{b['id'] for b in packet['visible_blocks']})
        route,_ = self.walk(['i/guard_repeat_leave','i/guard_repeat_leave_back'],route)
        self.finish(route)

    def test_12_quiet_exit_keeps_joe_and_skeleton_refusal(self):
        route,packet = self.town(['i/visit_prison','i/prison_service','i/service_inside','i/accept_joe','i/joe_quiet_exit','i/joe_quiet_back'])
        self.assertEqual(packet['state']['event.slot6'],'mad_joe')
        self.assertFalse(packet['state']['event.joe_fled'])
        route,packet = self.finish(route,skeleton=False)
        self.assertEqual(packet['state']['companions.optional_recruits'],['mad_joe'])
        self.assertIn('menace_assignment_account',packet['knowledge']['mad_joe'])
        self.assertIn('lastditch_direction_account',packet['knowledge']['mad_joe'])
        self.assertNotIn('skeleton',packet['character_profiles'])

    def test_13_replace_slot_confirmed_never_two_optional_companions(self):
        route,_ = self.town(['i/visit_prison','i/prison_service','i/service_inside','i/accept_joe','i/joe_quiet_exit','i/joe_quiet_back','i/depart_now','i/threshold_yes','i/threshold_outside'])
        packet = self.session.replay(route)
        self.assertNotIn('lore_menace/accept_skeleton',packet['available_choices'])
        route,packet = self.walk(['i/skeleton_replace','i/replace_confirm','lore_menace/accept_skeleton'],route)
        self.assertEqual(packet['state']['companions.optional_recruits'],['skeleton'])
        self.assertEqual(packet['state']['event.slot6'],'skeleton')
        self.finish(route)

    def test_14_skeleton_conversation_once_and_threshold_refusal(self):
        route,packet = self.walk([*INTRO,'lore_menace/leave_castle','i/threshold_no','i/threshold_reconsider'])
        self.assertNotIn('i/threshold_no',packet['available_choices'])
        route,packet = self.walk(['i/threshold_yes','i/threshold_outside','i/skeleton_ask','i/conversation_back'],route)
        self.assertNotIn('i/skeleton_ask',packet['available_choices'])
        self.assertFalse(any(b['provenance']['origin']=='source_exact' for b in packet['visible_blocks']))
        self.finish(route)

    def test_15_all_profession_reactions_and_real_knowledge(self):
        route,_ = self.walk(INTRO)
        route,packet = self.finish(route,roles=self.session.overlay['party'])
        visible = {b for h in packet['history'] for b in h['visible_block_ids']}
        for p in self.session.overlay['party']:
            self.assertIn('i/role_echo_'+p,visible)
            self.assertIn('i/role_report_'+p,visible)
            self.assertIn('menace_assignment_account',packet['knowledge'][p])
            self.assertIn('lastditch_direction_account',packet['knowledge'][p])
        self.assertIn('menace_assignment_account',packet['knowledge']['skeleton'])

    def test_16_reaction_requires_actor_weapon_and_experience(self):
        story = self.session.story
        condition = next(b for n in story['nodes'] for b in n['blocks'] if b['id']=='i/role_echo_party_hunter')['when']
        state = {k:copy.deepcopy(d['initial']) for k,d in story['state_definitions'].items()}
        self.assertFalse(matches(condition,state))
        state['event.role.party_hunter']=True
        self.assertTrue(matches(condition,state))
        state['event.weapon.party_hunter']='weapon_1'
        self.assertFalse(matches(condition,state))
        state['event.weapon.party_hunter']='story_bow';state['companions.starting'].remove('party_hunter')
        self.assertFalse(matches(condition,state))

    def test_17_all_six_gold_spots_once_and_reward_milestone_preserved(self):
        route,_ = self.walk(INTRO)
        choices=[c for i in range(1,7) for c in ['i/gold_'+str(i),'i/gold_back_'+str(i)]]
        route,packet = self.finish(route,treasure=[*choices,'i/treasure_finish'])
        self.assertEqual(packet['state']['event.gold'],7000)
        self.assertEqual(packet['state']['event.shield_owner'],'')
        center = next(e for e in packet['proposed_events'] if e['id']=='lore_menace/center_confirmed')
        self.assertTrue(center)
        self.assertTrue(all(packet['state']['event.gold_spot_'+str(i)] for i in range(1,7)))

    def test_18_shield_cancel_has_no_item(self):
        route,_ = self.walk(INTRO)
        _,packet = self.finish(route,treasure=['i/shield_find','i/shield_cancel','i/shield_cancel_back'])
        self.assertEqual(packet['state']['event.shield_owner'],'')
        self.assertEqual(packet['state']['event.gold'],0)

    def test_19_shield_recipient_stable_id_in_handoff(self):
        for recipient in ['protagonist',*self.session.overlay['party']]:
            route,_ = self.walk(INTRO)
            _,packet = self.finish(route,treasure=['i/shield_find','i/shield_'+recipient,'i/shield_back'])
            self.assertEqual(packet['handoff_packet']['state']['event.shield_owner'],recipient)
            self.assertIn('companions.starting',packet['handoff_packet']['state'])

    def test_20_no_world_truth_or_future_inventory_in_initial_packet(self):
        packet = self.session.replay([])
        self.assertEqual(packet['disclosed_events'],[])
        self.assertFalse(packet['knowledge'].get('protagonist'))
        self.assertNotIn('red_antares',packet['character_profiles'])
        self.assertEqual(packet['state']['event.shield_owner'],'')

    def test_21_invalid_forged_routes_and_double_rewards_rejected(self):
        for route in [{'state':{'event.gold':9999}},['i/accept_joe'],['lore_menace/acknowledge_reward'],['x']*161]:
            with self.assertRaises((ValueError,AssertionError)):self.session.replay(route)

    def test_22_archival_exact_and_name_refs_rename(self):
        ls=literals();data=indexes(self.profiles,load_references())
        for n in self.session.story['nodes']:
            for b in n['blocks']:
                if b['provenance']['origin']=='source_exact':
                    self.assertEqual(archival(b['text'],ls),''.join(ls[i]['text'] for i in b['literal_ids']))
        data=copy.deepcopy(data);data['characters']['party_hunter']['writing_name']['value']='하루'
        intro=next(b for n in self.session.story['nodes'] for b in n['blocks'] if b['id']=='i/intro_party_hunter')
        self.assertIn('하루는',render(intro['text'],data,ls,author=True))
        self.assertNotIn('사냥꾼',render(intro['text'],data,ls,author=True))

    def test_23_coverage_has_no_pending_or_dropped_dialogue(self):
        coverage = self.session.story['coverage']
        self.assertEqual(coverage['status'],'complete')
        self.assertFalse(coverage['deferred_source_refs'])
        for d in coverage['literal_dispositions']:
            literal=literals()[d['literal_id']]
            if literal['role'] in ('display_text_fragment','choice_label_or_prompt','text_variable_fragment') and literal['text'].strip():
                self.assertEqual(d['handling'],'verbatim')
                self.assertTrue(d['block_ids'] or d['choice_ids'])

    def test_24_omitted_dialogue_or_bad_dynamic_binding_fails(self):
        o=copy.deepcopy(self.session.overlay)
        n=next(n for n in o['nodes'] if n['id']=='i/mine_lore');n['blocks']=[b for b in n['blocks'] if b['id']!='i/gold_rumor']
        with self.assertRaisesRegex(ValueError,'dialogue omitted'):compile_chapter(o)
        o=copy.deepcopy(self.session.overlay);o['display_insertions']['i/shield_equipped_words'][0]['offset']=99999
        with self.assertRaisesRegex(ValueError,'outside source'):compile_chapter(o)

    def test_25_joe_armory_only_when_really_present_and_unarmed(self):
        route,packet = self.town(['i/visit_prison','i/prison_service','i/service_inside','i/accept_joe','i/joe_quiet_exit','i/joe_quiet_back',
            'i/visit_armory','i/armory_finish_joe','i/armory_back'])
        self.assertEqual(packet['state']['event.weapon.mad_joe'],'weapon_1')
        self.assertEqual(packet['state']['event.slot6'],'mad_joe')
        self.finish(route,skeleton=False)

    def test_26_every_optional_source_block_witnessed_on_a_real_route(self):
        # Independent of unittest ordering: witness the source blocks on real routes.
        self.witnessed.clear()
        town_routes=[
            ['i/visit_armory','i/armory_finish','i/armory_back'],
            ['i/visit_streets','i/streets_repeat_hint','i/street_second_back'],
            ['i/visit_tavern','i/tavern_personal','i/hear_tavern_people','i/late_veteran','i/late_veteran_back'],
            ['i/visit_tavern','i/tavern_menu','i/hear_tavern_people_menu','i/tavern_back'],
            ['i/visit_grave','i/grave_chest','i/grave_chest_back'],
            ['i/visit_support','i/support_again','i/support_repeat_back'],
            ['i/visit_mine_lore','i/mine_lore_back'],
            ['i/visit_prison','i/prison_request','i/decline_joe','i/joe_declined_back'],
            ['i/visit_prison','i/prison_request','i/accept_joe','i/joe_guard_exit','i/guard_escape','i/guard_try_again','i/guard_repeat_win','i/guard_victory_back']]
        for choices in town_routes:
            route,_=self.town(choices)
            self.finish(route)
        route,_=self.walk([*INTRO,'lore_menace/leave_castle','i/threshold_no','i/threshold_reconsider'])
        self.finish(route)
        for treasure in [[c for i in range(1,7) for c in ['i/gold_'+str(i),'i/gold_back_'+str(i)]]+['i/treasure_finish'],
                         ['i/shield_find','i/shield_protagonist','i/shield_back'],['i/shield_find','i/shield_cancel','i/shield_cancel_back']]:
            route,_=self.walk(INTRO)
            self.finish(route,treasure=treasure)
        expected={b['id'] for n in self.session.story['nodes'] for b in n['blocks']
                  if b['id'].startswith('i/') and b['provenance']['origin']=='source_exact'}
        self.assertFalse(expected-self.witnessed,sorted(expected-self.witnessed))

    def test_27_reader_export_is_identical_across_process_hash_seeds(self):
        script='import hashlib,json;from interactive import documents;print(json.dumps({k:hashlib.sha256(v.encode()).hexdigest() for k,v in documents().items()},sort_keys=True))'
        results=[]
        for seed in ['1','37']:
            env=dict(os.environ,PYTHONHASHSEED=seed,PYTHONPATH=str(ROOT/'tools'))
            output=subprocess.check_output([sys.executable,'-c',script],cwd=ROOT,env=env,text=True)
            results.append(json.loads(output))
        self.assertEqual(results[0],results[1])


if __name__=='__main__':unittest.main()
