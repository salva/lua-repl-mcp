# F05 — Effective input context is lost at remaining boundaries

Reviewers C2-A04/C2-D01/C2-Q02/C2-Q03; medium importance, cross-cutting existing F03.
**Accept combined**, confirmed by skeptical source triage; do not count duplicate
reports as separate defects. Source
[handler.lua:23](../../../../lua_repl_mcp/handler.lua#L23),57,63;
[protocol.lua:43](../../../../lua_repl_mcp/protocol.lua#L43),89;
[evaluator.lua:11](../../../../lua_repl_mcp/evaluator.lua#L11)–14,67–71;
[manager.lua:100](../../../../lua_repl_mcp/manager.lua#L100)–106;
[guardian.lua:221](../../../../lua_repl_mcp/guardian.lua#L221)–224;
[worker_supervisor.lua:39](../../../../lua_repl_mcp/worker_supervisor.lua#L39)–44.

Distinct branches: configured handler input uses undefined global downstream;
embedded validation recharges admitted expanded data; creation rechecks canonical
bytes across manager/guardian/supervisor; from_json reads unrelated ambient
admitted_input_bytes. Pure reviewer probes demonstrate raised-input ping rejection,
224-byte I256 tabbed cwd rejection and from_json global collision. Newline expanded
embedded execution is a proposed source trace, not executed by docs reviewer.

Focused option: local effective input binding, explicit existing admission context
through actual boundaries, raw fresh structural validation without canonical
re-admission for network data. Preserve canonical byte counting for actual library
calls and snapshot immutability. Remove stray from_json global if no explicit
option is needed. Alternative reuse complete original validated request for
explicit and implicit creation; choose smaller coherent change. Establish admitted
origin at actual ingress, not a freely caller-supplied bypass flag.
No token slicing/provenance framework,
fixed16MiB workaround, metatable invocation or new public path/argument cap.
Regress above-default handler input, ambient collisions, expansion-prone default
embedding and tight-floor managed create through actual guardian/native path.
