"""Shared complete-frame final-read boundary, without process fixtures."""
import types
import unittest
from unittest.mock import patch
import deadlines


class FinalRead(unittest.TestCase):
    def test_before_equal_after(self):
        for finish in (.999, 1., 1.001):
            with self.subTest(finish=finish):
                clock = [0.]
                stream = types.SimpleNamespace(fileno=lambda: 0)
                def read(*args):
                    clock[0] = finish
                    return b'\n'
                with patch.object(deadlines.time, 'monotonic', side_effect=lambda: clock[0]), patch.object(deadlines.select, 'select', return_value=([stream], [], [])), patch.object(deadlines.os, 'read', side_effect=read):
                    if finish < 1:
                        self.assertEqual(deadlines.frame(stream, timeout=1), b'\n')
                    else:
                        with self.assertRaisesRegex(AssertionError, 'complete-frame deadline'):
                            deadlines.frame(stream, timeout=1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
