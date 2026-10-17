# F03 — Hidden/bypassed limit defaults

High; contract/configuration consistency; cross-cutting decoding, validation,
evaluation and response wrapping. Valid escaped arrays and depth overrides are
rejected by hidden clone defaults; deep valid results can lose the JSON-RPC result.

Evidence: [protocol](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/protocol.lua#L13-L81),
[argument cloning](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/contracts.lua#L38-L45).
See [plan](F03-limit-context/03-plan-r3.md).
