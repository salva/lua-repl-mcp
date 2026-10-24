# Embed in an existing Lua host

Choose this when the host owns the public MCP connection and clients need its
Lua globals and APIs. To launch a supervised application through manager session
tools instead, use [managed custom hosts](custom-host.md); `handler.serve` does
not implement that private managed protocol.
The handler executes on the invoking thread in the existing global environment,
without a new interpreter, worker or background thread. It blocks while serving;
blocking user code cannot be preempted to process close/cancellation.

## Install only pure Lua

Use the exact [copy and package.path recipe](../README-IF-YOR-ARE-AN-AI.md#embedded-host-use).
Copy `init`, `handler`, `codec`, `framing`, `protocol`, `evaluator`, `limits`,
`errors`, `contracts` and `direct_schemas` modules under `lua_repl_mcp/`.
Add both `?.lua` and `?/init.lua` paths. Require `lua_repl_mcp.handler`, not
`manager` or `server`. No LuaRocks, luaposix or compiler is needed by the handler.
The current standalone package uses Lua 5.4; use a supported PUC-Rio host with
standard libraries for embedding. See [reference](reference.md#compatibility).

## Attach dedicated protocol I/O

Call `require('lua_repl_mcp.handler').serve(adapter, options)` from the host.
Adapter members are plain functions, not methods with implicit `self`:

| Function | Success | End/error |
| --- | --- | --- |
| `read(n)` | Between 1 and n bytes; must make progress | `nil, 'eof'` or `nil, error` |
| `write(bytes)` | Positive integer bytes written, at most offered length | `nil, error` |
| `flush()` | `true` | `nil, error` |

Short writes are retried. Invalid progress or exceptions terminate attachment.
Use dedicated streams/descriptors: ordinary host stdout must not corrupt MCP.
The linked recipe uses file `read(1)` because `read(n)` may wait to fill a large
request even when a complete short frame is available. Prefer a genuine bounded
read-some API when available. A successful require is not a functioning transport.

Discover `repl_execute` and `repl_close`. Execute takes code/args, not session IDs
or managed wait/hard-deadline fields. Host APIs are ordinary globals; for example
if the host defines `host_total`, `host_total = host_total + 2; return host_total`
mutates that same host value. It has the host's privileges, not sandbox isolation.

## Close and continue the parent

`repl_close` stops admission, writes and flushes its acknowledgement if possible,
then returns control to the host. Inspect the lifecycle record:

- `reason`: `close_requested`, `eof`, `transport_error` or `handler_error`.
- `acknowledgement_sent`: true only after successful acknowledgement flush.
- Optional diagnostics and close request ID describe failures/context.
- `pending_messages`: complete raw trailing frames in arrival order.
- `pending_bytes`: incomplete trailing frame bytes.

Close may be requested even when acknowledgement failed. Do not discard the
handoff: feed complete pending frames to parent-selected processing in order,
retain the partial tail and append future bytes. Unread bytes still belong to
the adapter. The handler does not execute those trailing messages, close handles,
reset globals, destroy the interpreter or exit the host. The parent chooses
continuation, reset and shutdown. EOF/errors also return without taking ownership.

## Configure bounds

Top-level options are positive integer `input_bytes`, `response_bytes`,
`read_bytes`, an `evaluator` table and optional UTF-8 `instructions`. Unknown
options or invalid limits return `handler_error` before protocol I/O. Defaults
are 16777216 input bytes, 134217728 response bytes and 65536 bytes per read.

The existing `evaluator` options are:

| Key | Default |
| --- | --- |
| `max_bytes` | 16777216 (16 MiB) |
| `max_depth` | 128 |
| `diagnostic_bytes` | 65536 |

`max_bytes` counts bytes in the encoded JSON `values` array, including its tuple
wrapper. `max_depth` counts nested containers per user argument or returned
value. `diagnostic_bytes` bounds combined cleaned message/traceback UTF-8 bytes.

All three must be positive Lua integers. `diagnostic_bytes` must be at least
49 bytes, enough to hold the current loss notice; smaller values are invalid.
For example, with the dedicated adapter described above:

```lua
local attachment = require('lua_repl_mcp.handler').serve(adapter, {
  evaluator = {max_bytes = 1048576, max_depth = 64, diagnostic_bytes = 4096},
})
```

These are evaluator bounds, not an execution time/memory sandbox. Container
roots count as one; scalar leaves add no depth. Positional tuples and fixed
protocol wrappers do not deduct from the user depth allowance. Smaller response
limits can reject otherwise valid values after side effects; do not assume
arbitrary low limits preserve all legal payloads. See [data and errors](data-errors.md).
