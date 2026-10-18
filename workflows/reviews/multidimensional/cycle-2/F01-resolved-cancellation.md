# F01 — Resolved operation cancellation

Reviewer C2-A01; high importance, local policy boundary. **Accept focused fix**,
confirmed by independent skeptical triage; native effect not rerun. Source
[manager.lua:54](../../../../lua_repl_mcp/manager.lua#L54)–58,142–146,189–203;
[client_transport.lua:143](../../../../lua_repl_mcp/client_transport.lua#L143)–161.

Busy rejection owns a session without an execution. Cancelling its uncommitted
response may kill a different running execution; completed creation has same guard
gap. This is residual F08, not permission to change active cancellation semantics.

Focused option: local resolved-operation predicate using existing fields.
Alternative explicit completion state affects more transitions and is unnecessary
unless predicate cannot distinguish them safely. Preserve destructive cancellation
for real active execution even if its pending zero-wait response is prepared;
preserve accepted kill cleanup and inert completed-response reservations.
Regress busy B cancel while A runs, resolved no_execution wait cancel after later
work starts, uncommitted successful creation cancel, active
zero-wait cancellation, terminal-result cancellation and commitment/reuse.
Source-derived scenario, not native reproduction. Do not add a state framework.
