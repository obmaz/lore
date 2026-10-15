"""Copyediting changes prose/display, never the archived scripts or branch rules."""
import hashlib
import unittest
from materials import ROOT,read
from ebook import payload_from_page
from prose_presentation import display_text
from text_refs import archival,literals,source_ids


class CopyeditTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.edits=read(ROOT/'writing/variants/B/copyedit-review.json')
        cls.chapters={i:read(ROOT/f'writing/variants/B/chapter{i:02}.json')for i in [1,2,3]}
        cls.registry=read(ROOT/'writing/script-overrides/registry.json')
        cls.payload=payload_from_page((ROOT/'writing/previews/chapter01-web.html').read_text())

    def body(self,chapter,key):return self.chapters[chapter]['block_overrides'][key]['text']
    def plain(self,chapter,key):return ''.join(s.get('text','')for s in self.body(chapter,key))

    def test_review_records_scope_and_no_canon_or_graph_approval(self):
        self.assertEqual(self.edits['scope'],['chapter01','chapter02','chapter03'])
        self.assertFalse(self.edits['policy']['base_story_and_branch_effects_changed'])
        self.assertFalse(self.edits['policy']['archival_source_changed'])
        self.assertFalse(self.edits['policy']['canon_approval'])
        self.assertFalse(self.edits['policy']['A_authored_prose_changed'])
        self.assertEqual([len(c['block_overrides'])for c in self.chapters.values()],[294,77,70])

    def test_ambiguous_actions_use_references_not_copied_names(self):
        for chapter,key,actor in [(1,'i/intro_party_cook','protagonist'),(1,'i/role_action_party_hunter','party_hunter'),
                                  (2,'lastditch_pyramid/room_body','protagonist'),(3,'gaia_evil_seal/rigel_approach','protagonist')]:
            refs=[s['ref']['id']for s in self.body(chapter,key)if 'ref'in s]
            self.assertIn(actor,refs)
        self.assertNotIn('그 사람은 멈추지 않았다. 그는',self.plain(1,'prologue/arrival_first'))

    def test_tavern_seating_does_not_return_to_blocking_the_door(self):
        self.assertNotIn('문을 계속 막고',self.plain(1,'i/tavern_story_menu_reply'))
        self.assertIn('짐은 의자 곁에',self.plain(1,'i/tavern_story_menu_reply'))
        self.assertIn('안내문',self.plain(1,'i/credit_frame'))
        self.assertNotIn('말이 들렸다',self.plain(1,'i/credit_frame'))

    def test_seal_confirmation_stops_before_crossing_and_exit_happens_once(self):
        turning=self.plain(3,'gaia_evil_seal/seal_return')
        self.assertIn('건널 준비',turning)
        self.assertNotIn('일행이 다 건넜다',turning)
        self.assertNotIn('무너진 성은 같은 모습',turning)
        self.assertIn('마지막 사람이 건넌',self.plain(3,'gaia_evil_seal/exit_body'))
        self.assertIn('마법은 끝났고',self.plain(3,'gaia_evil_seal/aided_exit'))
        self.assertNotIn('발이 닿을 때까지 기다렸다',self.plain(3,'gaia_evil_seal/aided_exit'))
        refs=[s.get('ref',{})for s in self.body(3,'gaia_evil_seal/seal_return')]
        self.assertIn({'catalog':'abilities','id':'magic_34'},refs)

    def test_all_written_speech_and_inscriptions_have_reviewed_overrides(self):
        expected={g['block_ids'][0]for g in self.payload['presentation']['groups']if g['kind']!='narration'}
        self.assertLessEqual(expected,set(self.registry['overrides']))
        blocks={b['id']:b for n in self.payload['nodes']for b in n['blocks']};source=literals()
        for key in expected:
            entry=self.registry['overrides'][key]
            raw=''.join(archival(blocks[id]['text'],source)for id in entry['source_block_ids'])
            self.assertEqual(entry['source_sha256'],hashlib.sha256(raw.encode()).hexdigest())
            self.assertEqual(entry['source_literal_ids'],[i for id in entry['source_block_ids']for i in source_ids(blocks[id]['text'])])

    def test_dialogue_spacing_corrections_preserve_archive(self):
        text=lambda key:display_text(self.registry['overrides'][key]['writing_overrides']['text'],self.payload['initial'],self.payload)
        self.assertIn('돌아오지 못했어',text('prologue/veteran_dialogue'))
        self.assertIn('그러나 그것은 한',text('prologue/lord_history_dialogue'))
        self.assertIn('부탁하건대',text('lore_menace/request_quote'))
        self.assertIn('나갈 수가 없소',text('gaia_evil_seal/rigel_605'))
        self.assertNotIn('LAST DITCH',text('gaia_evil_seal/request_516'))
        self.assertNotIn('Zombie',text('gaia_evil_seal/next_549'))
        self.assertIn('좀비',text('gaia_evil_seal/next_549'))
        self.assertIn('돌아오지못했어',''.join(self.payload['literals'].values()))
        self.assertIn('타도밖에',text('lore_menace/skeleton_quote'))
        self.assertIn('쩔쩔매는',text('i/drunk_lord'))
        self.assertNotIn('성주가 이어 하는 말',self.plain(3,'gaia_evil_seal/request_before'))

    def test_spell_name_only_changes_writer_display(self):
        item=read(ROOT/'reference/abilities.json')['items']['magic_19']
        self.assertEqual(item['original_name']['value'],'한명 치료')
        self.assertEqual(item['writing_name']['value'],'한 명 치료')
        self.assertEqual(item['writing_name']['status'],'proposed')
        self.assertTrue(item['writing_name']['metadata']['addition'])


if __name__=='__main__':unittest.main()
