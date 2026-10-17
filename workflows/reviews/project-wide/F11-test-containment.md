# F11 — Test discovery and watchdog containment gaps

Medium; validation reliability; test infrastructure cross-cutting. The glob
`u[1-7]*.lua` also includes U12 process fixtures, bypassing wrappers; readiness-only
readline and unbounded polling loops can hang or leave descendant fixtures.

Evidence: [runner](https://github.com/salva/lua-repl-mcp/blob/8383c03/tests/u9_suite.py#L19-L34),
[partial read](https://github.com/salva/lua-repl-mcp/blob/8383c03/tests/u2_live.py#L36-L38).
See [plan](F11-test-containment/03-plan-r2.md).
