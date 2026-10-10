import copy
import json
import unittest
from unittest.mock import patch

import jsonschema
from characters import load_characters
from disclosure import project_character
from materials import ROOT, read
from reference import load_references, schema_validator
from story_continuity import CANON, context, input_hashes, validate as validate_continuity
from text_refs import archival, indexes, literals, particle, render, source_ids, validate_text, reject_fixed_names, validate_names
from validate_story_authoring import validate
from writing import BOARD, PILOT, WRITING, DEFAULT_ROUTE, preview_story, validate_board


class WritingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profiles = load_characters()
        cls.refs = load_references()
        cls.data = indexes(cls.profiles,cls.refs)
        cls.raw = literals()
        cls.story = read(PILOT)
        cls.memory = read(PILOT.with_name('prologue.continuity.json'))
        cls.direct = preview_story(cls.story,cls.memory,DEFAULT_ROUTE,cls.profiles,cls.refs)
        cls.tavern = preview_story(cls.story,cls.memory,['enter_courtyard','visit_tavern','remember_veteran',*DEFAULT_ROUTE[1:]],cls.profiles,cls.refs)

    def quote(self,key):
        return copy.deepcopy(next(b for n in self.story['nodes'] for b in n['blocks'] if b['id']==key))

    def test_whole_board_accounts_for_eighteen_story_quests(self):
        board = read(BOARD)
        result = validate_board(board,self.data,self.profiles)
        self.assertEqual((result['units'],result['arcs']),(18,5))
        self.assertEqual(board['route_index'],'materials/quests.json#/route_edges')
        self.assertEqual(board['appendices'],['shared_system_and_text'])
        self.assertFalse(result['condition_paths_verified'])
        self.assertTrue(all(u['authored_fields']==['emotional_arc','bridge'] for u in board['units']))

    def test_board_rejects_unknown_cast_or_anchor(self):
        for field,value in [('cast_candidates','made_up'),('source_anchors','prologue:made_up'),('branches','made_up'),('disclosure_candidates','made_up')]:
            board = read(BOARD)
            board['units'][0][field].append(value)
            with self.assertRaisesRegex(ValueError,'unknown storyboard'):
                validate_board(board,self.data,self.profiles)

    def test_shared_templates_have_no_reader_prose_or_inventory(self):
        template = read(WRITING/'templates/quest.template.json')
        memory = read(WRITING/'templates/continuity.template.json')
        validate(template)
        self.assertEqual(validate_continuity(template,memory,read(CANON)),[])
        packet = context(template,memory,read(CANON),[],self.profiles)
        self.assertEqual(packet['visible_blocks'],[])
        self.assertEqual(packet['state'],{})
        validate_board(read(WRITING/'templates/storyboard.template.json'),self.data,self.profiles)

    def test_hero_name_is_added_not_original_or_phonetic(self):
        claim = read(ROOT/'reference/names.json')['characters']['protagonist']
        hero = self.profiles['characters']['protagonist']
        self.assertEqual(hero['writing_name'],claim)
        self.assertEqual(claim['value'],'홍길동')
        self.assertEqual((claim['origin'],claim['status'],claim['metadata']['kind']),('authored','proposed','new_setting'))
        self.assertIsNone(hero['canonical_name']['value'])
        self.assertIsNone(hero['korean_name']['value'])
        self.assertIsNone(hero['biography']['age']['value'])

    def test_name_override_input_has_strict_metadata_and_catalogs(self):
        for mutation in ('unmarked','source','unknown_catalog'):
            data = read(ROOT/'reference/names.json')
            if mutation=='unmarked':
                data['characters']['protagonist']['metadata']['addition'] = False
            elif mutation=='source':
                data['characters']['protagonist']['origin'] = 'source_exact'
            else:
                data['weapons'] = {}
            with self.assertRaises(jsonschema.ValidationError):
                schema_validator(ROOT/'reference/names.schema.json').validate(data)

    def test_source_json_does_not_copy_mutable_hero_name(self):
        for path in [BOARD,PILOT,WRITING/'templates/quest.template.json']:
            self.assertNotIn('홍길동',path.read_text())
        self.assertIn('홍길동은',json.dumps(self.direct,ensure_ascii=False))

    def test_renaming_hero_updates_every_reference_and_particle(self):
        profiles = copy.deepcopy(self.profiles)
        hero = profiles['characters']['protagonist']
        hero['writing_name']['value'] = hero['display_name'] = hero['disclosure']['public_display_name'] = '하나'
        data = indexes(profiles,self.refs)
        before = json.dumps(self.story,ensure_ascii=False)
        values = [render(b['text'],data,self.raw,profiles,['castle_arrival','lord_briefing']) for n in self.story['nodes'] for b in n['blocks']]
        self.assertTrue(any('하나는' in s for s in values))
        self.assertTrue(any('하나를' in s for s in values))
        self.assertNotIn('홍길동',''.join(values))
        self.assertEqual(before,json.dumps(self.story,ensure_ascii=False))

    def test_weapon_and_magic_names_are_references_not_new_inventory(self):
        data = copy.deepcopy(self.data)
        for cat in ('equipment','abilities','bestiary'):
            key = next(iter(data[cat]))
            token = [{'ref':{'catalog':cat,'id':key}}]
            old = render(token,data,self.raw,author=True)
            data[cat][key]['writing_name'] = {'value':'새 이름'}
            self.assertNotEqual(old,render(token,data,self.raw,author=True))
            self.assertEqual(render(token,data,self.raw,author=True),'새 이름')
        self.assertEqual(self.direct['state'],{'knowledge.missing_squad':False})

    def test_particles_support_jongseong_and_rieul(self):
        self.assertEqual(particle('홍길동','은/는'),'은')
        self.assertEqual(particle('하나','은/는'),'는')
        self.assertEqual(particle('칼','으로/로'),'로')
        self.assertEqual(particle('창','으로/로'),'으로')
        with self.assertRaisesRegex(ValueError,'Hangul'):
            particle('English','은/는')

    def test_unknown_reference_and_fixed_names_fail(self):
        with self.assertRaisesRegex(ValueError,'unknown text reference'):
            validate_text([{'ref':{'catalog':'equipment','id':'not_a_weapon'}}],self.data,self.raw)
        for value in ['홍길동은 걸었다.',self.refs['equipment']['items']['weapon_1']['original_name']['value']]:
            with self.assertRaisesRegex(ValueError,'fixed entity name'):
                reject_fixed_names([{'text':value}],self.data)

    def test_actual_draft_rejects_fixed_name(self):
        story = copy.deepcopy(self.story)
        story['nodes'][0]['blocks'][0]['text'] = [{'text':'홍길동은 걸었다.'}]
        with self.assertRaisesRegex(ValueError,'fixed entity name'):
            validate(story)

    def test_stale_compiled_name_and_disabled_reference_mode_fail(self):
        names = read(ROOT/'reference/names.json')
        names['characters']['protagonist']['value'] = '변경이름'
        with patch('text_refs.read',return_value=names):
            with self.assertRaisesRegex(ValueError,'compiled writing names are stale'):
                validate_names(self.data)
        story = copy.deepcopy(self.story)
        story['meta']['reference_text'] = False
        with self.assertRaisesRegex(ValueError,'enable reference_text'):
            preview_story(story,self.memory,[],self.profiles,self.refs)

    def test_source_quotes_keep_every_selected_fragment_in_order(self):
        ranges = {'guide_dialogue':(294,294),'veteran_dialogue':(90,99),'lord_intro_dialogue':(299,302),'lord_history_dialogue':(306,336)}
        for key,(start,end) in ranges.items():
            block = self.quote(key)
            ids = [i for i,l in self.raw.items() if l['source']['file']=='LORETALK.PAS' and start<=l['source']['line']<=end and l['role']=='display_text_fragment']
            self.assertEqual(source_ids(block['text']),ids)
            self.assertEqual(archival(block['text'],self.raw),''.join(self.raw[i]['text'] for i in ids))
            validate_text(block['text'],self.data,self.raw,require_bindings=True)

    def test_dialogue_rename_changes_display_not_archive(self):
        quote = self.quote('lord_intro_dialogue')['text']
        before = archival(quote,self.raw)
        data = copy.deepcopy(self.data)
        data['characters']['lord_ahn']['writing_name'] = {'value':'새성주'}
        self.assertIn('새성주',render(quote,data,self.raw,author=True))
        self.assertIn('Lord Ahn',before)
        self.assertEqual(archival(quote,self.raw),before)
        block = next(b for s in self.direct['sections'] for b in s['blocks'] if b['id']=='lord_intro_dialogue')
        self.assertEqual((block['origin'],block['display_origin']),('source_exact','source_adaptation'))

    def test_invalid_missing_and_reordered_source_bindings_fail(self):
        quote = self.quote('lord_intro_dialogue')['text']
        quote[0]['source']['bindings'][0]['start'] += 1
        with self.assertRaisesRegex(ValueError,'does not match'):
            validate_text(quote,self.data,self.raw)
        quote = self.quote('lord_intro_dialogue')['text']
        quote[0]['source']['bindings'] = []
        with self.assertRaisesRegex(ValueError,'unbound source'):
            validate_text(quote,self.data,self.raw,require_bindings=True)
        quote = self.quote('lord_intro_dialogue')['text']
        quote[0]['source']['literal_ids'].reverse()
        with self.assertRaisesRegex(ValueError,'occurrence order'):
            validate_text(quote,self.data,self.raw)

    def test_optional_testimony_is_not_known_on_direct_route(self):
        self.assertNotIn('veteran_story',self.direct['knowledge']['protagonist'])
        self.assertIn('veteran_story',self.tavern['knowledge']['protagonist'])
        self.assertIn('lord_briefing_account',self.direct['knowledge']['protagonist'])
        self.assertNotIn('squad_whereabouts',self.tavern['knowledge']['protagonist'])
        ids = lambda p:[b['id'] for s in p['sections'] for b in s['blocks']]
        self.assertNotIn('briefing_memory',ids(self.direct))
        self.assertIn('briefing_memory',ids(self.tavern))
        self.assertTrue(self.direct['provisional'])

    def test_no_future_prophecy_prison_or_assignment_reveal(self):
        self.assertEqual(self.direct['disclosed_events'],['castle_arrival','lord_briefing'])
        self.assertEqual(self.direct['sections'][-1]['node_id'],'first_quest_boundary')
        self.assertNotIn('prison',json.dumps(self.direct))
        fact = next(f for f in read(CANON)['facts'] if f['id']=='lord_briefing_account')
        self.assertEqual(fact['kind'],'testimony')
        self.assertEqual(fact['attributed_to'],'lord_ahn')
        self.assertEqual(fact['initial_knowers'],[])

    def test_hidden_identity_name_reference_is_projected_even_after_packet_remap(self):
        story = read(WRITING/'templates/quest.template.json')
        memory = read(WRITING/'templates/continuity.template.json')
        block = story['nodes'][0]['blocks'][0]
        block.update(kind='narration',text=[{'ref':{'catalog':'characters','id':'false_necromancer'}}])
        packet = preview_story(story,memory,[],self.profiles,self.refs)
        self.assertEqual(packet['sections'][0]['blocks'][0]['text'],project_character(self.profiles,'false_necromancer')['display_name'])
        self.assertNotIn('false_necromancer',json.dumps(packet))
        self.assertNotIn('사칭',json.dumps(packet,ensure_ascii=False))

    def test_future_name_override_cannot_open_secret_identity(self):
        profiles = copy.deepcopy(self.profiles)
        profiles['characters']['false_necromancer']['writing_name'] = copy.deepcopy(profiles['characters']['protagonist']['writing_name'])
        profiles['characters']['false_necromancer']['writing_name']['value'] = '비밀이름'
        self.assertNotIn('writing_name',project_character(profiles,'false_necromancer'))
        value = render([{'ref':{'catalog':'characters','id':'false_necromancer'}}],indexes(profiles,self.refs),self.raw,profiles)
        self.assertNotIn('비밀이름',value)

    def test_pilot_remains_partial_and_requires_review(self):
        result = validate(self.story)
        self.assertEqual(result['coverage'],'partial')
        self.assertEqual(result['unaccounted_scoped_literals'],0)
        self.assertTrue(any(d['handling']=='pending' for d in self.story['coverage']['literal_dispositions']))
        self.assertEqual(self.memory['review']['status'],'draft')
        self.assertTrue(all(e['approval']=='proposed' for e in self.memory['event_templates']))

    def test_terms_change_invalidates_reference_approval_fingerprint(self):
        first = input_hashes(self.story,self.memory,read(CANON),self.profiles)
        from text_refs import load_terms
        terms = copy.deepcopy(load_terms())
        terms['items']['lore']['korean_name']['value'] = '새지명'
        with patch('story_continuity.load_terms',return_value=terms):
            other = input_hashes(self.story,self.memory,read(CANON),self.profiles)
        self.assertNotEqual(first['references'],other['references'])


if __name__=='__main__':
    unittest.main()
