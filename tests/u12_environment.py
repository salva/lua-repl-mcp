"""Explicit installed-only mode shared by the U12 real-process fixtures."""
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CWD = Path(os.environ.get('U9_INSTALLED_CWD', ROOT)).resolve()
CLI = Path(os.environ.get('U12_INSTALLED_CLI', ROOT / 'lua-repl-mcp')).resolve()
PRELUDE = ''
if 'U9_INSTALLED_CWD' in os.environ:
    modules = Path(os.environ['U9_INSTALLED_MODULES']).resolve()
    assert CWD != ROOT, 'installed cwd must not be checkout root'
    assert CLI.is_file() and CLI != ROOT / 'lua-repl-mcp'
    for key in ('LUA_PATH_5_4', 'LUA_CPATH_5_4'):
        assert not os.environ.get(key), 'versioned paths override installation-only paths'
    expected_paths = {
        'LUA_PATH': [str(modules.parent / '?.lua'), str(modules.parent / '?/init.lua')],
        'LUA_CPATH': [str(modules.parents[3] / 'lib/lua/5.4/?.so')],
    }
    for key, expected in expected_paths.items():
        assert os.environ[key].split(';') == expected, 'non-installation search paths: ' + key
    assert CLI == modules.parents[3] / 'bin/lua-repl-mcp', 'CLI must belong to same tree'
    assert all((modules / source.name).read_bytes() == source.read_bytes()
               for source in (ROOT / 'lua_repl_mcp').glob('*.lua')), 'installed module identity'
    # Assert actual Lua resolution in the manager process, before any spawn.
    # Worker exec inherits precisely these paths; matrix barriers prove it readies.
    PRELUDE = '''
local expected=%s
for _,name in ipairs{'server','guardian','guardian_channel','worker_supervisor','worker_main'} do
 local found=assert(package.searchpath('lua_repl_mcp.'..name,package.path))
 assert(found==expected..'/'..name..'.lua', 'non-installed module: '..found)
end
''' % json.dumps(str(modules))
