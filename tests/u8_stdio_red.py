"""Focused U8 red probe; pass an eventual installed CLI as command arguments.

The current manager library is the only manager entry candidate in this tree.
This probe does not treat library unit tests as an external MCP endpoint.
"""
import json
import select
import subprocess
import sys

command = sys.argv[1:] or ['lua5.4', 'lua_repl_mcp/manager.lua']
p = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                     stderr=subprocess.PIPE, bufsize=0)
try:
    initialize = dict(jsonrpc='2.0', id='u8-initialize', method='initialize',
                      params=dict(protocolVersion='2025-11-25', capabilities={},
                                  clientInfo=dict(name='u8-red-probe', version='1')))
    p.stdin.write((json.dumps(initialize) + '\n').encode())
    p.stdin.flush()
    assert select.select([p.stdout], [], [], 5)[0], 'No MCP initialization response within 5s'
    raw = p.stdout.readline()
    assert raw, ('Manager candidate exited without an MCP initialization response; '
                 'complete external stdio integration is absent')
    response = json.loads(raw)
    assert response['id'] == initialize['id']
    assert response['result']['protocolVersion'] == '2025-11-25'
    assert response['result']['capabilities']['tools'] == {}
    assert 'tasks' not in response['result']['capabilities']
    print('PASS external_manager_initialization')
finally:
    p.stdin.close()
    try:
        p.wait(timeout=5)
    except subprocess.TimeoutExpired:
        p.kill()
        p.wait()
