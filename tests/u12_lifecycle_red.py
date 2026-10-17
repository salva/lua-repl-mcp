"""U12 red probe: real readiness/execution barriers and external containment.
Run: python3 tests/u12_lifecycle_red.py
Linux /proc is used only by the test to observe process identity and ownership.
"""
import concurrent.futures
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def identity(pid):
    try:
        fields = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
        return fields[19], fields[0], int(fields[1])  # starttime, state, ppid
    except FileNotFoundError:
        return None


def case(mode, state):
    p = subprocess.Popen([str(ROOT / 'lua-repl-mcp')], cwd=ROOT,
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, start_new_session=True, bufsize=0)
    buf = b''
    serial = 0
    worker = None
    original = None

    def rpc(method, params):
        nonlocal serial, buf
        serial += 1
        p.stdin.write((json.dumps(dict(jsonrpc='2.0', id=serial,
                                      method=method, params=params)) + '\n').encode())
        deadline = time.monotonic() + 8
        while True:
            while b'\n' not in buf:
                remaining = deadline - time.monotonic()
                assert remaining > 0 and select.select([p.stdout], [], [], remaining)[0], 'RPC watchdog'
                chunk = os.read(p.stdout.fileno(), 65536)
                assert chunk, 'unexpected manager EOF'
                buf += chunk
            line, buf = buf.split(b'\n', 1)
            value = json.loads(line)
            if value.get('id') == serial:
                assert 'result' in value, value
                return value['result']

    try:
        rpc('initialize', dict(protocolVersion='2025-11-25', capabilities={},
                               clientInfo=dict(name='u12-red', version='1')))
        p.stdin.write((json.dumps(dict(jsonrpc='2.0', method='notifications/initialized')) + '\n').encode())
        # Successful create is the worker-ready barrier.
        result = rpc('tools/call', dict(name='session_create', arguments={}))['structuredContent']
        session = result['session_id']
        children = Path(f'/proc/{p.pid}/task/{p.pid}/children').read_text().split()
        assert children, 'no owned process after ready'
        # Descend through a guardian if the implementation has one.
        child = int(children[0])
        descendants = Path(f'/proc/{child}/task/{child}/children').read_text().split()
        worker = int(descendants[0]) if descendants else child
        original = identity(worker)
        assert original and original[1] != 'Z'
        print(f'OBSERVE {mode}/{state}: manager={p.pid} worker={worker} worker_parent={original[2]} guardian_owned={original[2] != p.pid}', flush=True)
        if state == 'infinite':
            # Pipe token is an execution barrier, not a timing assumption.
            r, w = os.pipe()
            # Worker can open this test-owned FD via procfs without inheriting it.
            code = f'local f=assert(io.open("/proc/{os.getpid()}/fd/{w}","w")); f:write("X"); f:flush(); f:close(); while true do end'
            rpc('tools/call', dict(name='session_execute', arguments=dict(session_id=session, code=code, wait_timeout_ms=0)))
            assert select.select([r], [], [], 8)[0] and os.read(r, 1) == b'X', 'execution barrier watchdog'
            os.close(r)
            os.close(w)
        started = time.monotonic()
        os.kill(p.pid, mode)
        rc = p.wait(timeout=35)
        deadline = started + 32  # 30s policy plus observation/scheduling allowance
        while time.monotonic() < deadline:
            current = identity(worker)
            if current is None or current[0] != original[0] or current[1] == 'Z':
                break
            time.sleep(.05)
        current = identity(worker)
        alive = current is not None and current[0] == original[0] and current[1] != 'Z'
        expected_rc = -(signal.SIGKILL) if mode == signal.SIGKILL else 128 + mode
        print(f'OBSERVE {mode}/{state}: manager_rc={rc} expected_rc={expected_rc} worker_running_after_bound={alive} elapsed={time.monotonic()-started:.2f}s', flush=True)
        assert not alive and rc == expected_rc, 'U12 lifecycle gap: surviving worker and/or incorrect signal status'
        return True
    except Exception as e:
        print(f'FAIL {mode}/{state}: {e}', flush=True)
        return False
    finally:
        # Only this test's isolated process group; no host/shared processes.
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        p.wait(timeout=5)
        for stream in (p.stdin, p.stdout, p.stderr):
            stream.close()


if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(lambda args: case(*args), [
            (signal.SIGINT, 'idle'), (signal.SIGTERM, 'idle'),
            (signal.SIGKILL, 'infinite')]))
    raise SystemExit(0 if all(results) else 1)
