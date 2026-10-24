"""Independent installed MCP component client; no agent/UI acceptance implied.
Usage: python3 tests/u14_native_client.py WORK_ROOT CHECKOUT
WORK_ROOT contains rocks/, host, and outside/ from the documented clean build.
"""
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import time

w, root = map(lambda p: Path(p).resolve(), sys.argv[1:])
env = dict(os.environ)
for k in ('LUA_PATH_5_4', 'LUA_CPATH_5_4'):
    env.pop(k, None)
env['LUA_PATH'] = f'{w}/rocks/share/lua/5.4/?.lua;{w}/rocks/share/lua/5.4/?/init.lua'
env['LUA_CPATH'] = f'{w}/rocks/lib/lua/5.4/?.so'
p = subprocess.Popen([str(w/'rocks/bin/lua-repl-mcp'), '--startup-timeout-ms', '2000'],
                     cwd=w/'outside', env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                     stderr=subprocess.PIPE, bufsize=0)
buf = b''
seq = 0

def rpc(method, params):
    global seq, buf
    seq += 1
    p.stdin.write((json.dumps(dict(jsonrpc='2.0', id=seq, method=method, params=params))+'\n').encode())
    deadline = time.monotonic()+12
    while b'\n' not in buf:
        assert select.select([p.stdout], [], [], max(0, deadline-time.monotonic()))[0], 'MCP timeout'
        data = os.read(p.stdout.fileno(), 65536)
        assert data, 'MCP EOF'
        buf += data
    line, buf = buf.split(b'\n', 1)
    r = json.loads(line)
    assert r['id'] == seq, r
    assert 'error' not in r, r
    return r['result']

def call(name, **args):
    r = rpc('tools/call', dict(name=name, arguments=args))
    v = r['structuredContent']
    assert json.loads(r['content'][0]['text']) == v
    return v

try:
    rpc('initialize', dict(protocolVersion='2025-11-25', capabilities={}, clientInfo=dict(name='u14-independent', version='1')))
    p.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
    assert len(rpc('tools/list', {})['tools']) == 5
    command = [str(w/'host'), str(root/'tests/u14_native_host.lua'), '', 'space arg', '; echo NOT_SHELL', '$HOME', 'λ']
    sid = call('session_create', command=command)['session_id']
    def execute(code, **kw):
        return call('session_execute', session_id=sid, code=code, wait_timeout_ms=None, **kw)
    assert execute('host_value=host_api(host_value); return host_value,host_argv')['values'] == [110, command[2:]]
    assert execute('host_value=host_api(host_value); return host_value,require("lua_repl_mcp.bootstrap")~=nil')['values'] == [210, True]
    for code, error in [('local =', 'lua_syntax_error'), ('effects=(effects or 0)+1; error("once")', 'lua_runtime_error'), ('effects=effects+1; return function() end', 'result_serialization_error')]:
        assert execute(code)['error']['code'] == error
    assert execute('return effects,host_value')['values'] == [2, 210]
    receipt = str(w/'outside/continuation')
    Path(receipt).unlink(missing_ok=True)
    assert execute('host_receipt=...;host_stopping=true;return host_api(1)', args=[receipt])['values'] == [101]
    deadline=time.monotonic()+3
    while not Path(receipt).exists() and time.monotonic()<deadline:
        time.sleep(.01)
    assert Path(receipt).read_text() == 'host_stopping:210'
    implicit=call('session_execute', create_options=dict(command=command), code='return host_api(3),host_value', wait_timeout_ms=None)
    assert implicit['values'] == [103,10] and implicit['session_id'] != sid
    killed=call('session_kill', session_id=implicit['session_id'])
    assert killed['process_exit_confirmed'], killed
    # A genuinely foreign-C evaluation must still be terminated by the guardian.
    timed=call('session_execute', create_options=dict(command=command), code='host_block()',
               wait_timeout_ms=None, execution_timeout_ms=50)
    assert timed['error']['code'] == 'execution_timeout', timed
    assert timed['process_exit_confirmed'], timed
    print('PASS installed actual MCP explicit/implicit native API, literal argv, cross-chunk state, module, short native I/O, errors once-only, cooperative host continuation, confirmed kill and foreign-C deadline')
finally:
    p.stdin.close()
    try:
        assert p.wait(timeout=12)==0, p.stderr.read().decode()
    finally:
        if p.poll() is None:
            p.kill(); p.wait()
