#!/usr/bin/env python3
"""Complete installed regression driver. Test source is data, never a module path."""
from containment import enter
enter(2400)
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
modules = Path(os.environ['U9_INSTALLED_MODULES'])
assert Path.cwd() != root
assert ';;' not in os.environ['LUA_PATH']
assert str(root / '?.lua') not in os.environ['LUA_PATH']
os.environ['U9_INSTALLED_LUA_PATH'] = os.environ['LUA_PATH']
for source in sorted((root / 'lua_repl_mcp').glob('*.lua')):
    assert (modules / source.name).read_bytes() == source.read_bytes(), source
print('PASS installed_all_module_byte_identity', flush=True)
os.environ['U12_INSTALLED_CLI'] = str(modules.parents[3] / 'bin/lua-repl-mcp')
# Explicit fixture manifest; no filename-prefix/glob execution policy.
import json
manifest = json.loads((root / 'tests/fixtures.json').read_text())
for fixture in manifest:
    if not fixture['run']:
        continue
    test = root / 'tests' / fixture['path']
    print('RUN installed ' + test.name, flush=True)
    interpreter = sys.executable if test.suffix == '.py' else 'lua5.4'
    result = subprocess.run([interpreter, str(test)], timeout=fixture['deadline'],
                            capture_output=fixture['kind']=='historical', text=True)
    if fixture['kind']=='historical':
        print(result.stdout, end='')
        print(result.stderr, end='', file=sys.stderr)
        assert result.returncode == fixture['expected_status']
        assert fixture['expected_assertion'] in result.stderr, result.stderr
        print('PASS named historical 64MiB assertion (not current default)', flush=True)
    else:
        result.check_returncode()
subprocess.run([sys.executable, str(root / 'docs/check_contracts.py')], check=True, timeout=180)
print('PASS complete_installed_core_handler_manager_suite', flush=True)
