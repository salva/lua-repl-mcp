# F06 — Argument unpack escapes protection

Medium; evaluator robustness; both interfaces. About 2MiB of positional zero
arguments can make `table.unpack` throw before xpcall starts and terminate an
otherwise usable attachment/worker without executing the code.

Evidence: [invocation](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/evaluator.lua#L20-L22).
See [plan](F06-invocation-boundary/03-plan-r2.md).
