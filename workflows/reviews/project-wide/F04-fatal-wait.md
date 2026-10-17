# F04 — Fatal outcome hidden by expired wait

Medium; state-machine ordering; local manager/public response impact. An outstanding
execute can report running with terminated/unusable session after hard timeout and
cleanup, losing the only retrievable fatal outcome.

Evidence: [response preview](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/manager.lua#L257-L265).
See [plan](F04-fatal-wait/03-plan-r1.md).
