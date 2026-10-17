#!/usr/bin/env python3
"""Run U3 in an isolated process group; kill descendants on timeout/failure."""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
lua = shutil.which('lua5.4')
if not lua:
    sys.exit('lua5.4 required')
env = os.environ.copy()
# Explicit checkout path survives exec; installed paths remain supplied by LuaRocks.
env['LUA_PATH'] = str(root / '?.lua') + ';' + str(root / '?/init.lua') + ';' + env.get('LUA_PATH', ';')
env['U3_LUA'] = lua
env['U3_SCRIPT'] = str(root / 'tests/u3_posix.lua')
proc = subprocess.Popen([lua, env['U3_SCRIPT']], cwd=root, env=env,
                        start_new_session=True)
try:
    result = proc.wait(timeout=20)
except subprocess.TimeoutExpired:
    print('FAIL U3 external 20s watchdog', file=sys.stderr)
    result = 124
finally:
    # Also contain fixtures left behind by abrupt errors in the parent.
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    proc.wait()
sys.exit(result)
