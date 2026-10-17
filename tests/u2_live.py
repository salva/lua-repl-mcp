"""Live dedicated pipe fixture, schema validation and blocking close ordering."""
import importlib.util
import json
import pathlib
import select
import subprocess
import time
import jsonschema

spec = importlib.util.spec_from_file_location('contracts', 'docs/check_contracts.py')
contracts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contracts)
doc = json.loads(pathlib.Path('docs/schemas/api.json').read_text())
expanded = {n: {'$schema': doc['$schema'], **contracts.expand(v, doc['$defs'])}
            for n, v in doc['$defs'].items()}
# Verify generated runtime discovery stays byte-for-byte semantically in sync.
source = pathlib.Path('lua_repl_mcp/direct_schemas.lua').read_text()
tools = json.loads(source.split('[====[', 1)[1].split(']====]', 1)[0])
for tool in tools:
    for field, suffix in [('inputSchema', ''), ('outputSchema', '_output')]:
        assert tool[field] == expanded[tool['name'] + suffix]
        jsonschema.Draft202012Validator.check_schema(tool[field])

p = subprocess.Popen(['lua5.4', 'tests/u2_host.lua'], stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
def send(id, method, params=None):
    r = dict(jsonrpc='2.0', method=method)
    if id is not None:
        r['id'] = id
    if params is not None:
        r['params'] = params
    p.stdin.write((json.dumps(r) + '\n').encode())
def receive():
    assert select.select([p.stdout], [], [], 5)[0], 'host response timeout'
    return json.loads(p.stdout.readline())
try:
    send(1, 'initialize', dict(protocolVersion='2025-11-25', capabilities={}, clientInfo=dict(name='external', version='1')))
    assert receive()['result']['protocolVersion'] == '2025-11-25'
    send(None, 'notifications/initialized')
    send(2, 'tools/list')
    live_tools = receive()['result']['tools']
    assert live_tools == tools
    send(3, 'tools/call', dict(name='repl_execute', arguments=dict(code='host_block(); return host_value')))
    send(4, 'tools/call', dict(name='repl_close', arguments={}))
    # Both messages were delivered; native blocking call must not service close.
    assert not select.select([p.stdout], [], [], 0.1)[0]
    execution, close = receive(), receive()
    assert execution['id'] == 3 and close['id'] == 4
    for response, name in [(execution, 'repl_execute'), (close, 'repl_close')]:
        result = response['result']
        jsonschema.validate(result['structuredContent'], expanded[name + '_output'])
        assert json.loads(result['content'][0]['text']) == result['structuredContent']
        assert result['isError'] == ('error' in result['structuredContent'])
    assert execution['result']['structuredContent']['values'] == [11]
    assert receive() == dict(parent_continued=True, reason='close_requested')
    assert p.wait(timeout=5) == 0, p.stderr.read().decode()
finally:
    if p.poll() is None:
        p.kill()
        p.wait()
print('PASS live_pipe_blocked_host_close_order_parent_continuation_and_direct_schemas')
