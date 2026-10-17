# F08 — Invalid envelopes can tear down sessions

Medium; protocol robustness; ingress/manager. Duplicate outstanding IDs escape
as assertions into connection-wide cleanup; JSON false is misclassified as parse
failure rather than invalid request.

Evidence: [ingress](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/protocol.lua#L35-L40),
[binding](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/manager.lua#L159-L162).
See [plan](F08-ingress-robustness/03-plan-r2.md).
