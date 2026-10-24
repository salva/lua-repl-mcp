# Independent U14 native installed fixture

Candidate: `98f26efe62f5d768c8428cfda41355c9971b5a29`.
No production edits. This is a real C executable linked to Lua 5.4.6, not a
Lua launcher/proxy. Its C read/write callbacks deliberately transfer at most
7/11 bytes; its native API verifies state identity. Host Lua code loads ordinary
installed modules, serves in that state, then continues and writes a receipt.
The Python client executes installed MCP stdio, including initialize and actual
explicit/implicit tools/call. This is component-client, not agent/UI evidence.

Reproduce from checkout, with an unused work directory:

```sh
W="$SAIVAGE_CARD_WORK_ROOT/u14-independent"
mkdir -p "$W/outside"
env -u LUA_PATH -u LUA_CPATH -u LUA_PATH_5_4 -u LUA_CPATH_5_4 \
  luarocks --lua-version=5.4 --tree="$W/rocks" make lua-repl-mcp-0.1.0-1.rockspec
cc -Wall -Wextra -Werror tests/u14_native_host.c -o "$W/host" \
  $(pkg-config --cflags --libs lua5.4)
ulimit -n 256
python3 tests/u14_native_client.py "$W" "$PWD"
```

Fresh dependency installation resolved LuaRocks 3.8.0, luaposix 36.3-1 and
bit32 5.3.5.1-1. Interpreter and embedding pkg-config version: 5.4.6.
Client explicitly sets only `$W/rocks/share/lua/5.4/?.lua` and
`$W/rocks/share/lua/5.4/?/init.lua`, and `$W/rocks/lib/lua/5.4/?.so`;
removes versioned path overrides; runs from `$W/outside`, not source cwd.
The fixture script itself is a supplied absolute test input. Pure host modules
must not import posix. FD3 must arrive without CLOEXEC; host promptly sets it.
The native ABI uses the system Lua 5.4 headers/library matching that interpreter.

Assertions: literal empty/space/shell-looking/Unicode argv; host native API/global
across chunks; ordinary installed module import; isolated implicit allocation;
syntax/runtime/serialization errors and once-only effects; cooperative stopping
after flush; continued host state/borrowed FD ownership; confirmed kill; hard
deadline interrupting a genuinely foreign-C blocking API.

The fixture now also asserts subprocess CLOEXEC, pending/busy semantics while
foreign-C is active, and actual manager SIGKILL with exact native child identity
disappearance observed before containment final cleanup. `u14_native_matrix.lua`
covers all eight closed-stdio masks, graceful close, exec/cwd/stdio failure and
initialization timeout on that same installed production candidate.

Not covered by these fixtures: cancellation/single-consumer permutations,
native late-readiness variants, blocked-I/O wakeup, or an installation outside
the checkout filesystem. The preexisting partial-acquisition test was updated
from obsolete two-pipe injection points to socketpair/two-CLOEXEC/one-nonblock
points; it retains exact pre/post FD-count and fake-child ownership assertions.
Existing default tests cover additional shared primitives, not stronger custom
host assertions than actually executed.
