# Astra code quality and simplicity review

Reviewer `openai/gpt-6-astra`, session `ses_eb45f5ab0ffeZOdYMMnDTpbAdQ`.
Pinned source `701320b`; faithful condensed receipt, not automatic acceptance.
All handwritten runtime Lua modules were inspected, concentrating on evaluation,
conversion, validation, errors and backend coupling. No tests/process experiments,
edits, services or credentials; generated schemas and all tests/docs were not
independently audited. Revision identity was supplied rather than verified by
the reviewer. Reproductions are proposed, not measured runtime results.

## Findings

- **Existing F03/F01, high:** repeated encode/decode validation at contracts,
  worker protocol, worker main, evaluator and public wrapping loses effective
  limits and repeatedly allocates/expands representations. See
  [contracts.lua:38](../../../lua_repl_mcp/contracts.lua#L38),
  [worker_main.lua:49](../../../lua_repl_mcp/worker_main.lua#L49),
  [codec.lua:207](../../../lua_repl_mcp/codec.lua#L207).
  Use current raw-copy/effective-limit repair and remove immediately redundant
  validation without removing actual trust-boundary checks. A small separation
  of field validation/copy is preferable to a generic validated-value hierarchy.
- **Existing F06/F09, high:** [evaluator.lua:8](../../../lua_repl_mcp/evaluator.lua#L8)
  and17–23 require debug and unpack before protection. Protect local invocation
  preparation, truthful entry marker and optional traceback. No typed subsystem
  or arbitrary argument cap. Test absent/throwing debug, large tuple and recovery.
- **New CQ-N01, medium:** [errors.lua:5](../../../lua_repl_mcp/errors.lua#L5)
  and29–46 allocate one table entry per diagnostic character and concatenate the
  complete cleaned diagnostic before clipping to the default65536-byte budget.
  Proposed `error(string.rep('x',16*1024*1024),0)` produces millions of temporary
  entries; invalid bytes expand further. Allocation amplification is source-proven;
  actual memory exhaustion/latency is not measured. Smallest repair is one
  budget-aware cleaning helper, retaining bounded UTF-8-safe output while scanning
  remaining input as needed for accurate flags. Test ASCII/multibyte/invalid bytes
  beyond prefix, combined message/traceback budget, notice/flags and recovery;
  measure allocation separately. No general streaming codec or execution quota.
- **Existing F05/F07, medium:** generic failure shaping and cause collapse lose
  tool context/observed exits: [protocol.lua:25](../../../lua_repl_mcp/protocol.lua#L25),
  [worker_main.lua:13](../../../lua_repl_mcp/worker_main.lua#L13),
  [manager.lua:245](../../../lua_repl_mcp/manager.lua#L245).
  Use existing context-aware error constructors and explicit cause mapping; no
  parallel exception taxonomy. Validate actual failures against advertised schemas.
- **Existing F02/F03, high:** guardian mirror invokes native execute, encodes a
  worker command, discards pending bytes, then queues original input for another
  encoding: [guardian.lua:81](../../../lua_repl_mcp/guardian.lua#L81),127–132;
  [worker_supervisor.lua:92](../../../lua_repl_mcp/worker_supervisor.lua#L92).
  Separate short generation/state transition from transport encoding locally;
  encode at the owning boundary. Test no discarded command encoding or repeated
  snapshots. No generic backend/event framework. Cost magnitude is unmeasured.

## Strengths and historical baggage

Pure/native separation, explicit returns/counts, raw traversal/cycle and number
checks, safe error description, preview/commit ownership and checked capacities
are meaningful. Preserve owner-mandated globals, no capture/sandbox, guardian,
capacities and disposal policy. POSIX/Lua5.4 scope is not a compatibility defect.
Stable ordering/newline framing are bounded choices. Serialize-to-clone, repeated
validation and discarded mirror encoding have concrete costs, not merely age.
Fixed wrapper/queue constants are implementation choices, not universal mandates.
Current U13 rightly rejects typed-error/registry/universal-codec prescriptions.
Recommend current three-batch plan plus local diagnostic formatting correction;
no broader rewrite. Confidence high in source traces, medium in new issue's
operational severity pending measurement.
