# Lua REPL MCP: installation and use for AI clients

## Purpose and mode selection

Use this module to execute Lua through MCP while preserving globals between
calls. Always use explicit `return` for results; expressions are not implicitly
returned, and printed output is not captured.

- **Standalone manager:** launch `lua-repl-mcp` over MCP stdio. Each session has
  an independent persistent Lua process. Choose this for normal MCP-client use.
- **Managed custom host:** the manager launches your foreground executable with
  literal `command` argv. Chunks run in that program's existing Lua state via
  `lua_repl_mcp.session`, using session tools. Destructive cancellation/kill also
  destroys the application host. See [custom-host integration](site-docs/custom-host.md)
  for installation, FD3/bootstrap and native adapter requirements. Independent
  final runtime acceptance remains incomplete.
- **Embedded handler:** a Lua host attaches the handler to dedicated protocol
  I/O. Code runs synchronously in that host's existing globals, with access to its
  APIs. This is not a separate worker and cannot preempt blocking host code.

Both modes execute trusted code with full process privileges, **not in a
sandbox**. Obtain authorization for filesystem/network access and destructive
operations; do not expose the connection to untrusted users.

## Install the standalone manager from a checkout

Use a POSIX system with `lua5.4`, Lua 5.4 development headers, LuaRocks and a C
compiler. The package pins luaposix 36.3-1; do not assume manager support for Lua
5.5 or reuse Lua 5.4 native modules in another interpreter version.

From the repository root, choose an absolute writable installation directory:

```sh
export ROCKS_TREE="$PWD/.local/rocks"
luarocks --lua-version=5.4 --tree="$ROCKS_TREE" make lua-repl-mcp-0.1.0-1.rockspec
eval "$(luarocks --lua-version=5.4 --tree="$ROCKS_TREE" path)"
"$ROCKS_TREE/bin/lua-repl-mcp"
```

This is local-source installation, not a claim that a public LuaRocks release
exists. Dependency installation may require network access. The final command
starts a protocol server waiting for MCP input, not an interactive terminal REPL.
Normally let your MCP client launch it instead of running it manually.

Configure your client's **stdio** server entry with the absolute installed
executable path, no CLI arguments, and the LuaRocks environment from above.
Client configuration formats differ; use its actual documentation. Preserve
`PATH`, `LUA_PATH` and `LUA_CPATH` for worker processes as well as the manager.
Do not write diagnostic text to protocol stdout.

## Discover, execute, reuse and dispose

Complete the MCP initialization handshake, then call `tools/list`. Use the
advertised names and schemas; client UI names may be prefixed. The manager
provides `session_create`, `session_list`, `session_execute`, `session_wait` and
`session_kill`. There is no public task ID, reset tool or separate session-close
tool. The JSON below is **tool arguments**, not full JSON-RPC envelopes.

1. Call `session_execute` to allocate a session implicitly:

   ```json
   {"code":"local n = ...; counter = (counter or 0) + n; return counter","args":[2],"wait_timeout_ms":1000}
   ```

   Retain the returned `session_id`. On completion, expect `values: [2]`.
   If the reply is pending, use `session_wait`; do not submit the code again.

2. Call `session_execute` with that actual ID (replace the placeholder):

   ```json
   {"session_id":"<returned session_id>","code":"return counter","wait_timeout_ms":1000}
   ```

   Expect `[2]` again because globals persist. Top-level locals do not persist.

3. When finished, call `session_kill`:

   ```json
   {"session_id":"<returned session_id>"}
   ```

   This destroys session state. Inspect `process_exit_confirmed` and warnings;
   successful best-effort cleanup does not always establish OS process exit.

Read MCP `structuredContent` when available, rather than parsing both it and the
compatibility text as separate results. Check operation errors and execution
status before using `values`; an accepted call need not be a successful execution.

## Long-running work and results

- Set `wait_timeout_ms: 0` on execute to return asynchronously. Poll with
  `session_wait` using the same session ID and a bounded `wait_timeout_ms`, such
  as 1000. Wait expiry leaves execution running; polling never reexecutes code.
- `wait_timeout_ms: null` waits indefinitely; omission defaults to ten minutes.
  A client's own shorter deadline may interrupt either choice and close the
  connection, losing all sessions. Prefer bounded polling when uncertain.
- `execution_timeout_ms` is a separate hard deadline that destroys the session.
  Omission means no hard deadline. Accepted cancellation of an active request
  destroys its associated session; it is not a harmless way to stop waiting. Unknown, completed (even before
  response commitment) and answered request cancellations are inert.
- A terminal payload is consumed exactly once through execute or wait. Save it
  when received. Later wait can return `result_unavailable`. An accepted new
  execution replaces any unread prior result; do not execute into a busy session.

## Data, side effects and recovery

JSON `args` become Lua varargs (`...`). In Lua, JSON null is
`require('lua_repl_mcp').null`; nil return slots are preserved as JSON null.
Return JSON-compatible values, not functions, threads, userdata, cyclic tables,
or sparse/mixed tables. Conversion failure discards the entire return payload,
but does not roll back code already executed.

Syntax/runtime errors normally leave the session usable, and earlier side
effects may remain. Inspect `session_usable` and the returned status. Worker
exit, cancellation, hard timeout or kill can make the session unavailable.
Use `session_list` to inspect current sessions; do not blindly replay a
state-changing operation after a timeout or lost response.

Use `session_create` or execute's `create_options` to select `cwd` and explicit
stdout/stderr paths. Output files must not already exist; defaults discard worker
output to `/dev/null`. There is no automatic print capture. Manager connection
loss disposes of its sessions; persistence is not durable across reconnection.

## Managed custom-host first use

Prepare your foreground Lua-embedding executable and install the pure modules
in its actual interpreter, as described in [custom hosts](site-docs/custom-host.md).
The manager's LuaRocks environment does not automatically initialize an embedded
interpreter's package paths; native modules must match that host's Lua ABI.
A public `handler.serve` implementation alone is not a managed child.

After MCP discovery, call `session_create` with tool arguments (replace paths):

```json
{"command":["/opt/example/bin/lua-host","--managed-session","--label",""],"cwd":"/data/trial","stdout_path":"host-output.log","stderr_path":"host-error.log"}
```

Arguments are literal UTF-8 strings without NUL, not a shell command. The array
and first string must be nonempty; later empty strings are allowed. Omit command
for the default interpreter. It cannot change for an existing allocation.
For implicit creation, put the object in `session_execute.create_options` with
no session ID. In either path, retain the returned ID and use normal execute,
wait and kill calls. If the host registers `host_add`, execute
`total = host_add(20, 22); return total` and expect `[42]` when complete; then
`return total` confirms persistent state. This example API is host-supplied.

Set client launch args to `--startup-timeout-ms`, `60000` for a longer finite
startup budget (default 30000 ms, integer 1..2147483647). This covers allocation
setup and host readiness, not execution. Readiness proves protocol compatibility,
not application correctness. Inspect startup errors/output, repair installation
or adapter problems, then create a new session; never replay effects blindly.
A pending wait is non-destructive; accepted active-request cancellation, hard
timeout, kill or manager loss destroys the owned host, without rollback or a
finalizer guarantee. Cooperative `stopping` in the host adapter is different:
it cannot preempt Lua/foreign C or wake blocked I/O. The host owns FD3 CLOEXEC,
wakeup, eventual close and post-return policy; `session.serve` borrows I/O.

## Embedded-host use

The embedded handler needs a host running Lua 5.4 or newer supported PUC-Rio Lua,
with the standard libraries available and dedicated protocol I/O. It does not
need LuaRocks, luaposix, a compiler or the standalone executable. From a checkout,
copy only the pure-Lua dependency set into a directory you control:

```sh
export LUA_REPL_MODULES="$PWD/.local/embedded-lua"
mkdir -p "$LUA_REPL_MODULES/lua_repl_mcp"
for module in init handler codec framing protocol evaluator limits errors contracts direct_schemas; do
  cp "lua_repl_mcp/$module.lua" "$LUA_REPL_MODULES/lua_repl_mcp/$module.lua"
done
```

In the existing host interpreter, add that directory to its module search path
(replace the absolute path with the actual value of `LUA_REPL_MODULES`):

```lua
local modules = '/absolute/path/to/.local/embedded-lua'
package.path = modules .. '/?.lua;' .. modules .. '/?/init.lua;' .. package.path
local handler = require('lua_repl_mcp.handler')
```

Provide the adapter using the host's dedicated stream/socket APIs. For example,
if the host supplies Lua file handles named `protocol_input` and
`protocol_output` on the invoking thread, wrap them as follows (do not substitute
ordinary application stdout):

```lua
local adapter = {
  read = function(n)
    -- File read(n) may wait to fill n bytes. One byte guarantees progress
    -- for short MCP frames without waiting for EOF or another request.
    local bytes, err = protocol_input:read(1)
    if bytes == nil then return nil, err or 'eof' end
    return bytes
  end,
  write = function(bytes)
    local ok, err = protocol_output:write(bytes)
    if not ok then return nil, err end
    return #bytes
  end,
  flush = function()
    return protocol_output:flush()
  end,
}
local attachment = handler.serve(adapter)
-- The host now handles attachment.reason and the buffered handoff below.
```

This call blocks until close, EOF or failure. Host I/O must satisfy the progress
contract below; adapt non-file handles using their real APIs, not these file
methods. The one-byte file adapter prioritizes correctness over throughput;
prefer a bounded read-some API when the host offers one. A successful require
alone does not establish a working MCP transport.

The host calls `require('lua_repl_mcp.handler').serve(adapter, options)` in its
existing interpreter, without importing manager/native modules. Supply ordinary
functions `read(n)`, `write(bytes)`, `flush()` on dedicated protocol handles:
read returns bytes or `nil, 'eof'`/error; write returns positive byte progress or
`nil, error`; flush returns `true` or `nil, error`.

Discover `repl_execute` and `repl_close` instead of session tools. Close returns
control to the host without resetting globals or closing transport. The host
must inspect the returned reason, acknowledgement and buffered messages/bytes
before continuing; managed kill/deadline semantics do not apply to this mode.

## Detailed public contracts

- [Wire examples and initialization](docs/MCP_EXAMPLES.md)
- [Tool input/output schemas](docs/schemas/api.json)
