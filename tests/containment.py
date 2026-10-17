"""Linux-only external test owner. Never imports or trusts the product guardian.

Standalone wrappers re-exec under this owner; nested wrappers inherit it. Cleanup
signals only live direct children via pidfds, then reaps/adopts until empty.
"""
import ctypes
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

CONTEXT = 'LUA_TEST_CONTAINMENT'


def supervised():
    owner = os.environ.get(CONTEXT)
    pid = os.getpid()
    while owner and pid > 1:
        if str(pid) == owner:
            return True
        try:
            pid = int(Path(f'/proc/{pid}/status').read_text().split('PPid:\t')[1].splitlines()[0])
        except (FileNotFoundError, IndexError):
            break
    return False


def enter(timeout=420):
    if not supervised():
        os.execv(sys.executable, [sys.executable, str(Path(__file__).resolve()),
                                 str(timeout), sys.executable, *sys.argv])


def children():
    return [int(p) for p in Path(f'/proc/{os.getpid()}/task/{os.getpid()}/children').read_text().split()]


def run(command, timeout):
    if sys.platform != 'linux' or not hasattr(os, 'pidfd_open'):
        print('BLOCKED Linux subreaper/pidfd containment unavailable', file=sys.stderr)
        return 125
    # Qualify both pidfd operations before acquiring fixture processes.
    try:
        fd = os.pidfd_open(os.getpid())
        try:
            signal.pidfd_send_signal(fd, 0)
        finally:
            os.close(fd)
    except (OSError, AttributeError):
        print('BLOCKED pidfd signalling unavailable', file=sys.stderr)
        return 125
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(36, 1, 0, 0, 0) != 0:  # PR_SET_CHILD_SUBREAPER
        print('BLOCKED PR_SET_CHILD_SUBREAPER unavailable', file=sys.stderr)
        return 125
    env = dict(os.environ, **{CONTEXT: str(os.getpid())})
    child = subprocess.Popen(command, env=env, start_new_session=True)
    deadline = time.monotonic() + timeout
    interrupted = []
    def stop(sig, frame):
        interrupted.append(sig)
    old = {sig: signal.signal(sig, stop) for sig in (signal.SIGTERM, signal.SIGINT)}
    result = 124
    try:
        while not interrupted and time.monotonic() < deadline:
            info = os.waitid(os.P_PID, child.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
            if info:
                result = info.si_status if info.si_code == os.CLD_EXITED else 128 + info.si_status
                break
            time.sleep(.01)
        if interrupted:
            result = 128 + interrupted[0]
    finally:
        # Keep the immediate child unreaped until cleanup starts; no stale PGID
        # or process-name matching. Escaped sessions become our direct children.
        end = time.monotonic() + 5
        while True:
            for pid in children():
                try:
                    fd = os.pidfd_open(pid)
                    try:
                        signal.pidfd_send_signal(fd, signal.SIGKILL)
                    finally:
                        os.close(fd)
                except ProcessLookupError:
                    pass
            while True:
                try:
                    pid, status = os.waitpid(-1, os.WNOHANG)
                    if not pid:
                        break
                    if pid == child.pid:
                        child.returncode = os.waitstatus_to_exitcode(status)
                except ChildProcessError:
                    break
            if not children():
                break
            if time.monotonic() >= end:
                print('FAIL containment cleanup unconfirmed', file=sys.stderr)
                result = 126
                break
            time.sleep(.01)
        for sig, handler in old.items():
            signal.signal(sig, handler)
    return result


if __name__ == '__main__':
    raise SystemExit(run(sys.argv[2:], float(sys.argv[1])))
