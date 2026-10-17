# Astra architecture and lifecycle review

Reviewer: `openai/gpt-6-astra`, session `ses_eb45f7a82fferjDsCiiNcS62kH`.
Snapshot: `701320b6c8c2e1f83a00b0e5a8b8ac8bc7a6f657`.
This is a faithful condensed receipt of the returned independent review, not a
new execution plan. Findings remain allegations for consolidated critical triage.

## Verdict and limits

**No confirmed NEW findings.** The reviewer confirms outstanding defects already
covered by minimal U13; no additional architecture programme is justified.
Read-only inspection of instructions, SPEC, PLAN, current metaplan, runtime,
packaging, prior findings, inventory and selected fixtures. No tests, live state,
services, edits or credentials. Source traces are not fresh runtime proof.
Documentation and containment were not exhaustively independently re-audited.

## Strengths

Pure/native separation is real. The handler protects adapters/partial writes and
returns lifecycle status/trailing bytes without closing handles. Guardian owns
creation from inception, avoiding registration gaps. Existing generations,
commit-time consumption, checked capacities and monotonic deadlines are useful
boundaries to repair rather than replace.

## Reported findings (all existing U13)

Paths below refer to the pinned snapshot; later live repairs require reconciliation.

| Priority | Existing ID | Source evidence | Failure and smallest proposed correction |
| --- | --- | --- | --- |
| High | F02 | [guardian.lua](../../../lua_repl_mcp/guardian.lua#L24), lines24–64,119–125,172–175,190–195; [worker_supervisor.lua](../../../lua_repl_mcp/worker_supervisor.lua#L45),45–46 | Bulk report blocks commands, retains/retransmits results and shifts allocation startup origin. Separate small control, one-time result/ack, original deadlines and disposal independent of bulk. Specific resumability only if measured necessary, not a universal codec. |
| High | F03 | [protocol.lua](../../../lua_repl_mcp/protocol.lua#L35),35; [contracts.lua](../../../lua_repl_mcp/contracts.lua#L38),38–45; [codec.lua](../../../lua_repl_mcp/codec.lua#L209),209–210; [worker_supervisor.lua](../../../lua_repl_mcp/worker_supervisor.lua#L95),95–100 | Hidden defaults and serialize-to-clone reject admitted representation/depth. Thread effective options, raw validate/copy, preserve original JSON data. Small envelope calculations rather than span extraction/general serialization framework. |
| High | F04 | [manager.lua](../../../lua_repl_mcp/manager.lua#L140),140–145,200–206,257–265 | Uncommitted expired wait can report running after fatal disposal and lose explanation. Recorded fatal outcome takes precedence; no new state machine. |
| High | F08/F13 | [protocol.lua](../../../lua_repl_mcp/protocol.lua#L49),49–74; [manager.lua](../../../lua_repl_mcp/manager.lua#L159),159–174,285–287 | Duplicate ID asserts or bypasses ownership; completed cancellation releases reservation before commitment. Guard all ID-bearing dispatch with existing map; retain until enqueue, completed cancellation inert. No replacement registry. |
| Medium | F13 | [worker_supervisor.lua](../../../lua_repl_mcp/worker_supervisor.lua#L122),122–125; [guardian.lua](../../../lua_repl_mcp/guardian.lua#L153),153–157; [manager.lua](../../../lua_repl_mcp/manager.lua#L186),186–196 | Distinguish guardian timely validation, manager application and public commitment. Pre-application kill can freeze disposal; guardian validation does not defeat every kill. Clarify existing transitions, no event journal. |
| High | F06/F09 | [evaluator.lua](../../../lua_repl_mcp/evaluator.lua#L8),8,20–23 | Unpack fails outside protection; missing/throwing debug breaks import/error recovery. Protect preparation and invocation, marker immediately before chunk, optional protected traceback. No argument cap or typed framework. |
| High | F01 | [codec.lua](../../../lua_repl_mcp/codec.lua#L77),77–79; [evaluator.lua](../../../lua_repl_mcp/evaluator.lua#L34),34–48 | Comma locale can turn one fractional return into two integers. Codec-local numeric conversion preserving host locale, not global locale mutation/codec replacement. |
| Medium | F05/F07 | [worker_main.lua](../../../lua_repl_mcp/worker_main.lua#L13),13–36; [worker_protocol.lua](../../../lua_repl_mcp/worker_protocol.lua#L61),61; [manager.lua](../../../lua_repl_mcp/manager.lua#L151),151–155,246–250; [protocol.lua](../../../lua_repl_mcp/protocol.lua#L25),25–29 | Wrong cwd cause, lost observed exits and generic schema-invalid failures. Contextual existing constructors and explicit mapping, not typed failure subsystem. |

## Proposed scoped validation

- Installed guardian: blocked/partial bulk, largest legal record, control calls,
  manager-only death and original deadlines. Latency remains unmeasured.
- Tight custom capacities, escaped/short-number input, depth, immutable accepted
  input/fresh tables and real worker execution.
- Fatal/wait/commit/two-waiter and duplicate-ID/cancel/reuse/enqueue permutations.
- Large argument tuple without execution witness then success; absent/failing
  traceback; exact fractional values/return counts in C and available comma locale.
- Actual per-tool errors against schemas; distinct cwd/stdio/startup EOF and
  observed exit/signal causes, including preservation through cleanup.

Confidence is high for inspected source dependencies, conditional on locale
availability for locale reproduction. This does not certify repairs or acceptance.

## Historical baggage and evolutionary bias

Full-state retransmission, command/report lockstep, serialization-as-copy and
hidden defaults have concrete failure traces and merit removal. Guardian,
generations, commitment, strict conversion and progressive disposal are owner
requirements or necessary safety mechanisms. Their size alone is not an objection.
Complete minimal U13 rather than import superseded machinery or ritual gates.
