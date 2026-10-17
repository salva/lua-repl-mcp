#!/usr/bin/env python3
"""Real U5 manager processes under an external group watchdog; fixture files are disposable."""
import os
from pathlib import Path
import signal
import resource
import subprocess
import sys
import tempfile
root = Path(__file__).resolve().parents[1]
env = os.environ.copy()
env['LUA_PATH'] = f'{root}/?.lua;{root}/?/init.lua;' + env.get('LUA_PATH', ';')
work = Path(os.environ['SAIVAGE_CARD_WORK_ROOT']) / 'u5-process-tests'
work.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(dir=work) as directory:
    env['U5_DIR'] = directory
    env['U5_RESPONSES'] = str(Path(directory) / 'responses.jsonl')
    proc = subprocess.Popen(['lua5.4', 'tests/u5_process.lua'], cwd=root, env=env,
                            start_new_session=True,
                            preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_NOFILE, (256, 256)))
    try:
        result = proc.wait(timeout=45)
    except subprocess.TimeoutExpired:
        print('FAIL U5 external 45s watchdog', file=sys.stderr)
        result = 124
    finally:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    if result == 0:
        import json
        import jsonschema
        schema = json.loads((root / 'docs/schemas/api.json').read_text())
        responses = [json.loads(line) for line in Path(env['U5_RESPONSES']).read_text().splitlines()]
        for row in responses:
            selected = dict(schema, **{'$ref': '#/$defs/' + row['tool'] + '_output'})
            jsonschema.Draft202012Validator(selected).validate(row['response'])
        print(f'PASS U5 {len(responses)} committed real responses match API schemas')
    sys.exit(result)
