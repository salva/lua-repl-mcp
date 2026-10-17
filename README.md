# Lua REPL MCP

Execute Lua through MCP with persistent state, either in independent managed
sessions or inside an existing Lua application.

## What you can do

- Keep globals and functions between calls instead of rebuilding context.
- Run independent sessions concurrently through one MCP stdio connection.
- Pass JSON arguments and receive explicit Lua return values as JSON.
- Start long-running work asynchronously, then poll without executing it again.
- Embed a pure-Lua handler to expose an application's existing globals and APIs.

**Trusted code only: this is not a sandbox.** Lua has the host process's
privileges. Printed output is not automatically captured; use explicit `return`
to obtain results.

## Choose an interface

| Interface | Use it when | State and lifecycle |
| --- | --- | --- |
| Standalone session manager | Connecting a normal MCP client | One worker process per session; explicit kill disposes of its state |
| Embedded handler | Exposing an existing Lua application's APIs | Runs synchronously in the host interpreter; close returns control to the host |

Globals persist within a session or host interpreter; top-level locals do not.
Managed sessions belong to their client connection, not to durable storage.
Waiting is distinct from execution: a wait timeout leaves work running, whereas
cancellation or a hard execution timeout destroys the associated managed session.

## Install and get a first result

The standalone manager uses Lua 5.4 and POSIX facilities. From a local checkout,
install using LuaRocks and configure your MCP client to launch the installed
`lua-repl-mcp` executable over stdio. The package is not claimed to be publicly
available on LuaRocks.

Follow the [installation and usage guide](README-IF-YOR-ARE-AN-AI.md), which
includes the exact local-source install commands, environment setup, tool calls,
expected results and cleanup. It is written explicitly for LLM clients but also
provides a copyable first-use path for human users.

After initialization and tool discovery, `session_execute` with arguments
`{"code":"answer = 42; return answer","wait_timeout_ms":1000}` allocates a session.
Keep its returned `session_id`; a completed response contains `values: [42]`.
If pending, call `session_wait` with that ID instead of resubmitting the code.
Use `session_kill` when finished. Results are consumed once, so save returned
payloads rather than expecting a later wait to repeat them.

## Usage and reference

- [Task-oriented documentation](https://salva.github.io/lua-repl-mcp/)

- [Install, execute, poll, recover and embed](README-IF-YOR-ARE-AN-AI.md)
- [MCP initialization and wire examples](docs/MCP_EXAMPLES.md)
- [Tool input/output schemas](docs/schemas/api.json)

**Status:** development candidate, not a stable release. Known correctness and
lifecycle issues are being repaired; independently validate important results
and do not rely on it for production workloads yet.

Built with [Saivage](https://github.com/salva/saivage-v3).
