# F13 — Completion authority needs an explicit rule

Medium; contract ambiguity; design spans manager/guardian and tests. Guardian
validated completion before deadline defeats stale timeout, while a kill accepted
by the manager before relay discards that completion. Existing tests endorse both
without a sufficiently explicit definition of recorded completion.

Evidence: [decision sites](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/manager.lua#L140-L149),
[completion contract](https://github.com/salva/lua-repl-mcp/blob/8383c03/docs/SPEC.md#L1218-L1235).
See [plan](F13-completion-arbitration/03-plan-r3.md), [control progress](F02-guardian-control.md).
