# Install and get your first result

Choose the manager for a normal MCP client. To expose an existing application's
Lua state instead, follow [embedding](embedding.md).

## Prerequisites

Use POSIX, Lua 5.4, its development headers, LuaRocks and a C compiler. Native
luaposix is pinned to 36.3-1 (bit32 is a transitive native dependency). Do not load
Lua 5.4 native modules in Lua 5.5. Obtain the local-source checkout; a public
LuaRocks release is not assumed. Dependency installation may need network access.

## Install from the repository root

```sh
export ROCKS_TREE="$PWD/.local/rocks"
luarocks --lua-version=5.4 --tree="$ROCKS_TREE" make lua-repl-mcp-0.1.0-1.rockspec
eval "$(luarocks --lua-version=5.4 --tree="$ROCKS_TREE" path)"
```

Configure your client's stdio server entry with the **absolute** path
`$ROCKS_TREE/bin/lua-repl-mcp`, no arguments, and the resulting `PATH`, `LUA_PATH`
and `LUA_CPATH`. Your client may not expand shell variables: substitute the actual
path. Preserve the environment for worker processes too. Use the client's own
configuration syntax, not a guessed shared format. Running that executable in a
terminal waits for MCP input; it is not an interactive Lua prompt.

## Discover and execute

Your MCP client initializes, sends `notifications/initialized`, then calls
`tools/list`. See [complete wire examples](../docs/MCP_EXAMPLES.md#initialize).
The manager advertises five `session_*` tools; an embedded host advertises two
`repl_*` tools instead. Do not invent a reset or task-ID tool.

The following JSON is **tool arguments**, not JSON-RPC. Call `session_execute`:

```json
{"code":"answer = 42; return answer","wait_timeout_ms":1000}
```

Save the returned `session_id`. A completed result has `values: [42]`.
If pending, wait on that ID rather than executing the code again.

Call `session_execute` again, replacing the placeholder with the returned ID:

```json
{"session_id":"<returned session_id>","code":"return answer","wait_timeout_ms":1000}
```

Expect `[42]`: the global survived. When finished call `session_kill`:

```json
{"session_id":"<returned session_id>"}
```

This disposes of state. Inspect `process_exit_confirmed` and any cleanup warning.
Use `structuredContent` as the result; compatibility text is the same payload,
not a second result. Check errors/status before reading `values`.

## Next task and recovery

Try a [stateful counter and asynchronous polling](manager.md). If a chunk errors,
inspect `session_usable` before reusing state; effects before the error may remain.
If a client times out or disconnects, do not blindly replay state-changing code.
The [LLM guide](../README-IF-YOR-ARE-AN-AI.md) gives the same installation journey
and an independent pure-Lua copy/path/adapter recipe.
