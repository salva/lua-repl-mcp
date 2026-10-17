"""Reject accidental checkout/default fallbacks before installed U12 processes spawn.
Run with the same installed environment as u12_matrix.py, from any cwd.
"""
import os
import subprocess
import sys
from pathlib import Path
import u12_environment as target

assert 'U9_INSTALLED_CWD' in os.environ, 'this assertion requires installed mode'
assert target.CLI.is_file()
for key, bad in [
    ('LUA_PATH', os.environ['LUA_PATH'] + ';;'),
    ('LUA_CPATH', './?.so'),
    ('LUA_PATH_5_4', './?.lua'),
    ('LUA_CPATH_5_4', './?.so'),
    ('U12_INSTALLED_CLI', str(target.ROOT / 'lua-repl-mcp')),
    ('U9_INSTALLED_CWD', str(target.ROOT)),
]:
    env = dict(os.environ, **{key: bad})
    code = 'import sys; sys.path.insert(0, %r); import u12_environment' % str(Path(__file__).resolve().parent)
    result = subprocess.run([sys.executable, '-c', code], env=env,
                            capture_output=True, timeout=5)
    assert result.returncode != 0 and b'AssertionError' in result.stderr, (key, result.stderr)
    print('PASS installed_environment_rejects', key, flush=True)
