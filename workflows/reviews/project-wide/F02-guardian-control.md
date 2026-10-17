# F02 — Guardian control starvation

High; lifecycle boundedness; architectural across guardian, manager and transport.
Bulk retained-result report completion gates commands, delaying kill and startup
deadlines; consumed payloads are repeatedly relayed. Mocked noncompletion violates
deadlines; the full legal-load real-process case remains to be qualified.

Evidence: [guardian lockstep](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/guardian.lua#L145-L193).
See [plan](F02-guardian-control/03-plan-r3.md), [arbitration](F13-completion-arbitration.md).
