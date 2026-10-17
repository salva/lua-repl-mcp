"""Exact expiry and acquisition-transaction regressions for review R1/R2."""
import ast
import os
from pathlib import Path
import signal
import sys
import types
import unittest
from unittest.mock import patch

import containment

ROOT = Path(__file__).resolve().parents[1]


def functions(path, names, env):
    tree = ast.parse((ROOT/'tests'/path).read_text())
    nodes = [n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef) and n.name in names]
    exec(compile(ast.Module(body=nodes, type_ignores=[]), path, 'exec'), env)
    return env


class Transactions(unittest.TestCase):
    def test_handlers_restore_on_spawn_failure(self):
        before = {s: signal.getsignal(s) for s in (signal.SIGTERM, signal.SIGINT)}
        with patch.object(containment.subprocess, 'Popen', side_effect=OSError('spawn')):
            with self.assertRaisesRegex(OSError, 'spawn'):
                containment.run(['unused'], 1)
        self.assertEqual(before, {s: signal.getsignal(s) for s in before})

    def test_partial_handler_setup_restored(self):
        before = {s: signal.getsignal(s) for s in (signal.SIGTERM, signal.SIGINT)}
        real = signal.signal
        calls = []
        def install(sig, handler):
            calls.append(sig)
            if len(calls) == 2:
                raise RuntimeError('partial handlers')
            return real(sig, handler)
        with patch.object(signal, 'signal', side_effect=install):
            with self.assertRaisesRegex(RuntimeError, 'partial handlers'):
                containment.run(['unused'], 1)
        self.assertEqual(before, {s: signal.getsignal(s) for s in before})

    def test_acquired_child_reaped_if_popen_raises(self):
        real = containment.subprocess.Popen
        acquired = []
        before = signal.getsignal(signal.SIGTERM)
        def spawn(*a, **kw):
            child = real(*a, **kw)
            acquired.append(child)
            raise RuntimeError('after acquisition')
        with patch.object(containment.subprocess, 'Popen', side_effect=spawn):
            with self.assertRaisesRegex(RuntimeError, 'after acquisition'):
                containment.run([sys.executable, '-c', 'import time; time.sleep(30)'], 1)
        self.assertFalse(Path(f'/proc/{acquired[0].pid}').exists())
        acquired[0].returncode = -signal.SIGKILL
        self.assertEqual(signal.getsignal(signal.SIGTERM), before)

    def test_signal_before_spawn_skips_acquisition(self):
        real = os.pidfd_open
        def qualify(pid):
            fd = real(pid)
            os.kill(os.getpid(), signal.SIGINT)
            return fd
        with patch.object(os, 'pidfd_open', side_effect=qualify), patch.object(containment.subprocess, 'Popen') as spawn:
            self.assertEqual(containment.run(['unused'], 1), 130)
            spawn.assert_not_called()

    def test_signal_during_final_reap_keeps_cleanup_protected(self):
        real = os.waitpid
        fired = []
        def reap(*args):
            if not fired:
                fired.append(True)
                os.kill(os.getpid(), signal.SIGTERM)
            return real(*args)
        before = signal.getsignal(signal.SIGTERM)
        with patch.object(os, 'waitpid', side_effect=reap):
            self.assertEqual(containment.run([sys.executable, '-c', 'pass'], 2), 0)
        self.assertEqual(signal.getsignal(signal.SIGTERM), before)
        self.assertEqual(containment.children(), [])

    def test_qualification_failure_restores_handlers(self):
        before = signal.getsignal(signal.SIGTERM)
        with patch.object(os, 'pidfd_open', side_effect=OSError('unavailable')):
            self.assertEqual(containment.run(['unused'], 1), 125)
        self.assertEqual(signal.getsignal(signal.SIGTERM), before)


class Deadlines(unittest.TestCase):
    def test_website_final_before_equal_after_and_pending(self):
        for finish in (14.999, 15, 15.001):
            with self.subTest(finish=finish):
                clock = [0]
                deadlines = []
                def now():
                    value = clock[0]
                    if value == 0:
                        clock[0] = 14
                    return value
                def call(name, args, deadline):
                    deadlines.append(deadline)
                    clock[0] = finish
                    return {'status': 'completed'}
                env = functions('website_installed.py', {'completed'}, {
                    'time': types.SimpleNamespace(monotonic=now), 'call': call, 'sid': 'x'})
                if finish < 15:
                    self.assertEqual(env['completed']({'status': 'pending'}), {'status': 'completed'})
                else:
                    with self.assertRaisesRegex(AssertionError, 'total scenario deadline'):
                        env['completed']({'status': 'pending'})
                self.assertEqual(deadlines, [15])

    def test_website_rpc_minimum_budget_and_buffered_expiry(self):
        for finish in (14.999, 15, 15.001):
            clock = [14]
            waits = []
            stream = types.SimpleNamespace(write=lambda b: None, fileno=lambda: 1)
            def read(*args):
                clock[0] = finish
                return b'{"id":1,"result":{}}\n'
            def select(*args):
                waits.append(args[-1])
                return ([stream], [], [])
            env = functions('website_installed.py', {'rpc'}, dict(
                seq=0, pending=b'', p=types.SimpleNamespace(stdin=stream, stdout=stream),
                json=__import__('json'), time=types.SimpleNamespace(monotonic=lambda: clock[0]),
                os=types.SimpleNamespace(read=read), select=types.SimpleNamespace(select=select)))
            if finish < 15:
                self.assertEqual(env['rpc']('ping', {}, 15), {})
            else:
                with self.assertRaisesRegex(AssertionError, 'complete-frame deadline'):
                    env['rpc']('ping', {}, 15)
            self.assertEqual(waits, [1])
        env['pending'] = b'{"id":2,"result":{}}\n'
        clock[0] = 15
        with self.assertRaisesRegex(AssertionError, 'complete-frame deadline'):
            env['rpc']('ping', {}, 15)
        env['pending'] = b''
        clock[0] = 14
        env['os'].read = lambda *a: b''
        with self.assertRaisesRegex(AssertionError, 'EOF'):
            env['rpc']('ping', {}, 15)

    def test_website_pending_and_eof(self):
        for eof in (False, True):
            clock = [0]
            def call(*args):
                clock[0] += 8
                if eof:
                    raise AssertionError('EOF')
                return {'status': 'pending'}
            env = functions('website_installed.py', {'completed'}, {
                'time': types.SimpleNamespace(monotonic=lambda: clock[0]),
                'call': call, 'sid': 'x'})
            with self.assertRaisesRegex(AssertionError, 'EOF' if eof else 'total scenario deadline'):
                env['completed']({'status': 'pending'})

    def test_u8_target_and_saved_expiry(self):
        for buffered in (False, True):
            for finish in (14.999, 15, 15.001):
                with self.subTest(buffered=buffered, finish=finish):
                    clock = [0]
                    def now():
                        value = clock[0]
                        if value == 0:
                            clock[0] = finish if buffered else 14
                        return value
                    def receive(deadline):
                        self.assertEqual(deadline, 15)
                        clock[0] = finish
                        return {'id': 'target'}
                    obj = types.SimpleNamespace(saved={'target': 7} if buffered else {}, receive=receive)
                    env = functions('u8_live.py', {'get'}, {'time': types.SimpleNamespace(monotonic=now)})
                    if finish < 15:
                        env['get'](obj, 'target')
                    else:
                        with self.assertRaisesRegex(AssertionError, 'total response scenario deadline'):
                            env['get'](obj, 'target')
                        self.assertIn('target', obj.saved)

    def test_nested_u8_frame_budget_buffered_and_eof(self):
        for finish in (14.999, 15, 15.001):
            clock = [14]
            waits = []
            def read(*args):
                clock[0] = finish
                return b'{"jsonrpc":"2.0","id":"target"}\n'
            def select(*args):
                waits.append(args[-1])
                return ([1], [], [])
            env = functions('u8_live.py', {'receive'}, dict(
                time=types.SimpleNamespace(monotonic=lambda: clock[0]),
                os=types.SimpleNamespace(read=read), select=types.SimpleNamespace(select=select),
                json=__import__('json')))
            obj = types.SimpleNamespace(buf=b'', p=types.SimpleNamespace(stdout=types.SimpleNamespace(fileno=lambda: 1)))
            if finish < 15:
                self.assertEqual(env['receive'](obj, 15)['id'], 'target')
            else:
                with self.assertRaisesRegex(AssertionError, 'response timeout'):
                    env['receive'](obj, 15)
            self.assertEqual(waits, [1])
        clock[0] = 15
        obj.buf = b'{"jsonrpc":"2.0","id":"target"}\n'
        with self.assertRaisesRegex(AssertionError, 'response timeout'):
            env['receive'](obj, 15)
        clock[0] = 14
        obj.buf = b''
        obj.p.stderr = types.SimpleNamespace(read=lambda: b'')
        env['os'].read = lambda *a: b''
        with self.assertRaisesRegex(AssertionError, 'EOF'):
            env['receive'](obj, 15)


if __name__ == '__main__':
    unittest.main(verbosity=2)
