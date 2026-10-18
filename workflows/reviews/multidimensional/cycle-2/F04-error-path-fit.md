# F04 — Generated error pointer exceeds transport budget

Reviewer C2-Q01; high importance, error/codec/private framing boundary.
**accept**, confirmed by skeptical source triage. Native exit not rerun. Source
[codec.lua:84](../../../../lua_repl_mcp/codec.lua#L84)–86,143–144;
[evaluator.lua:50](../../../../lua_repl_mcp/evaluator.lua#L50)–51;
[errors.lua:37](../../../../lua_repl_mcp/errors.lua#L37)–39;
[worker_main.lua:10](../../../../lua_repl_mcp/worker_main.lua#L10)–11,57–64.

Pure probe: legal floor I256/V16/diagnostic49/worker1049142, result key1,100,000
bytes. Recoverable serialization error contains1,100,010-byte path and49-byte
message, fails worker encoding. Worker exit is source inference; next pure
evaluation succeeds. Distinct from previously fixed diagnostic-message retention.

Focused option: omit optional path if it cannot fit safe metadata budget or select
a truthful fitting ancestor; keep recoverable code/completed/effects and required
diagnostic-loss semantics. Alternative budget pointer generation before allocation
only if needed, not full serializer redesign. Never truncate to a false pointer,
restrict public keys, enlarge capacities or mask original failure as worker death.
Pure exact-floor/private-frame and real managed recovery/side-effect tests; include
large ASCII/escaped keys and maximum legal ID response fit as relevant.
