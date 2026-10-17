# Local release candidate: installation and embedding

This is trusted arbitrary code execution, **not a sandbox**. Do not expose the
connection to untrusted users or share privileged host credentials/state. No
public release/publication has been made. Normative semantics and limits are in
[SPEC](SPEC.md); wire schemas in `schemas/api.json`, examples in
[MCP_EXAMPLES](MCP_EXAMPLES.md). Validation and unresolved acceptance are in
[U9_EVIDENCE](U9_EVIDENCE.md).

## Install / run

On the verified Linux/POSIX target install Lua 5.4, its development headers,
LuaRocks and a C compiler. From this checkout:

```sh
luarocks --lua-version=5.4 --tree=/absolute/local/rocks make lua-repl-mcp-0.1.0-1.rockspec
eval "$(luarocks --lua-version=5.4 --tree=/absolute/local/rocks path)"
/absolute/local/rocks/bin/lua-repl-mcp
```

The rockspec installs every `lua_repl_mcp` module and the CLI. It pins
`luaposix == 36.3-1` (upstream 36.3); its transitive bit32 dependency is native.
The strict codec is included pure Lua, not an optional JSON library with different
number/null semantics. `make` is the supported local-source installation method;
the rockspec's file source is a local archive placeholder, not a public download.
No open-source license grant or publication metadata is invented for this private
candidate; the rockspec records `Proprietary` to avoid implying such a grant.

For isolated launch set `LUA_PATH` to the tree's `share/lua/5.4/?.lua` and
`share/lua/5.4/?/init.lua`, and `LUA_CPATH` to `lib/lua/5.4/?.so`. No checkout path
is needed. Keep those paths available to worker exec. The CLI uses `lua5.4`;
selecting a different `lua` default does not change it. Configure the client with
an absolute installed executable path and this environment. Service credentials
and deployment setup belong in project-local ignored operational state, not docs.

The manager uses POSIX fork/exec, pipes, nonblocking IO, poll, monotonic clocks,
signals and wait/reaping. Tests additionally use Linux `/proc` as an ownership
oracle. Lua 5.5 pure handler support is independently tested; luaposix 36.3's
`lua < 5.5` constraint prevents claiming a Lua 5.5 manager package. Never load a
5.4 native module into a 5.5 interpreter.

## Embedded host

Load `require('lua_repl_mcp.handler').serve(adapter, options)` in the **existing**
host interpreter. Do not load `server` or `manager`. Deploy the pure Lua modules
with a normal host package path; no native library is needed by the handler.
The native host example `tests/u9_host.c` is test code, not a product dependency.
It creates one Lua state, registers host functions, then calls the adapter fixture
`tests/u9_host.lua` on the same OS thread. This establishes only that host API,
not arbitrary third-party embedding engines.

Adapter functions are ordinary functions (no implicit `self`): `read(n)` returns
1..n bytes or `nil,'eof'` / `nil,error`; `write(bytes)` returns positive integer
progress up to the offered length or `nil,error`; `flush()` returns `true` or
`nil,error`. Reads/writes may block. Short writes are retried, invalid progress or
exceptions terminate the attachment. Supply dedicated protocol handles; do not
mix protocol frames with host/session stdout. No automatic print/io overrides or
capture are installed. User code can explicitly capture and return output.

Handler options: positive integer `input_bytes`, `response_bytes`, `read_bytes`,
`evaluator` limits and optional UTF-8 `instructions`. Unknown options fail with
`handler_error`; see `limits.lua` and SPEC §14.4 for evaluator and connection
limits. Manager library entrypoint is `server.serve(io, options)`; its bounded
nonblocking adapter uses `client_transport.lua`. CLI uses standard defaults,
not undocumented command-line switches. Tool arguments configure cwd, output
paths, execution/wait timeouts and session selection per advertised schemas.
Do not lower response bounds assuming all legal payloads will still fit: the
unresolved default maximum-fit contradiction is recorded in U9 evidence.

## Lifecycle, state, errors and outputs

Explicit `return` is required; chunks run once, globals/functions persist, locals
do not. JSON null maps to `require('lua_repl_mcp').null`; nil return slots are
preserved. Conversion rejects unsupported/cyclic/mixed/sparse data atomically,
with JSON Pointers; ordinary errors preserve side effects and session usability.

Direct mode is synchronous and cannot preempt blocking user code. `repl_close`
acknowledges and flushes before returning where possible. The structured result
reports `reason` (`close_requested`, `eof`, `transport_error`, `handler_error`),
`acknowledgement_sent`, optional diagnostics/close ID, `pending_messages` and
`pending_bytes`. On failed close write it may still report close_requested with
ack false. Parent must inspect it, replay complete pending frames in order and
retain the partial tail for the next read; handler does not execute trailing
frames, reset state, close handles or destroy the interpreter. The host chooses
continuation, reset and shutdown. Code runs on the invoking host thread, no new
interpreter or module-created background thread.

Manager tools create independent persistent worker processes, route sessions by
ID and correlate requests by JSON-RPC ID. Null execute session allocates; wait
and kill require concrete IDs. Async/poll/wait do not reexecute code. Exactly one
consumer receives a terminal payload; later consumers get result_unavailable.
Wait timeout only stops waiting; execution deadline, cancellation and kill dispose
of the worker. Worker `os.exit()` does not exit the manager. Cancellation suppresses
the cancelled RPC reply. There are no keep-alive guarantees or public task IDs.
Disconnect disposes all connection-owned workers and metadata; cleanup may be
bounded without confirmed process exit, reported honestly rather than as death.

Standard worker streams never carry MCP. Explicit output files are exclusively
created, never overwritten; paths resolve against the selected cwd, stdout and
stderr may share one newly created file. Startup failure may leave honestly
reported partial created paths. Manager owns child processes/descriptors; parent
hosts own direct adapters and interpreter handles. This is not safe isolation
against malicious trusted code, resource exhaustion or leaked host capabilities.
