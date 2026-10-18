# F06 — Fixed discovery wrappers consume user depth

Reviewer C2-D02; medium importance, local protocol/handler. **Accept focused fix**,
confirmed by skeptical structural triage. Source
[handler.lua:35](../../../../lua_repl_mcp/handler.lua#L35)–42;
[protocol.lua:76](../../../../lua_repl_mcp/protocol.lua#L76);
[direct_schemas.lua:2](../../../../lua_repl_mcp/direct_schemas.lua#L2).

Valid user depth1 produces output bound5 but tools/list needs at least6 container
levels. Encoding substitutes wrong response shape. Source structural trace,
not reviewer-executed reproduction. Fixed schema depth must not restrict user data.

Focused option: actual independent protocol/schema allowance alongside validated
per-user-value depth. Alternative larger minimum D weakens contract and is rejected.
Avoid universal magic wrapper constant or arbitrary deep encoding escape hatch.
Pure memory-adapter initialize/list at D1 validates advertised shape and successful
shallow execution; D/D+1 argument/result tests retain user-bound enforcement.
