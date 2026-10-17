#!/usr/bin/env python3
"""Complete installed regression driver. Test source is data, never a module path."""
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
print('PASS installed_18_module_byte_identity', flush=True)
# Lua adapters/process fixtures are driven by their native or external hosts.
external = {'u2_host.lua', 'u9_host.lua', 'u3_posix.lua'}
for test in sorted((root / 'tests').glob('u[1-7]*.lua')):
    if test.name in external or test.name.endswith('_process.lua'):
        continue
    print('RUN installed ' + test.name, flush=True)
    result = subprocess.run(['lua5.4', str(test)], timeout=240)
    if test.name == 'u7_coupled_defaults_red.lua':
        assert result.returncode == 1, 'historical hardcoded 64MiB reproducer must remain red'
        print('PASS historical_64MiB_red_preserved_not_current_default', flush=True)
    else:
        result.check_returncode()
for name in ['u2_live.py', 'u3_posix.py', 'u4_process.py', 'u5_process.py',
             'u6_process.py', 'u6_progressive_process.py', 'u7_process.py']:
    print('RUN installed ' + name, flush=True)
    subprocess.run([sys.executable, str(root / 'tests' / name)], check=True, timeout=420)
subprocess.run([sys.executable, str(root / 'docs/check_contracts.py')], check=True, timeout=180)
print('PASS complete_installed_core_handler_manager_suite', flush=True)
