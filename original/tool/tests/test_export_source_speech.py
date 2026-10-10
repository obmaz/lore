import unittest
import export_source_speech as speech

class SourceSpeechTest(unittest.TestCase):
    def test_generated_metadata_is_current(self):
        self.assertEqual(speech.OUT.read_text(), speech.render())

    def test_original_waits_and_immediate_messages_are_distinct(self):
        lines = speech.collect()
        self.assertTrue(lines['리학적인 파라독스에 의해 그는 생겨났던것이오.']['wait'])
        self.assertTrue(lines['   이것으로 전에 Sphinx 를 무찌르다']['wait'])
        self.assertTrue(lines['..그는 바로 당신인것이다.']['blank'])
        self.assertTrue(lines['알수없는 힘이 당신을 배척합니다.']['log'])
        self.assertFalse(lines['알수없는 힘이 당신을 배척합니다.']['wait'])
        self.assertEqual(lines['당신은 황금의 방패를 발견했다.']['color'], 15)
        self.assertEqual(lines['누가 오이디푸스의 창을 다루겠습니까 ?']['color'], 11)

    def test_source_newlines_do_not_change_metadata(self):
        # splitlines in collect makes the same artifact on LF/CRLF checkouts.
        self.assertNotIn('\r', speech.render())

    def test_npc_colors_blank_lines_and_mixed_word_colors(self):
        talk = speech.collect(('LORETALK',))
        self.assertEqual(talk[' 안녕하시오. 대담한 용사여.']['color'], 13)
        self.assertTrue(talk['고 있지. 죄책감을 잊기위해서 말이지...']['blank'])
        line = speech.collect()[' 나는 LORE 성의 성주 Lord Ahn 이오.']
        self.assertEqual(line['spans'], [(7, ' 나는 LORE 성의 성주 '),
                                        (11, 'Lord Ahn'), (7, ' 이오.')])
        self.assertEqual(''.join(part for _, part in line['spans']),
                         ' 나는 LORE 성의 성주 Lord Ahn 이오.')

    def test_dynamic_cprint_patterns_only_style_source_literals(self):
        patterns = speech.collect_patterns()
        self.assertEqual(len(patterns), 4)
        self.assertIn((10, 15, ' # ', ''), patterns)
        self.assertIn((7, 11, ' 당신이 다음 레벨이 되려면 경험치가 ', ''), patterns)
