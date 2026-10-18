"""Fault the infrastructure, not the guardian: real escaped children and crashes."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

from containment import run
from deadlines import frame

ROOT = Path(__file__).resolve().parents[1]


class Containment(unittest.TestCase):
    def test_adopted_zombie_reaped_before_fixture_exit(self):
        work = Path(os.environ['SAIVAGE_CARD_WORK_ROOT']) / 'u13-containment'
        work.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=work) as d:
            path = Path(d)
            exited = "import os,time; open(%r,'w').write(str(os.getpid())); time.sleep(.1)" % str(path/'exited')
            live = "import os,time; open(%r,'w').write(str(os.getpid())); time.sleep(60)" % str(path/'live')
            intermediate = "import os,subprocess,sys; os.setsid(); subprocess.Popen([sys.executable,'-c',%r]); subprocess.Popen([sys.executable,'-c',%r])" % (exited, live)
            driver = '''import os,subprocess,sys,time
from pathlib import Path
p=Path(%r)
subprocess.run([sys.executable,'-c',%r],check=True)
end=time.monotonic()+3
while not (p/'exited').exists() or not (p/'live').exists():
 assert time.monotonic()<end
 time.sleep(.01)
dead=int((p/'exited').read_text()); live=int((p/'live').read_text())
while Path('/proc/'+str(dead)).exists():
 assert time.monotonic()<end, 'adopted zombie held until fixture exit'
 time.sleep(.01)
assert Path('/proc/'+str(live)).exists(), 'live adoptee signalled during observation'
(p/'observed').write_text('before fixture exit')
os._exit(7)
''' % (str(path), intermediate)
            self.assertEqual(run([sys.executable, '-c', driver], 5), 7)
            self.assertTrue((path/'observed').exists())
            for name in ('exited', 'live'):
                self.assertFalse(Path('/proc/'+(path/name).read_text()).exists())
            with self.assertRaises(ChildProcessError):
                os.waitpid(-1, os.WNOHANG)

    def test_crash_timeout_nested_and_escape(self):
        work = Path(os.environ['SAIVAGE_CARD_WORK_ROOT']) / 'u13-containment'
        work.mkdir(exist_ok=True)
        for mode in ('aggregate-crash', 'nested-crash', 'timeout'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(dir=work) as d:
                path = Path(d)
                # A TERM-ignoring escaped session grandchild survives the local
                # wrapper; only the separate external subreaper can reap it.
                escaped = "import os,signal,time; os.setsid(); signal.signal(signal.SIGTERM,signal.SIG_IGN); open(%r,'w').write(str(os.getpid())); time.sleep(60)" % str(path/'escaped')
                nested = "import os,subprocess,sys,time; open(%r,'w').write(str(os.getpid())); subprocess.Popen([sys.executable,'-c',%r]); time.sleep(.15); os._exit(7)" % (str(path/'nested'), escaped)
                driver = "import subprocess,sys,time,os; open(%r,'w').write(str(os.getpid())); subprocess.Popen([sys.executable,'-c',%r]); time.sleep(.4); %s" % (str(path/'driver'), nested, 'time.sleep(60)' if mode in ('timeout','nested-crash') else 'os._exit(9)')
                start = time.monotonic()
                rc = run([sys.executable, '-c', driver], .8)
                self.assertEqual(rc, 124 if mode in ('timeout','nested-crash') else 9)
                self.assertLess(time.monotonic()-start, 3)
                for name in ('driver','nested','escaped'):
                    pid = int((path/name).read_text())
                    self.assertFalse(Path(f'/proc/{pid}').exists(), (mode,name,pid))
                with self.assertRaises(ChildProcessError):
                    os.waitpid(-1, os.WNOHANG)

    def test_owner_signal_and_standalone_entry(self):
        work = Path(os.environ['SAIVAGE_CARD_WORK_ROOT']) / 'u13-containment'
        work.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=work) as d:
            pidfile = Path(d)/'pid'
            code = "import os,time; open(%r,'w').write(str(os.getpid())); time.sleep(60)" % str(pidfile)
            owner = subprocess.Popen([sys.executable,str(ROOT/'tests/containment.py'),'5',sys.executable,'-c',code])
            try:
                deadline=time.monotonic()+3
                while not pidfile.exists():
                    self.assertLess(time.monotonic(),deadline)
                    time.sleep(.01)
                owner.send_signal(signal.SIGTERM)
                self.assertEqual(owner.wait(timeout=3),143)
                self.assertFalse(Path('/proc/'+pidfile.read_text()).exists())
            finally:
                if owner.poll() is None:
                    owner.terminate();owner.wait(timeout=6)

    def test_standalone_wrapper_inherits_one_owner(self):
        work = Path(os.environ['SAIVAGE_CARD_WORK_ROOT']) / 'u13-containment'
        work.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=work) as d:
            wrapper=Path(d)/'wrapper.py'
            wrapper.write_text("import sys,os; sys.path.insert(0,%r)\nfrom containment import enter,supervised\nenter(3)\nassert supervised()\nassert os.getsid(0)==os.getpid()\n" % str(ROOT/'tests'))
            # Invalid inherited marker must not bypass standalone ownership.
            result=subprocess.run([sys.executable,str(wrapper)],env=dict(os.environ,LUA_TEST_CONTAINMENT='99999999'),timeout=5)
            self.assertEqual(result.returncode,0)

    def test_partial_stall_eof_and_complete(self):
        for payload, delay, expected in [(b'{', .3, 'deadline'), (b'', 0, 'EOF'), (b'{}\n', 0, None)]:
            r,w = os.pipe()
            p = subprocess.Popen([sys.executable,'-c',
                'import os,time; os.write(%d,%r); time.sleep(%r)' % (w,payload,delay)], pass_fds=(w,))
            os.close(w)
            try:
                with os.fdopen(r,'rb',buffering=0) as stream:
                    if expected:
                        with self.assertRaisesRegex(AssertionError,expected):
                            frame(stream,.1)
                    else:
                        self.assertEqual(frame(stream,.1),payload)
            finally:
                p.kill();p.wait()

    def test_manifest_complete_and_explicit(self):
        rows=json.loads((ROOT/'tests/fixtures.json').read_text())
        self.assertEqual({r['path'] for r in rows if r['path'].endswith('.lua')}, {p.name for p in (ROOT/'tests').glob('*.lua')})
        self.assertEqual(len(rows),len({r['path'] for r in rows}))
        for row in rows:
            wrapper = row.get('wrapper', 'u9_suite.py')
            self.assertTrue((ROOT/'tests'/(row['path'] if wrapper == 'self' else wrapper)).is_file(), row)
            self.assertGreater(row['deadline'],0)
            if row['expected_status']:
                self.assertTrue(row['expected_assertion'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
