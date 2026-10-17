# F07 — Failure provenance lost or invalid

Medium; diagnostics/contracts; cross-cutting worker/guardian/manager. Observed
exit code/signal and startup diagnostics are dropped; cwd failures misclassified;
private reasons leak into public enums and transport failures claim execution stage.

Evidence: [public mapping](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/manager.lua#L9-L12),
[worker setup](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/worker_main.lua#L14-L36).
See [plan](F07-failure-provenance/03-plan-r2.md).
