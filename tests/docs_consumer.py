"""Validate LLM-guide arguments and run its embedded recipe over live pipes."""
import json
import os
import pathlib
import re
import selectors
import shutil
import subprocess
import tempfile
import time

from jsonschema import Draft202012Validator


ROOT = pathlib.Path(__file__).resolve().parents[1]
guide = (ROOT / 'README-IF-YOR-ARE-AN-AI.md').read_text()
schema = json.loads((ROOT / 'docs/schemas/api.json').read_text())
blocks = re.findall(r'```json\n(.*?)\n\s*```', guide, re.S)
for name, block in zip(
    ['session_execute', 'session_execute', 'session_kill'], blocks, strict=True
):
    Draft202012Validator({
        '$ref': '#/$defs/' + name, '$defs': schema['$defs']
    }).validate(json.loads(block))
print('PASS: 3 LLM-guide tool arguments match schemas')

# Workspace-local artifacts, never runtime state or credentials.
scratch = ROOT.parent / 'tmp'
with tempfile.TemporaryDirectory(prefix='lua-doc-consumer-', dir=scratch) as directory:
    path = pathlib.Path(directory)
    modules = path / 'modules'
    (modules / 'lua_repl_mcp').mkdir(parents=True)
    for name in (
        'init handler codec framing protocol evaluator limits errors contracts '
        'direct_schemas'
    ).split():
        shutil.copyfile(
            ROOT / 'lua_repl_mcp' / f'{name}.lua',
            modules / 'lua_repl_mcp' / f'{name}.lua',
        )
    snippets = re.findall(r'```lua\n(.*?)\n```', guide, re.S)
    assert len(snippets) == 2, 'Update test when guide Lua blocks change'
    code = (
        'local protocol_input, protocol_output = io.stdin, io.stdout\n'
        + snippets[0].replace('/absolute/path/to/.local/embedded-lua', str(modules))
        + '\n' + snippets[1]
        + "\nassert(attachment.reason == 'close_requested')\n"
        + "for name in pairs(package.loaded) do\n"
        + "  assert(not name:match('^posix') and name ~= 'lua_repl_mcp.manager' "
        + "and name ~= 'lua_repl_mcp.server', name)\nend\n"
    )
    (path / 'host.lua').write_text(code)
    proc = subprocess.Popen(
        ['lua5.4', str(path / 'host.lua')], cwd=path,
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        bufsize=0,
    )
    os.set_blocking(proc.stdout.fileno(), False)
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    pending = bytearray()

    def send(value):
        proc.stdin.write((json.dumps(value) + '\n').encode())
        proc.stdin.flush()

    def receive():
        deadline = time.monotonic() + 5
        while b'\n' not in pending:
            remaining = deadline - time.monotonic()
            assert remaining > 0 and selector.select(remaining), (
                'Complete response frame not received within five seconds'
            )
            try:
                chunk = os.read(proc.stdout.fileno(), 65536)
            except BlockingIOError:
                continue
            assert chunk, 'EOF before complete response frame'
            pending.extend(chunk)
            assert len(pending) <= 2 * 1024 * 1024, 'Unexpectedly large response'
        frame, _, tail = pending.partition(b'\n')
        pending[:] = tail
        return json.loads(frame)

    try:
        send({
            'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {
                'protocolVersion': '2025-11-25', 'capabilities': {},
                'clientInfo': {'name': 'doc-adapter-check', 'version': '1'},
            },
        })
        assert receive()['id'] == 1
        send({'jsonrpc': '2.0', 'method': 'notifications/initialized'})
        send({
            'jsonrpc': '2.0', 'id': 2, 'method': 'tools/call', 'params': {
                'name': 'repl_execute', 'arguments': {'code': 'return 42'},
            },
        })
        response = receive()
        assert response['result']['structuredContent']['values'] == [42], response
        send({
            'jsonrpc': '2.0', 'id': 3, 'method': 'tools/call',
            'params': {'name': 'repl_close', 'arguments': {}},
        })
        assert receive()['id'] == 3
        assert proc.wait(timeout=5) == 0, proc.stderr.read()
        print('PASS: embedded recipe initializes, executes and closes; no native imports')
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait(timeout=5)
        selector.close()
        for stream in (proc.stdin, proc.stdout, proc.stderr):
            stream.close()
