"""Locate original game RAM even when SDL allocations precede it."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from capture_dos_battle_memory import EXE, locate


class DosCaptureLocatorTest(unittest.TestCase):
    def reference(self, duplicate=False, code=True):
        base = 0x10000000
        player_offset = 0x144000
        code_offset = 0x130000
        player = bytes((i % 251 for i in range(330)))
        memory = bytearray(0x200000)
        memory[player_offset:player_offset + 330] = player
        if duplicate:
            memory[player_offset + 400:player_offset + 730] = player
        if code:
            memory[code_offset:code_offset + 19] = EXE.read_bytes()[225719:225738]
        with tempfile.TemporaryDirectory() as directory:
            saved = Path(directory) / 'PLAYER1.DAT'
            saved.write_bytes(player)
            with patch('capture_dos_battle_memory.os.open', return_value=9), \
                 patch('capture_dos_battle_memory.os.close'), \
                 patch('capture_dos_battle_memory.os.pread', side_effect=lambda fd, size, offset: bytes(memory[:size])) as read, \
                 patch.object(Path, 'read_text', return_value=f'{base:x}-{base + 0x1100000:x} rw-p 00000000 00:00 0\n'):
                result = locate(123, saved)
                self.assertLessEqual(read.call_args.args[1], 0x2000000)
                return result, base, player_offset, code_offset

    def test_game_beyond_first_mib_is_located_from_both_signatures(self):
        result, base, players, code = self.reference()
        self.assertEqual(result, dict(pid=123, mapping=base,
                                      player=base + players, random=base + code))

    def test_ambiguous_player_pattern_is_rejected(self):
        with self.assertRaises(AssertionError):
            self.reference(duplicate=True)

    def test_player_bytes_without_original_code_are_rejected(self):
        with self.assertRaisesRegex(AssertionError, 'unique live original'):
            self.reference(code=False)


if __name__ == '__main__':
    unittest.main()
