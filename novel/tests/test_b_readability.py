"""Guard reviewed B scene boundaries, not an automatic literary quality score."""
import unittest
from materials import ROOT,read


class BReadabilityTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.books={i:read(ROOT/f'writing/variants/B/chapter{i:02}.json')for i in (1,2,3)}
        cls.presentation=read(ROOT/'writing/interactive/prose-presentation.json')
        cls.review=read(ROOT/'writing/variants/B/copyedit-review.json')['passes'][-1]

    def body(self,chapter,key):
        return ''.join(s.get('text','')for s in self.books[chapter]['block_overrides'][key]['text'])

    def test_style_revision_is_explicit_and_does_not_change_A(self):
        styles=read(ROOT/'writing/styles.json')
        self.assertEqual(styles['profiles']['B']['revision'],self.review['style_revision'])
        self.assertEqual(read(ROOT/'writing/variants/B/series.json')['style_revision'],self.review['style_revision'])
        self.assertEqual([d['style_revision']for d in self.books.values()],[self.review['style_revision']]*3)
        self.assertEqual(styles['profiles']['A']['definition_ref'],'project.json#/style')
        self.assertEqual(read(ROOT/'writing/project.json')['style']['revision'],1)
        self.assertFalse(self.review['policy']['literary_or_canon_approval'])

    def test_tavern_sits_once_and_exploration_is_not_already_a_return(self):
        self.assertNotIn('앉아 계셔도',self.body(1,'i/tavern_story_personal_after'))
        self.assertNotIn('앉을 자리를 얻으러',self.body(1,'i/tavern_story_menu_after'))
        for actor in ('party_woodcutter','party_hunter','party_cook','party_magician'):
            self.assertNotIn('돌아가는 속도',self.body(1,'i/role_echo_'+actor))

    def test_battle_and_report_wait_for_their_original_result_blocks(self):
        text=self.body(2,'lastditch_pyramid/battle_body')
        self.assertIn('아직 끝난 싸움은 아니었다',text)
        self.assertNotIn('움직임이 끝내 멎었다',text)
        self.assertIn('적의 움직임이 마침내 멎었다',self.body(2,'lastditch_pyramid/won_body'))
        self.assertNotIn('성공을 인정하는 말',self.body(2,'lastditch_pyramid/report_body'))
        self.assertIn('성주의 대답을 기다렸다',self.body(2,'lastditch_pyramid/report_body'))

    def test_ruins_then_signs_then_city_and_aid_then_blessing(self):
        self.assertNotIn('다음 성이 가까워졌다',self.body(3,'gaia_evil_seal/ruins_body'))
        groups={g['block_ids'][0]:g for g in self.presentation['groups']}
        before=lambda key:''.join(s.get('text','')for s in groups[key]['editions']['B']['before'])
        self.assertIn('폐허에서 나와',before('gaia_evil_seal/road_sign_384'))
        self.assertIn('도착한 성문',before('gaia_evil_seal/city_name'))
        self.assertNotIn('축복을 내린다는 말',self.body(3,'gaia_evil_seal/aided_body'))
        self.assertNotIn('자기 길로 돌아섰다',self.body(3,'gaia_evil_seal/aided_body'))
        self.assertIn('축복을 받은 뒤',self.body(3,'gaia_evil_seal/aided_more'))

    def test_return_and_next_request_do_not_skip_ahead_then_go_back(self):
        returning=self.body(3,'gaia_evil_seal/seal_return')
        self.assertNotIn('끊어진 바닥을 앞두고',returning)
        self.assertIn('문 쪽으로 돌아갈 길',returning)
        self.assertNotIn('밖에 나오니 길표',self.body(3,'gaia_evil_seal/next_body'))
        self.assertIn('복도로 나온 일행',self.body(3,'gaia_evil_seal/next_wait'))
        self.assertFalse(self.review['policy']['branch_graph_or_effects_changed'])
        self.assertFalse(self.review['policy']['common_source_scripts_changed'])


if __name__=='__main__':unittest.main()
