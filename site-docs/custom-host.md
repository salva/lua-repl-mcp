# Run sessions inside your own Lua host

Use this mode when chunks must see an application's existing Lua globals, native
functions and ordinary `require` modules, while an MCP client uses the manager's
session tools. Each allocation launches one foreground host process. This is not
a proxy interpreter controlling the application by RPC.

Choose the default interpreter when no application APIs are needed: omit
`command`. Choose the independent [public handler](embedding.md) when the host
owns the MCP connection and must regain control on `repl_close`. That handler
speaks public MCP; it is **not** a managed child implementation.

This capability is a development candidate. Independent final runtime acceptance
is not complete; validate your own host integration before relying on it.

## Launch a prepared host

Install the manager using [getting started](getting-started.md). Build/install
your own Lua-embedding executable and the modules below before requesting a
session. These are tool arguments, after MCP initialization and discovery:

```json
{"command":["/opt/example/bin/lua-host","--managed-session","--label",""],"cwd":"/data/trial","stdout_path":"host-output.log","stderr_path":"host-error.log"}
```

Call `session_create` with those arguments and retain its `session_id`. Paths and
host flags are illustrative: replace them with your executable's actual interface
and an existing directory. Output files must not exist. Relative paths resolve
against the selected cwd; defaults discard output to `/dev/null`. Created files
use exclusive creation with mode 0600 subject to umask; existing input files are
not replaced. stdout and
stderr may share the same path. Output is not captured in MCP results.

`command` is a dense, nonempty array of UTF-8 strings without NUL. Its first
string must be nonempty; later strings may be empty. Arguments are literal:
there is no shell expansion, quoting evaluation, pipeline or redirection. Exec
path resolution occurs after cwd setup; use absolute executable paths for clarity.
Omission selects the configured/default Lua interpreter. A command is fixed for
that allocation; different sessions may use different commands. Keep the exact
host in foreground, not a daemon that escapes supervision.

For implicit creation, pass the same object as `session_execute.create_options`
while omitting `session_id`. For an existing session, reuse its ID without creation
options. For example, if your host installs `host_add` in its Lua state:

```json
{"session_id":"<returned session_id>","code":"total = host_add(20, 22); return total","wait_timeout_ms":1000}
```

Expect `values: [42]` when complete. A later `return total` in the same session
returns 42; top-level locals do not persist. A pending reply requires
`session_wait`, not resubmission. `host_add` is an application API you implement,
not a module supplied by this package.

The installed manager accepts `--startup-timeout-ms N` (default 30000, integer
1..2147483647), for example `lua-repl-mcp --startup-timeout-ms 60000`. Configure
these as separate client launch arguments. The finite startup budget begins at
allocation, covering setup, executable initialization and protocol readiness;
it is not `wait_timeout_ms` or the execution hard deadline.

## Install modules for the embedding interpreter

The manager/default wrapper requires Lua 5.4 and luaposix 36.3-1. The real native
host exercised during development embeds Lua 5.4.6. This does not certify arbitrary
embedding runtimes. Install the local rock using the exact commands in the
[LLM guide](../README-IF-YOR-ARE-AN-AI.md); expose its `share/lua/5.4/?.lua` and
`share/lua/5.4/?/init.lua` to the embedding interpreter's `package.path`.

Alternatively copy the pure managed dependency set from a checkout:

```sh
export LUA_REPL_MODULES="$PWD/.local/managed-lua"
mkdir -p "$LUA_REPL_MODULES/lua_repl_mcp"
for module in init session bootstrap worker_protocol codec framing protocol evaluator limits errors contracts direct_schemas; do
  cp "lua_repl_mcp/$module.lua" "$LUA_REPL_MODULES/lua_repl_mcp/$module.lua"
done
```

Prepend that absolute directory's `?.lua` and `?/init.lua` patterns to
`package.path` **in the host's existing Lua state**. The pure session/bootstrap
modules do not import luaposix or require native Lua modules. Any optional C
extensions loaded by your application must match its actual Lua ABI; the manager's
LuaRocks `LUA_CPATH` is not proof of compatibility. Do not load Lua 5.4 shared
modules into a different ABI. Distribution terms for your application are separate
from module-path setup; installation grants no additional license rights.

## Adopt the launch endpoint

The version-1 launch ABI supplies one blocking bidirectional Unix stream socket
on FD3, with configured standard streams on 0/1/2. Read the reserved environment
strings (the launcher overwrites these values):

- `LUA_REPL_MCP_SESSION_FD` — exactly `3`.
- `LUA_REPL_MCP_ALLOCATION_GENERATION` — positive allocation generation.
- `LUA_REPL_MCP_LIMITS` — JSON containing all seven connection budgets.

Decode them with the pure helper; malformed/missing input must fail startup:

```lua
local launch, problem = require('lua_repl_mcp.bootstrap').decode(
  os.getenv('LUA_REPL_MCP_SESSION_FD'),
  os.getenv('LUA_REPL_MCP_ALLOCATION_GENERATION'),
  os.getenv('LUA_REPL_MCP_LIMITS'))
assert(launch, problem)
-- host_io and host_cwd below must be supplied by your native integration.
-- Adopt launch.fd and mark it CLOEXEC before spawning or executing user code.
local outcome = require('lua_repl_mcp.session').serve(host_io, {
  allocation_generation = launch.allocation_generation,
  limits = launch.limits,
  cwd = host_cwd, -- actual absolute cwd, unchanged from launch until ready
  stopping = function() return host_stop_requested end,
})
-- Host inspects outcome, closes its endpoint and chooses continuation/exit.
```

This is integration code, not a generic runnable FD adapter: standard Lua file
I/O cannot portably adopt an inherited socket. Supply `host_io` using your host's
native socket APIs on the invoking Lua thread. Decode bounds are FD3, supported
positive integer generation spelling (at most 19 digits), and at most 4096 bytes
of exact validated limits JSON. Do not fabricate generations or loosen budgets.

The adapter contains plain functions, not colon methods:

| Function | Required result |
| --- | --- |
| `read(n)` | 1..n bytes; `nil` on EOF; `nil, diagnostic` on error |
| `write(bytes)` | positive integer bytes written, no more than supplied; or `nil, diagnostic` |
| `flush()` | `true`; or `nil, diagnostic` |

Handle interrupted system calls in the native adapter. Short reads/writes are
supported; empty reads are not progress. Do not wait to fill n bytes when a short
frame is already available. Do not send application logs on this socket.

Invoke `serve` only after application APIs are usable. It emits readiness and
runs generation-ordered chunks in the calling state; readiness proves protocol
compatibility, not binary authenticity or application correctness. A public
`handler.serve` cannot substitute for this private managed protocol.

## Outcomes, stopping and ownership

`session.serve` blocks and borrows the adapter. It returns a table with `reason`
(`closed`, `eof`, `host_stopping`, `protocol_error` or `transport_error`) and
available `diagnostics`. It does not close descriptors, redirect streams, spawn
threads, exit the process or reset globals. The host owns eventual close and its
post-return policy. EOF alone does not prove process exit.

`stopping` is optional (defaults false). It is checked before readiness and each
execution admission, including buffered commands, and after flushing an active
result. It cannot preempt Lua/foreign C or wake blocked I/O. Arrange wakeup using
your own stable descriptor lifetime, for example shutdown followed by close only
after the serving thread returns. Do not close/reuse an FD while that thread may
still access it. Private managed close has no acknowledgement and does not execute
buffered later commands; it is not public `repl_close`'s handoff contract.

Wait expiry leaves work running. Accepted active-request cancellation, hard
execution timeout, `session_kill` and manager loss instead destroy the owned host
process/session. They are **not an application's non-destructive Stop button**.
The manager supervises the exact child, not arbitrary daemonized descendants;
hard termination cannot guarantee finalizers, rollback or host continuation.
Check `process_exit_confirmed` and cleanup notices rather than inferring exit
from a removed session or EOF.

Ordinary syntax/runtime/serialization errors normally leave a healthy session
usable. Return JSON scalars/tables, not opaque userdata or native objects; keep
those in host globals and return IDs or summaries explicitly. Serialization
failure occurs after effects and discards the complete return payload. Results
are consumed once; a new accepted execution replaces an unread result. Never
replay a state-changing chunk after a lost reply just to get a result.

Startup failure may report `handshake_failed`, early EOF or process exit rather
than a detailed host diagnosis. Inspect known output/file receipts and repair the
host's module path, ABI, adapter or initialization before allocating a fresh
session. Late readiness cannot revive an aborted allocation. Retain external
application effects for reconciliation; neither startup disposal nor killing a
session promises to undo them. See [manager tasks](manager.md) and
[data and errors](data-errors.md) for result and recovery details.
