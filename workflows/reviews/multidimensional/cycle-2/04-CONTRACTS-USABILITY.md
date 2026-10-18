# Cycle 2 — public contracts and user journeys

Reviewer: fresh `openai/gpt-6-astra`, session `ses_eb21d8fceffe5e61gFiaMRJfjw`.
Source pin: `a600754a4cfb06983c278f633bd262721588f860`.
This condensed receipt preserves the returned claims/limits; findings await
consolidated skeptical triage, not automatic acceptance or implementation.

## Verdict and inspection limits

Two residual embedded-handler contract defects alleged, both within existing F03
effective-limit work. No new architecture/features proposed. Source inspection
only: no edits, subprocesses, install/build/browser tests or runtime probes.
Orchestrator-supplied publication checks are not reviewer runtime evidence.

## C2-D01 — embedded input context lost between framing and validation

**Residual prior F03; medium severity; high source confidence.**

References relative to the pinned repository:
[embedding.md:60](../../../../site-docs/embedding.md#L60)–63;
[handler.lua:23](../../../../lua_repl_mcp/handler.lua#L23),57;
[protocol.lua:43](../../../../lua_repl_mcp/protocol.lua#L43),89;
[codec.lua:263](../../../../lua_repl_mcp/codec.lua#L263),281–294;
[contracts.lua:48](../../../../lua_repl_mcp/contracts.lua#L48);
[evaluator.lua:13](../../../../lua_repl_mcp/evaluator.lua#L13);
[SPEC.md:1107](../../../../docs/SPEC.md#L1107)–1115.

Configured framing uses input_bytes, but protocol configuration references an
undefined input_bytes variable, falling back to16MiB decode default. Direct
validation and evaluator validation lack admitted-wire byte context and charge
canonical expansion again during cloning.

Proposed, **unexecuted**, reproductions:

1. input_bytes=32MiB, initialized handler, approximately17MiB ASCII Lua comment
   plus small return. Frame admitted, decoder rejects hidden16MiB ceiling.
2. Default options, `local x=...; return #x`, one3,000,000-newline string represented
   by JSON backslash-n: approximately6MB admitted wire, conservative clone charges
   six bytes/newline (>18MB), rejects before execution.

Smallest repair: propagate effective input limit and admitted-network versus
library-origin validation context through both passes, reusing raw-copy/admitted
input logic. A one-line variable fix alone does not resolve the expansion case.
Alternative fixed16MiB/canonical restriction is rejected as weakening approved
wire-byte semantics, not an acceptable simplification. No generic new framework.

## C2-D02 — user depth restricts fixed discovery structures

**Residual prior F03; medium severity; high structural confidence.**

References: [embedding.md:69](../../../../site-docs/embedding.md#L69)–89;
[limits.lua:7](../../../../lua_repl_mcp/limits.lua#L7)–14;
[handler.lua:35](../../../../lua_repl_mcp/handler.lua#L35)–42;
[protocol.lua:76](../../../../lua_repl_mcp/protocol.lua#L76);
[direct_schemas.lua:2](../../../../lua_repl_mcp/direct_schemas.lua#L2).

Proposed, **unexecuted**, reproduction: valid evaluator.max_depth=1, initialize,
tools/list. Output bound is D+4=5, while discovery already has six containers at
response/result/tools/tool/inputSchema/required. Encoding fails and substitutes
a tool-result-shaped limit error instead of required tools list.

Smallest repair: actual independent fixed protocol/schema depth allowances,
preserving per-user-value policy. One pure-handler depth1 discovery regression.
Reject increasing minimum user depth: schema wrappers must not dictate user policy.

## Fixed findings and strengths

- Previous source link errors fixed: repository-correct links and explicit
  allowlisted stage rewriting in build_website.py25–36.
- Embedded evaluator keys/defaults/units/diagnostic minimum/example documented
  at embedding.md65–85: prior DOC01 closed at this snapshot.
- Invalid repl_close arguments now use correct error-only shape, protocol89–92.
- Source/registry install status, independent pure copy, lifecycle/side effects,
  development-candidate status and public/work separation remain clear.

## Historical baggage and evolutionary bias

Residual handler-limit propagation requires focused fixes, not superseded machinery.
Preserve owner byte capacities, blocking embedding, independent process ownership
and lifecycle semantics. Accidental stricter limits and old approval counts are
not requirements. No process/platform/latency/publication acceptance established.
