# Subsystem map

Baseline: `8383c03e1d1b38fb33a0573f80aeecdf179673ee`. Paths below are relative
to the repository root; this is work evidence, never a public site input.

| Layer | Key sources | Surface and dependencies |
| --- | --- | --- |
| Public contracts | [SPEC](../../../docs/SPEC.md), [schemas](../../../docs/schemas/api.json), [examples](../../../docs/MCP_EXAMPLES.md) | Normative managed/direct behaviour, conversion and lifetime limits |
| Values/evaluation | [codec](../../../lua_repl_mcp/codec.lua), [contracts](../../../lua_repl_mcp/contracts.lua), [evaluator](../../../lua_repl_mcp/evaluator.lua), [limits](../../../lua_repl_mcp/limits.lua) | Pure-Lua JSON/arguments, execution in existing globals, strict all-or-nothing result conversion |
| Direct attachment | [handler](../../../lua_repl_mcp/handler.lua), [protocol](../../../lua_repl_mcp/protocol.lua), [framing](../../../lua_repl_mcp/framing.lua) | Blocking host adapters, MCP dispatch, close acknowledgement and trailing-byte handoff; no POSIX imports |
| Managed RPC | [server](../../../lua_repl_mcp/server.lua), [client transport](../../../lua_repl_mcp/client_transport.lua), [manager](../../../lua_repl_mcp/manager.lua) | Nonblocking stdio, admission, session/execution identity, result consumption, deadlines and cancellation |
| Guardian | [guardian](../../../lua_repl_mcp/guardian.lua), [private channel](../../../lua_repl_mcp/guardian_channel.lua) | Independent owner of worker spawning/reaping, private liveness and bounded relay, manager death disposal |
| Native workers | [supervisor](../../../lua_repl_mcp/worker_supervisor.lua), [POSIX](../../../lua_repl_mcp/worker_posix.lua), [worker](../../../lua_repl_mcp/worker_main.lua), [wire](../../../lua_repl_mcp/worker_protocol.lua) | Exec/startup/file creation, process identities, TERM/KILL escalation, pure evaluator invocation |
| Installation | [rockspec](../../../lua-repl-mcp-0.1.0-1.rockspec), [entrypoint](../../../lua-repl-mcp) | LuaRocks local installation, pinned luaposix, installed worker resolution |
| User documentation | [README](../../../README.md), [LLM guide](../../../README-IF-YOR-ARE-AN-AI.md), [website sources](../../../site-docs/) | User-first functional guides, trusted execution, schema downloads, only attribution names development system |
| Website build | [configuration](../../../mkdocs.yml), [tests](../../../tests/) | Local strict build, allowlisted sources, prefix links/browser/examples; no publication |
| Validation | [tests](../../../tests/), [contract checker](../../../docs/check_contracts.py), [evidence](../../../docs/validation/) | Deterministic boundary ordering plus real POSIX/live MCP/installed-package trials; evidence applicability is explicit |

Review dependencies run from contracts/value boundaries to attachment and
managed ownership; transport/lifecycle changes require installed and real-client
requalification. Documentation must describe delivered behaviour independently
of historical work narratives.

## Required review lens

For every retained restriction, interface, constant and gate, distinguish an
explicit owner requirement, demonstrated correctness need, current implementation
limitation, bounded-release choice or historical accident. Compare focused fixes
with a proportionate one-level-up alternative; prior approval and sunk effort
are not correctness evidence. Challenge added machinery without weakening genuine
cleanup, side-effect honesty or evidence limits.
