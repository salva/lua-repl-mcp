#!/usr/bin/env python3
"""Real U6 manager processes under an external group watchdog; fixture files are disposable."""
from containment import enter
enter(420)
import os
from pathlib import Path
import signal
import resource
import subprocess
import sys
import tempfile
root = Path(__file__).resolve().parents[1]
env = os.environ.copy()
if not os.environ.get('U9_INSTALLED_CWD'):
    env['LUA_PATH'] = f'{root}/?.lua;{root}/?/init.lua;' + env.get('LUA_PATH', ';')
work = Path(os.environ['SAIVAGE_CARD_WORK_ROOT']) / 'u6-process-tests'
work.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(dir=work) as directory:
    env['U6_DIR'] = directory
    env['U6_RESPONSES'] = str(Path(directory) / 'responses.jsonl')
    os.mkfifo(Path(directory) / 'blocked.fifo')
    proc = subprocess.Popen(['lua5.4', str(root / 'tests/u6_process.lua')], cwd=os.environ.get('U9_INSTALLED_CWD', root), env=env,
                            start_new_session=False,
                            preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_NOFILE, (256, 256)))
    try:
        result = proc.wait(timeout=45)
    except subprocess.TimeoutExpired:
        print('FAIL U6 external 45s watchdog', file=sys.stderr)
        result = 124
    finally:
        try:
            proc.kill()
        except ProcessLookupError:
            pass

    if result == 0:
        import json
        import jsonschema
        schema = json.loads((root / 'docs/schemas/api.json').read_text())
        responses = [json.loads(line) for line in Path(env['U6_RESPONSES']).read_text().splitlines()]
        for response in responses:
            selected = dict(schema, **{'$ref': '#/$defs/' + response['tool'] + '_output'})
            jsonschema.Draft202012Validator(selected).validate(response['response'])
        print(f'PASS U6 {len(responses)} committed responses match API schemas')
sys.exit(result)
