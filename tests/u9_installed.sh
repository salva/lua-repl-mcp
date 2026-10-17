#!/bin/sh
# Run from checkout; build/install in caller-selected disposable directory.
set -eu
if ! PYTHONPATH="$(dirname "$0")" python3 -c 'from containment import supervised; raise SystemExit(0 if supervised() else 1)'; then
  exec python3 "$(dirname "$0")/containment.py" 3000 sh "$0" "$@"
fi
: "${SAIVAGE_CARD_WORK_ROOT:?set a disposable card work root}"
ROOT=$(pwd)
W="$SAIVAGE_CARD_WORK_ROOT/u9-clean-reproducer"
[ ! -e "$W/rocks" ] || { echo 'Use an empty u9-clean-reproducer/rocks tree' >&2; exit 1; }
mkdir -p "$W/outside"
unset LUA_PATH LUA_CPATH LUA_PATH_5_4 LUA_CPATH_5_4
luarocks --lua-version=5.4 --tree="$W/rocks" make lua-repl-mcp-0.1.0-1.rockspec
# Explicit installation-only paths, never checkout/default/other-tree fallbacks.
export LUA_PATH="$W/rocks/share/lua/5.4/?.lua;$W/rocks/share/lua/5.4/?/init.lua"
export LUA_CPATH="$W/rocks/lib/lua/5.4/?.so"
cc -Wall -Wextra -Werror "$ROOT/tests/u9_host.c" -o "$W/host" $(pkg-config --cflags --libs lua5.4) -pthread
cd "$W/outside"
lua5.4 -e 'require("lua_repl_mcp.handler"); require("lua_repl_mcp.worker_main"); print("PASS installed_module_resolution")'
"$W/rocks/bin/lua-repl-mcp" </dev/null
LUA_CPATH='' "$W/host" "$ROOT/tests/u9_host.lua"
python3 -m venv "$W/venv"
"$W/venv/bin/pip" install jsonschema==4.19.2
U8_WORK_DIR="$W/live" "$W/venv/bin/python" "$ROOT/tests/u8_live.py" "$W/rocks/bin/lua-repl-mcp"

export U9_INSTALLED_CWD="$W/outside"
export U9_INSTALLED_MODULES="$W/rocks/share/lua/5.4/lua_repl_mcp"
"$W/venv/bin/python" "$ROOT/tests/u9_suite.py"
