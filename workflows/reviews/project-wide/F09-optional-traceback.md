# F09 — Optional debug library required at import

Medium; embedding compatibility; pure evaluator import path. Removing optional
`debug` makes handler import fail before it can provide traceback-when-available.

Evidence: [traceback capture](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/evaluator.lua#L8).
See [plan](F09-optional-traceback/03-plan-r1.md).
