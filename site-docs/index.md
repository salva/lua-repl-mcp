# Persistent Lua execution through MCP

Use Lua REPL MCP to keep working state between tool calls, compute explicit JSON
results, or give a client access to an existing Lua application's APIs.
This is static documentation, not a browser REPL or remote execution service.

**Trusted code only: not a sandbox.** Executed Lua has the process's full system
privileges. Authorize access before running code; do not expose privileged hosts
to untrusted clients. Printed output is not automatically captured.

## Choose your interface

| Your goal | Choose | State belongs to |
| --- | --- | --- |
| Run Lua from an ordinary MCP client | POSIX session manager | Independent worker process per session |
| Use an application's existing Lua globals and APIs | Embedded handler | The invoking host interpreter |

```text
MCP client -- stdio --> manager -- guardian --> Lua workers (one per session)
MCP client -- dedicated host I/O --> blocking handler --> existing host globals
```

## What you can accomplish

- Keep globals and functions between calls; send JSON inputs as Lua varargs.
- Run independent managed sessions concurrently over one connection.
- Start work asynchronously, then poll for a single-consumption result.
- Embed without manager/native dependencies or a separate interpreter.
- Recover from ordinary code errors without automatically losing prior state.

A call executes a complete Lua chunk once. Use `return` to produce results;
there is no implicit expression evaluation. Top-level locals do not persist.
Waiting is not execution: a wait timeout leaves work running, whereas a managed
hard execution deadline, cancellation or kill destroys that session. Connection
loss disposes of all its sessions; this is not durable storage.

## Get a first result

[Install the manager](getting-started.md), [embed in a host](embedding.md), or
use the exact [LLM consumer guide](../README-IF-YOR-ARE-AN-AI.md).
Continue with [stateful tasks and recovery](manager.md) and
[public reference](reference.md).

## Package status

The current source package is a **development candidate**, version 0.1.0-1,
not a stable release. Known correctness and lifecycle issues are being repaired;
independently validate important results and do not rely on it for production
workloads yet. No public package-registry availability is claimed.
The standalone target is Lua 5.4 on
POSIX; the independent handler is pure Lua. See [operations](operations.md) for
resource defaults and lifecycle limitations.

Built with [Saivage](https://github.com/salva/saivage-v3).
