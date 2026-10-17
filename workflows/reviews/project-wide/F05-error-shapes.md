# F05 — Generic failures violate tool schemas

Medium; public protocol conformance; shared direct/managed wrappers. Invalid
`repl_close` arguments and response-overflow fallbacks use execution-error shapes
where operation errors are required, adding forbidden status/missing metadata.

Evidence: [generic wrapper](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/protocol.lua#L25-L29).
See [plan](F05-error-shapes/03-plan-r1.md).
