"""External MCP conformance. Usage: python3 tests/u8_live.py [CLI [args...]]."""
import hashlib
import importlib.util
import json
import os
import pathlib
import select
import subprocess
import sys
import time
import tempfile
from urllib.request import urlopen
import jsonschema

root = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('contracts', root / 'docs/check_contracts.py')
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)
doc = json.loads((root / 'docs/schemas/api.json').read_text())
expanded = {n: {'$schema': doc['$schema'], **c.expand(doc['$defs'][n], doc['$defs'])}
            for n in c.MANAGER + c.DIRECT for n in (n, n + '_output')}
for schema in expanded.values():
    jsonschema.Draft202012Validator.check_schema(schema)
raw = pathlib.Path(os.environ['MCP_SCHEMA']).read_bytes() if 'MCP_SCHEMA' in os.environ else urlopen(c.UPSTREAM, timeout=30).read()
assert hashlib.sha256(raw).hexdigest() == c.SHA256
upstream = json.loads(raw)
def official(name, value):
    jsonschema.Draft202012Validator({'$ref': '#/$defs/' + name, '$defs': upstream['$defs']}).validate(value)

class Client:
    def __init__(self, command):
        self.p = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, bufsize=0)
        self.buf = b''
        self.next = 0
        self.saved = {}
        self.tools = {}
    def send(self, method, params=None, notification=False, fragmented=False):
        self.next += 1
        r = dict(jsonrpc='2.0', method=method)
        if not notification:
            r['id'] = 'u8-' + str(self.next)
        if params is not None:
            r['params'] = params
        data = (json.dumps(r) + '\n').encode()
        for i in range(0, len(data), 3 if fragmented else len(data)):
            self.p.stdin.write(data[i:i + (3 if fragmented else len(data))])
        return r.get('id')
    def receive(self):
        deadline = time.monotonic() + 8
        while b'\n' not in self.buf:
            assert time.monotonic() < deadline, 'response timeout'
            assert select.select([self.p.stdout], [], [], max(0, deadline-time.monotonic()))[0], 'response timeout'
            data = os.read(self.p.stdout.fileno(), 4096)
            assert data, 'unexpected protocol EOF: ' + self.p.stderr.read().decode()
            self.buf += data
        line, self.buf = self.buf.split(b'\n', 1)
        r = json.loads(line)
        assert r['jsonrpc'] == '2.0'
        return r
    def get(self, id):
        while id not in self.saved:
            r = self.receive()
            assert r['id'] not in self.saved
            self.saved[r['id']] = r
        return self.saved.pop(id)
    def rpc(self, method, params=None):
        return self.get(self.send(method, params))
    def init(self):
        r = self.get(self.send('initialize', dict(protocolVersion='unrecognized', capabilities={},
                   clientInfo=dict(name='external-u8', version='1')), fragmented=True))['result']
        official('InitializeResult', r)
        assert r['protocolVersion'] == '2025-11-25'
        assert r['capabilities'] == {'tools': {}}
        self.send('notifications/initialized', notification=True)
    def discover(self, names):
        r = self.rpc('tools/list')['result']
        official('ListToolsResult', r)
        assert {t['name'] for t in r['tools']} == set(names)
        for t in r['tools']:
            official('Tool', t)
            assert t['description'] == c.DESCRIPTIONS[t['name']]
            for field, suffix in [('inputSchema', ''), ('outputSchema', '_output')]:
                assert t[field] == expanded[t['name'] + suffix]
        self.tools = {t['name']: t for t in r['tools']}
    def start(self, name, args):
        return self.send('tools/call', dict(name=name, arguments=args))
    def result(self, id, name):
        r = self.get(id)['result']
        official('CallToolResult', r)
        v = r['structuredContent']
        jsonschema.validate(v, expanded[name + '_output'])
        assert json.loads(r['content'][0]['text']) == v
        assert r['isError'] == ('error' in v)
        return v
    def call(self, name, **args):
        return self.result(self.start(name, args), name)
    def close(self):
        self.p.stdin.close()
        try:
            assert self.p.wait(timeout=8) == 0, self.p.stderr.read().decode()
        finally:
            if self.p.poll() is None:
                self.p.kill()
                self.p.wait()

command = sys.argv[1:] or [str(root / 'lua-repl-mcp')]
x = Client(command)
try:
    assert x.rpc('tools/list')['error']['code'] == -32600
    assert x.rpc('ping')['result'] == {}
    x.init()
    assert x.rpc('initialize', {})['error']['code'] == -32600
    x.discover(c.MANAGER)
    assert x.rpc('resources/list')['error']['code'] == -32601
    assert x.rpc('tools/call', dict(name='repl_close', arguments={}))['error']['code'] == -32602
    x.p.stdin.write(b'{invalid}\n[]\n')
    assert x.receive()['error']['code'] == -32700
    assert x.receive()['error']['code'] == -32600
    x.send('unknown/notification', notification=True)
    assert x.rpc('ping')['result'] == {}
    for name, args in [('session_execute', {'code':'', 'unknown':True}),
                       ('session_wait', {'session_id':None}), ('session_kill', {'session_id':None}),
                       ('session_list', {'extra':0}), ('session_create', {'extra':False})]:
        assert x.call(name, **args)['error']['code'] == 'invalid_arguments'
    assert x.call('session_list') == {'sessions': []}
    print('PASS lifecycle_negatives_notifications_discovery_five_tools_ten_schemas')
    a = x.call('session_create')['session_id']
    assert x.call('session_wait', session_id=a)['error']['code'] == 'no_execution'
    r = x.call('session_execute', session_id=a, code='local n=...; counter=(counter or 0)+n; return counter,nil', args=[2], wait_timeout_ms=None)
    assert r['values'] == [2, None]
    assert x.call('session_execute', session_id=a, code='function add(n) counter=counter+n; return counter end; return add(3)')['values'] == [5]
    assert x.call('session_execute', session_id=a, code='local n=1')['values'] == []
    assert x.call('session_execute', session_id=a, code='return n')['values'] == [None]
    for code, error in [('local =', 'lua_syntax_error'), ('error("oops")', 'lua_runtime_error'),
                        ('counter=counter+1; return function() end', 'result_serialization_error')]:
        assert x.call('session_execute', session_id=a, code=code)['error']['code'] == error
    assert x.call('session_execute', session_id=a, code='return counter')['values'] == [6]
    assert x.call('session_execute', session_id=a, code='return ...', args=[None, {'a': None}, []])['values'] == [None, {'a': None}, {}]
    assert x.call('session_execute', session_id=a, code='local out={}; local old=print; print=function(v) out[#out+1]=v end; print("captured"); print=old; return out')['values'] == [['captured']]
    assert x.call('session_execute', session_id=a, code='print("not protocol"); io.stderr:write("not protocol"); os.execute("echo native"); return 42')['values'] == [42]
    print('PASS normative_explicit_persistence_null_returns_recoverable_errors_capture_output_isolation')
    r = x.call('session_execute', session_id=None, create_options={}, code='answer=42; return answer', wait_timeout_ms=0, execution_timeout_ms=600000)
    b = r['session_id']
    assert r['status'] == 'running'
    assert x.call('session_wait', session_id=b, wait_timeout_ms=None)['values'] == [42]
    assert x.call('session_wait', session_id=b)['error']['code'] == 'result_unavailable'
    slow = x.start('session_execute', dict(session_id=a, code='os.execute("sleep 0.2"); return 99'))
    fast = x.start('session_execute', dict(session_id=b, code='return 42'))
    first = x.receive()
    assert first['id'] == fast, 'expected out-of-order fast response'
    x.saved[first['id']] = first
    assert x.result(fast, 'session_execute')['values'] == [42]
    assert x.result(slow, 'session_execute')['values'] == [99]
    for code in ['os.execute("sleep 0.1"); return 9', 'os.execute("sleep 0.1"); error("fail")']:
        assert x.call('session_execute', session_id=a, code=code, wait_timeout_ms=0)['status'] == 'running'
        w1 = x.start('session_wait', dict(session_id=a, wait_timeout_ms=None))
        w2 = x.start('session_wait', dict(session_id=a, wait_timeout_ms=None))
        one, two = x.result(w1, 'session_wait'), x.result(w2, 'session_wait')
        assert sum(v.get('error', {}).get('code') == 'result_unavailable' for v in (one, two)) == 1
    print('PASS normative_async_poll_single_consumer_success_error_out_of_order')
    running = x.start('session_execute', dict(session_id=a, code='while true do end', wait_timeout_ms=None))
    x.send('notifications/cancelled', dict(requestId=running, reason='test'), notification=True)
    # Cancellation suppresses execute reply, not ping or other sessions.
    assert x.rpc('ping')['result'] == {}
    assert x.call('session_execute', session_id=b, code='return 43')['values'] == [43]
    deadline = time.monotonic() + 5
    while any(s['session_id'] == a for s in x.call('session_list')['sessions']):
        assert time.monotonic() < deadline
        time.sleep(0.01)
    assert running not in x.saved
    assert x.call('session_kill', session_id=a)['error']['code'] == 'unknown_session'
    assert 'error' not in x.call('session_kill', session_id=b)
    assert x.call('session_kill', session_id=b)['error']['code'] == 'unknown_session'
    t = x.call('session_execute', code='while true do end', execution_timeout_ms=30)
    assert t['error']['code'] == 'execution_timeout' and not t['session_usable']
    t = x.call('session_execute', code='os.exit(3)')
    assert t['error']['code'] == 'worker_exited'
    assert x.call('session_list') == {'sessions': []}
    print('PASS cancellation_reply_suppression_kill_hard_deadline_worker_exit')
    # Finite wait expiry is not a hard deadline, busy errors preserve execution.
    r = x.call('session_execute', code='os.execute("sleep 0.2"); return 51', wait_timeout_ms=0)
    sid = r['session_id']
    assert x.call('session_wait', session_id=sid, wait_timeout_ms=1)['status'] == 'running'
    assert x.call('session_execute', session_id=sid, code='return 999')['error']['code'] == 'session_busy'
    assert x.call('session_wait', session_id=sid, wait_timeout_ms=None)['values'] == [51]
    r = x.call('session_execute', session_id=sid, code='while true do end', wait_timeout_ms=0)
    # Cancellation of already answered execute has no destructive effect.
    x.send('notifications/cancelled', dict(requestId='unknown'), notification=True)
    waiter = x.start('session_wait', dict(session_id=sid, wait_timeout_ms=None))
    x.send('notifications/cancelled', dict(requestId=waiter), notification=True)
    assert x.rpc('ping')['result'] == {}
    deadline = time.monotonic() + 5
    while any(s['session_id'] == sid for s in x.call('session_list')['sessions']):
        assert time.monotonic() < deadline, 'cancelled worker not disposed'
        time.sleep(0.01)
    assert waiter not in x.saved
    sid = x.call('session_execute', code='while true do end', wait_timeout_ms=0)['session_id']
    assert 'error' not in x.call('session_kill', session_id=sid)
    print('PASS finite_wait_busy_preservation_wait_cancellation_active_kill')
    sid = x.call('session_execute', code='while true do end', wait_timeout_ms=0)['session_id']
    waits = [x.start('session_wait', dict(session_id=sid, wait_timeout_ms=None)) for _ in range(256)]
    assert x.call('session_wait', session_id=sid, wait_timeout_ms=None)['error']['code'] == 'limit_exceeded'
    assert x.rpc('ping')['result'] == {}
    assert any(s['session_id'] == sid for s in x.call('session_list')['sessions'])
    # Kill remains admitted through reserved controls with all ordinary slots full.
    assert 'error' not in x.call('session_kill', session_id=sid)
    outcomes = [x.result(id, 'session_wait')['error']['code'] for id in waits]
    assert outcomes.count('session_killed') == 1, outcomes
    assert outcomes.count('result_unavailable') == 255, outcomes
    assert x.call('session_list') == {'sessions': []}
    print('PASS external_256_wait_saturation_limit_ping_list_reserved_kill')


finally:
    x.close()
print('PASS external_manager_conformance')

# Real external allocation and disconnect, with Linux /proc only as a test oracle.
work = pathlib.Path(os.environ.get('U8_WORK_DIR') or (pathlib.Path(os.environ['SAIVAGE_CARD_WORK_ROOT']) / 'u8-live-fixtures'))
work.mkdir(parents=True, exist_ok=True)
def children(p):
    path = pathlib.Path('/proc') / str(p.pid) / 'task' / str(p.pid) / 'children'
    return [int(n) for n in path.read_text().split()]
def wait_children(p):
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline:
        ids = children(p)
        if ids:
            return ids
        time.sleep(0.01)
    raise AssertionError('no allocated worker observed')
# Cancellation during blocked startup owns and disposes only that allocation.
z = Client(command)
try:
    z.init()
    with tempfile.TemporaryDirectory(dir=work) as directory:
        fifo = pathlib.Path(directory) / 'blocked'
        os.mkfifo(fifo)
        creating = z.start('session_create', dict(stdin_path=str(fifo)))
        owned = wait_children(z.p)
        z.send('notifications/cancelled', dict(requestId=creating), notification=True)
        assert z.rpc('ping')['result'] == {}
        deadline = time.monotonic() + 5
        while z.call('session_list')['sessions']:
            assert time.monotonic() < deadline
            time.sleep(0.01)
        assert creating not in z.saved
        assert all(not pathlib.Path('/proc', str(pid)).exists() for pid in owned)
finally:
    z.close()
print('PASS creation_cancellation_blocked_fifo_responsive_ping_reaped')
for phase in ('idle', 'running', 'startup'):
    z = Client(command)
    owned = []
    try:
        z.init()
        with tempfile.TemporaryDirectory(dir=work) as directory:
            if phase == 'startup':
                fifo = pathlib.Path(directory) / 'blocked-input'
                os.mkfifo(fifo)
                z.start('session_create', dict(stdin_path=str(fifo)))
            else:
                sid = z.call('session_create', cwd=directory, stdout_path='out', stderr_path='out')['session_id']
                r = z.call('session_execute', session_id=sid, code='print("hello"); io.stderr:write("stderr"); return 1')
                assert r['values'] == [1]
                output = pathlib.Path(directory) / 'out'
                # Shared output is retained and never overwritten by failed creation.
                before = output.read_bytes()
                assert b'hello' in before
                assert z.call('session_create', cwd=directory, stdout_path='out')['error']['code'] == 'session_creation_error'
                assert output.read_bytes() == before
                if phase == 'running':
                    z.call('session_execute', session_id=sid, code='while true do end', wait_timeout_ms=0)
            owned = wait_children(z.p)
            z.close()
            assert all(not pathlib.Path('/proc', str(pid)).exists() for pid in owned), 'unreaped worker after disconnect'
    finally:
        if z.p.poll() is None:
            z.close()
print('PASS explicit_relative_shared_output_exclusive_creation_disconnect_idle_running_blocked_startup_reaping')

# Separate supplied pipes, passed explicitly; not host stdin/stdout.
rd, write_fd = os.pipe()
read_fd, wr = os.pipe()
env = os.environ.copy()
env.update(U8_READ_FD=str(rd), U8_WRITE_FD=str(wr))
y = Client.__new__(Client)
y.p = subprocess.Popen(['lua5.4', str(root / 'tests/u8_direct_host.lua')],
                       stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                       stderr=subprocess.PIPE, pass_fds=(rd, wr), env=env)
os.close(rd)
os.close(wr)
y.p.stdin = os.fdopen(write_fd, 'wb', buffering=0)
y.p.stdout = os.fdopen(read_fd, 'rb', buffering=0)
y.buf = b''
y.next = 0
y.saved = {}
y.tools = {}
try:
    y.init()
    y.discover(c.DIRECT)
    assert y.call('repl_execute', code='return host_api(2),host_value')['values'] == [12, 12]
    assert y.call('repl_execute', code='return 1', session_id='manager-only')['error']['code'] == 'invalid_arguments'
    # One atomic pipe write contains close, complete execute and partial tail.
    closing = dict(jsonrpc='2.0', id='close', method='tools/call', params=dict(name='repl_close', arguments={}))
    trailing = dict(jsonrpc='2.0', id='unexecuted', method='tools/call', params=dict(name='repl_execute', arguments=dict(code='host_value=999')))
    raw_trailing = json.dumps(trailing)
    y.p.stdin.write((json.dumps(closing)+'\n'+raw_trailing+'\n'+ '{"partial":').encode())
    assert y.result('close', 'repl_close') == {'status': 'closing'}
    # Parent's record is deliberately not a protocol response.
    line = y.buf
    while b'\n' not in line:
        assert select.select([y.p.stdout], [], [], 5)[0]
        data = os.read(y.p.stdout.fileno(), 4096)
        assert data
        line += data
    parent = json.loads(line.split(b'\n', 1)[0])
    assert parent == dict(parent_continued=True, host_value=999, pending_bytes='{"partial":', pending_messages=[raw_trailing])
finally:
    y.close()
    y.p.stdout.close()
print('PASS actual_dedicated_channel_direct_four_schemas_close_flush_handoff_parent_replay')
